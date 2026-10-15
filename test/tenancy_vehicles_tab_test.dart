import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:egesha/blocs/app_bloc.dart';
import 'package:egesha/blocs/app_state.dart';
import 'package:egesha/core/api/parking_iq_api.dart';
import 'package:egesha/models/api_models.dart';
import 'package:egesha/models/vehicle.dart';
import 'package:egesha/screens/dashboard/vehicles_screen.dart';

/// The Vehicles tab reads straight off AppState, so a bloc seeded with the
/// state under test is enough — no event ever has to run.
class _SeededAppBloc extends AppBloc {
  _SeededAppBloc(this._seed) : super(api: ParkingIqApi(debug: false));

  final AppState _seed;

  @override
  AppState get state => _seed;
}

Future<void> _pumpVehicles(WidgetTester tester, AppState state) async {
  await tester.pumpWidget(
    BlocProvider<AppBloc>(
      create: (_) => _SeededAppBloc(state),
      child: const MaterialApp(home: VehiclesScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('shows a tenancy plate the account does not hold', (tester) async {
    // The reported case: the plate was attached to the tenancy from the admin
    // panel, so GET /vehicles is empty and the plate only exists on the tenant.
    await _pumpVehicles(
      tester,
      AppState(tenantProfiles: [_profile(plateNumbers: const ['KDG 002B'])]),
    );

    await tester.scrollUntilVisible(find.text('Tenancy vehicles'), 250);

    expect(find.text('KDG 002B'), findsOneWidget);
    expect(find.text('Acme Tenant - Sarit Basement Parking'), findsOneWidget);
    expect(find.text('On your tenancy'), findsOneWidget);
  });

  testWidgets('points the empty fleet state at the tenancy list', (
    tester,
  ) async {
    await _pumpVehicles(
      tester,
      AppState(tenantProfiles: [_profile(plateNumbers: const ['KDG 002B'])]),
    );

    expect(
      find.text(
        'Your tenancy plates are listed below. Add your own vehicle to use '
        'AutoPay.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('does not repeat a plate the account also registered', (
    tester,
  ) async {
    await _pumpVehicles(
      tester,
      AppState(
        // Same car, spelled the way each source spells it.
        vehicles: const [
          Vehicle(
            id: 'vehicle-1',
            plateNumber: 'KDG002B',
            type: 'Saloon',
            make: 'Toyota',
            model: 'Axio',
          ),
        ],
        tenantProfiles: [_profile(plateNumbers: const ['KDG 002B'])],
      ),
    );

    expect(find.text('Tenancy vehicles'), findsNothing);
    expect(find.text('KDG002B'), findsOneWidget);
  });

  testWidgets('stays out of the way when there is no tenancy', (tester) async {
    await _pumpVehicles(
      tester,
      const AppState(
        vehicles: [
          Vehicle(
            id: 'vehicle-1',
            plateNumber: 'KCY001A',
            type: 'Saloon',
            make: 'Toyota',
            model: 'Axio',
          ),
        ],
      ),
    );

    expect(find.text('Tenancy vehicles'), findsNothing);
  });
}

TenantProfile _profile({List<String> plateNumbers = const []}) {
  return TenantProfile(
    id: 'tenant-1',
    name: 'Acme Tenant',
    clientId: 'client-1',
    clientName: 'Sarit Centre',
    locationId: 'location-1',
    locationName: 'Sarit Basement Parking',
    allocatedSlots: 2,
    status: 'ACTIVE',
    paymentStatus: 'PAID',
    slotEnforcement: 'REGISTERED_PLATES',
    subscriptionFee: 5000,
    pricingPlanName: 'Monthly Tenant Parking',
    plateNumbers: plateNumbers,
    ownerId: 'user-1',
    ownerName: 'Jane Driver',
    ownerPhoneNumber: '254711111111',
  );
}
