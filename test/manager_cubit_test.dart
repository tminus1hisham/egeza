import 'package:flutter_test/flutter_test.dart';

import 'package:egesha/blocs/manager_cubit.dart';
import 'package:egesha/blocs/manager_state.dart';
import 'package:egesha/core/api/parking_iq_api.dart';
import 'package:egesha/models/api_models.dart';
import 'package:egesha/models/parking_session.dart';
import 'package:egesha/models/vehicle.dart';

void main() {
  group('ManagerCubit location access', () {
    test('keeps only the locations the manager endpoints let it read',
        () async {
      final api = _ManagerFakeApi(
        locations: const [_sarit, _cbd],
        // Sarit is assigned; the CBD site 403s the way the API does for a
        // location this manager is not on.
        forbiddenLocationIds: {_cbdId},
      );
      final cubit = ManagerCubit(api: api);

      await cubit.start(interval: const Duration(minutes: 5));

      expect(cubit.state.locations.map((l) => l.id), [_saritId]);
      expect(cubit.state.selectedLocationId, _saritId);
      expect(cubit.state.locationName, 'Sarit');
      expect(cubit.state.hasNoAssignments, isFalse);

      await cubit.close();
    });

    test('reports no assignments rather than an error when nothing is readable',
        () async {
      final api = _ManagerFakeApi(
        locations: const [_sarit, _cbd],
        forbiddenLocationIds: {_saritId, _cbdId},
      );
      final cubit = ManagerCubit(api: api);

      await cubit.start(interval: const Duration(minutes: 5));

      expect(cubit.state.hasNoAssignments, isTrue);
      expect(cubit.state.errorMessage, isNull);
      expect(cubit.state.isLoading, isFalse);

      await cubit.close();
    });

    test('keeps a location whose probe failed for a reason other than access',
        () async {
      // A flaky network must not silently hide a site the manager runs.
      final api = _ManagerFakeApi(
        locations: const [_sarit],
        activeError: const ApiException('Bad gateway', statusCode: 502),
      );
      final cubit = ManagerCubit(api: api);

      await cubit.start(interval: const Duration(minutes: 5));

      expect(cubit.state.locations.map((l) => l.id), [_saritId]);

      await cubit.close();
    });
  });

  group('ManagerCubit daily figures', () {
    test('counts today only, and counts vehicles rather than entries',
        () async {
      final now = DateTime.now();
      final api = _ManagerFakeApi(
        locations: const [_sarit],
        sessions: [
          // KBR656Z came in twice today — one vehicle, two entries.
          _session('s-1', 'KBR656Z', start: now.subtract(const Duration(hours: 6)), paid: 200),
          _session('s-2', 'KBR656Z', start: now.subtract(const Duration(hours: 2)), paid: 100),
          _session('s-3', 'KDA123X', start: now.subtract(const Duration(hours: 1)), paid: 50),
          // Yesterday's session must not be counted at all.
          _session('s-old', 'KCC999Y',
              start: now.subtract(const Duration(days: 1)), paid: 900),
        ],
        liveSessions: [
          _session('s-3', 'KDA123X',
              start: now.subtract(const Duration(hours: 1)), active: true),
        ],
      );
      final cubit = ManagerCubit(api: api);

      await cubit.start(interval: const Duration(minutes: 5));

      expect(cubit.state.entriesToday, 3);
      expect(cubit.state.vehiclesToday, 2);
      expect(cubit.state.stillParked, 1);

      await cubit.close();
    });

    test('folds in an active session the full list has not caught up with',
        () async {
      final now = DateTime.now();
      final api = _ManagerFakeApi(
        locations: const [_sarit],
        sessions: [_session('s-1', 'KBR656Z', start: now)],
        // The gate opened s-2 seconds ago; only the active endpoint has it.
        liveSessions: [
          _session('s-1', 'KBR656Z', start: now, active: true),
          _session('s-2', 'KDA123X', start: now, active: true),
        ],
      );
      final cubit = ManagerCubit(api: api);

      await cubit.start(interval: const Duration(minutes: 5));

      // s-1 appears in both lists and must be counted once.
      expect(cubit.state.entriesToday, 2);
      expect(cubit.state.stillParked, 2);

      await cubit.close();
    });

    test('sums settled payments received today and ignores the rest', () async {
      final now = DateTime.now();
      final api = _ManagerFakeApi(
        locations: const [_sarit],
        payments: [
          _payment('p-1', 400, 'SUCCESS', now),
          _payment('p-2', 250, 'COMPLETED', now),
          // Pending money is not takings.
          _payment('p-3', 999, 'PENDING', now),
          _payment('p-4', 999, 'FAILED', now),
          // Yesterday's takings belong to yesterday.
          _payment('p-5', 999, 'SUCCESS', now.subtract(const Duration(days: 1))),
        ],
      );
      final cubit = ManagerCubit(api: api);

      await cubit.start(interval: const Duration(minutes: 5));

      expect(cubit.state.revenueSource, ManagerRevenueSource.payments);
      expect(cubit.state.revenueToday, 650);
      expect(cubit.state.settledPaymentsToday, 2);
      expect(cubit.state.averagePaymentToday, 325);

      await cubit.close();
    });

    test('falls back to session amounts when payments are unavailable',
        () async {
      final now = DateTime.now();
      final api = _ManagerFakeApi(
        locations: const [_sarit],
        sessions: [
          _session('s-1', 'KBR656Z', start: now, cost: 300, paid: 300),
          _session('s-2', 'KDA123X', start: now, cost: 200, paid: 0),
        ],
        paymentsError: const ApiException('Forbidden', statusCode: 403),
      );
      final cubit = ManagerCubit(api: api);

      await cubit.start(interval: const Duration(minutes: 5));

      expect(cubit.state.revenueSource, ManagerRevenueSource.sessions);
      expect(cubit.state.revenueToday, 300);
      // The unpaid 200 is what the site is still owed.
      expect(cubit.state.outstandingToday, 200);

      await cubit.close();
    });

    test('reports occupancy against the site capacity', () async {
      final now = DateTime.now();
      final api = _ManagerFakeApi(
        locations: const [_sarit],
        liveSessions: [
          for (var i = 0; i < 30; i++)
            _session('a-$i', 'KAA00${i}A', start: now, active: true),
        ],
      );
      final cubit = ManagerCubit(api: api);

      await cubit.start(interval: const Duration(minutes: 5));

      expect(cubit.state.capacity, 300);
      expect(cubit.state.stillParked, 30);
      expect(cubit.state.occupancyRatio, closeTo(0.1, 0.0001));
      expect(cubit.state.freeSpaces, 270);

      await cubit.close();
    });
  });

  group('ManagerCubit refresh loop', () {
    test('picks up a car that drove in after the first reading', () async {
      final now = DateTime.now();
      final api = _ManagerFakeApi(
        locations: const [_sarit],
        // The access probe reads the first entry and the opening refresh the
        // second; the gate opens the session before the first poll.
        activeSessionScript: [
          const <ParkingSession>[],
          const <ParkingSession>[],
          [_session('s-1', 'KBR656Z', start: now, active: true)],
        ],
      );
      final cubit = ManagerCubit(api: api);

      await cubit.start(interval: const Duration(milliseconds: 20));
      expect(cubit.state.stillParked, 0);

      await expectLater(
        cubit.stream,
        emitsThrough(
          isA<ManagerState>().having((s) => s.stillParked, 'stillParked', 1),
        ),
      );

      cubit.stop();
      await cubit.close();
    });

    test('keeps the last known figures when a refresh cannot reach the API',
        () async {
      final now = DateTime.now();
      final api = _ManagerFakeApi(
        locations: const [_sarit],
        sessions: [_session('s-1', 'KBR656Z', start: now, paid: 120)],
        payments: [_payment('p-1', 120, 'SUCCESS', now)],
      );
      final cubit = ManagerCubit(api: api);

      await cubit.start(interval: const Duration(minutes: 5));
      expect(cubit.state.revenueToday, 120);

      api.failEverything = true;
      await cubit.refresh();

      expect(cubit.state.revenueToday, 120, reason: 'figures must not blank');
      expect(cubit.state.errorMessage, isNotNull);

      await cubit.close();
    });

    test('stop cancels further polling', () async {
      final api = _ManagerFakeApi(locations: const [_sarit]);
      final cubit = ManagerCubit(api: api);

      await cubit.start(interval: const Duration(milliseconds: 20));
      await Future<void>.delayed(const Duration(milliseconds: 30));
      cubit.stop();

      final callsAtStop = api.sessionCallCount;
      await Future<void>.delayed(const Duration(milliseconds: 120));
      expect(api.sessionCallCount, callsAtStop);

      await cubit.close();
    });
  });
}

const _saritId = 'loc-sarit';
const _cbdId = 'loc-cbd';

const _sarit = ParkingLocation(
  id: _saritId,
  name: 'Sarit',
  maxCapacity: 300,
  currentOccupancy: 1,
);
const _cbd = ParkingLocation(
  id: _cbdId,
  name: 'Nairobi CBD Parking',
  maxCapacity: 250,
);

ParkingSession _session(
  String id,
  String plate, {
  required DateTime start,
  double cost = 0,
  double paid = 0,
  bool active = false,
}) {
  return ParkingSession(
    id: id,
    locationName: 'Sarit',
    startTime: start,
    endTime: active ? null : start.add(const Duration(hours: 1)),
    cost: cost > 0 ? cost : paid,
    amountPaid: paid,
    status: active ? 'ACTIVE' : 'COMPLETED',
    vehicle: Vehicle(plateNumber: plate, type: 'Saloon', make: 'Toyota', model: 'Axio'),
    isActive: active,
  );
}

PaymentTransaction _payment(
  String id,
  double amount,
  String status,
  DateTime createdAt,
) {
  return PaymentTransaction(
    id: id,
    amount: amount,
    status: status,
    createdAt: createdAt,
    plateNumber: 'KBR656Z',
    locationId: _saritId,
  );
}

/// Stands in for the real client. Each manager endpoint can be told to fail the
/// way the API fails: 403 for an unassigned location, anything else for a fault.
class _ManagerFakeApi extends ParkingIqApi {
  _ManagerFakeApi({
    required this.locations,
    this.sessions = const [],
    this.liveSessions = const [],
    this.payments = const [],
    this.forbiddenLocationIds = const {},
    this.activeError,
    this.paymentsError,
    this.activeSessionScript,
  }) : super(debug: false);

  final List<ParkingLocation> locations;
  final List<ParkingSession> sessions;
  final List<ParkingSession> liveSessions;
  final List<PaymentTransaction> payments;
  final Set<String> forbiddenLocationIds;
  final Object? activeError;
  final Object? paymentsError;

  /// One entry per active-sessions call; the last is held once it runs out.
  final List<List<ParkingSession>>? activeSessionScript;

  bool failEverything = false;
  int sessionCallCount = 0;
  int activeCallCount = 0;

  @override
  bool get hasToken => true;

  @override
  Future<List<ParkingLocation>> fetchParkingLocations() async => locations;

  void _guard(String locationId) {
    if (failEverything) {
      throw const ApiException('Network unreachable');
    }
    if (forbiddenLocationIds.contains(locationId)) {
      throw const ApiException('Forbidden', statusCode: 403);
    }
  }

  @override
  Future<List<ParkingSession>> managerLocationSessions(String locationId) async {
    sessionCallCount++;
    _guard(locationId);
    return sessions;
  }

  @override
  Future<List<ParkingSession>> managerActiveLocationSessions(
    String locationId,
  ) async {
    _guard(locationId);
    if (activeError != null) throw activeError!;

    final script = activeSessionScript;
    final index = activeCallCount++;
    if (script == null) return liveSessions;
    return script[index < script.length ? index : script.length - 1];
  }

  @override
  Future<List<PaymentTransaction>> managerLocationPayments(
    String locationId,
  ) async {
    _guard(locationId);
    if (paymentsError != null) throw paymentsError!;
    return payments;
  }
}
