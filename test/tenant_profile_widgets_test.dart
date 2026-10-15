import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:egesha/core/api/parking_iq_api.dart';
import 'package:egesha/models/api_models.dart';
import 'package:egesha/models/vehicle.dart';
import 'package:egesha/screens/dashboard/tenancy_screen.dart';

/// The tenant profile page states each fact once: the header says where the
/// tenancy stands, the metric tiles carry the numbers behind it, and the
/// panels below hold the terms. These tests pin the numbers and check the page
/// survives a small phone, since every tile has to hold a date or an amount.
class _Api extends ParkingIqApi {
  _Api(this.profile, this.subscriptions) : super(debug: false);

  final TenantProfile profile;
  final List<TenantSubscription> subscriptions;

  @override
  Future<List<TenantProfile>> fetchMyTenantProfiles() async => [profile];

  @override
  Future<List<TenantSubscription>> fetchTenantSubscriptions(
    String tenantId,
  ) async => subscriptions;
}

TenantProfile _profile({
  required String status,
  required String paymentStatus,
  DateTime? start,
  DateTime? end,
  int slots = 3,
  List<String> plates = const ['KDA 123A', 'KBR 656Z'],
}) {
  return TenantProfile(
    id: 'tenant-1',
    name: 'Nairobi Garage Karen Suite 4B',
    clientId: 'client-1',
    clientName: 'Nairobi Garage',
    locationId: 'location-1',
    locationName: 'Karen Basement Parking',
    allocatedSlots: slots,
    status: status,
    paymentStatus: paymentStatus,
    slotEnforcement: 'ALLOCATED_SLOTS',
    subscriptionFee: 12500,
    pricingPlanName: 'Monthly Tenant Parking',
    subscriptionStartDate: start,
    subscriptionEndDate: end,
    plateNumbers: plates,
    ownerId: 'user-1',
    ownerName: 'Jane Driver',
    ownerPhoneNumber: '254711111111',
  );
}

TenantSubscription _subscription({
  required String status,
  required String paymentStatus,
  DateTime? start,
  DateTime? end,
  int grace = 5,
}) {
  return TenantSubscription(
    id: 'sub-1',
    tenantId: 'tenant-1',
    tenantName: 'Nairobi Garage Karen Suite 4B',
    pricingType: 'FIXED_FEE',
    amount: 12500,
    startDate: start,
    endDate: end,
    status: status,
    paymentStatus: paymentStatus,
    gracePeriodDays: grace,
  );
}

Future<void> _pump(
  WidgetTester tester, {
  required TenantProfile profile,
  List<TenantSubscription> subscriptions = const [],
  Size size = const Size(360, 740),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      home: TenantProfileDetailScreen(
        profile: profile,
        registeredVehicles: const [
          Vehicle(
            id: 'v1',
            plateNumber: 'KDA 123A',
            type: 'Saloon',
            make: 'Toyota',
            model: 'Axio',
          ),
        ],
        api: _Api(profile, subscriptions),
        defaultPhoneNumber: '254711111111',
        onPay: (_) async {},
      ),
    ),
  );
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
}

/// Walks the whole page so every section below the fold is laid out too.
Future<void> _scrollThrough(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.drag(find.byType(ListView), const Offset(0, -400));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  }
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  final now = DateTime.now();

  testWidgets('a running cycle reports the time left, not just the dates', (
    tester,
  ) async {
    final start = now.subtract(const Duration(days: 12));
    final end = now.add(const Duration(days: 18));

    await _pump(
      tester,
      profile: _profile(
        status: 'ACTIVE',
        paymentStatus: 'PAID',
        start: start,
        end: end,
      ),
      subscriptions: [
        _subscription(
          status: 'ACTIVE',
          paymentStatus: 'PAID',
          start: start,
          end: end,
        ),
      ],
    );

    // The metric tiles: fee, days remaining, plates against the allocation.
    expect(find.text('KES 12,500'), findsOneWidget);
    expect(find.text('18 days'), findsOneWidget);
    expect(find.text('2 of 3'), findsOneWidget);
    // And the cycle itself, as a bar rather than two loose dates.
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
  });

  testWidgets('an undated tenancy says so instead of showing a fake date', (
    tester,
  ) async {
    await _pump(
      tester,
      profile: _profile(status: 'PENDING', paymentStatus: 'PENDING'),
    );

    expect(find.text('Not set'), findsOneWidget);
    expect(find.text('starts after payment'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    await _scrollThrough(tester);
    expect(find.text('Starts after payment'), findsOneWidget);
  });

  testWidgets('slot enforcement is spelled out, not left as an enum', (
    tester,
  ) async {
    await _pump(
      tester,
      profile: _profile(status: 'ACTIVE', paymentStatus: 'PAID'),
    );
    await _scrollThrough(tester);

    expect(find.text('Your 3 allocated slots'), findsOneWidget);
    expect(find.text('ALLOCATED_SLOTS'), findsNothing);
    expect(find.text('Allocated Slots'), findsNothing);
  });

  testWidgets('the grace window is shown only when there is one', (
    tester,
  ) async {
    final start = now.subtract(const Duration(days: 12));
    final end = now.add(const Duration(days: 18));

    await _pump(
      tester,
      profile: _profile(
        status: 'ACTIVE',
        paymentStatus: 'PAID',
        start: start,
        end: end,
      ),
      subscriptions: [
        _subscription(
          status: 'ACTIVE',
          paymentStatus: 'PAID',
          start: start,
          end: end,
          grace: 0,
        ),
      ],
    );
    await _scrollThrough(tester);

    expect(find.text('Grace period'), findsNothing);
  });

  testWidgets('the page holds together on a small phone', (tester) async {
    final start = now.subtract(const Duration(days: 28));
    final end = now.add(const Duration(days: 2));

    for (final profile in [
      _profile(
        status: 'ACTIVE',
        paymentStatus: 'PAID',
        start: start,
        end: end,
      ),
      _profile(status: 'PENDING', paymentStatus: 'PENDING'),
      _profile(
        status: 'SUSPENDED',
        paymentStatus: 'PAID',
        slots: 0,
        plates: const [],
      ),
    ]) {
      await _pump(
        tester,
        profile: profile,
        subscriptions: [
          _subscription(
            status: profile.status,
            paymentStatus: profile.paymentStatus,
            start: start,
            end: end,
          ),
        ],
        size: const Size(320, 640),
      );
      await _scrollThrough(tester);
    }
  });
}
