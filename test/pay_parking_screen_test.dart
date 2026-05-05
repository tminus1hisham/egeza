import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:park_iq/blocs/app_bloc.dart';
import 'package:park_iq/blocs/app_state.dart';
import 'package:park_iq/models/parking_session.dart';
import 'package:park_iq/models/vehicle.dart';
import 'package:park_iq/screens/dashboard/pay_parking_screen.dart';
import 'package:park_iq/widgets/primary_button.dart';

// Controllable bloc for widget tests — exposes emit via testEmit.
// Extends AppBloc so BlocProvider<AppBloc> resolves correctly.
class _TestAppBloc extends AppBloc {
  _TestAppBloc() : super();

  // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
  void testEmit(AppState newState) => emit(newState);
}

ParkingSession _completedSession() {
  return ParkingSession(
    id: 'session-1',
    locationName: 'CBD Parking Zone A',
    startTime: DateTime(2026, 5, 1, 8),
    endTime: DateTime(2026, 5, 1, 9),
    cost: 5,
    amountPaid: 5,
    status: 'COMPLETED',
    gracePeriodMinutes: 3,
    ratePerHour: 5,
    billableHours: 1,
    vehicle: const Vehicle(
      plateNumber: 'KBC 123A',
      type: 'Car',
      make: 'Toyota',
      model: 'Vitz',
    ),
    isActive: false,
  );
}

Widget _buildScreen(_TestAppBloc bloc) {
  return MaterialApp(
    home: BlocProvider<AppBloc>(
      create: (_) => bloc,
      child: const PayParkingScreen(),
    ),
  );
}

void main() {
  setUp(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({});
  });

  // ---------------------------------------------------------------------------
  // a. isWaitingForPayment == true
  // ---------------------------------------------------------------------------
  group('waiting for payment state', () {
    testWidgets('CircularProgressIndicator is visible in waiting dialog',
        (tester) async {
      final bloc = _TestAppBloc();

      await tester.pumpWidget(_buildScreen(bloc));

      bloc.testEmit(const AppState(isWaitingForPayment: true));
      await tester.pump();
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsWidgets);
    });

    testWidgets('Find Parking Session button is not tappable when isLoading',
        (tester) async {
      final bloc = _TestAppBloc();

      await tester.pumpWidget(_buildScreen(bloc));

      bloc.testEmit(const AppState(isLoading: true));
      await tester.pump();

      final buttons = tester.widgetList<ElevatedButton>(
        find.descendant(
          of: find.byType(PrimaryButton),
          matching: find.byType(ElevatedButton),
        ),
      );
      expect(buttons.any((b) => b.onPressed == null), isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // b. errorMessage set and isWaitingForPayment == false
  // ---------------------------------------------------------------------------
  testWidgets('SnackBar shows error message', (tester) async {
    final bloc = _TestAppBloc();

    await tester.pumpWidget(_buildScreen(bloc));

    bloc.testEmit(const AppState(errorMessage: 'Payment failed'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Payment failed'), findsOneWidget);
  });

  // ---------------------------------------------------------------------------
  // c. Session status becomes COMPLETED after waiting → receipt page pushed
  // ---------------------------------------------------------------------------
  testWidgets('receipt page shown after payment completes', (tester) async {
    final bloc = _TestAppBloc();

    await tester.pumpWidget(_buildScreen(bloc));

    // Enter waiting state so _wasWaitingForPayment is set to true.
    bloc.testEmit(const AppState(isWaitingForPayment: true));
    await tester.pump();
    await tester.pump();

    // Transition to completed — dialog hides and receipt is pushed.
    bloc.testEmit(AppState(
      isWaitingForPayment: false,
      selectedSession: _completedSession(),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Payment Successful'), findsOneWidget);
  });
}
