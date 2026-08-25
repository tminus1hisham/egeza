import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:egesha/blocs/manager_cubit.dart';
import 'package:egesha/blocs/manager_state.dart';
import 'package:egesha/core/api/parking_iq_api.dart';
import 'package:egesha/models/api_models.dart';
import 'package:egesha/models/parking_session.dart';
import 'package:egesha/models/vehicle.dart';
import 'package:egesha/screens/dashboard/property_sessions_screen.dart';
import 'package:egesha/screens/dashboard/reports_screen.dart';
import 'package:egesha/widgets/app_widgets.dart';

/// A cubit that holds whatever state it is given and never calls an API, but
/// still runs the real range switching so the period pills can be driven.
class _TestManagerCubit extends ManagerCubit {
  _TestManagerCubit(ManagerState initial) : super(api: _NoopApi()) {
    emit(initial);
  }

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

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  final now = DateTime.now();
  final loaded = _saritState(now);

  Future<PropertySessionsPreset?> pump(
    WidgetTester tester,
    ManagerState state, {
    Size size = const Size(320, 900),
  }) async {
    PropertySessionsPreset? requested;
    final cubit = _TestManagerCubit(state);
    addTearDown(cubit.close);

    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      BlocProvider<ManagerCubit>.value(
        value: cubit,
        child: MaterialApp(
          home: ReportsScreen(
            onOpenSessions: (preset) => requested = preset,
          ),
        ),
      ),
    );
    await tester.pump();
    return requested;
  }

  testWidgets('leads with the period, the money and the site', (tester) async {
    await pump(tester, loaded);

    final hero = tester.widget<PageHero>(find.byType(PageHero));
    expect(hero.eyebrow, 'Sarit · Today');
    // 300 settled this morning plus 200 this afternoon.
    expect(hero.value, 'KES 500');
    expect(
      hero.metrics.map((metric) => '${metric.label}=${metric.value}'),
      containsAll(<String>['Vehicles=3', 'Sessions=4', 'Parked now=1']),
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('explains the period in plain sentences before any chart',
      (tester) async {
    await pump(tester, loaded);

    expect(find.text('The short version'), findsOneWidget);
    expect(find.textContaining('KES 500 collected'), findsOneWidget);
    expect(find.textContaining('vehicles came in'), findsOneWidget);
    // The site is owed money by a car that already left, and says so.
    expect(find.textContaining('was never collected'), findsOneWidget);
    expect(find.textContaining('parked right now'), findsOneWidget);
  });

  testWidgets('switching the period redraws every figure on the page',
      (tester) async {
    await pump(tester, loaded);

    await tester.tap(find.text('7 days'));
    await tester.pumpAndSettle();

    final hero = tester.widget<PageHero>(find.byType(PageHero));
    expect(hero.eyebrow, 'Sarit · Last 7 days');
    // Today's 500 plus yesterday's 600.
    expect(hero.value, 'KES 1,100');
    // A week of trade is charted by the day, not by the hour.
    expect(find.text('Money by day'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('charts a single day by the hour', (tester) async {
    await pump(tester, loaded);

    expect(find.text('Money by hour'), findsOneWidget);
    expect(find.textContaining('Each bar is one hour'), findsOneWidget);
  });

  testWidgets('sends the reader to the rows behind the parked-now figure',
      (tester) async {
    PropertySessionsPreset? requested;
    final cubit = _TestManagerCubit(loaded);
    addTearDown(cubit.close);

    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      BlocProvider<ManagerCubit>.value(
        value: cubit,
        child: MaterialApp(
          home: ReportsScreen(onOpenSessions: (preset) => requested = preset),
        ),
      ),
    );
    await tester.pump();

    final button = find.text('See the vehicles parked now');
    await tester.ensureVisible(button);
    await tester.pump();
    await tester.tap(button);
    await tester.pump();

    expect(requested, isNotNull);
    expect(requested!.status, SessionStatusFilter.parkedNow);
  });

  testWidgets('says when every figure on the page is generated',
      (tester) async {
    await pump(tester, loaded.copyWith(isSample: true));

    expect(find.textContaining('Sample data'), findsOneWidget);
    final hero = tester.widget<PageHero>(find.byType(PageHero));
    expect((hero.pill! as PageHeroPill).label, 'Sample');
  });

  testWidgets('an account with no site is told so, not shown zeros',
      (tester) async {
    await pump(
      tester,
      const ManagerState(isLoading: false, hasNoAssignments: true),
    );

    expect(find.text('No property yet'), findsOneWidget);
    expect(find.byType(PageHero), findsNothing);
  });

  testWidgets('keeps the last figures and flags them when a refresh fails',
      (tester) async {
    await pump(
      tester,
      loaded.copyWith(errorMessage: 'Could not refresh — showing the last '
          'known figures'),
    );

    expect(find.textContaining('showing the last known figures'), findsOneWidget);
    expect(tester.widget<PageHero>(find.byType(PageHero)).value, 'KES 500');
  });

  testWidgets('draws a real generated site across every period',
      (tester) async {
    // End to end on the debug data: the cubit generates a site, the state
    // slices it, and the screen draws it — for a day, a week and a month.
    final cubit = ManagerCubit(api: _NoopApi(), useSampleData: true);
    await cubit.start(interval: const Duration(minutes: 5));

    tester.view.physicalSize = const Size(360, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      BlocProvider<ManagerCubit>.value(
        value: cubit,
        child: const MaterialApp(home: ReportsScreen()),
      ),
    );
    await tester.pump();

    for (final period in ['7 days', '30 days', 'Today']) {
      await tester.tap(find.text(period));
      await tester.pumpAndSettle();

      final hero = tester.widget<PageHero>(find.byType(PageHero));
      expect(hero.value, isNot('KES 0'), reason: '$period should have trade');
      expect(find.text('The short version'), findsOneWidget);
      expect(tester.takeException(), isNull, reason: '$period overflowed');
    }

    cubit.stop();
    await cubit.close();
  });

  testWidgets('reads back the bar the owner taps, and clears on a second tap', (
    tester,
  ) async {
    // Tall enough that the chart is on screen without scrolling, so a tap
    // lands on the bar rather than on whatever is pinned over it.
    await pump(tester, loaded, size: const Size(320, 1800));
    // The bars run up from nothing, and a bar of no height is nothing to tap.
    await tester.pumpAndSettle();

    // Nothing selected: the chart names its own best hour.
    expect(find.textContaining('Best hour:'), findsOneWidget);

    // The busiest-times card writes hours the same way, so count the label
    // rather than expecting it to be unique on the page.
    final hourLabel = find.text('08:00 – 09:00');
    final elsewhere = hourLabel.evaluate().length;

    // 08:00 is the ninth bar of the day.
    final bar = find.byType(FractionallySizedBox).at(8);
    expect(tester.getSize(bar).height, greaterThan(0));
    await tester.tap(bar);
    await tester.pumpAndSettle();

    expect(hourLabel.evaluate(), hasLength(elsewhere + 1));
    expect(find.textContaining('Best hour:'), findsNothing);

    await tester.tap(find.byType(FractionallySizedBox).at(8));
    await tester.pumpAndSettle();

    expect(hourLabel.evaluate(), hasLength(elsewhere));
    expect(find.textContaining('Best hour:'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('charts arrivals instead of money when asked', (tester) async {
    await pump(tester, loaded, size: const Size(320, 1800));

    expect(find.text('Money by hour'), findsOneWidget);

    // "Vehicles" is also a hero metric; the toggle is the later of the two.
    await tester.tap(find.text('Vehicles').last);
    await tester.pumpAndSettle();

    expect(find.text('Arrivals by hour'), findsOneWidget);
    expect(find.text('Money by hour'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps the period pills in reach after the page scrolls', (
    tester,
  ) async {
    await pump(tester, loaded, size: const Size(320, 640));

    final pillsBefore = tester.getTopLeft(find.text('7 days')).dy;
    expect(find.byType(PageHero), findsOneWidget);

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
    await tester.pumpAndSettle();

    // The hero has scrolled away entirely; the period switch stopped at the
    // top of the viewport rather than leaving with it.
    expect(find.byType(PageHero), findsNothing);
    final pillsAfter = tester.getTopLeft(find.text('7 days')).dy;
    expect(pillsAfter, lessThan(pillsBefore));
    expect(pillsAfter, lessThan(60));
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders in dark mode without borrowing light colours', (
    tester,
  ) async {
    final cubit = _TestManagerCubit(loaded);
    addTearDown(cubit.close);

    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      BlocProvider<ManagerCubit>.value(
        value: cubit,
        child: MaterialApp(
          theme: ThemeData(brightness: Brightness.dark),
          home: const ReportsScreen(),
        ),
      ),
    );
    await tester.pump();

    // Every card, meter track and rank badge on this page is painted from the
    // theme; a literal white would be one that was hardcoded.
    final surfaces = tester
        .widgetList<Container>(find.byType(Container))
        .map((container) => container.decoration)
        .whereType<BoxDecoration>()
        .map((decoration) => decoration.color)
        .whereType<Color>();
    expect(surfaces, isNot(contains(const Color(0xFFFFFFFF))));
    expect(tester.takeException(), isNull);
  });

  testWidgets('lays out on a narrow phone without overflowing', (tester) async {
    await pump(tester, loaded, size: const Size(320, 640));

    // Everything below the fold is still laid out by the scroll view, so an
    // overflow anywhere on the page would have thrown by now.
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('30 days'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}

ManagerState _saritState(DateTime now) {
  final yesterday = now.subtract(const Duration(days: 1));
  final sessions = [
    _session('s-1', 'KBR656Z', start: _at(now, 8), paid: 300, cost: 300),
    _session('s-2', 'KDA123X', start: _at(now, 9), paid: 0, cost: 150),
    _session('s-3', 'KCC999Y', start: _at(now, 11), cost: 80, active: true),
    _session('s-4', 'KBR656Z', start: _at(now, 13), paid: 200, cost: 200,
        autoPay: true),
    _session('s-0', 'KEE777C', start: _at(yesterday, 9), paid: 600, cost: 600),
  ];

  return ManagerState(
    isLoading: false,
    locations: const [
      ParkingLocation(id: 'loc-sarit', name: 'Sarit', maxCapacity: 300),
    ],
    selectedLocationId: 'loc-sarit',
    todaySessions: sessions.take(4).toList(),
    activeSessions: [sessions[2]],
    historySessions: sessions,
    historyPayments: [
      _payment('p-1', 300, 'SUCCESS', _at(now, 8)),
      _payment('p-2', 200, 'SUCCESS', _at(now, 13)),
      _payment('p-0', 600, 'SUCCESS', _at(yesterday, 10)),
    ],
    lastUpdated: now,
  );
}

DateTime _at(DateTime day, int hour) =>
    DateTime(day.year, day.month, day.day, hour);

ParkingSession _session(
  String id,
  String plate, {
  required DateTime start,
  double cost = 0,
  double paid = 0,
  bool active = false,
  bool autoPay = false,
}) {
  return ParkingSession(
    id: id,
    locationName: 'Sarit',
    startTime: start,
    endTime: active ? null : start.add(const Duration(hours: 1)),
    cost: cost > 0 ? cost : paid,
    amountPaid: paid,
    status: active ? 'ACTIVE' : 'COMPLETED',
    autoPayEnabled: autoPay,
    vehicle: Vehicle(
      plateNumber: plate,
      type: 'Saloon',
      make: 'Toyota',
      model: 'Axio',
      autoPayEnabled: autoPay,
    ),
    isActive: active,
  );
}

PaymentTransaction _payment(
  String id,
  double amount,
  String status,
  DateTime createdAt,
) {
  return PaymentTransaction(
    id: id,
    amount: amount,
    status: status,
    createdAt: createdAt,
    plateNumber: 'KBR656Z',
  );
}
