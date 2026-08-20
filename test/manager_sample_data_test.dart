import 'package:flutter_test/flutter_test.dart';

import 'package:egesha/blocs/manager_cubit.dart';
import 'package:egesha/blocs/manager_sample_data.dart';
import 'package:egesha/core/api/parking_iq_api.dart';
import 'package:egesha/models/api_models.dart';
import 'package:egesha/models/parking_session.dart';
import 'package:egesha/models/vehicle.dart';

/// Fails every call. Sample mode must not reach any of them.
class _ForbiddenApi extends ParkingIqApi {
  _ForbiddenApi() : super(debug: false);

  @override
  bool get hasToken => true;

  Never _fail() => throw StateError('sample mode must not call the API');

  @override
  Future<List<ParkingLocation>> fetchParkingLocations() => _fail();

  @override
  Future<List<ParkingSession>> managerLocationSessions(String locationId) =>
      _fail();

  @override
  Future<List<ParkingSession>> managerActiveLocationSessions(
    String locationId,
  ) =>
      _fail();

  @override
  Future<List<PaymentTransaction>> managerLocationPayments(
    String locationId,
  ) =>
      _fail();
}

void main() {
  group('sample data generation', () {
    test('produces a populated day for the site', () {
      final noon = DateTime(2026, 8, 16, 14, 30);
      final day = ManagerSampleData.forLocation(
        ManagerSampleData.saritId,
        now: noon,
      );

      expect(day.sessions, isNotEmpty);
      expect(day.activeSessions, isNotEmpty);
      expect(day.payments, isNotEmpty);

      // Every list has to hold the shapes the screen renders.
      expect(day.sessions.any((s) => s.isActive), isTrue);
      expect(day.sessions.any((s) => !s.isActive), isTrue);
      expect(day.sessions.any((s) => s.amountPaid > 0), isTrue);
      expect(
        day.sessions.any((s) => !s.isActive && s.cost > s.amountPaid),
        isTrue,
        reason: 'the "Owes" chip needs an exited unpaid session',
      );
      expect(day.payments.any((p) => p.isSettled), isTrue);
      expect(
        day.payments.any((p) => !p.isSettled),
        isTrue,
        reason: 'pending and failed money must not be counted as takings',
      );
    });

    test('is anchored to the day, so nothing lands in the future or yesterday',
        () {
      final afternoon = DateTime(2026, 8, 16, 15);
      final day = ManagerSampleData.forLocation(
        ManagerSampleData.saritId,
        now: afternoon,
      );

      for (final session in day.sessions) {
        expect(session.startTime.isAfter(afternoon), isFalse);
        expect(session.startTime.day, afternoon.day);
      }
      for (final session in day.activeSessions) {
        expect(session.endTime, isNull);
      }
    });

    test('is stable across polls, so the figures do not jitter', () {
      final at = DateTime(2026, 8, 16, 13);
      final first =
          ManagerSampleData.forLocation(ManagerSampleData.saritId, now: at);
      final second =
          ManagerSampleData.forLocation(ManagerSampleData.saritId, now: at);

      expect(second.sessions.length, first.sessions.length);
      expect(
        second.sessions.map((s) => '${s.id}${s.vehicle.plateNumber}${s.cost}'),
        first.sessions.map((s) => '${s.id}${s.vehicle.plateNumber}${s.cost}'),
      );
    });

    test('the day only ever moves forward', () {
      final earlier = ManagerSampleData.forLocation(
        ManagerSampleData.saritId,
        now: DateTime(2026, 8, 16, 11),
      );
      final later = ManagerSampleData.forLocation(
        ManagerSampleData.saritId,
        now: DateTime(2026, 8, 16, 16),
      );

      expect(later.sessions.length, greaterThan(earlier.sessions.length));
      // Cars that were parked at 11:00 have since driven out and paid.
      expect(later.payments.length, greaterThan(earlier.payments.length));
    });

    test('each site keeps its own day', () {
      final at = DateTime(2026, 8, 16, 13);
      final sarit =
          ManagerSampleData.forLocation(ManagerSampleData.saritId, now: at);
      final cbd =
          ManagerSampleData.forLocation(ManagerSampleData.cbdId, now: at);

      expect(
        sarit.sessions.first.vehicle.plateNumber,
        isNot(cbd.sessions.first.vehicle.plateNumber),
      );
      expect(sarit.sessions.first.locationName, 'Sarit');
      expect(cbd.sessions.first.locationName, 'Nairobi CBD Parking');
    });

    test('plates are written the way the gate cameras write them', () {
      final day = ManagerSampleData.forLocation(
        ManagerSampleData.saritId,
        now: DateTime(2026, 8, 16, 18),
      );

      for (final session in day.sessions) {
        final plate = session.vehicle.plateNumber;
        // Unspaced and uppercase, per the ANPR plate contract.
        expect(plate, Vehicle.plateKey(plate));
        expect(plate, matches(RegExp(r'^K[A-Z]{2}\d{3}[A-Z]$')));
      }
    });
  });

  group('ManagerCubit in sample mode', () {
    test('never calls the API and flags every reading as sample', () async {
      final cubit = ManagerCubit(api: _ForbiddenApi(), useSampleData: true);

      await cubit.start(interval: const Duration(minutes: 5));

      expect(cubit.state.isSample, isTrue);
      expect(cubit.state.hasNoAssignments, isFalse);
      expect(cubit.state.errorMessage, isNull);
      expect(cubit.state.locationName, 'Sarit');

      await cubit.close();
    });

    test('fills in the three headline numbers', () async {
      final cubit = ManagerCubit(api: _ForbiddenApi(), useSampleData: true);
      await cubit.start(interval: const Duration(minutes: 5));

      expect(cubit.state.revenueToday, greaterThan(0));
      expect(cubit.state.entriesToday, greaterThan(0));
      expect(cubit.state.stillParked, greaterThan(0));
      expect(cubit.state.stillParked, lessThanOrEqualTo(cubit.state.capacity));
      // A repeat visitor is baked in, so the two are never the same number
      // once the day is long enough to have had one.
      expect(
        cubit.state.vehiclesToday,
        lessThanOrEqualTo(cubit.state.entriesToday),
      );

      await cubit.close();
    });

    test('offers both sample sites so the switcher can be seen', () async {
      final cubit = ManagerCubit(api: _ForbiddenApi(), useSampleData: true);
      await cubit.start(interval: const Duration(minutes: 5));

      expect(cubit.state.locations, hasLength(2));

      final saritRevenue = cubit.state.revenueToday;
      await cubit.selectLocation(ManagerSampleData.cbdId);

      expect(cubit.state.locationName, 'Nairobi CBD Parking');
      expect(cubit.state.isSample, isTrue);
      expect(cubit.state.revenueToday, isNot(saritRevenue));

      await cubit.close();
    });

    test('a live cubit is never marked as sample', () async {
      final cubit = ManagerCubit(api: _ForbiddenApi());
      expect(cubit.state.isSample, isFalse);
      await cubit.close();
    });
  });
}
