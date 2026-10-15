import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:egesha/core/api/parking_iq_api.dart';
import 'package:egesha/models/api_models.dart';
import 'package:egesha/models/vehicle.dart';
import 'package:egesha/screens/dashboard/tenancy_screen.dart';

class _TenantProfileApi extends ParkingIqApi {
  _TenantProfileApi(this.latestProfile) : super(debug: false);

  final TenantProfile latestProfile;

  @override
  Future<List<TenantProfile>> fetchMyTenantProfiles() async => [latestProfile];

  @override
  Future<List<TenantSubscription>> fetchTenantSubscriptions(
    String tenantId,
  ) async => const [];
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('TenantProfile vehicle parsing', () {
    test('parses and de-duplicates the documented plateNumbers list', () {
      final profile = TenantProfile.fromJson({
        'id': 'tenant-1',
        'plateNumbers': [' KDA 123A ', 'kda-123a', '', 'KBR 456B'],
      });

      expect(profile.plateNumbers, ['KDA 123A', 'KBR 456B']);
    });

    test('accepts embedded vehicle objects from compatible API payloads', () {
      final profile = TenantProfile.fromJson({
        'id': 'tenant-1',
        'vehicles': [
          {'id': 'vehicle-1', 'plateNumber': 'KCY 001A'},
          {
            'vehicle': {'registrationNumber': 'KDG 002B'},
          },
        ],
        'tenantVehicles': [
          {'plate': 'kcy-001a'},
        ],
      });

      expect(profile.plateNumbers, ['KCY 001A', 'KDG 002B']);
    });
  });

  testWidgets('refreshes tenant plates instead of keeping the stale snapshot', (
    tester,
  ) async {
    final initialProfile = _profile();
    final latestProfile = _profile(plateNumbers: const ['KDG 002B']);

    await tester.pumpWidget(
      MaterialApp(
        home: TenantProfileDetailScreen(
          profile: initialProfile,
          api: _TenantProfileApi(latestProfile),
          defaultPhoneNumber: null,
          onPay: (_) async {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('KDG 002B'), findsOneWidget);
    expect(find.text('No plates'), findsNothing);
  });

  testWidgets('lists a tenant plate the account itself does not hold', (
    tester,
  ) async {
    // The case that hides an admin-added vehicle: it is attached to the
    // tenancy, so GET /vehicles (registeredVehicles) is empty.
    final profile = _profile(plateNumbers: const ['KDG 002B']);

    await tester.pumpWidget(
      MaterialApp(
        home: TenantProfileDetailScreen(
          profile: profile,
          api: _TenantProfileApi(profile),
          defaultPhoneNumber: null,
          onPay: (_) async {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Vehicles'), 250);

    expect(find.text('KDG 002B'), findsOneWidget);
    expect(find.text('On this tenancy'), findsOneWidget);
    expect(find.text('No vehicles'), findsNothing);
  });

  testWidgets('describes a tenant plate with the account vehicle details', (
    tester,
  ) async {
    final profile = _profile(plateNumbers: const ['kcy-001a']);

    await tester.pumpWidget(
      MaterialApp(
        home: TenantProfileDetailScreen(
          profile: profile,
          registeredVehicles: const [
            Vehicle(
              id: 'vehicle-1',
              plateNumber: 'KCY 001A',
              type: 'Saloon',
              make: 'Toyota',
              model: 'Axio',
            ),
          ],
          api: _TenantProfileApi(profile),
          defaultPhoneNumber: null,
          onPay: (_) async {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Vehicles'), 250);

    // Listed once, under the tenant's own plate spelling.
    expect(find.text('kcy-001a'), findsOneWidget);
    expect(find.text('KCY 001A'), findsNothing);
    expect(find.text('Toyota Axio - On this tenancy'), findsOneWidget);
  });

  testWidgets('shows registered account vehicles and their tenant link state', (
    tester,
  ) async {
    final profile = _profile();

    await tester.pumpWidget(
      MaterialApp(
        home: TenantProfileDetailScreen(
          profile: profile,
          registeredVehicles: const [
            Vehicle(
              id: 'vehicle-1',
              plateNumber: 'KCY 001A',
              type: 'Saloon',
              make: 'Toyota',
              model: 'Axio',
            ),
          ],
          api: _TenantProfileApi(profile),
          defaultPhoneNumber: null,
          onPay: (_) async {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Vehicles'), 250);

    expect(find.text('KCY 001A'), findsOneWidget);
    expect(
      find.text('Toyota Axio - Not linked to this tenancy'),
      findsOneWidget,
    );
  });

  testWidgets('says so when the tenancy and the account are both empty', (
    tester,
  ) async {
    final profile = _profile();

    await tester.pumpWidget(
      MaterialApp(
        home: TenantProfileDetailScreen(
          profile: profile,
          api: _TenantProfileApi(profile),
          defaultPhoneNumber: null,
          onPay: (_) async {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Vehicles'), 250);

    expect(find.text('No vehicles'), findsOneWidget);
    expect(find.text('No plates on this tenancy yet'), findsOneWidget);
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
