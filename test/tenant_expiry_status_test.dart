import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:egesha/blocs/app_bloc.dart';
import 'package:egesha/blocs/app_state.dart';
import 'package:egesha/core/api/parking_iq_api.dart';
import 'package:egesha/core/theme/app_colors.dart';
import 'package:egesha/models/api_models.dart';
import 'package:egesha/screens/dashboard/tenancy_screen.dart';

/// The tenancy list reads its profiles off AppState, and a demo session keeps
/// it from reaching for the network on top of them.
class _SeededAppBloc extends AppBloc {
  _SeededAppBloc(this._seed) : super(api: ParkingIqApi(debug: false));

  final AppState _seed;

  @override
  AppState get state => _seed;
}

class _TenantProfileApi extends ParkingIqApi {
  _TenantProfileApi(this.profile) : super(debug: false);

  final TenantProfile profile;

  @override
  Future<List<TenantProfile>> fetchMyTenantProfiles() async => [profile];

  @override
  Future<List<TenantSubscription>> fetchTenantSubscriptions(
    String tenantId,
  ) async => const [];
}

Future<void> _pumpTenancy(WidgetTester tester, TenantProfile profile) async {
  await tester.pumpWidget(
    BlocProvider<AppBloc>(
      create: (_) => _SeededAppBloc(
        AppState(tenantProfiles: [profile], demoRole: 'tenant'),
      ),
      child: const MaterialApp(home: TenancyScreen()),
    ),
  );
  // Not pumpAndSettle: a demo session never loads tenancy requests, so the
  // requests placeholder below the cards spins for the whole test.
  await tester.pump(const Duration(milliseconds: 100));
}

Future<void> _pumpDetail(WidgetTester tester, TenantProfile profile) async {
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
}

/// The bordered box the tenancy is drawn in - the list card, or the header on
/// the detail screen. Both are the closest bordered ancestor of the name.
Finder _cardOf(String tenantName) => find
    .ancestor(
      of: find.text(tenantName),
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is Container &&
            widget.decoration is BoxDecoration &&
            (widget.decoration! as BoxDecoration).border != null,
      ),
    )
    .first;

/// Scopes a text match to that box, so the filter bar and the summary counters
/// above the list cannot answer for it.
Finder _inCard(String tenantName, String text) =>
    find.descendant(of: _cardOf(tenantName), matching: find.text(text));

Color _outlineAround(WidgetTester tester, String tenantName) {
  final decoration =
      tester.widget<Container>(_cardOf(tenantName)).decoration!
          as BoxDecoration;
  return (decoration.border! as Border).top.color;
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('TenantProfile cycle status', () {
    test('is on track while the end date is comfortably ahead', () {
      final profile = _profile(endsInDays: 20);

      expect(profile.cycleStatus(), TenantCycleStatus.onTrack);
      expect(profile.isExpired, isFalse);
      expect(profile.canPay, isFalse);
    });

    test('is ending soon inside the last week of the cycle', () {
      expect(
        _profile(endsInDays: 7).cycleStatus(),
        TenantCycleStatus.endingSoon,
      );
      expect(
        _profile(endsInDays: 1).cycleStatus(),
        TenantCycleStatus.endingSoon,
      );
      expect(
        _profile(endsInDays: 0).cycleStatus(),
        TenantCycleStatus.endingSoon,
      );
      expect(_profile(endsInDays: 8).cycleStatus(), TenantCycleStatus.onTrack);
    });

    test('is expired once the paid-through date has passed', () {
      // The case the status field gets wrong: the service still says
      // ACTIVE/PAID, but the date it was paid through is gone.
      final profile = _profile(endsInDays: -1);

      expect(profile.status, 'ACTIVE');
      expect(profile.cycleStatus(), TenantCycleStatus.expired);
      expect(profile.isExpired, isTrue);
      expect(profile.canPay, isTrue);
    });

    test('is expired when the service says so outright', () {
      final profile = _profile(status: 'EXPIRED', endsInDays: null);

      expect(profile.cycleStatus(), TenantCycleStatus.expired);
    });

    test('is undated until the tenancy carries an end date', () {
      expect(
        _profile(endsInDays: null).cycleStatus(),
        TenantCycleStatus.undated,
      );
    });

    test('judges against a fresher cycle when one is passed', () {
      final profile = _profile(endsInDays: -3);

      expect(
        profile.cycleStatus(DateTime.now().add(const Duration(days: 30))),
        TenantCycleStatus.onTrack,
      );
    });
  });

  group('tenancy list card', () {
    testWidgets('outlines an expired tenancy in red and offers a renewal', (
      tester,
    ) async {
      await _pumpTenancy(tester, _profile(endsInDays: -2));

      expect(_outlineAround(tester, 'Acme Tenant'), AppColors.error);
      expect(_inCard('Acme Tenant', 'Expired'), findsOneWidget);
      expect(_inCard('Acme Tenant', 'Renew'), findsOneWidget);
      expect(find.text('Pay Now'), findsNothing);
      expect(_inCard('Acme Tenant', 'Active'), findsNothing);
    });

    testWidgets('outlines a tenancy in its last week in yellow', (
      tester,
    ) async {
      await _pumpTenancy(tester, _profile(endsInDays: 5));

      expect(_outlineAround(tester, 'Acme Tenant'), AppColors.warning);
      expect(_inCard('Acme Tenant', 'Ending soon'), findsOneWidget);
      expect(_inCard('Acme Tenant', 'Ends in 5 days'), findsOneWidget);
      expect(_inCard('Acme Tenant', 'Expired'), findsNothing);
      // Still paid for, so the warning is a heads-up rather than a bill: the
      // renewal button only arrives once the cycle actually ends.
      expect(find.text('Renew'), findsNothing);
    });

    testWidgets('leaves a healthy tenancy on the plain outline', (
      tester,
    ) async {
      await _pumpTenancy(tester, _profile(endsInDays: 20));

      expect(_outlineAround(tester, 'Acme Tenant'), AppColors.border);
      expect(_inCard('Acme Tenant', 'Active'), findsOneWidget);
      expect(find.text('Renew'), findsNothing);
    });
  });

  group('tenant profile detail', () {
    testWidgets('says expired on the header and renews from the bottom bar', (
      tester,
    ) async {
      await _pumpDetail(tester, _profile(endsInDays: -4));

      expect(_outlineAround(tester, 'Acme Tenant'), AppColors.error);
      expect(_inCard('Acme Tenant', 'Expired'), findsOneWidget);
      expect(find.text('Renew Subscription'), findsOneWidget);
      expect(find.text('Pay Subscription'), findsNothing);
    });

    testWidgets('warns in yellow through the last week of the cycle', (
      tester,
    ) async {
      await _pumpDetail(tester, _profile(endsInDays: 3));

      expect(_outlineAround(tester, 'Acme Tenant'), AppColors.warning);
      expect(_inCard('Acme Tenant', 'Ending soon'), findsOneWidget);
    });
  });
}

TenantProfile _profile({
  String status = 'ACTIVE',
  String paymentStatus = 'PAID',
  required int? endsInDays,
}) {
  final now = DateTime.now();
  return TenantProfile(
    id: 'tenant-1',
    name: 'Acme Tenant',
    clientId: 'client-1',
    clientName: 'Sarit Centre',
    locationId: 'location-1',
    locationName: 'Sarit Basement Parking',
    allocatedSlots: 2,
    status: status,
    paymentStatus: paymentStatus,
    slotEnforcement: 'REGISTERED_PLATES',
    subscriptionFee: 5000,
    pricingPlanName: 'Monthly Tenant Parking',
    subscriptionStartDate: now.subtract(const Duration(days: 30)),
    subscriptionEndDate: endsInDays == null
        ? null
        : now.add(Duration(days: endsInDays)),
    ownerId: 'user-1',
    ownerName: 'Jane Driver',
    ownerPhoneNumber: '254711111111',
  );
}
