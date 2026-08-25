import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:egesha/blocs/app_bloc.dart';
import 'package:egesha/blocs/app_event.dart';
import 'package:egesha/core/api/parking_iq_api.dart';
import 'package:egesha/screens/auth/sign_in_screen.dart';

/// The demo buttons must not touch the network, so a call reaching this fails
/// the test rather than hanging on a real request.
class _OfflineApi extends ParkingIqApi {
  _OfflineApi() : super(debug: false);

  bool tokenWasSet = false;

  @override
  void setToken(String? token) {
    if (token != null && token.isNotEmpty) tokenWasSet = true;
    super.setToken(token);
  }
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
  });

  group('demo sign-in', () {
    test('the tenant demo lands on the tenancy side with figures to show',
        () async {
      final api = _OfflineApi();
      final bloc = AppBloc(api: api);

      bloc.add(const StartDemoSession('tenant'));
      await bloc.stream.firstWhere((state) => state.isDemoSession);

      final state = bloc.state;
      expect(state.isAuthenticated, isTrue);
      expect(state.shouldShowTenancy, isTrue);
      expect(state.shouldShowReports, isFalse);
      expect(state.tenantProfiles, isNotEmpty);
      expect(state.vehicles, isNotEmpty);
      expect(state.walletBalance, greaterThan(0));

      // The placeholder token lives in state alone — handing it to the API
      // client would put the demo on the wire and start the polling watches.
      expect(api.tokenWasSet, isFalse);
      expect(api.hasToken, isFalse);

      await bloc.close();
    });

    test('the owner demo lands on the owner side on sample data', () async {
      final bloc = AppBloc(api: _OfflineApi());

      bloc.add(const StartDemoSession('owner'));
      await bloc.stream.firstWhere((state) => state.isDemoSession);

      final state = bloc.state;
      expect(state.isAuthenticated, isTrue);
      expect(state.shouldShowReports, isTrue);
      expect(state.debugSampleData, isTrue);
      expect(state.shouldShowTenancy, isFalse);

      await bloc.close();
    });

    test('a dashboard refresh keeps the seeded data instead of expiring it',
        () async {
      final bloc = AppBloc(api: _OfflineApi());

      bloc.add(const StartDemoSession('tenant'));
      await bloc.stream.firstWhere((state) => state.isDemoSession);
      final seeded = bloc.state;

      bloc.add(LoadDashboardData());
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(bloc.state, seeded);
      expect(bloc.state.sessionExpired, isFalse);
      expect(bloc.state.vehicles, isNotEmpty);

      await bloc.close();
    });

    test('signing out of the owner demo drops the forced debug switches',
        () async {
      final bloc = AppBloc(api: _OfflineApi());

      bloc.add(const StartDemoSession('owner'));
      await bloc.stream.firstWhere((state) => state.isDemoSession);
      expect(bloc.state.debugManagerMode, isTrue);

      bloc.add(SignOut());
      await bloc.stream.firstWhere((state) => !state.isDemoSession);

      expect(bloc.state.isAuthenticated, isFalse);
      expect(bloc.state.debugManagerMode, isNull);
      expect(bloc.state.debugSampleData, isFalse);

      await bloc.close();
    });
  });

  testWidgets('the sign-in screen offers both demo buttons', (tester) async {
    final bloc = AppBloc(api: _OfflineApi());
    addTearDown(bloc.close);

    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<AppBloc>.value(
          value: bloc,
          child: const SignInScreen(),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Tenancy login'), findsOneWidget);
    expect(find.text('Owner login'), findsOneWidget);
  });
}
