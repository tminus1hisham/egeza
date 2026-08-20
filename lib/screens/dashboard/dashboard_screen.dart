import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';
import '../../blocs/app_bloc.dart';
import '../../blocs/app_event.dart';
import '../../blocs/app_state.dart';
import '../../models/api_models.dart';
import '../../models/vehicle.dart';
import '../../models/parking_session.dart';
import '../../models/session_promo_hold.dart';
import '../../core/error_handler.dart';
import '../../widgets/add_vehicle_sheet.dart';
import '../../widgets/promo_code_sheet.dart';
import '../../widgets/stk_confirmation_sheet.dart';
import 'manager_screen.dart';
import 'wallet_screen.dart';
import 'active_session_screen.dart';
import 'pay_parking_screen.dart';
import 'settings_screen.dart';
import 'tenancy_screen.dart';
import 'vehicle_detail_screen.dart';
import 'vehicles_screen.dart';

class DashboardScreen extends StatefulWidget {
  final VoidCallback? onVehiclesTap;
  final VoidCallback? onWalletTap;
  final VoidCallback? onHistoryTap;
  final VoidCallback? onTenancyTap;
  final VoidCallback? onSettingsTap;

  const DashboardScreen({
    super.key,
    this.onVehiclesTap,
    this.onWalletTap,
    this.onHistoryTap,
    this.onTenancyTap,
    this.onSettingsTap,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  static const Duration _routeSettleDelay = Duration(milliseconds: 300);

  bool _waitingDialogVisible = false;
  bool _wasWaitingForPayment = false;
  bool _wasApplyingPromo = false;

  @override
  void initState() {
    super.initState();
    context.read<AppBloc>().add(LoadDashboardData());
  }

  /// The session the driver is currently parked in, if any. Exited-but-unpaid
  /// sessions stay in [ParkingSession.isAwaitingPayment] and are handled by the
  /// vehicle screens, so only a running session earns the home-page slot.
  ParkingSession? _liveSession(AppState state) {
    for (final session in state.recentSessions) {
      if (session.isActive) return session;
    }
    return null;
  }

  Future<void> _waitForRouteToSettle() async {
    await WidgetsBinding.instance.endOfFrame;
    await Future<void>.delayed(_routeSettleDelay);
  }

  /// Surfaces the outcome of a checkout or a promo redemption.
  Future<void> _handlePaymentState(AppState state) async {
    // A promo raises no M-Pesa prompt, so it never opens the waiting dialog
    // and never reaches the payment branch below — it only needs its result
    // said out loud.
    if (state.isApplyingPromo) {
      _wasApplyingPromo = true;
      return;
    }
    if (_wasApplyingPromo) {
      _wasApplyingPromo = false;
      if (!mounted) return;

      final promoError = state.errorMessage;
      if (promoError != null && promoError.isNotEmpty) {
        ErrorHandler.showErrorMessage(context, promoError);
        return;
      }
      final promoStatus = state.statusMessage;
      if (promoStatus != null && promoStatus.isNotEmpty) {
        ErrorHandler.showSuccess(context, promoStatus);
      }
      // Deliberately no reload: the bloc already holds the discounted figures,
      // and refetching would overwrite them with a bill the server has not
      // finished discounting yet.
      return;
    }

    if (state.isWaitingForPayment) {
      _wasWaitingForPayment = true;
      _showWaitingDialog();
      return;
    }

    await _hideWaitingDialog();
    if (!mounted) return;
    if (!_wasWaitingForPayment) return;
    _wasWaitingForPayment = false;

    final error = state.errorMessage;
    if (error != null && error.isNotEmpty) {
      ErrorHandler.showErrorMessage(context, error);
      return;
    }

    final status = state.statusMessage;
    if (status != null && status.isNotEmpty) {
      ErrorHandler.showSuccess(context, status);
    }
    context.read<AppBloc>().add(LoadDashboardData());
  }

  void _showWaitingDialog() {
    if (_waitingDialogVisible || !mounted) return;
    _waitingDialogVisible = true;
    final colors = context.colors;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: Dialog(
          backgroundColor: colors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 26, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: colors.primary),
                const SizedBox(height: 20),
                Text(
                  'Waiting for M-Pesa confirmation...',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Complete the prompt on your phone.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ).then((_) {
      _waitingDialogVisible = false;
    });
  }

  Future<void> _hideWaitingDialog() async {
    if (!_waitingDialogVisible || !mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
    _waitingDialogVisible = false;
    await _waitForRouteToSettle();
  }

  Future<void> _onRefresh() {
    context.read<AppBloc>().add(LoadDashboardData());
    return Future<void>.value();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: BlocListener<AppBloc, AppState>(
        listenWhen: (prev, curr) =>
            prev.isWaitingForPayment != curr.isWaitingForPayment ||
            prev.isApplyingPromo != curr.isApplyingPromo ||
            prev.errorMessage != curr.errorMessage ||
            prev.statusMessage != curr.statusMessage,
        listener: (context, state) {
          unawaited(_handlePaymentState(state));
        },
        child: Scaffold(
        backgroundColor: context.colors.background,
        body: BlocBuilder<AppBloc, AppState>(
          builder: (context, state) {
            if (state.isLoading) {
              return Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      context.colors.primaryDeep,
                      context.colors.primaryDark,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Center(
                  child: CircularProgressIndicator(
                    color: context.colors.accent,
                  ),
                ),
              );
            }
            return Column(
              children: [
                _buildHeader(context, state),
                Expanded(
                  child: RefreshIndicator(
                    color: context.colors.primary,
                    onRefresh: _onRefresh,
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          const SizedBox(height: 14),
                          if (_liveSession(state) case final live?) ...[
                            _buildLiveSessionCard(context, state, live),
                            const SizedBox(height: 14),
                          ],
                          _buildQuickActions(context, state),
                          if (state.isManager) ...[
                            const SizedBox(height: 14),
                            _buildManagerEntry(context, state),
                          ],
                          if (state.shouldShowTenancy) ...[
                            const SizedBox(height: 14),
                            _buildTenancySnapshot(context, state),
                          ],
                          // const SizedBox(height: 14),
                          // _buildVehicles(context, state),
                          const SizedBox(height: 14),
                          _buildRecentSessions(context, state),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
        ),
      ),
    );
  }

  // ── LIVE SESSION ─────────────────────────────────────────────────────────
  /// Compact card that sits just above Quick Actions while a session is
  /// running, so paying never requires digging into the session list.
  ///
  /// What the card offers depends on the parked vehicle: AutoPay is going to
  /// settle at the gate on its own, so those drivers get a promo code instead
  /// of a payment button they would never need to press.
  Widget _buildLiveSessionCard(
    BuildContext context,
    AppState state,
    ParkingSession session,
  ) {
    final colors = context.colors;
    final autoPay = _sessionAutoPay(state, session);
    final cost = session.cost;
    final costLabel = cost > 0 ? 'KES ${cost.toStringAsFixed(0)}' : 'Free';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Material(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (ctx) => ActiveSessionScreen(session: session),
            ),
          ),
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: colors.success.withValues(alpha: 0.35)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.025),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const _LivePill(count: 1),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        session.locationName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: colors.textPrimary,
                        ),
                      ),
                    ),
                    Text(
                      costLabel,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: colors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 5,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          _platePill(session.vehicle.plateNumber),
                          Icon(
                            Icons.access_time_rounded,
                            size: 12,
                            color: colors.textMuted,
                          ),
                          _SessionDuration(
                            session: session,
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: colors.textSecondary,
                            ),
                          ),
                          if (autoPay) _autoPayChip(context),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    _LiveSessionAction(
                      autoPay: autoPay,
                      hold: state.livePromoHold(session.id),
                      onPayNow: () => showStkConfirmationSheet(
                        context,
                        session: session,
                        routeSettleDelay: _routeSettleDelay,
                      ),
                      onUsePromo: () => showPromoCodeSheet(
                        context,
                        session: session,
                        routeSettleDelay: _routeSettleDelay,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── HEADER ───────────────────────────────────────────────────────────────
  Widget _buildHeader(BuildContext context, AppState state) {
    final autoPayCount = state.vehicles.where((v) => v.autoPayEnabled).length;
    final isLowBalance = state.walletBalance < 500;
    final autoPayLabel = state.vehicles.isEmpty
        ? 'No vehicles yet'
        : '$autoPayCount/${state.vehicles.length} AutoPay';
    final tenantProfileCount = state.visibleTenantProfiles.length;
    final tenantMetricLabel = state.isTenant
        ? tenantProfileCount == 0
            ? 'Tenant access'
            : '$tenantProfileCount tenant ${tenantProfileCount == 1 ? 'profile' : 'profiles'}'
        : 'M-Pesa linked';
    final tenantMetricIcon =
        state.isTenant ? Icons.domain_rounded : Icons.phone_android_rounded;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primaryDeep,
            AppColors.primaryDark,
            context.colors.primary,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          stops: const [0, 0.58, 1],
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDeep.withValues(alpha: 0.26),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _darkHeaderChip(
                              Icons.local_parking_rounded,
                              'Egesha',
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                _greeting(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.poppins(
                                  color: Colors.white.withValues(alpha: 0.74),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          state.userName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _headerRoundButton(
                        Icons.settings_outlined,
                        () => _openSettings(context),
                      ),
                      // const SizedBox(width: 8),
                      // Material(
                      //   color: Colors.white.withValues(alpha: 0.13),
                      //   borderRadius: BorderRadius.circular(15),
                      //   child: InkWell(
                      //     onTap: () {},
                      //     borderRadius: BorderRadius.circular(15),
                      //     child: Container(
                      //       width: 42,
                      //       height: 42,
                      //       decoration: BoxDecoration(
                      //         borderRadius: BorderRadius.circular(15),
                      //         border: Border.all(
                      //           color: Colors.white.withValues(alpha: 0.12),
                      //         ),
                      //       ),
                      //       child: Stack(
                      //         children: [
                      //           const Center(
                      //             child: Icon(
                      //               Icons.notifications_outlined,
                      //               color: Colors.white,
                      //               size: 20,
                      //             ),
                      //           ),
                      //           Positioned(
                      //             right: 11,
                      //             top: 11,
                      //             child: Container(
                      //               width: 7,
                      //               height: 7,
                      //               decoration: BoxDecoration(
                      //                 color: context.colors.accent,
                      //                 borderRadius: BorderRadius.circular(999),
                      //               ),
                      //             ),
                      //           ),
                      //         ],
                      //       ),
                      //     ),
                      //   ),
                      // ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 13),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.12),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            'Wallet Balance',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                              color: Colors.white.withValues(alpha: 0.75),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        Material(
                          color: Colors.white.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(999),
                          child: InkWell(
                            onTap: () => _openWallet(context),
                            borderRadius: BorderRadius.circular(999),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Padding(
                                  padding: EdgeInsets.only(left: 10),
                                  child: Icon(
                                    Icons.add_rounded,
                                    color: Colors.white,
                                    size: 14,
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    4,
                                    6,
                                    12,
                                    6,
                                  ),
                                  child: Text(
                                    'Top Up',
                                    style: GoogleFonts.poppins(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    _AnimatedBalance(balance: state.walletBalance),
                    if (isLowBalance) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.warning.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: AppColors.warning.withValues(alpha: 0.5),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.warning_amber_rounded,
                              color: AppColors.warning,
                              size: 13,
                            ),
                            const SizedBox(width: 5),
                            Flexible(
                              child: Text(
                                'Low balance - top up to avoid disruption',
                                style: GoogleFonts.poppins(
                                  color: AppColors.warning,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _headerMetric(
                            Icons.check_circle_rounded,
                            autoPayLabel,
                          ),
                        ),
                        _headerDivider(),
                        Expanded(
                          child: _headerMetric(
                            tenantMetricIcon,
                            tenantMetricLabel,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── QUICK ACTIONS ────────────────────────────────────────────────────────
  Widget _headerMetric(IconData icon, String label) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF9BE7BE), size: 15),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              color: Colors.white.withValues(alpha: 0.82),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _darkHeaderChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: context.colors.accent, size: 13),
          const SizedBox(width: 5),
          Text(
            label,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _headerDivider() {
    return Container(
      width: 1,
      height: 20,
      margin: const EdgeInsets.symmetric(horizontal: 12),
      color: Colors.white.withValues(alpha: 0.14),
    );
  }

  /// Three equal tiles, no hero banner. The banner duplicated the Pay tile and
  /// cost a whole card of height on a screen whose job is to show what is
  /// happening now; topping up already has its own button on the wallet card.
  Widget _buildQuickActions(BuildContext context, AppState state) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick Actions',
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: context.colors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _quickTile(
                  Icons.credit_card_rounded,
                  'Pay',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const PayParkingScreen(),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _quickTile(
                  Icons.directions_car_outlined,
                  'Add Car',
                  // Opens the sheet directly — the tile says Add Car, so
                  // landing on the Vehicles list was a step too many.
                  onTap: () => showAddVehicleSheet(context),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _quickTile(
                  state.shouldShowTenancy
                      ? Icons.domain_outlined
                      : Icons.history_rounded,
                  state.shouldShowTenancy
                      ? (state.isTenant ? 'Tenant' : 'Requests')
                      : 'History',
                  onTap: state.shouldShowTenancy
                      ? () => _openTenancy(context)
                      : _openHistory,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Way in to the operator's view of a site. Sits on Home rather than only in
  /// Settings because live takings are what a manager opens the app for.
  Widget _buildManagerEntry(BuildContext context, AppState state) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Material(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ManagerScreen(
                api: context.read<AppBloc>().api,
                useSampleData: state.debugSampleData,
              ),
            ),
          ),
          borderRadius: BorderRadius.circular(22),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: context.colors.border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.025),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: context.colors.accentLight,
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(color: context.colors.mintBorder),
                  ),
                  child: Icon(
                    Icons.insights_rounded,
                    color: context.colors.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Manager view',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          color: context.colors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        state.debugSampleData
                            ? 'Sample data — generated figures for previewing '
                                'the layout'
                            : 'Live takings, vehicles in today and cars still '
                                'parked',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          color: context.colors.textSecondary,
                          fontSize: 11.5,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right_rounded,
                  color: context.colors.textMuted,
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTenancySnapshot(BuildContext context, AppState state) {
    final profiles = state.visibleTenantProfiles;
    final primaryProfile = _primaryTenantProfile(profiles);
    final latestRequest = _latestTenancyRequest(state.tenancyRequests);
    final title = state.isTenant ? 'Tenant Parking' : 'Tenancy Requests';
    final subtitle = primaryProfile != null
        ? _tenantProfileSubtitle(primaryProfile)
        : latestRequest != null
            ? _tenancyRequestSubtitle(latestRequest)
            : 'Tenant access is enabled';
    final actionLabel = state.hasPayableTenancy
        ? 'Pay Subscription'
        : state.isTenant
            ? 'View Tenancy'
            : 'View Requests';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Material(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          onTap: () => _openTenancy(context),
          borderRadius: BorderRadius.circular(22),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: context.colors.border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.025),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: context.colors.accentLight,
                        borderRadius: BorderRadius.circular(13),
                        border: Border.all(color: context.colors.mintBorder),
                      ),
                      child: Icon(
                        Icons.domain_rounded,
                        color: context.colors.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.poppins(
                                    color: context.colors.textPrimary,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              _tenancyBadge(context, state, primaryProfile),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            subtitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                              color: context.colors.textSecondary,
                              fontSize: 11.5,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _tenancyMetric(
                        context,
                        'Active',
                        '${state.activeTenantProfileCount}',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _tenancyMetric(
                        context,
                        'To pay',
                        '${state.payableTenantProfileCount}',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _tenancyMetric(
                        context,
                        'Requests',
                        '${state.tenancyRequests.length}',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _openTenancy(context),
                    icon: Icon(
                      state.hasPayableTenancy
                          ? Icons.phone_android_rounded
                          : Icons.arrow_forward_rounded,
                      size: 17,
                    ),
                    label: Text(actionLabel),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      minimumSize: const Size(0, 0),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      textStyle: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _tenancyMetric(BuildContext context, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      decoration: BoxDecoration(
        color: context.colors.pageGrey,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.colors.border),
      ),
      child: Column(
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              color: context.colors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              color: context.colors.textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _tenancyBadge(
    BuildContext context,
    AppState state,
    TenantProfile? profile,
  ) {
    final label = profile != null
        ? _tenantProfileStatusLabel(profile)
        : state.hasTenancyRequests
            ? 'Requested'
            : 'Tenant';
    final color = profile?.isActivePaid == true
        ? context.colors.success
        : state.hasPayableTenancy
            ? context.colors.warning
            : context.colors.primary;

    return Container(
      margin: const EdgeInsets.only(left: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.poppins(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _quickTile(
    IconData icon,
    String label, {
    required VoidCallback onTap,
  }) {
    return Material(
      color: context.colors.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          constraints: const BoxConstraints(minHeight: 72),
          padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: context.colors.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.025),
                blurRadius: 12,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: context.colors.accentLight,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, color: context.colors.primary, size: 17),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: context.colors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── MY VEHICLES ──────────────────────────────────────────────────────────
  Widget _buildVehicles(BuildContext context, AppState state) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  'My Vehicles',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: context.colors.textPrimary,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: () => _openVehicles(context),
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('Add Vehicle'),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  minimumSize: const Size(0, 30),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  textStyle: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (state.vehicles.isEmpty)
            _emptyVehicle()
          else
            ...state.vehicles.map((v) => _vehicleTile(v)),
        ],
      ),
    );
  }

  Widget _vehicleTile(Vehicle v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => VehicleDetailScreen(vehicle: v)),
          ),
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: context.colors.border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 12,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: context.colors.accentLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.directions_car_rounded,
                    color: context.colors.primary,
                    size: 19,
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          Text(
                            v.plateNumber,
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: context.colors.textPrimary,
                            ),
                          ),
                          _autoPayBadge(v.autoPayEnabled),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            margin: const EdgeInsets.only(right: 6),
                            decoration: BoxDecoration(
                              color: v.autoPayEnabled
                                  ? context.colors.success
                                  : context.colors.textMuted,
                              shape: BoxShape.circle,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              '${v.make} ${v.model} - ${v.type}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.poppins(
                                fontSize: 11.5,
                                color: context.colors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: context.colors.textMuted,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _autoPayBadge(bool active) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: active ? context.colors.accentLight : context.colors.pageGrey,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: active ? context.colors.accent : context.colors.border,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (active) ...[
            Icon(
              Icons.check_circle_rounded,
              size: 11,
              color: context.colors.success,
            ),
            const SizedBox(width: 3),
          ],
          Text(
            active ? 'AutoPay' : 'No AutoPay',
            style: GoogleFonts.poppins(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: active
                  ? context.colors.success
                  : context.colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyVehicle() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.colors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: context.colors.accentLight,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.directions_car_outlined,
              color: context.colors.primary,
              size: 21,
            ),
          ),
          const SizedBox(height: 9),
          Text(
            'No vehicles added yet',
            style: GoogleFonts.poppins(
              color: context.colors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Add a vehicle to start parking smarter',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              color: context.colors.textSecondary,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () => _openVehicles(context),
            icon: const Icon(Icons.add_rounded, size: 17),
            label: const Text('Add Vehicle'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
              minimumSize: const Size(0, 0),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              textStyle: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── RECENT SESSIONS ──────────────────────────────────────────────────────
  Widget _buildRecentSessions(BuildContext context, AppState state) {
    final activeCount =
        state.recentSessions.where((session) => session.isActive).length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        'Recent Sessions',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: context.colors.textPrimary,
                        ),
                      ),
                    ),
                    if (activeCount > 0) ...[
                      const SizedBox(width: 8),
                      _LivePill(count: activeCount),
                    ],
                  ],
                ),
              ),
              TextButton(
                onPressed: _openHistory,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  minimumSize: const Size(0, 30),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  textStyle: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                child: const Text('View all'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: context.colors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: context.colors.border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.025),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: state.recentSessions.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 20,
                      horizontal: 20,
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.local_parking_rounded,
                          color: context.colors.textMuted,
                          size: 32,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'No parking sessions yet',
                          style: GoogleFonts.poppins(
                            color: context.colors.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Your session history will appear here',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            color: context.colors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: state.recentSessions.length,
                    separatorBuilder: (_, idx) => Divider(
                      height: 1,
                      indent: 54,
                      color: context.colors.divider,
                    ),
                    itemBuilder: (context, i) =>
                        _sessionTile(context, state.recentSessions[i]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _sessionTile(BuildContext context, ParkingSession session) {
    final amount = session.amountPaid > 0 ? session.amountPaid : session.cost;
    final amountLabel =
        amount > 0 ? 'KES ${amount.toStringAsFixed(0)}' : 'Free';
    final dayStr = _dayLabel(session.startTime);

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: !session.isSettled
          ? () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (ctx) => ActiveSessionScreen(session: session),
              ),
            )
          : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: LayoutBuilder(
          builder: (context, constraints) => Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: context.colors.accentLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.location_on_outlined,
                  color: context.colors.primary,
                  size: 17,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      session.locationName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: context.colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Wrap(
                      spacing: 6,
                      runSpacing: 5,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _platePill(session.vehicle.plateNumber),
                        Icon(
                          Icons.access_time_rounded,
                          size: 12,
                          color: context.colors.textMuted,
                        ),
                        _SessionDuration(
                          session: session,
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: context.colors.textSecondary,
                          ),
                        ),
                        Text(
                          dayStr,
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: context.colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              // Amount and state each size themselves to their text, so a big
              // fee beside a two-word state runs off the tile on a narrow
              // phone. Half the row is theirs; past that they wrap.
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: constraints.maxWidth / 2),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      amountLabel,
                      textAlign: TextAlign.end,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: context.colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    _sessionStateLabel(context, session),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Three states, not two: a session can be running, settled, or exited with
  /// the fee still owing. Collapsing the last two into "Paid" told drivers
  /// their money was taken when it hadn't been.
  Widget _sessionStateLabel(BuildContext context, ParkingSession session) {
    if (session.isActive) {
      return _sessionStateRow(
        color: context.colors.success,
        label: 'Active',
        dot: true,
      );
    }
    if (session.isAwaitingPayment) {
      return _sessionStateRow(
        color: context.colors.warning,
        label: 'Payment due',
        icon: Icons.error_outline_rounded,
      );
    }
    return _sessionStateRow(
      color: context.colors.success,
      label: 'Paid',
      icon: Icons.check_circle_rounded,
    );
  }

  Widget _sessionStateRow({
    required Color color,
    required String label,
    IconData? icon,
    bool dot = false,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (dot)
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          )
        else if (icon != null)
          Icon(icon, size: 13, color: color),
        SizedBox(width: dot ? 4 : 3),
        // Inside the capped column above, the state label has to be able to
        // wrap rather than push the row wider than it is allowed to be.
        Flexible(
          child: Text(
            label,
            textAlign: TextAlign.end,
            style: GoogleFonts.poppins(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  /// Whether the car in [session] is on AutoPay.
  ///
  /// The registered vehicle is the authority — the driver flips the switch
  /// there and the session payload can lag behind it — but an ANPR session for
  /// a plate this account has not registered is not in [AppState.vehicles] at
  /// all, so the session's own flag stands in.
  bool _sessionAutoPay(AppState state, ParkingSession session) {
    final plateKey = Vehicle.plateKey(session.vehicle.plateNumber);
    for (final vehicle in state.vehicles) {
      if (Vehicle.plateKey(vehicle.plateNumber) == plateKey) {
        return vehicle.autoPayEnabled;
      }
    }
    return session.autoPayEnabled || session.vehicle.autoPayEnabled;
  }

  /// Says why the card is not asking for money.
  Widget _autoPayChip(BuildContext context) {
    final colors = context.colors;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.bolt_rounded, size: 12, color: colors.success),
        const SizedBox(width: 2),
        Text(
          'AutoPay',
          style: GoogleFonts.poppins(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: colors.success,
          ),
        ),
      ],
    );
  }

  Widget _platePill(String plate) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: context.colors.accentLight,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: context.colors.accent.withValues(alpha: 0.4),
          width: 1,
        ),
      ),
      child: Text(
        plate,
        style: GoogleFonts.poppins(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: context.colors.primary,
        ),
      ),
    );
  }

  TenantProfile? _primaryTenantProfile(List<TenantProfile> profiles) {
    for (final profile in profiles) {
      if (profile.isActivePaid) return profile;
    }
    for (final profile in profiles) {
      if (profile.canPay) return profile;
    }
    return profiles.isEmpty ? null : profiles.first;
  }

  TenancyRequest? _latestTenancyRequest(List<TenancyRequest> requests) {
    if (requests.isEmpty) return null;
    final sorted = [...requests]
      ..sort((a, b) {
        final aDate = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bDate = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bDate.compareTo(aDate);
      });
    return sorted.first;
  }

  String _tenantProfileSubtitle(TenantProfile profile) {
    final location = profile.locationName.isNotEmpty
        ? profile.locationName
        : 'Tenant parking';

    if (profile.isActivePaid) {
      final expiry = profile.subscriptionEndDate == null
          ? null
          : ' until ${_formatDateShort(profile.subscriptionEndDate!)}';
      return '$location is active$expiry.';
    }

    if (profile.canPay) {
      return '$location needs KES ${_formatAmount(profile.subscriptionFee)} to activate tenant benefits.';
    }

    return '$location is ${_tenantProfileStatusLabel(profile).toLowerCase()}.';
  }

  String _tenancyRequestSubtitle(TenancyRequest request) {
    final location = request.locationName.isNotEmpty
        ? request.locationName
        : 'selected parking';
    return '${_tenancyRequestStatusLabel(request.status)} request for $location.';
  }

  String _tenantProfileStatusLabel(TenantProfile profile) {
    final status = profile.status;
    final payment = profile.paymentStatus;
    if (status == 'ACTIVE' && payment == 'PAID') return 'Active';
    if (status == 'SUSPENDED') return 'Suspended';
    if (status == 'OVERDUE' || payment == 'OVERDUE') return 'Overdue';
    if (status == 'EXPIRED') return 'Expired';
    if (status == 'PENDING' || payment == 'PENDING') {
      return 'Pending';
    }
    return _humanizeCode(status);
  }

  String _tenancyRequestStatusLabel(String status) {
    final normalized = status.trim().toUpperCase();
    if (normalized == 'APPROVED') return 'Approved';
    if (normalized == 'REJECTED' || normalized == 'DECLINED') {
      return 'Rejected';
    }
    if (normalized == 'CANCELLED' || normalized == 'CANCELED') {
      return 'Cancelled';
    }
    return 'Pending';
  }

  String _formatAmount(num amount) {
    return amount
        .toStringAsFixed(0)
        .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (match) => ',');
  }

  String _formatDateShort(DateTime value) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${value.day} ${months[value.month - 1]}';
  }

  String _humanizeCode(String value) {
    if (value.isEmpty) return 'Unknown';
    return value
        .split('_')
        .where((part) => part.isNotEmpty)
        .map(
          (part) => '${part.substring(0, 1)}${part.substring(1).toLowerCase()}',
        )
        .join(' ');
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  String _dayLabel(DateTime dt) {
    final now = DateTime.now().toUtc().add(const Duration(hours: 3));
    final value = _eat(dt);
    final today = DateTime(now.year, now.month, now.day);
    final sessionDay = DateTime(value.year, value.month, value.day);
    final diff = today.difference(sessionDay).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[value.weekday - 1];
  }

  void _openWallet(BuildContext context) {
    if (widget.onWalletTap != null) {
      widget.onWalletTap!();
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const WalletScreen(showBackButton: true),
      ),
    );
  }

  void _openVehicles(BuildContext context) {
    if (widget.onVehiclesTap != null) {
      widget.onVehiclesTap!();
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const VehiclesScreen(showBackButton: true),
      ),
    );
  }

  void _openHistory() {
    widget.onHistoryTap?.call();
  }

  void _openSettings(BuildContext context) {
    if (widget.onSettingsTap != null) {
      widget.onSettingsTap!();
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const SettingsScreen(showBackButton: true),
      ),
    );
  }

  Widget _headerRoundButton(IconData icon, VoidCallback onTap) {
    return Material(
      color: Colors.white.withValues(alpha: 0.13),
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: Icon(icon, color: Colors.white, size: 19),
        ),
      ),
    );
  }

  void _openTenancy(BuildContext context) {
    if (widget.onTenancyTap != null) {
      widget.onTenancyTap!();
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const TenancyScreen(showBackButton: true),
      ),
    );
  }
}

DateTime _apiUtc(DateTime dt) {
  if (dt.isUtc) return dt;
  return DateTime.utc(
    dt.year,
    dt.month,
    dt.day,
    dt.hour,
    dt.minute,
    dt.second,
    dt.millisecond,
    dt.microsecond,
  );
}

DateTime _eat(DateTime dt) => _apiUtc(dt).add(const Duration(hours: 3));

String _formatBalance(double balance) {
  return 'KES ${balance.toStringAsFixed(0).replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',')}';
}

/// Counts from the old balance to the new one instead of swapping digits.
///
/// The balance now changes on its own, from a background poll the user didn't
/// ask for — a number that silently rewrites itself mid-glance reads as a
/// render glitch, where a short count-up reads as money arriving.
class _AnimatedBalance extends StatelessWidget {
  const _AnimatedBalance({required this.balance});

  final double balance;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      // begin == end, so the first build is static; on rebuild the builder
      // animates from the previous tween's end to this one.
      tween: Tween<double>(begin: balance, end: balance),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) => Text(
        _formatBalance(value),
        style: GoogleFonts.poppins(
          color: Colors.white,
          fontSize: 28,
          fontWeight: FontWeight.w700,
          height: 1.1,
        ),
      ),
    );
  }
}

/// A running session's elapsed time, ticked once a second.
///
/// Only the tile that is still running holds a timer; a finished session's
/// duration is fixed, so it renders as plain text with nothing scheduled.
class _SessionDuration extends StatefulWidget {
  const _SessionDuration({required this.session, required this.style});

  final ParkingSession session;
  final TextStyle style;

  @override
  State<_SessionDuration> createState() => _SessionDurationState();
}

class _SessionDurationState extends State<_SessionDuration> {
  Timer? _ticker;

  bool get _isRunning => widget.session.endTime == null;

  @override
  void initState() {
    super.initState();
    _syncTicker();
  }

  @override
  void didUpdateWidget(covariant _SessionDuration oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncTicker();
  }

  void _syncTicker() {
    if (_isRunning) {
      _ticker ??= Timer.periodic(
        const Duration(seconds: 1),
        (_) => setState(() {}),
      );
      return;
    }
    _ticker?.cancel();
    _ticker = null;
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final startUtc = _apiUtc(widget.session.startTime);
    final endUtc = widget.session.endTime == null
        ? DateTime.now().toUtc()
        : _apiUtc(widget.session.endTime!);
    final raw = endUtc.difference(startUtc);
    final duration = raw.isNegative ? Duration.zero : raw;
    final h = duration.inHours;
    final m = duration.inMinutes % 60;

    return Text(h > 0 ? '${h}h ${m}m' : '${m}m', style: widget.style);
  }
}

/// Pulsing "live" marker shown while at least one session is running, so the
/// list reads as something being watched rather than a stale snapshot.
class _LivePill extends StatefulWidget {
  const _LivePill({required this.count});

  final int count;

  @override
  State<_LivePill> createState() => _LivePillState();
}

class _LivePillState extends State<_LivePill>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = context.colors.success;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FadeTransition(
            opacity: Tween<double>(begin: 1, end: 0.25).animate(_controller),
            child: Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
          ),
          const SizedBox(width: 5),
          Text(
            widget.count == 1 ? 'Live' : 'Live · ${widget.count}',
            style: GoogleFonts.poppins(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// The one action the live session card offers, which depends entirely on how
/// the bill is going to be paid.
///
/// * AutoPay off — "Pay now", the M-Pesa prompt.
/// * AutoPay on — "Use promo", because AutoPay already has the bill covered
///   and the only thing left worth doing is knocking money off it.
/// * AutoPay on with a promo already applied — the discount and what is left
///   of its hold, counted down in place. The swap back to "Use promo" happens
///   here rather than in the bloc: a hold lapses with the passage of time, not
///   with anything the app does, so nothing else would fire a rebuild.
class _LiveSessionAction extends StatefulWidget {
  const _LiveSessionAction({
    required this.autoPay,
    required this.hold,
    required this.onPayNow,
    required this.onUsePromo,
  });

  final bool autoPay;
  final SessionPromoHold? hold;
  final VoidCallback onPayNow;
  final VoidCallback onUsePromo;

  @override
  State<_LiveSessionAction> createState() => _LiveSessionActionState();
}

class _LiveSessionActionState extends State<_LiveSessionAction> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _syncTicker();
  }

  @override
  void didUpdateWidget(covariant _LiveSessionAction oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncTicker();
  }

  void _syncTicker() {
    final hold = widget.hold;
    if (hold != null && hold.isLiveAt(DateTime.now())) {
      _ticker ??= Timer.periodic(
        const Duration(seconds: 1),
        (_) => setState(() {}),
      );
      return;
    }
    _ticker?.cancel();
    _ticker = null;
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.autoPay) {
      return _button(
        label: 'Pay now',
        onPressed: widget.onPayNow,
        background: context.colors.primary,
      );
    }

    final hold = widget.hold;
    final now = DateTime.now();
    if (hold == null || hold.isExpiredAt(now)) {
      // Cancel the ticker the moment the countdown runs out, without waiting
      // for the next parent rebuild to notice.
      _ticker?.cancel();
      _ticker = null;
      return _button(
        label: 'Use promo',
        onPressed: widget.onUsePromo,
        background: context.colors.primary,
      );
    }

    return _appliedPromo(hold, now);
  }

  Widget _button({
    required String label,
    required VoidCallback onPressed,
    required Color background,
  }) {
    return SizedBox(
      height: 34,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: background,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        child: Text(label),
      ),
    );
  }

  Widget _appliedPromo(SessionPromoHold hold, DateTime now) {
    final colors = context.colors;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colors.success.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.success.withValues(alpha: 0.35)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.local_offer_rounded,
                size: 12,
                color: colors.success,
              ),
              const SizedBox(width: 4),
              Text(
                'KES ${hold.discountAmount.toStringAsFixed(0)} off',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: colors.success,
                ),
              ),
            ],
          ),
          Text(
            'ends in ${hold.countdownLabelAt(now)}',
            style: GoogleFonts.poppins(
              fontSize: 10,
              color: colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
