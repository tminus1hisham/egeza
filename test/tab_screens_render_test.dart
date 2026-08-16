import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:egesha/blocs/app_bloc.dart';
import 'package:egesha/blocs/app_event.dart';
import 'package:egesha/blocs/app_state.dart';
import 'package:egesha/models/vehicle.dart';
import 'package:egesha/screens/dashboard/history_screen.dart';
import 'package:egesha/screens/dashboard/settings_detail_screen.dart';
import 'package:egesha/screens/dashboard/settings_screen.dart';
import 'package:egesha/screens/dashboard/vehicles_screen.dart';
import 'package:egesha/screens/dashboard/wallet_screen.dart';
import 'package:egesha/widgets/app_widgets.dart';

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

/// The four tab screens all open with a [PageHero] now that the page header is
/// gone. These pump each one at the narrowest phone width the app supports —
/// where a hero row that is one element too wide would overflow.
void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  final populated = AppState(
    userName: 'James Mwangi',
    phoneNumber: '712345678',
    walletBalance: 24500,
    vehicles: const [
      Vehicle(
        plateNumber: 'KBR656Z',
        type: 'Saloon',
        make: 'Toyota',
        model: 'Prado',
        autoPayEnabled: true,
      ),
      Vehicle(
        plateNumber: 'KDA123X',
        type: 'SUV',
        make: 'Nissan',
        model: 'X-Trail',
      ),
    ],
  );

  late _StaticAppBloc bloc;

  tearDown(() => bloc.close());

  Future<void> pumpScreen(
    WidgetTester tester,
    Widget screen, {
    required AppState state,
    Size size = const Size(320, 800),
  }) async {
    bloc = _StaticAppBloc(state);
    tester.view.physicalSize = size;
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

  final screens = <String, Widget Function()>{
    'Wallet': () => const WalletScreen(),
    'History': () => const HistoryScreen(),
    'Vehicles': () => const VehiclesScreen(),
    'Settings': () => const SettingsScreen(),
  };

  for (final entry in screens.entries) {
    testWidgets('${entry.key} opens with a PageHero and no overflow',
        (tester) async {
      await pumpScreen(tester, entry.value(), state: populated);

      expect(find.byType(PageHero), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('${entry.key} renders empty state without overflow',
        (tester) async {
      await pumpScreen(tester, entry.value(), state: const AppState());

      expect(find.byType(PageHero), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('a pushed tab screen inlines its back arrow into the hero',
      (tester) async {
    await pumpScreen(
      tester,
      const VehiclesScreen(showBackButton: true),
      state: populated,
    );

    // The arrow lives inside the hero, not stranded on the row above it.
    expect(
      find.descendant(
        of: find.byType(PageHero),
        matching: find.byWidgetPredicate(
          (w) => w is PageAction && w.tooltip == 'Back',
        ),
      ),
      findsOneWidget,
    );
    expect(find.byType(PageBackButton), findsNothing);
  });

  testWidgets('a root tab screen carries no back arrow at all', (tester) async {
    await pumpScreen(tester, const VehiclesScreen(), state: populated);

    expect(find.byType(PageBackButton), findsNothing);
    expect(
      find.byWidgetPredicate((w) => w is PageAction && w.tooltip == 'Back'),
      findsNothing,
    );
  });

  testWidgets('Wallet hides See all when there is nowhere to send it',
      (tester) async {
    await pumpScreen(tester, const WalletScreen(), state: populated);

    // Pushed rather than hosted by MainNavigation: no History tab to switch to,
    // so the link is absent rather than dead.
    expect(find.text('See all'), findsNothing);
  });

  // Settings' sub-pages are structurally identical — hero, then panels — so
  // without the label on the back control nothing tells them apart.
  group('settings sub-pages name themselves', () {
    testWidgets('Personal details', (tester) async {
      await pumpScreen(
        tester,
        PersonalDetailsSettingsPage(state: populated),
        state: populated,
      );

      expect(
        find.descendant(
          of: find.byType(PageBackButton),
          matching: find.text('Personal details'),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('Security', (tester) async {
      await pumpScreen(
        tester,
        const SecuritySettingsPage(),
        state: populated,
      );

      expect(
        find.descendant(
          of: find.byType(PageBackButton),
          matching: find.text('Security'),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  });
}
