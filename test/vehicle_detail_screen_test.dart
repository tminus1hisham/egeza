import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:egesha/blocs/app_bloc.dart';
import 'package:egesha/blocs/app_event.dart';
import 'package:egesha/blocs/app_state.dart';
import 'package:egesha/models/parking_session.dart';
import 'package:egesha/models/vehicle.dart';
import 'package:egesha/screens/dashboard/vehicle_detail_screen.dart';
import 'package:egesha/widgets/app_widgets.dart';

/// Holds a fixed state and records what the screen dispatches, so a pump never
/// reaches the real API.
class _RecordingAppBloc extends AppBloc {
  _RecordingAppBloc(this._state) : super(initialAuthToken: 'token');

  AppState _state;
  final List<AppEvent> events = [];

  @override
  AppState get state => _state;

  @override
  void add(AppEvent event) => events.add(event);

  set state(AppState value) => _state = value;
}

/// Vehicle Details was the last screen still painting from private colour
/// constants and its own gradient. These cover what the rebuild is for: numbers
/// that reconcile, copy that describes its own state, no invented location
/// data, and an AutoPay switch that reads the bloc rather than a local copy.
void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  const prado = Vehicle(
    id: 'v1',
    plateNumber: 'KBR656Z',
    type: 'SUV / 4x4',
    make: 'Toyota',
    model: 'Prado',
    autoPayEnabled: true,
  );

  ParkingSession session({
    required String id,
    required String location,
    required DateTime start,
    DateTime? end,
    double cost = 180,
    bool isActive = false,
    // Settled by default. `isActive: false` alone no longer implies paid —
    // an exited session with an unpaid status is a bill, not history.
    String status = 'COMPLETED',
  }) {
    return ParkingSession(
      id: id,
      locationName: location,
      startTime: start,
      endTime: end,
      cost: cost,
      status: status,
      vehicle: prado,
      isActive: isActive,
    );
  }

  final settledSessions = [
    session(
      id: 's1',
      location: 'Garden City Mall',
      start: DateTime.utc(2026, 8, 14, 9, 20),
      end: DateTime.utc(2026, 8, 14, 11, 0),
      cost: 180,
    ),
    session(
      id: 's2',
      location: 'Sarit Centre',
      start: DateTime.utc(2026, 8, 12, 6, 5),
      end: DateTime.utc(2026, 8, 12, 7, 0),
      cost: 120,
    ),
  ];

  final liveSession = session(
    id: 's0',
    location: 'Two Rivers Mall',
    start: DateTime.now().toUtc().subtract(const Duration(hours: 2)),
    cost: 240,
    isActive: true,
    status: 'ACTIVE',
  );

  late _RecordingAppBloc bloc;

  tearDown(() => bloc.close());

  Future<void> pumpDetail(
    WidgetTester tester, {
    required AppState state,
    Vehicle vehicle = prado,
    Size size = const Size(320, 900),
  }) async {
    bloc = _RecordingAppBloc(state);
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      BlocProvider<AppBloc>.value(
        value: bloc,
        child: MaterialApp(home: VehicleDetailScreen(vehicle: vehicle)),
      ),
    );
    await tester.pump();
  }

  AppState stateWith({
    List<ParkingSession> sessions = const [],
    Vehicle vehicle = prado,
  }) {
    return AppState(vehicles: [vehicle], recentSessions: sessions);
  }

  group('hero', () {
    testWidgets('leads with the plate, not a generic page title',
        (tester) async {
      await pumpDetail(tester, state: stateWith(sessions: settledSessions));

      expect(find.byType(PageHero), findsOneWidget);
      expect(find.text('KBR656Z'), findsWidgets);
      // The old bespoke header named the page instead of the car.
      expect(find.text('Vehicle Details'), findsNothing);
      expect(find.text('Toyota Prado · SUV / 4x4'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('session count and spend are drawn from the same list',
        (tester) async {
      await pumpDetail(
        tester,
        state: stateWith(sessions: [liveSession, ...settledSessions]),
      );

      // Two settled sessions worth 180 + 120. The live session is money in
      // progress and appears in neither number — it has its own card.
      expect(find.text('2'), findsOneWidget);
      expect(find.text('KES 300'), findsOneWidget);
    });

    testWidgets('states AutoPay once, in the hero pill', (tester) async {
      await pumpDetail(tester, state: stateWith(sessions: settledSessions));

      expect(find.text('AutoPay on'), findsOneWidget);
    });

    testWidgets('reports never seen when the plate has no sessions',
        (tester) async {
      await pumpDetail(tester, state: stateWith());

      expect(find.text('Never'), findsOneWidget);
      expect(find.text('No sessions yet'), findsOneWidget);
    });
  });

  group('live session', () {
    testWidgets('outranks the settings group', (tester) async {
      await pumpDetail(
        tester,
        state: stateWith(sessions: [liveSession, ...settledSessions]),
      );

      final live = tester.getTopLeft(find.text('Running total')).dy;
      final setup = tester.getTopLeft(find.text('Vehicle setup')).dy;
      expect(live, lessThan(setup));
    });

    testWidgets('is absent when the plate is not parked', (tester) async {
      await pumpDetail(tester, state: stateWith(sessions: settledSessions));

      expect(find.text('Running total'), findsNothing);
      expect(find.text('Pay now'), findsNothing);
    });

    testWidgets('paying dispatches for the live session', (tester) async {
      await pumpDetail(tester, state: stateWith(sessions: [liveSession]));

      await tester.tap(find.text('Pay now'));
      await tester.pump();

      expect(bloc.events, hasLength(1));
      expect((bloc.events.single as PayParkingSession).sessionId, 's0');
    });

    testWidgets('the caption describes the AutoPay state it is in',
        (tester) async {
      await pumpDetail(tester, state: stateWith(sessions: [liveSession]));
      expect(
        find.text('AutoPay will charge this at the barrier'),
        findsOneWidget,
      );

      // The regression this replaces: with AutoPay off the card used to say
      // "Deducts automatically at exit".
      await pumpDetail(
        tester,
        vehicle: prado.copyWith(autoPayEnabled: false),
        state: stateWith(
          sessions: [liveSession],
          vehicle: prado.copyWith(autoPayEnabled: false),
        ),
      );
      expect(find.text('Pay here or at the exit barrier'), findsOneWidget);
    });
  });

  group('AutoPay', () {
    testWidgets('reads the bloc rather than a copy taken at push time',
        (tester) async {
      await pumpDetail(
        tester,
        // The pushed vehicle says AutoPay is on; the bloc says otherwise.
        vehicle: prado,
        state: stateWith(vehicle: prado.copyWith(autoPayEnabled: false)),
      );

      expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
      expect(find.text('AutoPay on'), findsNothing);
      expect(find.text('AutoPay off'), findsOneWidget);
    });

    testWidgets('flipping dispatches and locks the switch until confirmed',
        (tester) async {
      await pumpDetail(tester, state: stateWith());

      await tester.tap(find.byType(Switch));
      await tester.pump();

      final event = bloc.events.single as SetVehicleAutoPay;
      expect(event.vehicleId, 'v1');
      expect(event.plateNumber, 'KBR656Z');
      expect(event.enabled, isFalse);

      // Shows the requested value while in flight, and refuses a second tap
      // that would queue a contradicting request.
      final control = tester.widget<Switch>(find.byType(Switch));
      expect(control.value, isFalse);
      expect(control.onChanged, isNull);
    });
  });

  group('history', () {
    testWidgets('shows real times instead of invented bay numbers',
        (tester) async {
      await pumpDetail(tester, state: stateWith(sessions: settledSessions));

      // Times are rendered in EAT (UTC+3) from the session itself.
      expect(find.text('14 Aug · 12:20 → 14:00'), findsOneWidget);
      expect(find.text('12 Aug · 09:05 → 10:00'), findsOneWidget);

      // The strings the removed _locationSubtitle used to fabricate.
      expect(find.text('Basement · Bay B-11'), findsNothing);
      expect(find.text('Ground Floor · Bay A-07'), findsNothing);
      expect(find.textContaining('Bay '), findsNothing);
    });

    testWidgets('lists settled sessions only, so the live one is not doubled',
        (tester) async {
      await pumpDetail(
        tester,
        state: stateWith(sessions: [liveSession, ...settledSessions]),
      );

      // Named once, in its own card's header.
      expect(find.textContaining('Two Rivers Mall'), findsOneWidget);
    });

    testWidgets('caps the list until asked for the rest', (tester) async {
      final many = List.generate(
        7,
        (i) => session(
          id: 'm$i',
          location: 'Location $i',
          start: DateTime.utc(2026, 8, 14 - i, 9, 0),
          end: DateTime.utc(2026, 8, 14 - i, 10, 0),
        ),
      );

      await pumpDetail(
        tester,
        state: stateWith(sessions: many),
        size: const Size(320, 2400),
      );

      expect(find.text('View all 7'), findsOneWidget);
      expect(find.text('Location 5'), findsNothing);

      await tester.tap(find.text('View all 7'));
      await tester.pump();

      expect(find.text('Location 5'), findsOneWidget);
      expect(find.text('Show less'), findsOneWidget);
    });
  });

  group('removal', () {
    testWidgets('is a quiet control that confirms before dispatching',
        (tester) async {
      await pumpDetail(tester, state: stateWith(sessions: settledSessions));

      await tester.tap(find.text('Remove this vehicle'));
      await tester.pumpAndSettle();

      // The dialog names the plate and says what is actually lost.
      expect(find.text('Remove KBR656Z?'), findsOneWidget);
      expect(bloc.events, isEmpty);

      await tester.tap(find.text('Keep it'));
      await tester.pumpAndSettle();
      expect(bloc.events, isEmpty);

      await tester.tap(find.text('Remove this vehicle'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove'));
      await tester.pumpAndSettle();

      final event = bloc.events.single as RemoveVehicle;
      expect(event.plateNumber, 'KBR656Z');
      expect(event.vehicleId, 'v1');
    });
  });

  testWidgets('renders in dark mode without borrowing light colours',
      (tester) async {
    bloc = _RecordingAppBloc(stateWith(sessions: [liveSession, ...settledSessions]));
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      BlocProvider<AppBloc>.value(
        value: bloc,
        child: MaterialApp(
          theme: ThemeData(brightness: Brightness.dark),
          home: const VehicleDetailScreen(vehicle: prado),
        ),
      ),
    );
    await tester.pump();

    // The empty-state card used to hardcode Colors.white, which is what a
    // literal surface looks like on a dark page.
    final surfaces = tester
        .widgetList<Container>(find.byType(Container))
        .map((c) => c.decoration)
        .whereType<BoxDecoration>()
        .map((d) => d.color)
        .whereType<Color>();

    expect(surfaces, isNot(contains(Colors.white)));
    expect(tester.takeException(), isNull);
  });
}
