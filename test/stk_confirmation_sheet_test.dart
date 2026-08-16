import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:egesha/blocs/app_bloc.dart';
import 'package:egesha/core/api/parking_iq_api.dart';
import 'package:egesha/models/api_models.dart';
import 'package:egesha/models/parking_session.dart';
import 'package:egesha/models/vehicle.dart';
import 'package:egesha/screens/dashboard/pay_parking_screen.dart';

void main() {
  // The sheet's controllers used to be disposed from the route's popped
  // future, which fires when the pop *starts*. The sheet was still mounted and
  // animating out — and the retracting keyboard rebuilt its fields against
  // disposed controllers, which cascaded into a full-screen red framework
  // assertion instead of the payment going through.
  testWidgets('closing the STK sheet with the keyboard up does not throw',
      (tester) async {
    await _openStkSheet(tester);

    await tester.tap(find.textContaining('via M-Pesa'));
    // Keyboard retracts as the sheet closes.
    tester.view.viewInsets = FakeViewPadding.zero;
    await tester.pumpAndSettle(const Duration(seconds: 2));

    expect(tester.takeException(), isNull);
  });

  testWidgets('cancelling the STK sheet with the keyboard up does not throw',
      (tester) async {
    await _openStkSheet(tester);

    await tester.ensureVisible(find.text('Cancel'));
    await tester.pump();
    await tester.tap(find.text('Cancel'));
    tester.view.viewInsets = FakeViewPadding.zero;
    await tester.pumpAndSettle(const Duration(seconds: 2));

    expect(tester.takeException(), isNull);
    expect(find.text('M-Pesa prompt'), findsNothing);
  });
}

/// Drives the screen from plate entry to an open M-Pesa sheet, with the soft
/// keyboard raised.
Future<void> _openStkSheet(WidgetTester tester) async {
  final bloc = AppBloc(
    api: _Api(),
    initialAuthToken: 'token',
    initialPhoneNumber: '0712345678',
  );
  addTearDown(bloc.close);

  await tester.pumpWidget(
    MaterialApp(
      home: BlocProvider<AppBloc>.value(
        value: bloc,
        child: const PayParkingScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();

  await tester.enterText(find.byType(TextFormField).first, 'KBC123A');
  await tester.pump();
  await tester.tap(find.text('Find Parking Session'));
  await tester.pumpAndSettle();

  expect(find.text('Session Found'), findsOneWidget, reason: 'session sheet');

  await tester.tap(find.textContaining('Pay KES'));
  await tester.pumpAndSettle(const Duration(seconds: 1));

  expect(find.text('M-Pesa prompt'), findsOneWidget, reason: 'stk sheet');

  tester.view.viewInsets = const FakeViewPadding(bottom: 700);
  addTearDown(tester.view.resetViewInsets);
  await tester.pump();
}

ParkingSession _session({String status = 'ACTIVE', bool isActive = true}) {
  return ParkingSession(
    id: 'session-1',
    locationName: 'Sarit',
    startTime: DateTime(2026, 5, 1, 8),
    cost: 5,
    status: status,
    vehicle: const Vehicle(
      plateNumber: 'KBC 123A',
      type: 'Car',
      make: 'Toyota',
      model: 'Vitz',
    ),
    isActive: isActive,
  );
}

class _Api extends ParkingIqApi {
  _Api() : super(debug: false);

  @override
  bool get hasToken => true;

  @override
  Future<List<ParkingSession>> activeParkingSessionsForPlate(
    String plateNumber,
  ) async => [_session()];

  @override
  Future<ParkingSession> calculateParkingSession(String sessionId) async =>
      _session();

  @override
  Future<ParkingSession> parkingSession(String sessionId) async => _session();

  @override
  Future<MpesaResponse> startSessionStkPush({
    required String phoneNumber,
    required double amount,
    required String sessionId,
    required String plateNumber,
    required String location,
    String transactionDesc = 'Parking session payment',
  }) async => const MpesaResponse(
    paymentId: 'payment-1',
    checkoutRequestId: 'ws_CO_123',
    status: 'PENDING',
  );

  @override
  Future<PaymentStatusSnapshot> paymentStatus(String paymentId) async =>
      const PaymentStatusSnapshot(status: 'PENDING');
}
