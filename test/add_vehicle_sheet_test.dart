import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:egesha/blocs/app_bloc.dart';
import 'package:egesha/blocs/app_event.dart';
import 'package:egesha/widgets/add_vehicle_sheet.dart';

/// Records what the sheet dispatches without forwarding it, so the test never
/// reaches the real API.
class _RecordingAppBloc extends AppBloc {
  _RecordingAppBloc() : super(initialAuthToken: 'token');

  final List<AppEvent> events = [];

  @override
  void add(AppEvent event) => events.add(event);
}

/// The sheet is opened from three places — the Vehicles fleet card, the
/// Vehicles add card, and the dashboard's Add Car tile — so it owns its own
/// form state rather than borrowing a screen's controllers.
void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  late _RecordingAppBloc bloc;

  setUp(() => bloc = _RecordingAppBloc());
  tearDown(() => bloc.close());

  Widget host() {
    return BlocProvider<AppBloc>.value(
      value: bloc,
      child: MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () => showAddVehicleSheet(context),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> openSheet(WidgetTester tester) async {
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Finder fieldNamed(String label) => find.widgetWithText(TextField, label);

  testWidgets('opens with the add vehicle form', (tester) async {
    await tester.pumpWidget(host());
    await openSheet(tester);

    expect(find.text('Add vehicle'), findsOneWidget);
    expect(fieldNamed('Plate number'), findsOneWidget);
    expect(fieldNamed('Make'), findsOneWidget);
    expect(fieldNamed('Model'), findsOneWidget);
    expect(find.text('Save Vehicle'), findsOneWidget);
  });

  testWidgets('saving dispatches AddVehicle with an upper-cased plate',
      (tester) async {
    await tester.pumpWidget(host());
    await openSheet(tester);

    await tester.enterText(fieldNamed('Plate number'), 'kbr 656z');
    await tester.enterText(fieldNamed('Make'), 'Toyota');
    await tester.enterText(fieldNamed('Model'), 'Prado');
    await tester.pump();

    await tester.tap(find.text('Save Vehicle'));
    await tester.pumpAndSettle();

    expect(bloc.events, hasLength(1));
    final event = bloc.events.single as AddVehicle;
    // The sheet only upper-cases. Stripping the space to the ANPR canonical
    // form is AppBloc's job, via Vehicle.plateKey() in the AddVehicle handler.
    expect(event.plateNumber, 'KBR 656Z');
    expect(event.make, 'Toyota');
    expect(event.model, 'Prado');
    expect(event.autoPayEnabled, isTrue);

    // Sheet closes once saved.
    expect(find.text('Add vehicle'), findsNothing);
  });

  testWidgets('blank make and model fall back rather than saving empties',
      (tester) async {
    await tester.pumpWidget(host());
    await openSheet(tester);

    await tester.enterText(fieldNamed('Plate number'), 'KDG112A');
    await tester.pump();
    await tester.tap(find.text('Save Vehicle'));
    await tester.pumpAndSettle();

    final event = bloc.events.single as AddVehicle;
    expect(event.make, 'Custom');
    expect(event.model, 'Vehicle');
  });

  testWidgets('an empty plate dispatches nothing and keeps the sheet open',
      (tester) async {
    await tester.pumpWidget(host());
    await openSheet(tester);

    await tester.tap(find.text('Save Vehicle'));
    await tester.pumpAndSettle();

    expect(bloc.events, isEmpty);
    expect(find.text('Add vehicle'), findsOneWidget);
  });

  testWidgets('reopening starts from an empty form', (tester) async {
    await tester.pumpWidget(host());

    await openSheet(tester);
    await tester.enterText(fieldNamed('Plate number'), 'KBR656Z');
    await tester.pump();
    Navigator.of(tester.element(find.text('Add vehicle'))).pop();
    await tester.pumpAndSettle();

    await openSheet(tester);
    final plate = tester.widget<TextField>(fieldNamed('Plate number'));
    expect(plate.controller!.text, isEmpty);
  });

  testWidgets('AutoPay defaults on and can be toggled off', (tester) async {
    await tester.pumpWidget(host());
    await openSheet(tester);

    expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
    expect(find.text('Charged automatically at exit'), findsOneWidget);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
    expect(find.text('Pay manually for each session'), findsOneWidget);

    await tester.enterText(fieldNamed('Plate number'), 'KBR656Z');
    await tester.pump();
    await tester.tap(find.text('Save Vehicle'));
    await tester.pumpAndSettle();

    expect((bloc.events.single as AddVehicle).autoPayEnabled, isFalse);
  });
}
