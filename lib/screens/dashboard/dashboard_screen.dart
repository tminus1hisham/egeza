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
  @override
  void initState() {
    super.initState();
    context.read<AppBloc>().add(LoadDashboardData());
  }

  Future<void> _onRefresh() {
    context.read<AppBloc>().add(LoadDashboardData());
    return Future<void>.value();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
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
                          const SizedBox(height: 22),
                          _buildQuickActions(context, state),
                          if (state.shouldShowTenancy) ...[
                            const SizedBox(height: 24),
                            _buildTenancySnapshot(context, state),
                          ],
                          const SizedBox(height: 24),
                          _buildVehicles(context, state),
                          const SizedBox(height: 24),
                          _buildRecentSessions(context, state),
                          const SizedBox(height: 32),
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
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 26),
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
                              'egesha',
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
                        const SizedBox(height: 7),
                        Text(
                          state.userName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 24,
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
                      const SizedBox(width: 8),
                      Material(
                        color: Colors.white.withValues(alpha: 0.13),
                        borderRadius: BorderRadius.circular(15),
                        child: InkWell(
                          onTap: () {},
                          borderRadius: BorderRadius.circular(15),
                          child: Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(15),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.12),
                              ),
                            ),
                            child: Stack(
                              children: [
                                const Center(
                                  child: Icon(
                                    Icons.notifications_outlined,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                                Positioned(
                                  right: 11,
                                  top: 11,
                                  child: Container(
                                    width: 7,
                                    height: 7,
                                    decoration: BoxDecoration(
                                      color: context.colors.accent,
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 22),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(18, 17, 18, 18),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(24),
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
                        Text(
                          'Wallet Balance',
                          style: GoogleFonts.poppins(
                            color: Colors.white.withValues(alpha: 0.75),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
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
                    const SizedBox(height: 8),
                    Text(
                      'KES ${state.walletBalance.toStringAsFixed(0).replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',')}',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 34,
                        fontWeight: FontWeight.w700,
                        height: 1.1,
                      ),
                    ),
                    if (isLowBalance) ...[
                      const SizedBox(height: 8),
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
                            Text(
                              'Low balance - top up to avoid disruption',
                              style: GoogleFonts.poppins(
                                color: AppColors.warning,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
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

  Widget _buildQuickActions(BuildContext context, AppState state) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick Actions',
            style: GoogleFonts.poppins(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: context.colors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),

          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryDeep.withValues(alpha: 0.18),
                  blurRadius: 20,
                  offset: const Offset(0, 9),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(20),
              clipBehavior: Clip.antiAlias,
              child: Ink(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.primaryDark, AppColors.primaryDeep],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: InkWell(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const PayParkingScreen()),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 17,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.1),
                            ),
                          ),
                          child: const Icon(
                            Icons.credit_card_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Pay Parking',
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Find a session and pay with M-Pesa',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.poppins(
                                  color: Colors.white.withValues(alpha: 0.64),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.chevron_right_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // 3 small action tiles
          Row(
            children: [
              Expanded(
                child: _quickTile(
                  Icons.account_balance_wallet_outlined,
                  'Top Up',
                  onTap: () => _openWallet(context),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _quickTile(
                  Icons.directions_car_outlined,
                  'Add Car',
                  onTap: () => _openVehicles(context),
                ),
              ),
              const SizedBox(width: 10),
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
            padding: const EdgeInsets.all(18),
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
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: context.colors.accentLight,
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: context.colors.mintBorder),
                      ),
                      child: Icon(
                        Icons.domain_rounded,
                        color: context.colors.primary,
                        size: 23,
                      ),
                    ),
                    const SizedBox(width: 13),
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
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              _tenancyBadge(context, state, primaryProfile),
                            ],
                          ),
                          const SizedBox(height: 5),
                          Text(
                            subtitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                              color: context.colors.textSecondary,
                              fontSize: 12,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
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
                const SizedBox(height: 16),
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
                      padding: const EdgeInsets.symmetric(vertical: 12),
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: context.colors.pageGrey,
        borderRadius: BorderRadius.circular(14),
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
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
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
          height: 104,
          padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 8),
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
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: context.colors.accentLight,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: context.colors.primary, size: 20),
              ),
              const SizedBox(height: 9),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  fontSize: 12,
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
              Text(
                'My Vehicles',
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: context.colors.textPrimary,
                ),
              ),
              TextButton.icon(
                onPressed: () => _openVehicles(context),
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('Add Vehicle'),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(0, 36),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  textStyle: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
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
      padding: const EdgeInsets.only(bottom: 10),
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: context.colors.accentLight,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.directions_car_rounded,
                    color: context.colors.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          Text(
                            v.plateNumber,
                            style: GoogleFonts.poppins(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: context.colors.textPrimary,
                            ),
                          ),
                          _autoPayBadge(v.autoPayEnabled),
                        ],
                      ),
                      const SizedBox(height: 5),
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
                                fontSize: 12,
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
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 24),
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
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: context.colors.accentLight,
              borderRadius: BorderRadius.circular(17),
            ),
            child: Icon(
              Icons.directions_car_outlined,
              color: context.colors.primary,
              size: 26,
            ),
          ),
          const SizedBox(height: 12),
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
          const SizedBox(height: 16),
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Sessions',
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: context.colors.textPrimary,
                ),
              ),
              TextButton(
                onPressed: _openHistory,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(0, 36),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('View all'),
              ),
            ],
          ),
          const SizedBox(height: 12),
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
                      vertical: 28,
                      horizontal: 24,
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
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: state.recentSessions.length,
                    separatorBuilder: (_, idx) => Divider(
                      height: 1,
                      indent: 64,
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
    final startUtc = _apiUtc(session.startTime);
    final endUtc = session.endTime == null
        ? DateTime.now().toUtc()
        : _apiUtc(session.endTime!);
    final rawDuration = endUtc.difference(startUtc);
    final duration = rawDuration.isNegative ? Duration.zero : rawDuration;
    final h = duration.inHours;
    final m = duration.inMinutes % 60;
    final durationStr = h > 0 ? '${h}h ${m}m' : '${m}m';
    final dayStr = _dayLabel(session.startTime);

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: session.isActive
          ? () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (ctx) => ActiveSessionScreen(session: session),
              ),
            )
          : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: context.colors.accentLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.location_on_outlined,
                color: context.colors.primary,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    session.locationName,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: context.colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
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
                      Text(
                        durationStr,
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
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  amountLabel,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: context.colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                session.isActive
                    ? Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: context.colors.success,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Active',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: context.colors.success,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      )
                    : Row(
                        children: [
                          Icon(
                            Icons.check_circle_rounded,
                            size: 13,
                            color: context.colors.success,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            'Paid',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: context.colors.success,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
              ],
            ),
          ],
        ),
      ),
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
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: Icon(icon, color: Colors.white, size: 20),
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
