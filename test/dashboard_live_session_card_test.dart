import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:egesha/blocs/app_bloc.dart';
import 'package:egesha/core/api/parking_iq_api.dart';
import 'package:egesha/models/parking_session.dart';
import 'package:egesha/models/vehicle.dart';
import 'package:egesha/screens/dashboard/dashboard_screen.dart';

void main() {
  // The running session used to be reachable only by scrolling to Recent
  // Sessions and opening it; the home card puts checkout one tap away.
  testWidgets('live session card sits above Quick Actions and opens the sheet',
      (tester) async {
    await _pumpDashboard(tester, sessions: [_session(isActive: true)]);

    expect(find.text('Pay now'), findsOneWidget);

    final cardY = tester.getTopLeft(find.text('Pay now')).dy;
    final quickActionsY = tester.getTopLeft(find.text('Quick Actions')).dy;
    expect(cardY, lessThan(quickActionsY));

    await tester.tap(find.text('Pay now'));
    // The Live pill pulses forever, so settle by hand rather than pumpAndSettle.
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('M-Pesa prompt'), findsOneWidget);
  });

  testWidgets('no card when nothing is running', (tester) async {
    await _pumpDashboard(
      tester,
      sessions: [_session(isActive: false, status: 'COMPLETED')],
    );

    expect(find.text('Pay now'), findsNothing);
    expect(find.text('Quick Actions'), findsOneWidget);
  });
}

Future<void> _pumpDashboard(
  WidgetTester tester, {
  required List<ParkingSession> sessions,
}) async {
  // Wide enough that the pre-existing low-balance header row does not
  // overflow and drown the assertions in unrelated exceptions.
  tester.view.physicalSize = const Size(600, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final bloc = AppBloc(
    api: _Api(sessions),
    initialAuthToken: 'token',
    initialPhoneNumber: '0712345678',
  );
  addTearDown(bloc.close);

  await tester.pumpWidget(
    MaterialApp(
      home: BlocProvider<AppBloc>.value(
        value: bloc,
        child: const DashboardScreen(),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

ParkingSession _session({required bool isActive, String status = 'ACTIVE'}) {
  return ParkingSession(
    id: 'session-1',
    locationName: 'Sarit',
    startTime: DateTime.utc(2026, 8, 15, 7),
    endTime: isActive ? null : DateTime.utc(2026, 8, 15, 9),
    cost: 120,
    status: status,
    vehicle: const Vehicle(
      plateNumber: 'KBR656Z',
      type: 'Saloon',
      make: 'Toyota',
      model: 'Axio',
    ),
    isActive: isActive,
  );
}

class _Api extends ParkingIqApi {
  _Api(this._sessions) : super(debug: false);

  final List<ParkingSession> _sessions;

  @override
  bool get hasToken => true;

  @override
  Future<List<ParkingSession>> recentParkingSessions() async => _sessions;

  @override
  Future<List<ParkingSession>> activeParkingSessions() async =>
      const <ParkingSession>[];

  @override
  Future<List<ParkingSession>> parkingSessionsForPlate(String plateNumber) async =>
      const <ParkingSession>[];
}
