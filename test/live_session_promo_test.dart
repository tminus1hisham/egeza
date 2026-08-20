import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:egesha/blocs/app_bloc.dart';
import 'package:egesha/blocs/app_event.dart';
import 'package:egesha/core/api/parking_iq_api.dart';
import 'package:egesha/models/api_models.dart';
import 'package:egesha/models/parking_session.dart';
import 'package:egesha/models/session_promo_hold.dart';
import 'package:egesha/models/vehicle.dart';
import 'package:egesha/screens/dashboard/dashboard_screen.dart';

void main() {
  // ---------------------------------------------------------------------------
  // The card's single action, which follows the parked car's AutoPay switch.
  // ---------------------------------------------------------------------------
  group('live session card action', () {
    testWidgets('AutoPay off keeps Pay now', (tester) async {
      await _pumpDashboard(tester, sessions: [_session(autoPay: false)]);

      expect(find.text('Pay now'), findsOneWidget);
      expect(find.text('Use promo'), findsNothing);
    });

    testWidgets('AutoPay on swaps Pay now for Use promo', (tester) async {
      await _pumpDashboard(tester, sessions: [_session(autoPay: true)]);

      // AutoPay settles at the gate, so a payment button would be asking for
      // money the driver already arranged to send.
      expect(find.text('Pay now'), findsNothing);
      expect(find.text('Use promo'), findsOneWidget);
      expect(find.text('AutoPay'), findsWidgets);
    });

    testWidgets('the registered vehicle overrides a stale session flag',
        (tester) async {
      // The switch lives on the vehicle; a session payload can lag behind it.
      await _pumpDashboard(
        tester,
        sessions: [_session(autoPay: false)],
        vehicles: [
          const Vehicle(
            plateNumber: 'KBR656Z',
            type: 'Saloon',
            make: 'Toyota',
            model: 'Axio',
            autoPayEnabled: true,
          ),
        ],
      );

      expect(find.text('Use promo'), findsOneWidget);
      expect(find.text('Pay now'), findsNothing);
    });

    testWidgets('Use promo opens the promo sheet', (tester) async {
      await _pumpDashboard(tester, sessions: [_session(autoPay: true)]);

      await tester.tap(find.text('Use promo'));
      // The Live pill pulses forever, so settle by hand rather than
      // pumpAndSettle.
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Apply promo code'), findsOneWidget);
      expect(find.text('Enter promo code'), findsOneWidget);
    });

    testWidgets('an applied promo shows the discount and its countdown',
        (tester) async {
      final bloc = await _pumpDashboard(
        tester,
        sessions: [_session(autoPay: true)],
        api: _PromoApi(bill: 200, discountAmount: 120, finalAmount: 80),
      );

      bloc.add(const ApplySessionPromo(sessionId: 'session-1', code: 'MALL50'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('KES 120 off'), findsOneWidget);
      expect(find.text('ends in 59m'), findsOneWidget);
      // One promo per session — no second Use promo button behind the pill.
      expect(find.text('Use promo'), findsNothing);
    });

    testWidgets('the promo outcome is said out loud', (tester) async {
      // A promo opens no dialog, so the snackbar is the only feedback the
      // driver gets that the code landed.
      final bloc = await _pumpDashboard(
        tester,
        sessions: [_session(autoPay: true)],
        api: _PromoApi(bill: 200, discountAmount: 120, finalAmount: 80),
      );

      bloc.add(const ApplySessionPromo(sessionId: 'session-1', code: 'MALL50'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(
        find.textContaining('AutoPay settles the remaining KES 80'),
        findsOneWidget,
      );
    });
  });

  // ---------------------------------------------------------------------------
  // What a promo does to the bill.
  // ---------------------------------------------------------------------------
  group('promo redemption rules', () {
    test('a promo bigger than the bill sorts it and is used up', () async {
      final api = _PromoApi(bill: 80, discountAmount: 200, finalAmount: 0);
      final bloc = AppBloc(api: api, initialAuthToken: 'token');

      bloc.add(const ApplySessionPromo(sessionId: 'session-1', code: 'BIG'));

      final state = await bloc.stream.firstWhere(
        (s) => !s.isApplyingPromo && s.statusMessage != null,
      );

      final hold = state.promoHolds['session-1']!;
      expect(hold.coveredBill, isTrue);
      expect(hold.remainingDue, 0);
      // Used up on the spot: it never holds, so it is never offered again.
      expect(hold.isExpiredAt(hold.appliedAt), isTrue);
      expect(state.livePromoHold('session-1'), isNull);

      final session = state.recentSessions.single;
      expect(session.isSettled, isTrue);
      expect(session.isActive, isFalse);
      expect(session.cost, 0);
      expect(session.amountPaid, 0);
      expect(session.discountAmount, 200);

      expect(api.payCount, 1);
      expect(api.stkPushCount, 0, reason: 'AutoPay drivers are never prompted');

      await bloc.close();
    });

    test('a promo short of the bill leaves the rest to AutoPay', () async {
      final api = _PromoApi(bill: 200, discountAmount: 120, finalAmount: 80);
      final bloc = AppBloc(api: api, initialAuthToken: 'token');

      bloc.add(const ApplySessionPromo(sessionId: 'session-1', code: 'MALL50'));

      final state = await bloc.stream.firstWhere(
        (s) => !s.isApplyingPromo && s.statusMessage != null,
      );

      final hold = state.livePromoHold('session-1')!;
      expect(hold.coveredBill, isFalse);
      expect(hold.discountAmount, 120);
      expect(hold.remainingDue, 80);
      expect(
        hold.expiresAt.difference(hold.appliedAt),
        SessionPromoHold.holdDuration,
      );

      final session = state.recentSessions.single;
      expect(session.isActive, isTrue, reason: 'the car has not left yet');
      expect(session.cost, 80);
      expect(session.discountAmount, 120);

      expect(state.statusMessage, contains('AutoPay'));
      expect(api.payCount, 0, reason: 'AutoPay collects at the gate, not here');
      expect(api.stkPushCount, 0);

      await bloc.close();
    });

    test('the hold lapses an hour after it was applied', () async {
      final api = _PromoApi(bill: 200, discountAmount: 120, finalAmount: 80);
      final bloc = AppBloc(api: api, initialAuthToken: 'token');

      bloc.add(const ApplySessionPromo(sessionId: 'session-1', code: 'MALL50'));

      final state = await bloc.stream.firstWhere(
        (s) => !s.isApplyingPromo && s.statusMessage != null,
      );
      final applied = state.promoHolds['session-1']!.appliedAt;

      expect(
        state.livePromoHold(
          'session-1',
          now: applied.add(const Duration(minutes: 59)),
        ),
        isNotNull,
      );
      expect(
        state.livePromoHold(
          'session-1',
          now: applied.add(const Duration(hours: 1, seconds: 1)),
        ),
        isNull,
      );

      await bloc.close();
    });

    test('the discount the session records beats the one the code claimed',
        () async {
      // Two services answer here, and only the parking one bills the gate.
      final api = _PromoApi(
        bill: 200,
        discountAmount: 120,
        finalAmount: 80,
        sessionDiscount: 90,
      );
      final bloc = AppBloc(api: api, initialAuthToken: 'token');

      bloc.add(const ApplySessionPromo(sessionId: 'session-1', code: 'MALL50'));

      final state = await bloc.stream.firstWhere(
        (s) => !s.isApplyingPromo && s.statusMessage != null,
      );

      expect(state.livePromoHold('session-1')!.discountAmount, 90);
      expect(state.recentSessions.single.discountAmount, 90);
      expect(state.statusMessage, contains('KES 90'));

      await bloc.close();
    });

    test('a wallet charge that still happened is reported, not hidden',
        () async {
      // The code claimed to cover everything; the server disagreed and took
      // KES 40. Saying "nothing is due" here would be a lie about money.
      final api = _PromoApi(
        bill: 200,
        discountAmount: 200,
        finalAmount: 0,
        paidAmount: 40,
      );
      final bloc = AppBloc(api: api, initialAuthToken: 'token');

      bloc.add(const ApplySessionPromo(sessionId: 'session-1', code: 'BIG'));

      final state = await bloc.stream.firstWhere(
        (s) => !s.isApplyingPromo && s.statusMessage != null,
      );

      expect(state.statusMessage, contains('KES 40'));
      expect(state.statusMessage, contains('wallet'));
      expect(state.recentSessions.single.amountPaid, 40);

      await bloc.close();
    });

    test('a failed settlement is not reported as a settled session', () async {
      final api = _PromoApi(
        bill: 200,
        discountAmount: 200,
        finalAmount: 0,
        payThrows: true,
      );
      final bloc = AppBloc(api: api, initialAuthToken: 'token');

      bloc.add(const ApplySessionPromo(sessionId: 'session-1', code: 'BIG'));

      final state = await bloc.stream.firstWhere((s) => s.errorMessage != null);

      expect(state.isApplyingPromo, isFalse);
      // Nothing was closed out, so nothing may claim to be.
      expect(state.promoHolds, isEmpty);
      expect(
        state.recentSessions.where((s) => s.isSettled),
        isEmpty,
      );

      await bloc.close();
    });

    test('an empty code is rejected without calling the API', () async {
      final api = _PromoApi(bill: 200, discountAmount: 120, finalAmount: 80);
      final bloc = AppBloc(api: api, initialAuthToken: 'token');

      bloc.add(const ApplySessionPromo(sessionId: 'session-1', code: '   '));

      final state = await bloc.stream.firstWhere((s) => s.errorMessage != null);
      expect(state.errorMessage, contains('promo code'));
      expect(api.applyCount, 0);

      await bloc.close();
    });
  });
}

Future<AppBloc> _pumpDashboard(
  WidgetTester tester, {
  required List<ParkingSession> sessions,
  List<Vehicle> vehicles = const [],
  ParkingIqApi? api,
}) async {
  // Wide enough that the pre-existing low-balance header row does not overflow
  // and drown the assertions in unrelated exceptions.
  tester.view.physicalSize = const Size(600, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final bloc = AppBloc(
    api: api ?? _DashboardApi(sessions: sessions, vehicles: vehicles),
    initialAuthToken: 'token',
    initialPhoneNumber: '0712345678',
  );
  addTearDown(bloc.close);

  await tester.pumpWidget(
    MaterialApp(
      home: BlocProvider<AppBloc>.value(
        value: bloc,
        child: const DashboardScreen(),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));

  return bloc;
}

ParkingSession _session({
  required bool autoPay,
  double cost = 200,
  bool isActive = true,
  double discountAmount = 0,
  double amountPaid = 0,
}) {
  return ParkingSession(
    id: 'session-1',
    locationName: 'Sarit',
    startTime: DateTime.utc(2026, 8, 15, 7),
    endTime: isActive ? null : DateTime.utc(2026, 8, 15, 9),
    cost: cost,
    amountPaid: amountPaid,
    discountAmount: discountAmount,
    status: isActive ? 'ACTIVE' : 'COMPLETED',
    autoPayEnabled: autoPay,
    vehicle: Vehicle(
      plateNumber: 'KBR656Z',
      type: 'Saloon',
      make: 'Toyota',
      model: 'Axio',
      autoPayEnabled: autoPay,
    ),
    isActive: isActive,
  );
}

/// Serves the dashboard its lists and nothing else.
class _DashboardApi extends ParkingIqApi {
  _DashboardApi({required this.sessions, required this.vehicles})
      : super(debug: false);

  final List<ParkingSession> sessions;
  final List<Vehicle> vehicles;

  @override
  bool get hasToken => true;

  @override
  Future<List<Vehicle>> listVehicles() async => vehicles;

  @override
  Future<List<ParkingSession>> recentParkingSessions() async => sessions;

  @override
  Future<List<ParkingSession>> activeParkingSessions() async =>
      const <ParkingSession>[];

  @override
  Future<List<ParkingSession>> parkingSessionsForPlate(
    String plateNumber,
  ) async =>
      const <ParkingSession>[];

  @override
  Future<ParkingSession> calculateParkingSession(String sessionId) async =>
      sessions.first;
}

/// Redeems one code against one AutoPay session, and counts every way money
/// could have been taken.
class _PromoApi extends ParkingIqApi {
  _PromoApi({
    required this.bill,
    required this.discountAmount,
    required this.finalAmount,
    this.sessionDiscount = 0,
    this.paidAmount = 0,
    this.payThrows = false,
  }) : super(debug: false);

  final double bill;
  final double discountAmount;
  final double finalAmount;

  /// What the session echoes back after the redemption — the parking service's
  /// own record, as opposed to the tenancy service's.
  final double sessionDiscount;

  /// What `/pay` reports as actually taken from the wallet.
  final double paidAmount;
  final bool payThrows;

  int applyCount = 0;
  int payCount = 0;
  int stkPushCount = 0;
  String? lastCode;

  @override
  bool get hasToken => true;

  ParkingSession _live() => _session(
        autoPay: true,
        cost: bill,
        discountAmount: applyCount > 0 ? sessionDiscount : 0,
      );

  @override
  Future<List<Vehicle>> listVehicles() async => const <Vehicle>[];

  @override
  Future<List<ParkingSession>> recentParkingSessions() async => [_live()];

  @override
  Future<List<ParkingSession>> activeParkingSessions() async =>
      const <ParkingSession>[];

  @override
  Future<List<ParkingSession>> parkingSessionsForPlate(
    String plateNumber,
  ) async =>
      const <ParkingSession>[];

  @override
  Future<ParkingSession> calculateParkingSession(String sessionId) async =>
      _live();

  @override
  Future<ParkingSession> parkingSession(String sessionId) async => _live();

  @override
  Future<DiscountRedemption> applyDiscount({
    required String sessionId,
    required String code,
  }) async {
    applyCount++;
    lastCode = code;
    return DiscountRedemption(
      id: 'redemption-1',
      discountRuleId: 'rule-1',
      tenantId: 'tenant-1',
      tenantName: 'Sarit Centre',
      sessionId: sessionId,
      discountAmount: discountAmount,
      used: true,
      originalAmount: bill,
      finalAmount: finalAmount,
      reimbursementStatus: 'RESERVED',
    );
  }

  @override
  Future<ParkingSession> payParkingSession({
    required String sessionId,
    bool useWallet = true,
    String? phoneNumber,
  }) async {
    payCount++;
    if (payThrows) throw const ApiException('Wallet service unavailable');
    return _session(
      autoPay: true,
      cost: paidAmount,
      amountPaid: paidAmount,
      discountAmount: sessionDiscount,
      isActive: false,
    );
  }

  @override
  Future<MpesaResponse> startSessionStkPush({
    required String phoneNumber,
    required double amount,
    required String sessionId,
    required String plateNumber,
    required String location,
    String transactionDesc = 'Parking session payment',
  }) async {
    stkPushCount++;
    return const MpesaResponse(
      paymentId: 'payment-1',
      checkoutRequestId: 'ws_CO_123',
      status: 'PENDING',
    );
  }
}
