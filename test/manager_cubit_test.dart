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

  group('ManagerCubit owner (client) access', () {
    test('an owner reaches their property even though every /manager/* 403s',
        () async {
      // This is what a site owner actually looks like on this backend: they own
      // Sarit but are not assigned as its manager, so the probe finds nothing
      // and the whole owner view used to come up empty.
      final api = _ManagerFakeApi(
        locations: const [_sarit, _cbd],
        ownedLocations: const [_sarit],
        forbiddenLocationIds: {_saritId, _cbdId},
      );
      final cubit = ManagerCubit(api: api);

      await cubit.start(interval: const Duration(minutes: 5));

      expect(cubit.state.hasNoAssignments, isFalse);
      expect(cubit.state.locations.map((l) => l.id), [_saritId]);
      expect(cubit.state.selectedLocationId, _saritId);
      // Owned sites are listed outright, so the site list costs one call and
      // the manager routes are never asked.
      expect(api.clientLocationCallCount, 1);
      expect(api.sessionCallCount, 0);

      await cubit.close();
    });

    test('the figures come from the client endpoints, filtered to the site',
        () async {
      final now = DateTime.now();
      final api = _ManagerFakeApi(
        locations: const [_sarit, _cbd],
        ownedLocations: const [_sarit, _cbd],
        forbiddenLocationIds: {_saritId, _cbdId},
        clientSessionList: [
          _session('s-1', 'KBR656Z',
              start: now.subtract(const Duration(hours: 2)),
              active: true,
              locationId: _saritId),
          // Paid at the machine but still on the ground: parsing turns
          // isActive off for it, so anything counting on that flag loses a car.
          _session('s-2', 'KDA123X',
              start: now.subtract(const Duration(hours: 1)),
              active: true,
              paid: 150,
              locationId: _saritId),
          _session('s-3', 'KCC999Y',
              start: now.subtract(const Duration(hours: 3)),
              paid: 200,
              locationId: _saritId),
          // The client's other site — not this screen's numbers.
          _session('s-4', 'KDD111A',
              start: now, active: true, locationId: _cbdId),
        ],
        clientPaymentList: [
          _payment('p-1', 200, 'SUCCESS', now),
          _payment('p-2', 800, 'SUCCESS', now, locationId: _cbdId),
        ],
      );
      final cubit = ManagerCubit(api: api);

      await cubit.start(interval: const Duration(minutes: 5));

      expect(cubit.state.stillParked, 2);
      expect(cubit.state.entriesToday, 3);
      expect(cubit.state.revenueSource, ManagerRevenueSource.payments);
      expect(cubit.state.revenueToday, 200);
      // One estate-wide call serves the whole screen.
      expect(api.clientSessionCallCount, 1);

      await cubit.close();
    });

    test('switching period fetches that window, and its comparison, from the '
        'ranged report endpoints', () async {
      final now = DateTime.now();
      final api = _ManagerFakeApi(
        locations: const [_sarit],
        ownedLocations: const [_sarit],
        forbiddenLocationIds: {_saritId},
        clientSessionList: [
          _session('s-now', 'KBR656Z', start: now, active: true),
        ],
        // Three weeks back: outside anything the flat list would still carry.
        reportSessionList: [
          _session('s-old', 'KCC999Y',
              start: now.subtract(const Duration(days: 21)), paid: 400),
        ],
      );
      final cubit = ManagerCubit(api: api);
      await cubit.start(interval: const Duration(minutes: 5));

      cubit.selectRange(ReportRange.month);
      await Future<void>.delayed(Duration.zero);

      // The window asked for reaches back over the comparison period too — the
      // screen shows every figure "vs previous".
      final asked = api.requestedWindows.last;
      expect(asked.start, cubit.state.window.previous.start);
      expect(asked.end, cubit.state.window.end);

      // A session no other call would have returned is now in the report.
      expect(
        cubit.state.historySessions.map((s) => s.id),
        contains('s-old'),
      );
      // ...and it counts towards the period: today's car plus the old one.
      expect(cubit.state.report.entries, 2);

      // Today's live row is still there — the period rows are merged, not
      // swapped in.
      expect(cubit.state.historySessions.map((s) => s.id), contains('s-now'));

      await cubit.close();
    });

    test('a period already in hand is not fetched again', () async {
      final api = _ManagerFakeApi(
        locations: const [_sarit],
        ownedLocations: const [_sarit],
      );
      final cubit = ManagerCubit(api: api);
      await cubit.start(interval: const Duration(minutes: 5));

      cubit.selectRange(ReportRange.week);
      await Future<void>.delayed(Duration.zero);
      final afterFirst = api.requestedWindows.length;

      cubit.selectRange(ReportRange.today);
      await Future<void>.delayed(Duration.zero);
      cubit.selectRange(ReportRange.week);
      await Future<void>.delayed(Duration.zero);
      cubit.selectRange(ReportRange.week);
      await Future<void>.delayed(Duration.zero);

      // today + week again = two more windows, and the repeat costs nothing.
      expect(api.requestedWindows.length, afterFirst + 2);

      await cubit.close();
    });

    test('a manager account never calls the ranged endpoints', () async {
      // No /manager/* route takes a date, so there is nothing to ask.
      final api = _ManagerFakeApi(locations: const [_sarit]);
      final cubit = ManagerCubit(api: api);
      await cubit.start(interval: const Duration(minutes: 5));

      cubit.selectRange(ReportRange.month);
      await Future<void>.delayed(Duration.zero);

      expect(api.requestedWindows, isEmpty);

      await cubit.close();
    });

    test('a manager account still finds its sites by probing', () async {
      // ownedLocations null — /client/locations 403s, as it does for a manager.
      final api = _ManagerFakeApi(
        locations: const [_sarit, _cbd],
        forbiddenLocationIds: {_cbdId},
      );
      final cubit = ManagerCubit(api: api);

      await cubit.start(interval: const Duration(minutes: 5));

      expect(cubit.state.locations.map((l) => l.id), [_saritId]);
      expect(api.clientSessionCallCount, 0);
      expect(api.sessionCallCount, greaterThan(0));

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
  String? locationId,
}) {
  return ParkingSession(
    id: id,
    locationName: locationId == _cbdId ? 'Nairobi CBD Parking' : 'Sarit',
    locationId: locationId,
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
  DateTime createdAt, {
  String locationId = _saritId,
}) {
  return PaymentTransaction(
    id: id,
    amount: amount,
    status: status,
    createdAt: createdAt,
    plateNumber: 'KBR656Z',
    locationId: locationId,
  );
}

/// Stands in for the real client. Each manager endpoint can be told to fail the
/// way the API fails: 403 for an unassigned location, anything else for a fault.
class _ManagerFakeApi extends ParkingIqApi {
  _ManagerFakeApi({
    required this.locations,
    this.ownedLocations,
    this.clientSessionList = const [],
    this.clientPaymentList = const [],
    this.reportSessionList = const [],
    this.sessions = const [],
    this.liveSessions = const [],
    this.payments = const [],
    this.forbiddenLocationIds = const {},
    this.activeError,
    this.paymentsError,
    this.activeSessionScript,
  }) : super(debug: false);

  final List<ParkingLocation> locations;

  /// The sites `/client/locations` hands back. Null is an account that is not a
  /// client at all — the endpoint 403s, exactly as it does for a manager.
  final List<ParkingLocation>? ownedLocations;
  final List<ParkingSession> clientSessionList;
  final List<PaymentTransaction> clientPaymentList;

  /// Rows only the ranged report endpoints know about — older than whatever the
  /// flat `/client/sessions` list carries.
  final List<ParkingSession> reportSessionList;

  /// Every window `/client/reports/*` was asked for, in order.
  final List<({DateTime start, DateTime end})> requestedWindows = [];
  final List<ParkingSession> sessions;
  final List<ParkingSession> liveSessions;
  final List<PaymentTransaction> payments;
  final Set<String> forbiddenLocationIds;
  final Object? activeError;
  final Object? paymentsError;

  /// One entry per active-sessions call; the last is held once it runs out.
  final List<List<ParkingSession>>? activeSessionScript;

  bool failEverything = false;
  int clientLocationCallCount = 0;
  int clientSessionCallCount = 0;
  int sessionCallCount = 0;
  int activeCallCount = 0;

  @override
  bool get hasToken => true;

  @override
  Future<List<ParkingLocation>> fetchParkingLocations() async => locations;

  @override
  Future<List<ParkingLocation>> clientLocations() async {
    clientLocationCallCount++;
    final owned = ownedLocations;
    if (owned == null) {
      throw const ApiException('Forbidden', statusCode: 403);
    }
    return owned;
  }

  @override
  Future<List<ParkingSession>> clientSessions() async {
    clientSessionCallCount++;
    return clientSessionList;
  }

  @override
  Future<List<PaymentTransaction>> clientPayments() async => clientPaymentList;

  @override
  Future<List<ParkingSession>> clientSessionReport({
    required DateTime start,
    required DateTime end,
  }) async {
    requestedWindows.add((start: start, end: end));
    return [
      for (final session in reportSessionList)
        if (!session.startTime.isBefore(start) && session.startTime.isBefore(end))
          session,
    ];
  }

  @override
  Future<List<PaymentTransaction>> clientPaymentReport({
    required DateTime start,
    required DateTime end,
  }) async =>
      const [];

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
