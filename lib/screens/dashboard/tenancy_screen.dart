import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../blocs/app_bloc.dart';
import '../../blocs/app_event.dart';
import '../../blocs/app_state.dart';
import '../../core/api/parking_iq_api.dart';
import '../../core/payment/payment_validation.dart';
import '../../core/theme/app_colors.dart';
import '../../models/api_models.dart';
import '../../models/vehicle.dart';
import '../../widgets/app_widgets.dart';
import '../../widgets/primary_button.dart';

class TenancyScreen extends StatefulWidget {
  final bool showBackButton;

  const TenancyScreen({super.key, this.showBackButton = false});

  @override
  State<TenancyScreen> createState() => _TenancyScreenState();
}

class _TenancyScreenState extends State<TenancyScreen> {
  late final ParkingIqApi _api;

  List<TenantProfile>? _profiles;
  List<TenancyRequest>? _requests;
  bool _loading = true;
  String? _loadError;
  String _filter = 'ALL';
  String? _payingTenantId;
  bool _paymentDialogVisible = false;

  @override
  void initState() {
    super.initState();
    final appState = context.read<AppBloc>().state;
    final token = appState.authToken;
    _api = ParkingIqApi(token: token);
    _profiles = appState.tenantProfiles.isEmpty
        ? null
        : appState.tenantProfiles;
    _requests = appState.tenancyRequests.isEmpty
        ? null
        : appState.tenancyRequests;
    _loading = _profiles == null && _requests == null;
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });

    List<TenantProfile>? profiles;
    List<TenancyRequest>? requests;
    String? error;

    try {
      profiles = await _api.fetchMyTenantProfiles();
    } on ApiException catch (e) {
      error = e.message;
    } catch (_) {
      error = 'Failed to load tenant profiles.';
    }

    try {
      requests = await _api.fetchTenancyRequests();
    } on ApiException catch (e) {
      requests = _isNoTenancyRequestsError(e)
          ? const <TenancyRequest>[]
          : _requests;
    } catch (_) {
      requests = _requests;
    }

    if (!mounted) return;
    setState(() {
      _profiles = profiles ?? _profiles;
      _requests = requests ?? _requests;
      _loadError = error;
      _loading = false;
    });
  }

  Future<void> _openRequestForm() async {
    final state = context.read<AppBloc>().state;
    final submitted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TenantRequestSheet(
        api: _api,
        initialTenantName: state.userName,
        vehicles: state.vehicles,
      ),
    );
    if (submitted == true) {
      await _loadData();
      if (mounted) context.read<AppBloc>().add(LoadDashboardData());
    }
  }

  Future<void> _openProfile(TenantProfile profile) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => TenantProfileDetailScreen(
          profile: profile,
          api: _api,
          defaultPhoneNumber: context.read<AppBloc>().state.phoneNumber,
          onPay: _payTenantSubscription,
        ),
      ),
    );
    _loadData();
  }

  Future<void> _payTenantSubscription(TenantProfile profile) async {
    final phone = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TenantPaymentSheet(
        profile: profile,
        defaultPhoneNumber: context.read<AppBloc>().state.phoneNumber,
      ),
    );
    if (phone == null || phone.isEmpty) return;

    setState(() => _payingTenantId = profile.id);

    try {
      final response = await _api.payTenantSubscription(
        tenantId: profile.id,
        phoneNumber: phone,
      );

      if (!mounted) return;
      _showPaymentDialog(
        response.customerMessage ?? 'Waiting for M-Pesa confirmation...',
      );

      final status = await _pollTenantPayment(profile.id);
      if (!mounted) return;
      _hidePaymentDialog();

      if (status.isSuccess) {
        await _loadData();
        if (mounted) context.read<AppBloc>().add(LoadDashboardData());
        _showSnack(
          status.customerMessage ??
              'Tenant subscription payment successful. Tenant parking benefits are active.',
        );
      } else {
        _showSnack(
          status.customerMessage ?? _paymentFailureMessage(status),
          isError: true,
        );
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      _hidePaymentDialog();
      _showSnack(e.message, isError: true);
    } catch (e) {
      if (!mounted) return;
      _hidePaymentDialog();
      _showSnack(
        e.toString().replaceFirst('Exception: ', ''),
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _payingTenantId = null);
    }
  }

  Future<TenantPaymentStatus> _pollTenantPayment(String tenantId) async {
    TenantPaymentStatus? lastStatus;

    for (var attempt = 0; attempt < 30; attempt++) {
      if (!mounted) {
        return const TenantPaymentStatus(
          paymentStatus: 'CANCELLED',
          customerMessage: 'Payment polling cancelled',
        );
      }

      if (attempt > 0) {
        await Future.delayed(const Duration(seconds: 3));
      }

      try {
        lastStatus = await _api.tenantPaymentStatus(tenantId);
        if (lastStatus.isTerminal) return lastStatus;
      } catch (_) {
        if (attempt == 29) rethrow;
      }
    }

    return TenantPaymentStatus(
      paymentId: lastStatus?.paymentId,
      checkoutRequestId: lastStatus?.checkoutRequestId,
      tenantId: lastStatus?.tenantId ?? tenantId,
      tenantName: lastStatus?.tenantName,
      subscriptionId: lastStatus?.subscriptionId,
      paymentStatus: 'TIMEOUT',
      tenantPaymentStatus: lastStatus?.tenantPaymentStatus ?? 'PENDING',
      subscriptionStatus: lastStatus?.subscriptionStatus ?? 'PENDING',
      customerMessage: 'M-Pesa confirmation timed out',
    );
  }

  String _paymentFailureMessage(TenantPaymentStatus status) {
    switch (status.paymentStatus) {
      case 'CANCELLED':
      case 'CANCELED':
        return 'M-Pesa payment was cancelled';
      case 'TIMEOUT':
      case 'TIMED_OUT':
        return 'M-Pesa confirmation timed out';
      case 'FAILED':
        return 'M-Pesa payment failed';
      default:
        return 'Tenant subscription payment did not complete';
    }
  }

  void _showPaymentDialog(String message) {
    if (_paymentDialogVisible || !mounted) return;
    _paymentDialogVisible = true;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: Dialog(
          backgroundColor: context.colors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 26, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: context.colors.primary),
                const SizedBox(height: 20),
                Text(
                  'Waiting for M-Pesa confirmation...',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: context.colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: context.colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ).then((_) {
      _paymentDialogVisible = false;
    });
  }

  void _hidePaymentDialog() {
    if (!_paymentDialogVisible || !mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
    _paymentDialogVisible = false;
  }

  void _showSnack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor:
            isError ? context.colors.error : context.colors.primaryDark,
        content: Text(
          message,
          style: GoogleFonts.poppins(color: Colors.white),
        ),
      ),
    );
  }

  List<TenantProfile> get _filteredProfiles {
    final profiles = _profiles ?? const <TenantProfile>[];
    return profiles.where((profile) {
      final status = profile.status;
      final payment = profile.paymentStatus;
      return switch (_filter) {
        'ACTIVE' => profile.isActivePaid,
        'PENDING' => status == 'PENDING' || payment == 'PENDING',
        'OVERDUE' => status == 'OVERDUE' || payment == 'OVERDUE',
        'EXPIRED' => status == 'EXPIRED',
        _ => true,
      };
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final profiles = _profiles ?? const <TenantProfile>[];

    return Scaffold(
      backgroundColor: context.colors.pageGrey,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            AppPageHeader(
              title: 'Tenancy',
              subtitle: 'Tenant parking subscriptions',
              icon: Icons.domain_outlined,
              showBackButton: widget.showBackButton,
              showIconWithBack: widget.showBackButton,
              trailing: AppHeaderButton(
                icon: Icons.refresh_rounded,
                tooltip: 'Refresh tenancy',
                onTap: _loadData,
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                color: context.colors.primary,
                onRefresh: _loadData,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 110),
                  children: [
                    _TenancySummaryHeader(
                      profiles: profiles,
                      onRequest: _openRequestForm,
                    ),
                    const SizedBox(height: 18),
                    _FilterBar(
                      selected: _filter,
                      onChanged: (value) => setState(() => _filter = value),
                    ),
                    const SizedBox(height: 18),
                    _SectionTitle(
                      title: 'My tenant profiles',
                      action: 'Apply',
                      onAction: _openRequestForm,
                    ),
                    const SizedBox(height: 10),
                    if (_loading && _profiles == null)
                      const _TenancyLoadingCard()
                    else if (_loadError != null && _profiles == null)
                      _TenancyErrorCard(message: _loadError!, onRetry: _loadData)
                    else if (_filteredProfiles.isEmpty)
                      _TenancyEmptyCard(filter: _filter)
                    else
                      for (final profile in _filteredProfiles)
                        _TenantProfileCard(
                          profile: profile,
                          isPaying: _payingTenantId == profile.id,
                          onView: () => _openProfile(profile),
                          onPay: profile.canPay
                              ? () => _payTenantSubscription(profile)
                              : null,
                        ),
                    const SizedBox(height: 22),
                    _SectionTitle(
                      title: 'Recent requests',
                      action: 'New',
                      onAction: _openRequestForm,
                    ),
                    const SizedBox(height: 10),
                    _RequestList(requests: _requests),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TenantProfileDetailScreen extends StatefulWidget {
  final TenantProfile profile;
  final ParkingIqApi api;
  final String? defaultPhoneNumber;
  final Future<void> Function(TenantProfile profile) onPay;

  const TenantProfileDetailScreen({
    super.key,
    required this.profile,
    required this.api,
    required this.defaultPhoneNumber,
    required this.onPay,
  });

  @override
  State<TenantProfileDetailScreen> createState() =>
      _TenantProfileDetailScreenState();
}

class _TenantProfileDetailScreenState
    extends State<TenantProfileDetailScreen> {
  List<TenantSubscription>? _subscriptions;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSubscriptions();
  }

  Future<void> _loadSubscriptions() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final subscriptions =
          await widget.api.fetchTenantSubscriptions(widget.profile.id);
      if (!mounted) return;
      setState(() => _subscriptions = subscriptions);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Failed to load subscriptions.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pay() async {
    await widget.onPay(widget.profile);
    if (mounted) _loadSubscriptions();
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.profile;
    final activeSubscription = _subscriptions == null
        ? null
        : _subscriptions!.where((item) => item.isActivePaid).firstOrNull;

    return Scaffold(
      backgroundColor: context.colors.pageGrey,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            AppPageHeader(
              title: 'Tenant profile',
              subtitle: profile.locationName,
              icon: Icons.domain_outlined,
              showBackButton: true,
              showIconWithBack: true,
              trailing: AppHeaderButton(
                icon: Icons.refresh_rounded,
                tooltip: 'Refresh subscriptions',
                onTap: _loadSubscriptions,
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                color: context.colors.primary,
                onRefresh: _loadSubscriptions,
                child: ListView(
                  padding: EdgeInsets.fromLTRB(
                    20,
                    18,
                    20,
                    profile.canPay ? 120 : 36,
                  ),
                  children: [
                    _TenantDetailHeader(
                      profile: profile,
                      activeSubscription: activeSubscription,
                    ),
                    const SizedBox(height: 18),
                    _DetailPanel(
                      title: 'Parking privileges',
                      rows: [
                        _DetailRowData('Client', profile.clientName),
                        _DetailRowData('Location', profile.locationName),
                        _DetailRowData(
                          'Slots',
                          '${profile.allocatedSlots} allocated',
                        ),
                        _DetailRowData(
                          'Enforcement',
                          _humanizeCode(profile.slotEnforcement),
                        ),
                        _DetailRowData(
                          'Plates',
                          profile.plateNumbers.isEmpty
                              ? 'No plates'
                              : profile.plateNumbers.join(', '),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    _DetailPanel(
                      title: 'Current subscription',
                      rows: [
                        _DetailRowData(
                          'Plan',
                          profile.pricingPlanName,
                        ),
                        _DetailRowData(
                          'Amount',
                          'KES ${_formatAmount(profile.subscriptionFee)}',
                        ),
                        _DetailRowData(
                          'Status',
                          _profileStatusLabel(profile),
                        ),
                        _DetailRowData(
                          'Starts',
                          _formatDate(profile.subscriptionStartDate),
                        ),
                        _DetailRowData(
                          'Ends',
                          _formatDate(profile.subscriptionEndDate),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    _SectionTitle(
                      title: 'Subscription history',
                      action: null,
                      onAction: null,
                    ),
                    const SizedBox(height: 10),
                    if (_loading && _subscriptions == null)
                      const _TenancyLoadingCard()
                    else if (_error != null)
                      _TenancyErrorCard(
                        message: _error!,
                        onRetry: _loadSubscriptions,
                      )
                    else if (_subscriptions == null || _subscriptions!.isEmpty)
                      const _SubscriptionEmptyCard()
                    else
                      for (final subscription in _subscriptions!)
                        _SubscriptionCard(subscription: subscription),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: profile.canPay
          ? SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
                decoration: BoxDecoration(
                  color: context.colors.surface,
                  border: Border(top: BorderSide(color: context.colors.border)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 18,
                      offset: const Offset(0, -6),
                    ),
                  ],
                ),
                child: PrimaryButton(
                  text: _payCta(profile),
                  icon: Icons.phone_android_rounded,
                  onPressed: _pay,
                ),
              ),
            )
          : null,
    );
  }
}

class _TenancySummaryHeader extends StatelessWidget {
  final List<TenantProfile> profiles;
  final VoidCallback onRequest;

  const _TenancySummaryHeader({
    required this.profiles,
    required this.onRequest,
  });

  @override
  Widget build(BuildContext context) {
    final active = profiles.where((item) => item.isActivePaid).length;
    final payable = profiles.where((item) => item.canPay).length;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            context.colors.primaryDeep,
            context.colors.primaryDark,
            context.colors.primary,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          stops: const [0, 0.58, 1],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: context.colors.primaryDeep.withValues(alpha: 0.18),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(17),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.12),
                  ),
                ),
                child: Icon(
                  Icons.apartment_rounded,
                  color: context.colors.accent,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${profiles.length} tenant profiles',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$active active, $payable need payment',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        color: Colors.white.withValues(alpha: 0.72),
                        fontSize: 12,
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
                child: _SummaryMetric(
                  icon: Icons.check_circle_outline_rounded,
                  label: 'Active',
                  value: '$active',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _SummaryMetric(
                  icon: Icons.payments_outlined,
                  label: 'Due',
                  value: '$payable',
                ),
              ),
              const SizedBox(width: 10),
              Material(
                color: Colors.white.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  onTap: onRequest,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    width: 52,
                    height: 52,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.18),
                      ),
                    ),
                    child: const Icon(
                      Icons.add_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _SummaryMetric({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Row(
        children: [
          Icon(icon, color: context.colors.accent, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                color: Colors.white.withValues(alpha: 0.74),
                fontSize: 11,
              ),
            ),
          ),
          Text(
            value,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;

  const _FilterBar({
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    const filters = [
      ('ALL', 'All'),
      ('ACTIVE', 'Active'),
      ('PENDING', 'Pending'),
      ('OVERDUE', 'Overdue'),
      ('EXPIRED', 'Expired'),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final filter in filters) ...[
            _FilterPill(
              label: filter.$2,
              selected: selected == filter.$1,
              onTap: () => onChanged(filter.$1),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? context.colors.primary : context.colors.surface,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? context.colors.primary : context.colors.border,
            ),
          ),
          child: Text(
            label,
            style: GoogleFonts.poppins(
              color: selected ? Colors.white : context.colors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _TenantProfileCard extends StatelessWidget {
  final TenantProfile profile;
  final bool isPaying;
  final VoidCallback onView;
  final VoidCallback? onPay;

  const _TenantProfileCard({
    required this.profile,
    required this.isPaying,
    required this.onView,
    required this.onPay,
  });

  @override
  Widget build(BuildContext context) {
    final tone = _statusTone(context, profile);
    final secondary = _profileSecondaryText(profile);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
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
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            onTap: onView,
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: tone.color.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Icon(tone.icon, color: tone.color, size: 22),
                      ),
                      const SizedBox(width: 13),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              profile.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.poppins(
                                color: context.colors.textPrimary,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              profile.locationName.isNotEmpty
                                  ? profile.locationName
                                  : profile.locationId,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.poppins(
                                color: context.colors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      _StatusBadge(tone: tone),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _InfoChip(
                        icon: Icons.payments_outlined,
                        text: 'KES ${_formatAmount(profile.subscriptionFee)}',
                      ),
                      _InfoChip(
                        icon: Icons.event_available_outlined,
                        text: secondary,
                      ),
                      _InfoChip(
                        icon: Icons.local_parking_outlined,
                        text: '${profile.allocatedSlots} slots',
                      ),
                    ],
                  ),
                  if (profile.plateNumbers.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 7,
                      runSpacing: 7,
                      children: [
                        for (final plate in profile.plateNumbers)
                          _PlatePill(plate: plate),
                      ],
                    ),
                  ],
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: PrimaryButton(
                          text: 'View Details',
                          icon: Icons.chevron_right_rounded,
                          isOutlined: true,
                          onPressed: onView,
                        ),
                      ),
                      if (onPay != null) ...[
                        const SizedBox(width: 10),
                        Expanded(
                          child: PrimaryButton(
                            text: _payCta(profile),
                            icon: Icons.phone_android_rounded,
                            isLoading: isPaying,
                            onPressed: isPaying ? null : onPay,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TenantDetailHeader extends StatelessWidget {
  final TenantProfile profile;
  final TenantSubscription? activeSubscription;

  const _TenantDetailHeader({
    required this.profile,
    required this.activeSubscription,
  });

  @override
  Widget build(BuildContext context) {
    final tone = _statusTone(context, profile);
    final subscription = activeSubscription;
    final graceUntil = subscription?.endDate == null
        ? null
        : subscription!.endDate!.add(Duration(days: subscription.gracePeriodDays));

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: context.colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: tone.color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(tone.icon, color: tone.color, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        color: context.colors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      profile.locationName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        color: context.colors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _StatusBadge(tone: tone),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _DetailMetric(
                  label: 'Amount',
                  value: 'KES ${_formatAmount(profile.subscriptionFee)}',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _DetailMetric(
                  label: 'Valid until',
                  value: _formatDateShort(
                    subscription?.endDate ?? profile.subscriptionEndDate,
                  ),
                ),
              ),
            ],
          ),
          if (graceUntil != null) ...[
            const SizedBox(height: 12),
            _NoticeLine(
              icon: Icons.schedule_outlined,
              text: 'Grace until ${_formatDate(graceUntil)}',
            ),
          ],
        ],
      ),
    );
  }
}

class _DetailMetric extends StatelessWidget {
  final String label;
  final String value;

  const _DetailMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.colors.pageGrey,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              color: context.colors.textSecondary,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              color: context.colors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _NoticeLine extends StatelessWidget {
  final IconData icon;
  final String text;

  const _NoticeLine({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: context.colors.primary, size: 16),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              color: context.colors.textSecondary,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }
}

class _DetailPanel extends StatelessWidget {
  final String title;
  final List<_DetailRowData> rows;

  const _DetailPanel({
    required this.title,
    required this.rows,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(title: title, action: null, onAction: null),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: context.colors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: context.colors.border),
          ),
          child: Column(
            children: [
              for (var i = 0; i < rows.length; i++) ...[
                _DetailRow(data: rows[i]),
                if (i != rows.length - 1)
                  Divider(
                    height: 1,
                    indent: 16,
                    endIndent: 16,
                    color: context.colors.divider,
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _DetailRowData {
  final String label;
  final String value;

  const _DetailRowData(this.label, this.value);
}

class _DetailRow extends StatelessWidget {
  final _DetailRowData data;

  const _DetailRow({required this.data});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: Text(
              data.label,
              style: GoogleFonts.poppins(
                color: context.colors.textSecondary,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              data.value,
              textAlign: TextAlign.end,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                color: context.colors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SubscriptionCard extends StatelessWidget {
  final TenantSubscription subscription;

  const _SubscriptionCard({required this.subscription});

  @override
  Widget build(BuildContext context) {
    final active = subscription.isActivePaid;
    final color = active
        ? context.colors.success
        : subscription.paymentStatus == 'OVERDUE'
            ? context.colors.warning
            : context.colors.textSecondary;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.colors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.receipt_long_outlined, color: color, size: 21),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'KES ${_formatAmount(subscription.amount)}',
                  style: GoogleFonts.poppins(
                    color: context.colors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _subscriptionDateText(subscription),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    color: context.colors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            _humanizeCode(subscription.paymentStatus),
            style: GoogleFonts.poppins(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onAction;

  const _SectionTitle({
    required this.title,
    required this.action,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: GoogleFonts.poppins(
              color: context.colors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        if (action != null && onAction != null)
          TextButton.icon(
            onPressed: onAction,
            icon: const Icon(Icons.add_rounded, size: 16),
            label: Text(action!),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(0, 34),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              textStyle: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
      ],
    );
  }
}

class _RequestList extends StatelessWidget {
  final List<TenancyRequest>? requests;

  const _RequestList({required this.requests});

  @override
  Widget build(BuildContext context) {
    if (requests == null) {
      return const _TenancyLoadingCard(compact: true);
    }
    if (requests!.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: _surfaceDecoration(context),
        child: Text(
          'Make your request today to enjoy tenant privileges.',
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            color: context.colors.textSecondary,
            fontSize: 13,
          ),
        ),
      );
    }

    return Container(
      decoration: _surfaceDecoration(context),
      child: Column(
        children: [
          for (var i = 0; i < requests!.length; i++) ...[
            _RequestRow(request: requests![i]),
            if (i != requests!.length - 1)
              Divider(height: 1, color: context.colors.divider, indent: 72),
          ],
        ],
      ),
    );
  }
}

bool _isNoTenancyRequestsError(ApiException error) {
  final message = error.message.trim().toLowerCase();
  return error.statusCode == 404 ||
      message.isEmpty ||
      (message.contains('no') && message.contains('request')) ||
      message.contains('not found') ||
      message.contains('none found') ||
      message.contains('no record');
}

class _RequestRow extends StatelessWidget {
  final TenancyRequest request;

  const _RequestRow({required this.request});

  @override
  Widget build(BuildContext context) {
    final status = request.status.toUpperCase();
    final color = switch (status) {
      'APPROVED' => context.colors.success,
      'REJECTED' => context.colors.error,
      'CANCELLED' => context.colors.textMuted,
      _ => context.colors.warning,
    };
    final icon = switch (status) {
      'APPROVED' => Icons.check_circle_outline_rounded,
      'REJECTED' => Icons.cancel_outlined,
      _ => Icons.hourglass_empty_rounded,
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 21),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  request.tenantName.isEmpty
                      ? 'Tenancy request'
                      : request.tenantName,
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
                  '${request.locationName} - ${request.plateNumber}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    color: context.colors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            _humanizeCode(status),
            style: GoogleFonts.poppins(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _TenantRequestSheet extends StatefulWidget {
  final ParkingIqApi api;
  final String initialTenantName;
  final List<Vehicle> vehicles;

  const _TenantRequestSheet({
    required this.api,
    required this.initialTenantName,
    required this.vehicles,
  });

  @override
  State<_TenantRequestSheet> createState() => _TenantRequestSheetState();
}

class _TenantRequestSheetState extends State<_TenantRequestSheet> {
  late final TextEditingController _tenantNameController;
  late final TextEditingController _plateController;
  final _messageController = TextEditingController();

  List<ParkingLocation>? _locations;
  ParkingLocation? _selectedLocation;
  TenancyPolicy? _policy;
  bool _loadingLocations = true;
  bool _loadingPolicy = false;
  bool _submitting = false;
  String? _locationError;
  String? _policyError;
  String? _formError;

  @override
  void initState() {
    super.initState();
    _tenantNameController =
        TextEditingController(text: widget.initialTenantName);
    _plateController = TextEditingController(
      text: widget.vehicles.isEmpty ? '' : widget.vehicles.first.plateNumber,
    );
    _loadLocations();
  }

  @override
  void dispose() {
    _tenantNameController.dispose();
    _plateController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _loadLocations() async {
    setState(() {
      _loadingLocations = true;
      _locationError = null;
    });

    try {
      final locations = await widget.api.fetchParkingLocations();
      if (!mounted) return;
      setState(() => _locations = locations);
    } on ApiException catch (e) {
      if (mounted) setState(() => _locationError = e.message);
    } catch (_) {
      if (mounted) setState(() => _locationError = 'Could not load locations.');
    } finally {
      if (mounted) setState(() => _loadingLocations = false);
    }
  }

  Future<void> _loadPolicy(ParkingLocation location) async {
    setState(() {
      _selectedLocation = location;
      _policy = null;
      _policyError = null;
      _loadingPolicy = true;
    });

    try {
      final policy = await widget.api.fetchTenancyPolicy(location.id);
      if (!mounted) return;
      setState(() => _policy = policy);
    } on ApiException catch (e) {
      if (mounted) setState(() => _policyError = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _policyError = 'Could not load tenancy policy.');
      }
    } finally {
      if (mounted) setState(() => _loadingPolicy = false);
    }
  }

  Future<void> _submit() async {
    final tenantName = _tenantNameController.text.trim();
    final plateNumber = PaymentValidation.normalizePlateNumber(
      _plateController.text,
    );
    final message = _messageController.text.trim();

    if (_selectedLocation == null) {
      setState(() => _formError = 'Select the parking location.');
      return;
    }
    if (_policy == null || !_policy!.active) {
      setState(
        () => _formError =
            'This location does not have an active tenancy policy yet.',
      );
      return;
    }
    if (tenantName.isEmpty) {
      setState(() => _formError = 'Enter the tenant or business name.');
      return;
    }

    try {
      PaymentValidation.validatePlateNumber(plateNumber);
    } on PaymentValidationException catch (e) {
      setState(() => _formError = e.message);
      return;
    }

    setState(() {
      _submitting = true;
      _formError = null;
    });

    try {
      await widget.api.submitTenancyRequest(
        locationId: _selectedLocation!.id,
        tenantName: tenantName,
        plateNumber: plateNumber,
        message: message.isEmpty
            ? 'Requesting tenant parking privileges.'
            : message,
      );
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) setState(() => _formError = e.message);
    } catch (_) {
      if (mounted) setState(() => _formError = 'Submission failed.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final bottomPadding = mq.padding.bottom;

    return SizedBox(
      height: mq.size.height * 0.9,
      child: Container(
        decoration: BoxDecoration(
          color: context.colors.pageGrey,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 14),
            _SheetHandle(color: context.colors.border),
            const SizedBox(height: 16),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                children: [
                  Text(
                    'Request tenancy',
                    style: GoogleFonts.poppins(
                      color: context.colors.textPrimary,
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'The location policy sets the amount, slots, duration, and grace period.',
                    style: GoogleFonts.poppins(
                      color: context.colors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 18),
                  _LocationSelector(
                    locations: _locations,
                    selected: _selectedLocation,
                    loading: _loadingLocations,
                    error: _locationError,
                    onChanged: (location) {
                      if (location != null) _loadPolicy(location);
                    },
                    onRetry: _loadLocations,
                  ),
                  const SizedBox(height: 12),
                  _PolicyPreview(
                    policy: _policy,
                    loading: _loadingPolicy,
                    error: _policyError,
                  ),
                  const SizedBox(height: 12),
                  _SheetField(
                    label: 'Tenant name',
                    hint: 'Carrefour Sarit',
                    controller: _tenantNameController,
                  ),
                  const SizedBox(height: 12),
                  _SheetField(
                    label: 'Plate number',
                    hint: 'KDS132A',
                    controller: _plateController,
                    textCapitalization: TextCapitalization.characters,
                  ),
                  const SizedBox(height: 12),
                  _SheetField(
                    label: 'Message',
                    hint: 'Requesting tenant parking for operations vehicle',
                    controller: _messageController,
                    maxLines: 3,
                  ),
                  if (_formError != null) ...[
                    const SizedBox(height: 12),
                    _InlineError(message: _formError!),
                  ],
                  const SizedBox(height: 18),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(20, 10, 20, 20 + bottomPadding),
              child: PrimaryButton(
                text: 'Submit request',
                icon: Icons.send_rounded,
                isLoading: _submitting,
                onPressed: _submitting ? null : _submit,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TenantPaymentSheet extends StatefulWidget {
  final TenantProfile profile;
  final String? defaultPhoneNumber;

  const _TenantPaymentSheet({
    required this.profile,
    required this.defaultPhoneNumber,
  });

  @override
  State<_TenantPaymentSheet> createState() => _TenantPaymentSheetState();
}

class _TenantPaymentSheetState extends State<_TenantPaymentSheet> {
  late final TextEditingController _phoneController;
  String? _error;

  @override
  void initState() {
    super.initState();
    _phoneController = TextEditingController(
      text: widget.defaultPhoneNumber ?? '',
    );
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  void _submit() {
    try {
      final phone = PaymentValidation.requireValidMpesaPhone(
        _phoneController.text.trim(),
      );
      Navigator.pop(context, phone);
    } on PaymentValidationException catch (e) {
      setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final bottomPadding = mq.padding.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: context.colors.pageGrey,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(20, 14, 20, 20 + bottomPadding),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: _SheetHandle(color: context.colors.border)),
              const SizedBox(height: 18),
              Text(
                _payCta(widget.profile),
                style: GoogleFonts.poppins(
                  color: context.colors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${widget.profile.name} - KES ${_formatAmount(widget.profile.subscriptionFee)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  color: context.colors.textSecondary,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 18),
              _SheetField(
                label: 'M-Pesa number',
                hint: '0712 345 678',
                controller: _phoneController,
                keyboardType: TextInputType.phone,
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                _InlineError(message: _error!),
              ],
              const SizedBox(height: 18),
              PrimaryButton(
                text: 'Send M-Pesa prompt',
                icon: Icons.phone_android_rounded,
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LocationSelector extends StatelessWidget {
  final List<ParkingLocation>? locations;
  final ParkingLocation? selected;
  final bool loading;
  final String? error;
  final ValueChanged<ParkingLocation?> onChanged;
  final VoidCallback onRetry;

  const _LocationSelector({
    required this.locations,
    required this.selected,
    required this.loading,
    required this.error,
    required this.onChanged,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return _FieldShell(
        label: 'Parking location',
        child: Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                color: context.colors.primary,
                strokeWidth: 2,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Loading locations',
              style: GoogleFonts.poppins(
                color: context.colors.textMuted,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    if (error != null) {
      return _FieldShell(
        label: 'Parking location',
        child: Row(
          children: [
            Expanded(
              child: Text(
                error!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  color: context.colors.error,
                  fontSize: 13,
                ),
              ),
            ),
            TextButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      );
    }

    return _FieldShell(
      label: 'Parking location',
      child: DropdownButton<ParkingLocation>(
        value: selected,
        isExpanded: true,
        underline: const SizedBox.shrink(),
        icon: Icon(
          Icons.keyboard_arrow_down_rounded,
          color: context.colors.textSecondary,
        ),
        hint: Text(
          'Select a location',
          style: GoogleFonts.poppins(
            color: context.colors.textMuted,
            fontSize: 14,
          ),
        ),
        dropdownColor: context.colors.surface,
        borderRadius: BorderRadius.circular(16),
        style: GoogleFonts.poppins(
          color: context.colors.textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        items: (locations ?? const <ParkingLocation>[])
            .map(
              (location) => DropdownMenuItem<ParkingLocation>(
                value: location,
                child: Text(
                  location.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            )
            .toList(),
        onChanged: onChanged,
      ),
    );
  }
}

class _PolicyPreview extends StatelessWidget {
  final TenancyPolicy? policy;
  final bool loading;
  final String? error;

  const _PolicyPreview({
    required this.policy,
    required this.loading,
    required this.error,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Container(
        padding: const EdgeInsets.all(15),
        decoration: _surfaceDecoration(context),
        child: Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                color: context.colors.primary,
                strokeWidth: 2,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Loading tenancy policy',
              style: GoogleFonts.poppins(
                color: context.colors.textSecondary,
                fontSize: 13,
              ),
            ),
          ],
        ),
      );
    }

    if (error != null) {
      return _InlineError(message: error!);
    }

    if (policy == null) {
      return Container(
        padding: const EdgeInsets.all(15),
        decoration: _surfaceDecoration(context),
        child: Text(
          'Select a location to view its tenancy policy.',
          style: GoogleFonts.poppins(
            color: context.colors.textSecondary,
            fontSize: 13,
          ),
        ),
      );
    }

    final active = policy!.active;

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: active
            ? context.colors.accentLight
            : context.colors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: active
              ? context.colors.mintBorder
              : context.colors.error.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                active
                    ? Icons.verified_outlined
                    : Icons.info_outline_rounded,
                color: active ? context.colors.primary : context.colors.error,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  policy!.pricingPlanName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    color: context.colors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'KES ${_formatAmount(policy!.subscriptionFee)} per ${policy!.subscriptionDurationDays} days',
            style: GoogleFonts.poppins(
              color: context.colors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'Up to ${policy!.allocatedSlots} slots - ${policy!.gracePeriodDays}-day grace period',
            style: GoogleFonts.poppins(
              color: context.colors.textSecondary,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _SheetField extends StatelessWidget {
  final String label;
  final String hint;
  final TextEditingController controller;
  final int maxLines;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;

  const _SheetField({
    required this.label,
    required this.hint,
    required this.controller,
    this.maxLines = 1,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.sentences,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            color: context.colors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          textCapitalization: textCapitalization,
          style: GoogleFonts.poppins(
            color: context.colors.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.poppins(
              color: context.colors.textMuted,
              fontSize: 13,
            ),
            filled: true,
            fillColor: context.colors.inputFill,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: context.colors.inputBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: context.colors.inputBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: context.colors.primary, width: 1.8),
            ),
          ),
        ),
      ],
    );
  }
}

class _FieldShell extends StatelessWidget {
  final String label;
  final Widget child;

  const _FieldShell({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            color: context.colors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: context.colors.inputFill,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: context.colors.inputBorder),
          ),
          child: child,
        ),
      ],
    );
  }
}

class _InlineError extends StatelessWidget {
  final String message;

  const _InlineError({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.colors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.colors.error.withValues(alpha: 0.18)),
      ),
      child: Text(
        message,
        style: GoogleFonts.poppins(
          color: context.colors.error,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _SheetHandle extends StatelessWidget {
  final Color color;

  const _SheetHandle({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final _StatusTone tone;

  const _StatusBadge({required this.tone});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: tone.color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: tone.color.withValues(alpha: 0.20)),
      ),
      child: Text(
        tone.label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.poppins(
          color: tone.color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoChip({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: context.colors.pageGrey,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: context.colors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: context.colors.primary, size: 14),
          const SizedBox(width: 5),
          Text(
            text,
            style: GoogleFonts.poppins(
              color: context.colors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _PlatePill extends StatelessWidget {
  final String plate;

  const _PlatePill({required this.plate});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: context.colors.accentLight,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: context.colors.mintBorder),
      ),
      child: Text(
        plate,
        style: GoogleFonts.poppins(
          color: context.colors.primary,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _TenancyLoadingCard extends StatelessWidget {
  final bool compact;

  const _TenancyLoadingCard({this.compact = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(compact ? 18 : 26),
      decoration: _surfaceDecoration(context),
      child: Center(
        child: CircularProgressIndicator(color: context.colors.primary),
      ),
    );
  }
}

class _TenancyErrorCard extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _TenancyErrorCard({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _surfaceDecoration(context),
      child: Column(
        children: [
          Icon(Icons.error_outline_rounded, color: context.colors.error),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              color: context.colors.error,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 10),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

class _TenancyEmptyCard extends StatelessWidget {
  final String filter;

  const _TenancyEmptyCard({required this.filter});

  @override
  Widget build(BuildContext context) {
    final filtered = filter != 'ALL';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 28),
      decoration: _surfaceDecoration(context),
      child: Column(
        children: [
          Icon(
            Icons.domain_disabled_outlined,
            color: context.colors.textMuted,
            size: 32,
          ),
          const SizedBox(height: 10),
          Text(
            filtered ? 'No profiles in this filter' : 'No tenant profiles yet',
            style: GoogleFonts.poppins(
              color: context.colors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            filtered
                ? 'Switch filters to see other tenant profiles.'
                : 'Apply for tenancy at a parking location to get started.',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              color: context.colors.textSecondary,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _SubscriptionEmptyCard extends StatelessWidget {
  const _SubscriptionEmptyCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: _surfaceDecoration(context),
      child: Text(
        'No subscription history yet.',
        textAlign: TextAlign.center,
        style: GoogleFonts.poppins(
          color: context.colors.textSecondary,
          fontSize: 13,
        ),
      ),
    );
  }
}

class _StatusTone {
  final Color color;
  final IconData icon;
  final String label;

  const _StatusTone({
    required this.color,
    required this.icon,
    required this.label,
  });
}

BoxDecoration _surfaceDecoration(BuildContext context) {
  return BoxDecoration(
    color: context.colors.surface,
    borderRadius: BorderRadius.circular(20),
    border: Border.all(color: context.colors.border),
  );
}

_StatusTone _statusTone(BuildContext context, TenantProfile profile) {
  final status = profile.status;
  final payment = profile.paymentStatus;

  if (status == 'SUSPENDED') {
    return _StatusTone(
      color: context.colors.error,
      icon: Icons.block_outlined,
      label: 'Suspended',
    );
  }
  if (profile.isActivePaid) {
    return _StatusTone(
      color: context.colors.success,
      icon: Icons.check_circle_outline_rounded,
      label: 'Active',
    );
  }
  if (status == 'OVERDUE' || payment == 'OVERDUE') {
    return _StatusTone(
      color: context.colors.warning,
      icon: Icons.warning_amber_rounded,
      label: 'Overdue',
    );
  }
  if (status == 'EXPIRED') {
    return _StatusTone(
      color: context.colors.textSecondary,
      icon: Icons.event_busy_outlined,
      label: 'Expired',
    );
  }

  return _StatusTone(
    color: context.colors.primary,
    icon: Icons.pending_actions_outlined,
    label: 'Pending Payment',
  );
}

String _profileStatusLabel(TenantProfile profile) {
  return _statusLabelFromValues(profile.status, profile.paymentStatus);
}

String _statusLabelFromValues(String status, String paymentStatus) {
  if (status == 'ACTIVE' && paymentStatus == 'PAID') return 'Active';
  if (status == 'SUSPENDED') return 'Suspended';
  if (status == 'OVERDUE' || paymentStatus == 'OVERDUE') return 'Overdue';
  if (status == 'EXPIRED') return 'Expired';
  if (status == 'PENDING' || paymentStatus == 'PENDING') {
    return 'Pending Payment';
  }
  return _humanizeCode(status);
}

String _profileSecondaryText(TenantProfile profile) {
  if (profile.isActivePaid) {
    return profile.subscriptionEndDate == null
        ? 'Active'
        : 'Valid until ${_formatDateShort(profile.subscriptionEndDate)}';
  }
  if (profile.paymentStatus == 'OVERDUE' || profile.status == 'OVERDUE') {
    return 'Tenant benefits disabled';
  }
  if (profile.status == 'EXPIRED') {
    return 'Renew to continue';
  }
  return 'KES ${_formatAmount(profile.subscriptionFee)} required';
}

String _payCta(TenantProfile profile) {
  if (profile.paymentStatus == 'OVERDUE' || profile.status == 'OVERDUE') {
    return 'Pay To Reactivate';
  }
  return 'Pay Subscription';
}

String _subscriptionDateText(TenantSubscription subscription) {
  if (subscription.startDate == null || subscription.endDate == null) {
    return 'Cycle starts after payment';
  }
  return '${_formatDateShort(subscription.startDate)} - ${_formatDateShort(subscription.endDate)}';
}

String _formatAmount(num amount) {
  return amount
      .toStringAsFixed(0)
      .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (match) => ',');
}

String _formatDate(DateTime? value) {
  if (value == null) return 'Not started';
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
  return '${value.day} ${months[value.month - 1]} ${value.year}';
}

String _formatDateShort(DateTime? value) {
  if (value == null) return 'Pending';
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
  if (value.isEmpty) return '-';
  return value
      .split('_')
      .where((part) => part.isNotEmpty)
      .map(
        (part) => '${part.substring(0, 1)}${part.substring(1).toLowerCase()}',
      )
      .join(' ');
}
