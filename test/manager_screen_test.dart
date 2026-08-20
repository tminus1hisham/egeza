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
import 'package:egesha/screens/dashboard/manager_screen.dart';
import 'package:egesha/widgets/app_widgets.dart';

/// Holds a fixed state and never talks to an API, so the screen can be pumped
/// in every condition it has to survive.
class _StaticManagerCubit extends ManagerCubit {
  _StaticManagerCubit(this._state) : super(api: _NoopApi());

  final ManagerState _state;

  @override
  ManagerState get state => _state;

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
  final busySarit = ManagerState(
    isLoading: false,
    locations: const [_sarit],
    selectedLocationId: _saritId,
    todaySessions: [
      _session('s-1', 'KBR656Z', start: _at(now, 7), paid: 300, cost: 300),
      _session('s-2', 'KDA123X', start: _at(now, 9), paid: 0, cost: 150),
      _session('s-3', 'KCC999Y', start: _at(now, 10), active: true, cost: 80),
    ],
    activeSessions: [
      _session('s-3', 'KCC999Y', start: _at(now, 10), active: true, cost: 80),
    ],
    todayPayments: [
      PaymentTransaction(
        id: 'p-1',
        amount: 300,
        status: 'SUCCESS',
        createdAt: _at(now, 8),
        plateNumber: 'KBR656Z',
      ),
    ],
    lastUpdated: now,
  );

  Future<void> pump(
    WidgetTester tester,
    ManagerState state, {
    Size size = const Size(320, 800),
  }) async {
    final cubit = _StaticManagerCubit(state);
    addTearDown(cubit.close);

    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      BlocProvider<ManagerCubit>.value(
        value: cubit,
        child: const MaterialApp(home: ManagerView()),
      ),
    );
    await tester.pump();
  }

  testWidgets('leads with the three numbers a manager came for',
      (tester) async {
    await pump(tester, busySarit);

    // Money made today, on the hero's value line.
    expect(find.text('KES 300'), findsWidgets);

    // Vehicles in today and cars still on the ground, as hero metrics.
    final hero = tester.widget<PageHero>(find.byType(PageHero));
    expect(hero.eyebrow, 'Sarit · Takings today');
    expect(hero.value, 'KES 300');
    expect(
      hero.metrics.map((m) => '${m.label}=${m.value}'),
      containsAll(<String>['Vehicles today=3', 'Parked now=1']),
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('shows live occupancy against the site capacity', (tester) async {
    await pump(tester, busySarit);

    expect(find.text('1 of 300 spaces'), findsOneWidget);
    expect(find.text('299 spaces free'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('lists what is parked right now and what left today',
      (tester) async {
    await pump(tester, busySarit, size: const Size(320, 1600));

    expect(find.text('Parked right now'), findsOneWidget);
    expect(find.text('1 vehicle'), findsOneWidget);
    expect(find.text('Exits today'), findsOneWidget);
    // The two closed sessions, one paid and one still owing.
    expect(find.text('2 sessions'), findsOneWidget);
    expect(find.text('Owes 150'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('says so when payments could not be read', (tester) async {
    await pump(
      tester,
      busySarit.copyWith(revenueSource: ManagerRevenueSource.sessions),
      size: const Size(320, 1600),
    );

    expect(
      find.textContaining('Payment records are unavailable'),
      findsOneWidget,
    );
    // Falls back to what today's sessions recorded as paid.
    final hero = tester.widget<PageHero>(find.byType(PageHero));
    expect(hero.value, 'KES 300');
  });

  testWidgets('an empty site renders its own empty states, not zeros in a list',
      (tester) async {
    await pump(
      tester,
      const ManagerState(
        isLoading: false,
        locations: [_sarit],
        selectedLocationId: _saritId,
      ).copyWith(lastUpdated: now),
      size: const Size(320, 1400),
    );

    expect(find.text('Nothing on the ground'), findsOneWidget);
    expect(find.text('No exits yet today'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an unassigned account is told why there is nothing to see',
      (tester) async {
    await pump(
      tester,
      const ManagerState(isLoading: false, hasNoAssignments: true),
    );

    expect(find.text('No sites assigned'), findsOneWidget);
    expect(find.byType(PageHero), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a failed refresh keeps the figures and flags them as stale',
      (tester) async {
    await pump(
      tester,
      busySarit.copyWith(
        errorMessage: 'Could not refresh — showing the last known figures',
      ),
    );

    // The numbers are still there rather than replaced by an error page.
    expect(find.byType(PageHero), findsOneWidget);
    expect(
      find.text('Could not refresh — showing the last known figures'),
      findsOneWidget,
    );
  });

  testWidgets('sample readings are badged, live ones are not', (tester) async {
    await pump(tester, busySarit);
    expect(tester.widget<PageHero>(find.byType(PageHero)).pill, isA<PageHeroPill>()
        .having((p) => p.label, 'label', 'Live'));
    expect(find.textContaining('Sample data'), findsNothing);

    // A generated figure that is not labelled is worse than no figure at all,
    // so the badge has to sit above everything it applies to.
    await pump(tester, busySarit.copyWith(isSample: true));
    expect(tester.widget<PageHero>(find.byType(PageHero)).pill, isA<PageHeroPill>()
        .having((p) => p.label, 'label', 'Sample'));
    expect(find.textContaining('Sample data'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a full site caps its lists instead of rendering every row',
      (tester) async {
    final crowd = [
      for (var i = 0; i < 40; i++)
        _session('busy-$i', 'KAA${i.toString().padLeft(3, '0')}B',
            start: _at(now, 8), active: true, cost: 120),
    ];

    await pump(
      tester,
      busySarit.copyWith(activeSessions: crowd, todaySessions: crowd),
      size: const Size(320, 2400),
    );

    // The header still reports the true count; the rows are a top slice.
    expect(find.text('40 vehicles'), findsOneWidget);
    expect(find.text('+32 more parked'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('offers a switcher only when more than one site is managed',
      (tester) async {
    await pump(tester, busySarit);
    expect(find.text('Nairobi CBD Parking'), findsNothing);

    await pump(
      tester,
      busySarit.copyWith(locations: const [_sarit, _cbd]),
    );
    expect(find.text('Nairobi CBD Parking'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

const _saritId = 'loc-sarit';

const _sarit = ParkingLocation(
  id: _saritId,
  name: 'Sarit',
  maxCapacity: 300,
);
const _cbd = ParkingLocation(
  id: 'loc-cbd',
  name: 'Nairobi CBD Parking',
  maxCapacity: 250,
);

DateTime _at(DateTime day, int hour) =>
    DateTime(day.year, day.month, day.day, hour);

ParkingSession _session(
  String id,
  String plate, {
  required DateTime start,
  double cost = 0,
  double paid = 0,
  bool active = false,
}) {
  return ParkingSession(
    id: id,
    locationName: 'Sarit',
    startTime: start,
    endTime: active ? null : start.add(const Duration(hours: 1)),
    cost: cost,
    amountPaid: paid,
    status: active ? 'ACTIVE' : 'COMPLETED',
    vehicle: Vehicle(
      plateNumber: plate,
      type: 'Saloon',
      make: 'Toyota',
      model: 'Axio',
    ),
    isActive: active,
  );
}
