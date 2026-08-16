import 'package:flutter_test/flutter_test.dart';
import 'package:egesha/blocs/app_bloc.dart';
import 'package:egesha/blocs/app_event.dart';
import 'package:egesha/blocs/app_state.dart';
import 'package:egesha/core/api/parking_iq_api.dart';
import 'package:egesha/models/parking_session.dart';
import 'package:egesha/models/vehicle.dart';

void main() {
  group('AppBloc session watch', () {
    test('surfaces a session that appears after the dashboard loaded',
        () async {
      // First poll sees nothing; the gate opens a session before the second.
      final api = _SessionWatchFakeApi([
        const <ParkingSession>[],
        [_session('s-1', isActive: true)],
      ]);
      final bloc = AppBloc(api: api, initialAuthToken: 'token');

      bloc.add(const StartSessionWatch(interval: Duration(milliseconds: 20)));

      await expectLater(
        bloc.stream,
        emitsThrough(
          isA<AppState>()
              .having((s) => s.recentSessions.length, 'sessions', 1)
              .having((s) => s.recentSessions.first.id, 'id', 's-1')
              // A background poll must never flip loading or message state.
              .having((s) => s.isLoading, 'isLoading', isFalse)
              .having((s) => s.statusMessage, 'statusMessage', isNull)
              .having((s) => s.errorMessage, 'errorMessage', isNull),
        ),
      );

      bloc.add(StopSessionWatch());
      await bloc.close();
    });

    test('does not emit while the session list is unchanged', () async {
      // ParkingSession has no value equality, so an unchanged list still
      // arrives as fresh objects — the signature check is what stops the churn.
      final api = _SessionWatchFakeApi([
        [_session('s-1', isActive: true)],
      ]);
      final bloc = AppBloc(api: api, initialAuthToken: 'token');
      final states = <AppState>[];
      final sub = bloc.stream.listen(states.add);

      bloc.add(const StartSessionWatch(interval: Duration(milliseconds: 20)));
      await Future<void>.delayed(const Duration(milliseconds: 140));

      expect(api.callCount, greaterThan(2));
      expect(states.where((s) => s.recentSessions.isNotEmpty), hasLength(1));

      await sub.cancel();
      await bloc.close();
    });

    test('stops polling once the token is rejected', () async {
      final api = _SessionWatchFakeApi(
        const [],
        error: const ApiException('Forbidden', statusCode: 403),
      );
      final bloc = AppBloc(api: api, initialAuthToken: 'token');

      bloc.add(const StartSessionWatch(interval: Duration(milliseconds: 20)));

      await Future<void>.delayed(const Duration(milliseconds: 140));
      expect(api.callCount, 1);
      expect(bloc.state.recentSessions, isEmpty);

      await bloc.close();
    });

    test('stop cancels further polling', () async {
      final api = _SessionWatchFakeApi([
        [_session('s-1', isActive: true)],
      ]);
      final bloc = AppBloc(api: api, initialAuthToken: 'token');

      bloc.add(const StartSessionWatch(interval: Duration(milliseconds: 20)));
      await Future<void>.delayed(const Duration(milliseconds: 30));
      bloc.add(StopSessionWatch());
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final callsAtStop = api.callCount;
      await Future<void>.delayed(const Duration(milliseconds: 140));
      expect(api.callCount, callsAtStop);

      await bloc.close();
    });
  });
}

ParkingSession _session(String id, {required bool isActive}) {
  return ParkingSession(
    id: id,
    locationName: 'Kimathi Street',
    startTime: DateTime.utc(2026, 8, 15, 7),
    cost: 50,
    status: isActive ? 'ACTIVE' : 'COMPLETED',
    vehicle: const Vehicle(
      plateNumber: 'KBR656Z',
      type: 'Saloon',
      make: 'Toyota',
      model: 'Axio',
    ),
    isActive: isActive,
  );
}

class _SessionWatchFakeApi extends ParkingIqApi {
  _SessionWatchFakeApi(this._sessions, {this.error}) : super(debug: false);

  /// One entry per poll; the last entry is held once the script runs out.
  final List<List<ParkingSession>> _sessions;
  final Object? error;
  int callCount = 0;

  @override
  bool get hasToken => true;

  @override
  Future<List<ParkingSession>> recentParkingSessions() async {
    callCount++;
    if (error != null) throw error!;
    final index = callCount - 1;
    return _sessions[index < _sessions.length ? index : _sessions.length - 1];
  }

  // The watch merges three sources; only `recent` carries the script here so
  // the other two stay empty rather than doubling every session.
  @override
  Future<List<ParkingSession>> activeParkingSessions() async =>
      const <ParkingSession>[];

  @override
  Future<List<ParkingSession>> parkingSessionsForPlate(String plateNumber) async =>
      const <ParkingSession>[];
}
