import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:egesha/blocs/app_bloc.dart';
import 'package:egesha/blocs/app_event.dart';
import 'package:egesha/blocs/app_state.dart';
import 'package:egesha/blocs/manager_cubit.dart';
import 'package:egesha/blocs/manager_state.dart';
import 'package:egesha/core/api/parking_iq_api.dart';
import 'package:egesha/models/api_models.dart';
import 'package:egesha/models/parking_session.dart';
import 'package:egesha/models/vehicle.dart';
import 'package:egesha/screens/dashboard/dashboard_screen.dart';
import 'package:egesha/screens/dashboard/history_screen.dart';
import 'package:egesha/screens/dashboard/manager_screen.dart';

class _StaticAppBloc extends AppBloc {
  _StaticAppBloc(this._state) : super(initialAuthToken: 'token');
  final AppState _state;
  @override
  AppState get state => _state;
  @override
  void add(AppEvent event) {}
}

class _StaticManagerCubit extends ManagerCubit {
  _StaticManagerCubit(this._state) : super(api: _NoopApi());
  final ManagerState _state;
  @override
  ManagerState get state => _state;
  @override
  Future<void> start({Duration interval = ManagerCubit.defaultInterval}) async {}
  @override
  Future<void> refresh() async {}
}

class _NoopApi extends ParkingIqApi {
  _NoopApi() : super(debug: false);
  @override
  bool get hasToken => false;
}

/// Feeds the dashboard a fixed set of sessions without reaching the network.
class _SessionsApi extends ParkingIqApi {
  _SessionsApi(this._sessions) : super(debug: false);

  final List<ParkingSession> _sessions;

  @override
  bool get hasToken => true;
  @override
  Future<List<ParkingSession>> recentParkingSessions() async => _sessions;
  @override
  Future<List<ParkingSession>> activeParkingSessions() async =>
      const <ParkingSession>[];
  @override
  Future<List<ParkingSession>> parkingSessionsForPlate(String plate) async =>
      const <ParkingSession>[];
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  final now = DateTime.now();
  const car = Vehicle(
    plateNumber: 'KBR656Z',
    type: 'Saloon',
    make: 'Toyota Land Cruiser',
    model: 'Prado',
  );

  ParkingSession session(
    String id, {
    required String location,
    required double cost,
    double paid = 0,
    String status = 'COMPLETED',
    bool active = false,
    DateTime? end,
  }) =>
      ParkingSession(
        id: id,
        locationName: location,
        startTime: now.subtract(const Duration(hours: 3)),
        endTime: end,
        cost: cost,
        amountPaid: paid,
        status: status,
        vehicle: car,
        isActive: active,
      );

  final appState = AppState(
    userName: 'James Mwangi',
    recentSessions: [
      session('s1',
          location: 'Sarit Centre Basement Parking',
          cost: 1250,
          status: 'EXIT_PENDING_PAYMENT'),
      session('s2', location: 'Two Rivers Mall', cost: 128500, paid: 128500),
      session('s3',
          location: 'Village Market',
          cost: 80,
          status: 'ACTIVE',
          active: true),
    ],
    walletTransactions: [
      WalletTransaction(
        id: 't1',
        amount: 128500,
        type: 'AUTOPAY',
        status: 'PENDING',
        reference: 'REF-9988776655',
        description: 'AutoPay parking fee Sarit Centre',
        createdAt: now,
      ),
      WalletTransaction(
        id: 't2',
        amount: 5000,
        type: 'DEPOSIT',
        status: 'COMPLETED',
        reference: 'QK12AB34CD',
        description: 'Wallet top-up via M-Pesa',
        createdAt: now.subtract(const Duration(days: 2)),
      ),
    ],
  );

  final managerState = ManagerState(
    isLoading: false,
    locations: [
      ParkingLocation(
        id: 'loc-1',
        name: 'Sarit Centre Basement Parking',
        maxCapacity: 300,
      ),
    ],
    selectedLocationId: 'loc-1',
    todaySessions: [
      session('m1', location: 'Sarit', cost: 128500, paid: 0, end: now),
      session('m2',
          location: 'Sarit', cost: 128500, status: 'ACTIVE', active: true),
    ],
    activeSessions: [
      session('m2',
          location: 'Sarit', cost: 128500, status: 'ACTIVE', active: true),
    ],
    todayPayments: const [],
    lastUpdated: now,
  );

  Future<void> pump(WidgetTester tester, Widget child, double scale) async {
    tester.view.physicalSize = const Size(320, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(scale)),
          child: child,
        ),
      ),
    );
    await tester.pump();
  }

  for (final scale in <double>[1.0, 1.3, 1.6]) {
    testWidgets('history activity + sessions survive text scale $scale',
        (tester) async {
      final bloc = _StaticAppBloc(appState);
      addTearDown(bloc.close);
      await pump(
        tester,
        BlocProvider<AppBloc>.value(value: bloc, child: const HistoryScreen()),
        scale,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('manager session rows survive text scale $scale',
        (tester) async {
      final cubit = _StaticManagerCubit(managerState);
      addTearDown(cubit.close);
      await pump(
        tester,
        BlocProvider<ManagerCubit>.value(value: cubit, child: const ManagerView()),
        scale,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('dashboard recent sessions survive text scale $scale',
        (tester) async {
      final bloc = AppBloc(
        api: _SessionsApi(appState.recentSessions),
        initialAuthToken: 'token',
        initialPhoneNumber: '0712345678',
      );
      addTearDown(bloc.close);
      await pump(
        tester,
        BlocProvider<AppBloc>.value(
          value: bloc,
          child: const DashboardScreen(),
        ),
        scale,
      );
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.takeException(), isNull);
    });
  }
}
