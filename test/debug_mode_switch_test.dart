import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:egesha/blocs/app_bloc.dart';
import 'package:egesha/blocs/app_event.dart';
import 'package:egesha/blocs/app_state.dart';
import 'package:egesha/core/api/parking_iq_api.dart';
import 'package:egesha/core/user_prefs.dart';
import 'package:egesha/screens/dashboard/settings_screen.dart';

/// Never reaches the network; the debug switch touches no endpoint anyway.
class _OfflineApi extends ParkingIqApi {
  _OfflineApi() : super(debug: false);

  @override
  bool get hasToken => false;
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
  });

  group('view mode resolution', () {
    test('follows the account role when no override is set', () {
      expect(const AppState(userRole: 'USER').isManager, isFalse);
      expect(const AppState(userRole: 'MANAGER').isManager, isTrue);
      expect(const AppState(userRole: 'ADMIN').isManager, isTrue);
      expect(const AppState(userRole: 'CLIENT').isManager, isTrue);
      expect(const AppState(userRole: 'MANAGER').isDebugModeOverridden, isFalse);
    });

    test('the override wins in both directions', () {
      const driverForcedUp =
          AppState(userRole: 'USER', debugManagerMode: true);
      expect(driverForcedUp.isManager, isTrue);
      expect(driverForcedUp.hasManagerRole, isFalse);
      expect(driverForcedUp.isDebugModeOverridden, isTrue);

      // The point of a switch rather than a one-way flag: a real manager has to
      // be able to see the driver side too.
      const managerForcedDown =
          AppState(userRole: 'MANAGER', debugManagerMode: false);
      expect(managerForcedDown.isManager, isFalse);
      expect(managerForcedDown.isDebugModeOverridden, isTrue);
    });

    test('an override that agrees with the role is not flagged as overriding',
        () {
      const agreeing = AppState(userRole: 'MANAGER', debugManagerMode: true);
      expect(agreeing.isManager, isTrue);
      expect(agreeing.isDebugModeOverridden, isFalse);
    });
  });

  group('SetDebugManagerMode', () {
    test('sets, flips, and clears the override', () async {
      final bloc = AppBloc(api: _OfflineApi(), initialAuthToken: 'token');

      bloc.add(const SetDebugManagerMode(true));
      await expectLater(
        bloc.stream,
        emitsThrough(
          isA<AppState>().having((s) => s.isManager, 'isManager', isTrue),
        ),
      );

      bloc.add(const SetDebugManagerMode(false));
      await expectLater(
        bloc.stream,
        emitsThrough(
          isA<AppState>().having((s) => s.isManager, 'isManager', isFalse),
        ),
      );

      // Null is a real value here — back to following the account role, not
      // "false". A copyWith that treated it as "no change" would strand the
      // switch on its last position forever.
      bloc.add(const SetDebugManagerMode(null));
      await expectLater(
        bloc.stream,
        emitsThrough(
          isA<AppState>()
              .having((s) => s.debugManagerMode, 'debugManagerMode', isNull),
        ),
      );

      await bloc.close();
    });

    test('persists across a restart', () async {
      final bloc = AppBloc(api: _OfflineApi(), initialAuthToken: 'token');
      bloc.add(const SetDebugManagerMode(true));
      await expectLater(
        bloc.stream,
        emitsThrough(
          isA<AppState>().having((s) => s.isManager, 'isManager', isTrue),
        ),
      );
      await bloc.close();

      final saved = await UserPrefs.load();
      expect(saved.debugManagerMode, isTrue);

      final restarted = AppBloc(
        api: _OfflineApi(),
        initialDebugManagerMode: saved.debugManagerMode,
      );
      expect(restarted.state.isManager, isTrue);
      await restarted.close();
    });

    test('survives sign out, because it is a device setting not account data',
        () async {
      final bloc = AppBloc(api: _OfflineApi(), initialAuthToken: 'token');
      bloc.add(const SetDebugManagerMode(true));
      await expectLater(
        bloc.stream,
        emitsThrough(
          isA<AppState>().having((s) => s.isManager, 'isManager', isTrue),
        ),
      );

      bloc.add(SignOut());
      await expectLater(
        bloc.stream,
        emitsThrough(
          isA<AppState>().having((s) => s.authToken, 'authToken', isNull),
        ),
      );

      expect(bloc.state.debugManagerMode, isTrue);
      await bloc.close();
    });
  });

  group('Developer section in Settings', () {
    Future<AppBloc> pumpSettings(
      WidgetTester tester, {
      required AppState initial,
    }) async {
      final bloc = _SeededAppBloc(initial);
      addTearDown(bloc.close);

      tester.view.physicalSize = const Size(320, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        BlocProvider<AppBloc>.value(
          value: bloc,
          child: const MaterialApp(home: SettingsScreen()),
        ),
      );
      await tester.pump();
      return bloc;
    }

    testWidgets('the switch reads the mode currently on screen', (tester) async {
      await pumpSettings(tester, initial: const AppState(userRole: 'USER'));

      await tester.scrollUntilVisible(find.text('Manager mode'), 300);
      expect(find.text('Showing the driver view'), findsOneWidget);

      final toggle = tester.widget<Switch>(_managerSwitch());
      expect(toggle.value, isFalse);
      expect(tester.takeException(), isNull);
    });

    testWidgets('flipping it turns the manager view on for a driver account',
        (tester) async {
      final bloc =
          await pumpSettings(tester, initial: const AppState(userRole: 'USER'));

      await tester.scrollUntilVisible(find.text('Manager mode'), 300);
      await tester.tap(_managerSwitch());
      await tester.pumpAndSettle();

      expect(bloc.state.isManager, isTrue);
      expect(find.text('Showing the manager view'), findsOneWidget);
      // The way back out only appears once the mode disagrees with the role.
      expect(find.text('Follow account role'), findsOneWidget);
    });

    testWidgets('a real manager can flip down to the driver view',
        (tester) async {
      final bloc = await pumpSettings(
        tester,
        initial: const AppState(userRole: 'MANAGER'),
      );

      await tester.scrollUntilVisible(find.text('Manager mode'), 300);
      expect(tester.widget<Switch>(_managerSwitch()).value, isTrue);

      await tester.tap(_managerSwitch());
      await tester.pumpAndSettle();

      expect(bloc.state.isManager, isFalse);
      expect(find.text('Showing the driver view'), findsOneWidget);
    });

    testWidgets('the reset row hands the mode back to the account role',
        (tester) async {
      final bloc = await pumpSettings(
        tester,
        initial: const AppState(userRole: 'USER', debugManagerMode: true),
      );

      await tester.scrollUntilVisible(find.text('Follow account role'), 300);
      await tester.tap(find.text('Follow account role'));
      await tester.pumpAndSettle();

      expect(bloc.state.debugManagerMode, isNull);
      expect(bloc.state.isManager, isFalse);
      expect(find.text('Follow account role'), findsNothing);
    });
  });
}

Finder _managerSwitch() => find.descendant(
      of: find.ancestor(
        of: find.text('Manager mode'),
        matching: find.byType(Row),
      ),
      matching: find.byType(Switch),
    );

/// A real bloc — the switch has to actually round-trip through the event
/// handler — started from a chosen state and kept off the network.
class _SeededAppBloc extends AppBloc {
  _SeededAppBloc(AppState seed) : super(api: _OfflineApi()) {
    emit(seed);
  }
}
