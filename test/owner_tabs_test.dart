import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:egesha/blocs/app_bloc.dart';
import 'package:egesha/blocs/app_event.dart';
import 'package:egesha/blocs/app_state.dart';
import 'package:egesha/core/api/parking_iq_api.dart';
import 'package:egesha/models/api_models.dart';
import 'package:egesha/models/parking_session.dart';
import 'package:egesha/models/vehicle.dart';
import 'package:egesha/screens/dashboard/history_screen.dart';
import 'package:egesha/screens/dashboard/main_nav.dart';
import 'package:egesha/screens/dashboard/property_sessions_screen.dart';
import 'package:egesha/screens/dashboard/reports_screen.dart';

/// Holds a fixed state and swallows dispatched events, so pumping the
/// navigator never reaches the real API.
class _StaticAppBloc extends AppBloc {
  _StaticAppBloc(this._state)
      : super(initialAuthToken: 'token', api: _NoSitesApi());

  final AppState _state;

  @override
  AppState get state => _state;

  @override
  void add(AppEvent event) {}
}

/// Signed in, but assigned to no location — the owner screens then settle on
/// their "no property" state instead of starting a polling loop the test would
/// have to wait out.
class _NoSitesApi extends ParkingIqApi {
  _NoSitesApi() : super(debug: false);

  @override
  bool get hasToken => true;

  @override
  Future<List<ParkingLocation>> fetchParkingLocations() async => const [];
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('who gets the owner side', () {
    test('a site owner or manager does, a driver does not', () {
      expect(const AppState(userRole: 'PATNER').shouldShowReports, isTrue);
      expect(const AppState(userRole: 'CLIENT').shouldShowReports, isTrue);
      expect(const AppState(userRole: 'MANAGER').shouldShowReports, isTrue);
      expect(const AppState(userRole: 'ADMIN').shouldShowReports, isTrue);
      expect(const AppState(userRole: 'USER').shouldShowReports, isFalse);
      expect(const AppState(userRole: 'TENANT').shouldShowReports, isFalse);
    });

    test('the debug switch decides when it is set', () {
      expect(
        const AppState(userRole: 'USER', debugManagerMode: true)
            .shouldShowReports,
        isTrue,
      );
      expect(
        const AppState(userRole: 'CLIENT', debugManagerMode: false)
            .shouldShowReports,
        isFalse,
      );
    });
  });

  Future<_StaticAppBloc> pumpNav(WidgetTester tester, AppState state) async {
    final bloc = _StaticAppBloc(state);
    addTearDown(bloc.close);

    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      BlocProvider<AppBloc>.value(
        value: bloc,
        child: const MaterialApp(home: MainNavigation()),
      ),
    );
    await tester.pump();
    return bloc;
  }

  testWidgets('an owner gets Reports, in the middle of the bar',
      (tester) async {
    await pumpNav(tester, const AppState(userRole: 'PATNER'));

    expect(find.byKey(const ValueKey('nav-reports')), findsOneWidget);
    expect(find.byKey(const ValueKey('nav-sessions')), findsOneWidget);
    // The driver-only History tab has given way to the property list.
    expect(find.byKey(const ValueKey('nav-history')), findsNothing);

    final centre = tester.getSize(find.byType(MainNavigation)).width / 2;
    expect(
      tester.getCenter(find.byKey(const ValueKey('nav-reports'))).dx,
      closeTo(centre, 1),
    );
  });

  testWidgets('a driver keeps the four tabs they had', (tester) async {
    await pumpNav(tester, const AppState(userRole: 'USER'));

    expect(find.byKey(const ValueKey('nav-reports')), findsNothing);
    expect(find.byKey(const ValueKey('nav-sessions')), findsNothing);
    expect(find.byKey(const ValueKey('nav-history')), findsOneWidget);
    expect(find.byType(ReportsScreen), findsNothing);
  });

  testWidgets('the owner tabs open the property screens', (tester) async {
    await pumpNav(tester, const AppState(userRole: 'CLIENT'));

    await tester.tap(find.byKey(const ValueKey('nav-reports')));
    await tester.pumpAndSettle();
    expect(find.byType(ReportsScreen), findsOneWidget);
    expect(find.text('No property yet'), findsWidgets);

    await tester.tap(find.byKey(const ValueKey('nav-sessions')));
    await tester.pumpAndSettle();
    expect(find.byType(PropertySessionsScreen), findsOneWidget);
  });

  testWidgets('an owner can still open their own history as a page',
      (tester) async {
    // The wallet only offers "See all" once this account has parked itself.
    await pumpNav(
      tester,
      AppState(
        userRole: 'CLIENT',
        recentSessions: [
          ParkingSession(
            id: 's-1',
            locationName: 'Sarit',
            startTime: DateTime.now().subtract(const Duration(hours: 2)),
            endTime: DateTime.now().subtract(const Duration(hours: 1)),
            cost: 120,
            amountPaid: 120,
            vehicle: const Vehicle(
              plateNumber: 'KBR656Z',
              type: 'Saloon',
              make: 'Toyota',
              model: 'Axio',
            ),
            isActive: false,
          ),
        ],
      ),
    );

    await tester.tap(find.byKey(const ValueKey('nav-wallet')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('See all'));
    await tester.pumpAndSettle();

    // Pushed rather than a tab, so it carries a way back.
    final history = tester.widget<HistoryScreen>(find.byType(HistoryScreen));
    expect(history.showBackButton, isTrue);
  });
}
