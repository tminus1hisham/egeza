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
import 'package:egesha/widgets/app_widgets.dart';
import 'package:egesha/widgets/manager_widgets.dart';

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

  Future<ValueNotifier<PropertySessionsPreset?>> pump(
    WidgetTester tester,
    ManagerState state, {
    // Wide enough that every filter pill is on screen at once, so a test can
    // tap one. The narrow-phone case is its own test at the bottom.
    Size size = const Size(600, 1400),
    VoidCallback? onOpenMyActivity,
  }) async {
    final preset = ValueNotifier<PropertySessionsPreset?>(null);
    addTearDown(preset.dispose);
    final cubit = _TestManagerCubit(state);
    addTearDown(cubit.close);

    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      BlocProvider<ManagerCubit>.value(
        value: cubit,
        child: MaterialApp(
          home: PropertySessionsScreen(
            preset: preset,
            onOpenMyActivity: onOpenMyActivity,
          ),
        ),
      ),
    );
    await tester.pump();
    return preset;
  }

  /// Plates on screen, in the order they are listed.
  List<String> platesOn(WidgetTester tester) {
    return tester
        .widgetList<PlateTag>(find.byType(PlateTag))
        .map((tag) => tag.plate)
        .toList();
  }

  /// Taps a filter pill by its label. Scoped to the pill rows because several
  /// of these words — AutoPay, Unpaid — also appear on the rows below.
  Future<void> tapPill(WidgetTester tester, String label) async {
    final pill = find.descendant(
      of: find.byType(FilterPills),
      matching: find.text(label),
    );
    await tester.tap(pill.first);
    await tester.pumpAndSettle();
  }

  testWidgets('lists the whole property, not the signed-in driver',
      (tester) async {
    await pump(tester, loaded);

    // Four cars used the site today; none of them belong to this account.
    expect(
      platesOn(tester),
      containsAll(<String>['KBR656Z', 'KDA123X', 'KCC999Y', 'KFF222D']),
    );

    final hero = tester.widget<PageHero>(find.byType(PageHero));
    expect(hero.eyebrow, 'Sarit · Sessions');
    expect(hero.value, '4');
    expect(tester.takeException(), isNull);
  });

  testWidgets('pins the cars still inside to the top of the list',
      (tester) async {
    await pump(tester, loaded);

    expect(platesOn(tester).first, 'KCC999Y');
  });

  testWidgets('parked now comes off the live list and ignores the period',
      (tester) async {
    await pump(tester, loaded);

    await tapPill(tester, 'Parked now');

    expect(platesOn(tester), ['KCC999Y']);
    // The period pills are gone: a car on the ground is on the ground.
    expect(find.text('7 days'), findsNothing);
    expect(
      find.textContaining('on the ground right now'),
      findsOneWidget,
    );
  });

  testWidgets('AutoPay narrows to the vehicles that pay without stopping',
      (tester) async {
    await pump(tester, loaded);

    await tapPill(tester, 'AutoPay');

    expect(platesOn(tester), ['KFF222D']);
    expect(find.textContaining('1 AutoPay session today'), findsOneWidget);
  });

  testWidgets('unpaid shows only cars that left without settling',
      (tester) async {
    await pump(tester, loaded);

    await tapPill(tester, 'Unpaid');

    // KDA123X drove off owing 150. The car still inside owes nothing yet.
    expect(platesOn(tester), ['KDA123X']);
    expect(find.textContaining('Owes 150'), findsOneWidget);
  });

  testWidgets('the period filter reaches back past today', (tester) async {
    await pump(tester, loaded);

    expect(platesOn(tester).contains('KEE777C'), isFalse);

    await tapPill(tester, '7 days');

    expect(platesOn(tester).contains('KEE777C'), isTrue);
    expect(find.textContaining('in the last 7 days'), findsOneWidget);
  });

  testWidgets('all time reaches the whole record', (tester) async {
    await pump(tester, loaded);

    await tapPill(tester, 'All time');

    expect(platesOn(tester), hasLength(6));
  });

  testWidgets('searching a plate ignores how the plate was spaced',
      (tester) async {
    await pump(tester, loaded);

    await tester.tap(find.byIcon(Icons.search_rounded));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'kbr 656');
    await tester.pumpAndSettle();

    expect(platesOn(tester), ['KBR656Z']);
  });

  testWidgets('a filter pushed in from the reports screen is applied',
      (tester) async {
    final preset = await pump(tester, loaded);

    preset.value = const PropertySessionsPreset(
      status: SessionStatusFilter.parkedNow,
    );
    await tester.pumpAndSettle();

    expect(platesOn(tester), ['KCC999Y']);
  });

  testWidgets('an owner can still reach their own activity', (tester) async {
    var opened = 0;
    await pump(tester, loaded, onOpenMyActivity: () => opened++);

    await tester.tap(find.byIcon(Icons.person_outline_rounded));
    await tester.pump();

    expect(opened, 1);
  });

  testWidgets('grows a page at a time rather than building thousands of rows',
      (tester) async {
    final crowd = [
      for (var i = 0; i < 60; i++)
        _session('c-$i', 'KAA${i.toString().padLeft(3, '0')}A',
            start: now.subtract(Duration(minutes: i)), paid: 100, cost: 100),
    ];
    await pump(
      tester,
      loaded.copyWith(historySessions: crowd, activeSessions: const []),
      size: const Size(320, 2400),
    );

    expect(platesOn(tester), hasLength(25));
    expect(find.textContaining('Show 25 more'), findsOneWidget);

    await tester.ensureVisible(find.textContaining('Show 25 more'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Show 25 more'));
    await tester.pumpAndSettle();

    expect(platesOn(tester), hasLength(50));
  });

  testWidgets('says what to do when a filter matches nothing', (tester) async {
    await pump(tester, loaded.copyWith(historySessions: const [
      // Nothing today at all.
    ], todaySessions: const [], activeSessions: const []));

    expect(find.text('No sessions match'), findsOneWidget);
  });

  testWidgets('lays out on a narrow phone without overflowing', (tester) async {
    // Filters are driven through the preset here rather than by tapping: at
    // 320px the last pills sit off the edge of their own scrolling row, which
    // is the point of that row.
    final preset = await pump(tester, loaded, size: const Size(320, 640));
    expect(tester.takeException(), isNull);

    preset.value = const PropertySessionsPreset(
      status: SessionStatusFilter.unpaid,
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(platesOn(tester), ['KDA123X']);
  });
}

ManagerState _saritState(DateTime now) {
  final yesterday = now.subtract(const Duration(days: 1));
  final lastMonth = now.subtract(const Duration(days: 20));
  final parked = _session('s-3', 'KCC999Y', start: _at(now, 11), cost: 80,
      active: true);

  final sessions = [
    _session('s-1', 'KBR656Z', start: _at(now, 8), paid: 300, cost: 300),
    _session('s-2', 'KDA123X', start: _at(now, 9), paid: 0, cost: 150),
    parked,
    _session('s-4', 'KFF222D', start: _at(now, 13), paid: 200, cost: 200,
        autoPay: true),
    _session('s-0', 'KEE777C', start: _at(yesterday, 9), paid: 600, cost: 600),
    _session('s-old', 'KGG333E', start: _at(lastMonth, 9), paid: 400,
        cost: 400),
  ];

  return ManagerState(
    isLoading: false,
    locations: const [
      ParkingLocation(id: 'loc-sarit', name: 'Sarit', maxCapacity: 300),
    ],
    selectedLocationId: 'loc-sarit',
    todaySessions: sessions.take(4).toList(),
    activeSessions: [parked],
    historySessions: sessions,
    historyPayments: const [],
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
