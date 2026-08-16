import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:egesha/blocs/app_bloc.dart';
import 'package:egesha/blocs/app_event.dart';
import 'package:egesha/blocs/app_state.dart';
import 'package:egesha/models/api_models.dart';
import 'package:egesha/models/parking_session.dart';
import 'package:egesha/models/vehicle.dart';
import 'package:egesha/screens/dashboard/history_screen.dart';
import 'package:egesha/screens/dashboard/vehicles_screen.dart';

/// Holds a fixed state and swallows dispatched events, so pumping a screen
/// never reaches the real API.
class _StaticAppBloc extends AppBloc {
  _StaticAppBloc(this._state) : super(initialAuthToken: 'token');

  final AppState _state;

  @override
  AppState get state => _state;

  @override
  void add(AppEvent event) {}
}

/// The All/AutoPay/Manual and All/Paid/AutoPay strips are the only way to
/// narrow either list, so each tab has to actually remove rows — on *every*
/// list it sits above.
void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  const autoPayVehicle = Vehicle(
    plateNumber: 'KBR656Z',
    type: 'Saloon',
    make: 'Toyota',
    model: 'Prado',
    autoPayEnabled: true,
  );
  const manualVehicle = Vehicle(
    plateNumber: 'KDA123X',
    type: 'SUV',
    make: 'Nissan',
    model: 'X-Trail',
  );

  final settledSession = ParkingSession(
    id: 's-paid',
    locationName: 'Sarit Centre',
    startTime: DateTime(2026, 8, 14, 9),
    endTime: DateTime(2026, 8, 14, 11),
    cost: 200,
    amountPaid: 200,
    status: 'COMPLETED',
    vehicle: manualVehicle,
    isActive: false,
  );
  final autoPaySession = ParkingSession(
    id: 's-auto',
    locationName: 'Two Rivers',
    startTime: DateTime(2026, 8, 14, 12),
    endTime: DateTime(2026, 8, 14, 13),
    cost: 100,
    amountPaid: 100,
    status: 'COMPLETED',
    autoPayEnabled: true,
    vehicle: autoPayVehicle,
    isActive: false,
  );
  // Car has left, fee still outstanding — settled by neither route.
  final unpaidSession = ParkingSession(
    id: 's-unpaid',
    locationName: 'Village Market',
    startTime: DateTime(2026, 8, 14, 15),
    cost: 150,
    status: 'EXIT_PENDING_PAYMENT',
    vehicle: manualVehicle,
    isActive: false,
  );

  final state = AppState(
    userName: 'James Mwangi',
    vehicles: const [autoPayVehicle, manualVehicle],
    recentSessions: [settledSession, autoPaySession, unpaidSession],
    walletTransactions: [
      WalletTransaction(
        id: 't1',
        amount: 200,
        type: 'PAYMENT',
        status: 'COMPLETED',
        description: 'Parking payment',
        createdAt: DateTime(2026, 8, 14, 11),
      ),
      WalletTransaction(
        id: 't2',
        amount: 100,
        type: 'PAYMENT',
        status: 'COMPLETED',
        description: 'AutoPay parking',
        createdAt: DateTime(2026, 8, 14, 13),
      ),
      WalletTransaction(
        id: 't3',
        amount: 150,
        type: 'PAYMENT',
        status: 'PENDING',
        description: 'Parking payment',
        createdAt: DateTime(2026, 8, 14, 15),
      ),
    ],
  );

  late _StaticAppBloc bloc;

  tearDown(() => bloc.close());

  Future<void> pumpScreen(WidgetTester tester, Widget screen) async {
    bloc = _StaticAppBloc(state);
    // Roomy on purpose: the test font draws every glyph as a full-size box, so
    // a phone-width viewport overflows these rows on label length alone. Layout
    // at real widths is what tab_screens_render_test.dart covers; this file is
    // about which rows survive the filter.
    tester.view.physicalSize = const Size(1000, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      BlocProvider<AppBloc>.value(
        value: bloc,
        child: MaterialApp(home: screen),
      ),
    );
    await tester.pump();
  }

  /// Taps a filter chip by its label and settles the selection animation.
  /// Scoped to the chip's [AnimatedContainer] because 'AutoPay' and 'Manual'
  /// also label hero metrics above the bar and row pills below it.
  Future<void> tapFilter(WidgetTester tester, String label) async {
    await tester.tap(
      find.descendant(
        of: find.byType(AnimatedContainer),
        matching: find.text(label),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('Vehicles filter', () {
    testWidgets('All shows every vehicle', (tester) async {
      await pumpScreen(tester, const VehiclesScreen());

      expect(find.text('KBR656Z'), findsOneWidget);
      expect(find.text('KDA123X'), findsOneWidget);
      expect(find.text('2 shown'), findsOneWidget);
    });

    testWidgets('AutoPay keeps only autopay vehicles', (tester) async {
      await pumpScreen(tester, const VehiclesScreen());
      await tapFilter(tester, 'AutoPay');

      expect(find.text('KBR656Z'), findsOneWidget);
      expect(find.text('KDA123X'), findsNothing);
      expect(find.text('1 shown'), findsOneWidget);
    });

    testWidgets('Manual keeps only non-autopay vehicles', (tester) async {
      await pumpScreen(tester, const VehiclesScreen());
      await tapFilter(tester, 'Manual');

      expect(find.text('KDA123X'), findsOneWidget);
      expect(find.text('KBR656Z'), findsNothing);
      expect(find.text('1 shown'), findsOneWidget);
    });
  });

  group('History filter', () {
    testWidgets('All shows every session', (tester) async {
      await pumpScreen(tester, const HistoryScreen());

      expect(find.text('3 sessions'), findsOneWidget);
      expect(find.text('Village Market'), findsOneWidget);
    });

    testWidgets('Paid drops the session still owing money', (tester) async {
      await pumpScreen(tester, const HistoryScreen());
      await tapFilter(tester, 'Paid');

      expect(find.text('2 sessions'), findsOneWidget);
      expect(find.text('Sarit Centre'), findsOneWidget);
      expect(find.text('Two Rivers'), findsOneWidget);
      expect(find.text('Village Market'), findsNothing);
    });

    testWidgets('AutoPay keeps only autopay sessions', (tester) async {
      await pumpScreen(tester, const HistoryScreen());
      await tapFilter(tester, 'AutoPay');

      expect(find.text('1 sessions'), findsOneWidget);
      expect(find.text('Two Rivers'), findsOneWidget);
      expect(find.text('Sarit Centre'), findsNothing);
    });

    testWidgets('a filter with no matching session says so', (tester) async {
      await pumpScreen(tester, const HistoryScreen());
      await tapFilter(tester, 'AutoPay');
      // Only the autopay session survives; narrow further with a search that
      // matches nothing to reach the filtered-empty copy.
      await tester.tap(find.byTooltip('Search history'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'nowhere');
      await tester.pumpAndSettle();

      expect(find.text('No parking sessions match this filter'), findsOneWidget);
      expect(find.text('No parking sessions yet'), findsNothing);
    });
  });
}
