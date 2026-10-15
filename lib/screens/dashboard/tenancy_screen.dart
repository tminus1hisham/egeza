import 'dart:io';

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

  /// Running on the sign-in screen's tenancy demo button — see [AppState.isDemoSession].
  bool _isDemo = false;

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
    _isDemo = appState.isDemoSession;
    if (!_isDemo) _loadData();
  }

  Future<void> _loadData() async {
    // A demo session has no account behind it — the seeded profiles taken from
    // AppState above are the whole story, and the fetch would only 401.
    if (_isDemo) {
      setState(() => _loading = false);
      return;
    }

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
    final registeredVehicles = context.read<AppBloc>().state.vehicles;
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => TenantProfileDetailScreen(
          profile: profile,
          registeredVehicles: registeredVehicles,
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
        'ACTIVE' => profile.isActivePaid && !profile.isExpired,
        'PENDING' => status == 'PENDING' || payment == 'PENDING',
        'OVERDUE' => status == 'OVERDUE' || payment == 'OVERDUE',
        'EXPIRED' => profile.isExpired,
        _ => true,
      };
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final profiles = _profiles ?? const <TenantProfile>[];

    return AdaptiveStatusBar(
      child: Scaffold(
        backgroundColor: context.colors.pageGrey,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Expanded(
                child: RefreshIndicator(
                  color: context.colors.primary,
                  onRefresh: _loadData,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                    children: [
                      // Refresh dropped: the RefreshIndicator above already
                      // covers it with pull-to-refresh.
                      if (widget.showBackButton) ...[
                        const PageBackButton(),
                        const SizedBox(height: 8),
                      ],
                      _TenancySummaryHeader(
                        profiles: profiles,
                        onRequest: _openRequestForm,
                      ),
                      const SizedBox(height: 14),
                      _FilterBar(
                        selected: _filter,
                        onChanged: (value) => setState(() => _filter = value),
                      ),
                      const SizedBox(height: 14),
                      _SectionTitle(
                        title: 'My tenant profiles',
                        action: 'Apply',
                        onAction: _openRequestForm,
                      ),
                      const SizedBox(height: 8),
                      if (_loading && _profiles == null)
                        const _TenancyLoadingCard()
                      else if (_loadError != null && _profiles == null)
                        _TenancyErrorCard(
                          message: _loadError!,
                          onRetry: _loadData,
                        )
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
                      const SizedBox(height: 18),
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
      ),
    );
  }
}

class TenantProfileDetailScreen extends StatefulWidget {
  final TenantProfile profile;
  final List<Vehicle> registeredVehicles;
  final ParkingIqApi api;
  final String? defaultPhoneNumber;
  final Future<void> Function(TenantProfile profile) onPay;

  const TenantProfileDetailScreen({
    super.key,
    required this.profile,
    this.registeredVehicles = const [],
    required this.api,
    required this.defaultPhoneNumber,
    required this.onPay,
  });

  @override
  State<TenantProfileDetailScreen> createState() =>
      _TenantProfileDetailScreenState();
}

class _TenantProfileDetailScreenState extends State<TenantProfileDetailScreen> {
  late TenantProfile _profile;
  List<TenantSubscription>? _subscriptions;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _profile = widget.profile;
    _loadSubscriptions();
  }

  Future<void> _loadSubscriptions() async {
    final isRefresh = _subscriptions != null;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final results = await Future.wait<Object?>([
        widget.api.fetchTenantSubscriptions(_profile.id),
        _fetchLatestProfile(),
      ]);
      final subscriptions = results[0] as List<TenantSubscription>;
      final latestProfile = results[1] as TenantProfile?;
      if (!mounted) return;
      setState(() {
        _subscriptions = subscriptions;
        _profile = latestProfile ?? _profile;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      if (isRefresh) {
        _showRefreshError(e.message);
      } else {
        setState(() => _error = e.message);
      }
    } on SocketException {
      if (!mounted) return;
      const msg = 'No internet connection. Check your network and try again.';
      if (isRefresh) {
        _showRefreshError(msg);
      } else {
        setState(() => _error = msg);
      }
    } catch (_) {
      if (!mounted) return;
      const msg = 'Something went wrong loading subscription history.';
      if (isRefresh) {
        _showRefreshError(msg);
      } else {
        setState(() => _error = msg);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<TenantProfile?> _fetchLatestProfile() async {
    try {
      final profiles = await widget.api.fetchMyTenantProfiles();
      for (final profile in profiles) {
        if (profile.id == _profile.id) return profile;
      }
    } catch (_) {
      // Subscription history is still useful when the profile refresh fails.
    }
    return null;
  }

  void _showRefreshError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        action: SnackBarAction(label: 'Retry', onPressed: _loadSubscriptions),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _pay() async {
    await widget.onPay(_profile);
    if (mounted) _loadSubscriptions();
  }

  @override
  Widget build(BuildContext context) {
    final profile = _profile;
    final currentSubscription = _currentSubscription(_subscriptions);
    final vehicles = _tenantVehicles(profile, widget.registeredVehicles);

    return AdaptiveStatusBar(
      child: Scaffold(
        backgroundColor: context.colors.pageGrey,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Expanded(
                child: RefreshIndicator(
                  color: context.colors.primary,
                  onRefresh: _loadSubscriptions,
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(
                      20,
                      22,
                      20,
                      profile.canPay ? 120 : 36,
                    ),
                    children: [
                      // Refresh dropped: the RefreshIndicator above already
                      // covers it with pull-to-refresh.
                      const PageBackButton(label: 'Tenant profile'),
                      const SizedBox(height: 12),
                      _TenantDetailHeader(
                        profile: profile,
                        subscription: currentSubscription,
                      ),
                      const SizedBox(height: 12),
                      _TenantMetricsRow(
                        profile: profile,
                        subscription: currentSubscription,
                        vehicles: vehicles,
                      ),
                      const SizedBox(height: 18),
                      _TenantVehiclePanel(
                        vehicles: vehicles,
                        allocatedSlots: profile.allocatedSlots,
                      ),
                      const SizedBox(height: 18),
                      _DetailPanel(
                        title: 'Tenancy details',
                        rows: _tenancyDetailRows(profile, currentSubscription),
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
                      else if (_error != null && _subscriptions == null)
                        _TenancyErrorCard(
                          message: _error!,
                          onRetry: _loadSubscriptions,
                        )
                      else if (_subscriptions == null ||
                          _subscriptions!.isEmpty)
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
                    border: Border(
                      top: BorderSide(color: context.colors.border),
                    ),
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
                    icon: _payCtaIcon(profile),
                    onPressed: _pay,
                  ),
                ),
              )
            : null,
      ),
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
      padding: const EdgeInsets.all(14),
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
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: context.colors.primaryDeep.withValues(alpha: 0.18),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.12),
                  ),
                ),
                child: Icon(
                  Icons.apartment_rounded,
                  color: context.colors.accent,
                  size: 22,
                ),
              ),
              const SizedBox(width: 11),
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
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '$active active, $payable need payment',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        color: Colors.white.withValues(alpha: 0.72),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _SummaryMetric(
                  icon: Icons.check_circle_outline_rounded,
                  label: 'Active',
                  value: '$active',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _SummaryMetric(
                  icon: Icons.payments_outlined,
                  label: 'Due',
                  value: '$payable',
                ),
              ),
              const SizedBox(width: 8),
              Material(
                color: Colors.white.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  onTap: onRequest,
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.18),
                      ),
                    ),
                    child: const Icon(
                      Icons.add_rounded,
                      color: Colors.white,
                      size: 20,
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Row(
        children: [
          Icon(icon, color: context.colors.accent, size: 15),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                color: Colors.white.withValues(alpha: 0.74),
                fontSize: 10,
              ),
            ),
          ),
          Text(
            value,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 13,
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
            const SizedBox(width: 6),
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
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
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
              fontSize: 11,
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
    final border = _cycleBorder(context, profile);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(16),
          border: border.toBorder(),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.025),
              blurRadius: 12,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: onView,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(13),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: tone.color.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(tone.icon, color: tone.color, size: 19),
                      ),
                      const SizedBox(width: 10),
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
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              profile.locationName.isNotEmpty
                                  ? profile.locationName
                                  : profile.locationId,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.poppins(
                                color: context.colors.textSecondary,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      _StatusBadge(tone: tone),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
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
                    const SizedBox(height: 9),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final plate in profile.plateNumbers)
                          _PlatePill(plate: plate),
                      ],
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: PrimaryButton(
                          text: onPay != null ? 'View' : 'View Details',
                          height: 42,
                          fontSize: 13,
                          icon: Icons.chevron_right_rounded,
                          isOutlined: true,
                          onPressed: onView,
                        ),
                      ),
                      if (onPay != null) ...[
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 2,
                          child: PrimaryButton(
                            text: _payCtaShort(profile),
                            height: 42,
                            fontSize: 13,
                            icon: _payCtaIcon(profile),
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

/// The tenant profile header.
///
/// Everything here answers one question - "where does this tenancy stand right
/// now?" - so the card carries the identity, a single plain-language headline
/// (renewal, overdue, grace, activation) and the cycle it belongs to. The
/// numbers behind it live in [_TenantMetricsRow] so nothing is stated twice.
class _TenantDetailHeader extends StatelessWidget {
  final TenantProfile profile;
  final TenantSubscription? subscription;

  const _TenantDetailHeader({
    required this.profile,
    required this.subscription,
  });

  @override
  Widget build(BuildContext context) {
    final end = subscription?.endDate ?? profile.subscriptionEndDate;
    final tone = _statusTone(context, profile, cycleEnd: end);
    final headline = _tenantHeadline(context, profile, subscription);
    final start = subscription?.startDate ?? profile.subscriptionStartDate;
    final progress = _cycleProgress(start, end);
    final border = _cycleBorder(context, profile, cycleEnd: end);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(22),
        border: border.toBorder(),
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
                      _tenantSubtitle(profile),
                      maxLines: 2,
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
              // Flexible so a long label ('Pending Payment') gives way on a
              // narrow phone instead of pushing the row over the edge.
              Flexible(child: _StatusBadge(tone: tone)),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            decoration: BoxDecoration(
              color: headline.color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: headline.color.withValues(alpha: 0.18)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(headline.icon, color: headline.color, size: 17),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    headline.text,
                    style: GoogleFonts.poppins(
                      color: context.colors.textPrimary,
                      fontSize: 12,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (progress != null) ...[
            const SizedBox(height: 14),
            _CycleBar(
              start: start!,
              end: end!,
              progress: progress,
              color: headline.color,
            ),
          ],
        ],
      ),
    );
  }
}

/// How far the current billing cycle has run - the one thing a start and an
/// end date say together that neither says alone.
class _CycleBar extends StatelessWidget {
  final DateTime start;
  final DateTime end;
  final double progress;
  final Color color;

  const _CycleBar({
    required this.start,
    required this.end,
    required this.progress,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final labelStyle = GoogleFonts.poppins(
      color: context.colors.textSecondary,
      fontSize: 10,
      fontWeight: FontWeight.w600,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 6,
            backgroundColor: context.colors.pageGrey,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
        const SizedBox(height: 7),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                _formatDateShort(start),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: labelStyle,
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                _formatDateShort(end),
                maxLines: 1,
                textAlign: TextAlign.end,
                overflow: TextOverflow.ellipsis,
                style: labelStyle,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// The three facts a tenant checks before parking: what the tenancy costs, how
/// much of the cycle is left, and how many plates the allocation covers.
class _TenantMetricsRow extends StatelessWidget {
  final TenantProfile profile;
  final TenantSubscription? subscription;
  final List<_TenantVehicleData> vehicles;

  const _TenantMetricsRow({
    required this.profile,
    required this.subscription,
    required this.vehicles,
  });

  @override
  Widget build(BuildContext context) {
    final time = _tenantTimeMetric(context, profile, subscription);
    final onTenancy = vehicles.where((vehicle) => vehicle.onTenancy).length;
    final slots = profile.allocatedSlots;

    // The tiles carry captions of different lengths, so they are sized
    // together to keep the row square.
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _TenantMetric(
              label: 'Subscription',
              value: 'KES ${_formatAmount(profile.subscriptionFee)}',
              caption: profile.pricingPlanName,
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: _TenantMetric(
              label: time.label,
              value: time.value,
              caption: time.caption,
              valueColor: time.color,
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: _TenantMetric(
              label: 'Plates',
              value: slots > 0 ? '$onTenancy of $slots' : '$onTenancy',
              caption: slots > 0 ? 'slots allocated' : 'on this tenancy',
            ),
          ),
        ],
      ),
    );
  }
}

class _TenantMetric extends StatelessWidget {
  final String label;
  final String value;
  final String caption;
  final Color? valueColor;

  const _TenantMetric({
    required this.label,
    required this.value,
    required this.caption,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 12),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              color: context.colors.textMuted,
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              style: GoogleFonts.poppins(
                color: valueColor ?? context.colors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            caption,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              color: context.colors.textSecondary,
              fontSize: 10,
              height: 1.25,
            ),
          ),
        ],
      ),
    );
  }
}

/// The plates this tenancy parks on, as vehicles rather than as label/value
/// rows - the plate leads, and the line under it says what the app knows about
/// the car and whether the tenancy actually covers it.
class _TenantVehiclePanel extends StatelessWidget {
  final List<_TenantVehicleData> vehicles;
  final int allocatedSlots;

  const _TenantVehiclePanel({
    required this.vehicles,
    required this.allocatedSlots,
  });

  @override
  Widget build(BuildContext context) {
    final onTenancy = vehicles.where((vehicle) => vehicle.onTenancy).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(
          title: 'Vehicles',
          action: null,
          onAction: null,
          trailing: allocatedSlots > 0
              ? '$onTenancy of $allocatedSlots slots'
              : null,
        ),
        const SizedBox(height: 10),
        if (vehicles.isEmpty)
          const _TenantVehicleEmptyCard()
        else
          Container(
            decoration: _surfaceDecoration(context),
            child: Column(
              children: [
                for (var i = 0; i < vehicles.length; i++) ...[
                  _TenantVehicleRow(vehicle: vehicles[i]),
                  if (i != vehicles.length - 1)
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

class _TenantVehicleRow extends StatelessWidget {
  final _TenantVehicleData vehicle;

  const _TenantVehicleRow({required this.vehicle});

  @override
  Widget build(BuildContext context) {
    final color = vehicle.onTenancy
        ? context.colors.primary
        : context.colors.textMuted;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              vehicle.onTenancy
                  ? Icons.directions_car_filled_outlined
                  : Icons.no_crash_outlined,
              color: color,
              size: 19,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  vehicle.plate,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    color: context.colors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  vehicle.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    color: context.colors.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TenantVehicleEmptyCard extends StatelessWidget {
  const _TenantVehicleEmptyCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
      decoration: _surfaceDecoration(context),
      child: Column(
        children: [
          Icon(
            Icons.no_crash_outlined,
            color: context.colors.textMuted,
            size: 28,
          ),
          const SizedBox(height: 8),
          Text(
            'No vehicles',
            style: GoogleFonts.poppins(
              color: context.colors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            'No plates on this tenancy yet',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              color: context.colors.textSecondary,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            'Ask the site manager to add your plate so the cameras let it in.',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              color: context.colors.textMuted,
              fontSize: 11,
            ),
          ),
        ],
      ),
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

  /// A read-only counter shown at the end of the row (e.g. "2 of 3 slots").
  final String? trailing;

  const _SectionTitle({
    required this.title,
    required this.action,
    required this.onAction,
    this.trailing,
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
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        if (trailing != null)
          Text(
            trailing!,
            style: GoogleFonts.poppins(
              color: context.colors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        if (action != null && onAction != null)
          TextButton.icon(
            onPressed: onAction,
            icon: const Icon(Icons.add_rounded, size: 16),
            label: Text(action!),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(0, 30),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              textStyle: GoogleFonts.poppins(
                fontSize: 11,
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
        padding: const EdgeInsets.all(14),
        decoration: _surfaceDecoration(context),
        child: Text(
          'Make your request today to enjoy tenant privileges.',
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            color: context.colors.textSecondary,
            fontSize: 12,
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
              Divider(height: 1, color: context.colors.divider, indent: 60),
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
      padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
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
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${request.locationName} - ${request.plateNumber}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    color: context.colors.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _humanizeCode(status),
            style: GoogleFonts.poppins(
              color: color,
              fontSize: 11,
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
          fontSize: 10,
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: context.colors.pageGrey,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: context.colors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: context.colors.primary, size: 13),
          const SizedBox(width: 4),
          Text(
            text,
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
}

class _PlatePill extends StatelessWidget {
  final String plate;

  const _PlatePill({required this.plate});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: context.colors.accentLight,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: context.colors.mintBorder),
      ),
      child: Text(
        plate,
        style: GoogleFonts.poppins(
          color: context.colors.primary,
          fontSize: 10,
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
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
      decoration: _surfaceDecoration(context),
      child: Column(
        children: [
          Icon(
            Icons.domain_disabled_outlined,
            color: context.colors.textMuted,
            size: 28,
          ),
          const SizedBox(height: 8),
          Text(
            filtered ? 'No profiles in this filter' : 'No tenant profiles yet',
            style: GoogleFonts.poppins(
              color: context.colors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            filtered
                ? 'Switch filters to see other tenant profiles.'
                : 'Apply for tenancy at a parking location to get started.',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              color: context.colors.textSecondary,
              fontSize: 11,
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
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      decoration: _surfaceDecoration(context),
      child: Column(
        children: [
          Icon(
            Icons.receipt_long_outlined,
            color: context.colors.textMuted,
            size: 30,
          ),
          const SizedBox(height: 10),
          Text(
            'No subscription history yet.',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              color: context.colors.textSecondary,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

/// The outline a tenant profile card and its detail header wear.
///
/// This is the whole point of the border: a tenancy reads its own deadline
/// from across the screen - plain while there is nothing to chase, amber
/// through the last week of the cycle, red once it has expired.
class _CycleBorder {
  final Color color;
  final double width;

  const _CycleBorder({required this.color, required this.width});

  Border toBorder() => Border.all(color: color, width: width);
}

_CycleBorder _cycleBorder(
  BuildContext context,
  TenantProfile profile, {
  DateTime? cycleEnd,
}) {
  switch (profile.cycleStatus(cycleEnd)) {
    case TenantCycleStatus.expired:
      return _CycleBorder(color: context.colors.error, width: 1.6);
    case TenantCycleStatus.endingSoon:
      return _CycleBorder(color: context.colors.warning, width: 1.6);
    case TenantCycleStatus.onTrack:
    case TenantCycleStatus.undated:
      return _CycleBorder(color: context.colors.border, width: 1);
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

/// The badge, icon and accent a tenant profile wears.
///
/// [cycleEnd] is the end date of the loaded subscription where the screen has
/// one; without it the profile's own end date decides. Expiry is checked
/// before the status field because a tenancy the service still calls
/// ACTIVE/PAID is expired the moment the date it was paid through passes.
_StatusTone _statusTone(
  BuildContext context,
  TenantProfile profile, {
  DateTime? cycleEnd,
}) {
  final status = profile.status;
  final payment = profile.paymentStatus;
  final cycle = profile.cycleStatus(cycleEnd);

  if (status == 'SUSPENDED') {
    return _StatusTone(
      color: context.colors.error,
      icon: Icons.block_outlined,
      label: 'Suspended',
    );
  }
  // Overdue outranks expired: the cycle is over either way, but a tenancy
  // inside its grace window still opens the barrier, and "overdue" is the
  // word for that.
  if (status == 'OVERDUE' || payment == 'OVERDUE') {
    return _StatusTone(
      color: context.colors.warning,
      icon: Icons.warning_amber_rounded,
      label: 'Overdue',
    );
  }
  if (cycle == TenantCycleStatus.expired) {
    return _StatusTone(
      color: context.colors.error,
      icon: Icons.event_busy_outlined,
      label: 'Expired',
    );
  }
  if (profile.isActivePaid) {
    if (cycle == TenantCycleStatus.endingSoon) {
      return _StatusTone(
        color: context.colors.warning,
        icon: Icons.schedule_outlined,
        label: 'Ending soon',
      );
    }
    return _StatusTone(
      color: context.colors.success,
      icon: Icons.check_circle_outline_rounded,
      label: 'Active',
    );
  }

  return _StatusTone(
    color: context.colors.primary,
    icon: Icons.pending_actions_outlined,
    label: 'Pending Payment',
  );
}

String _profileSecondaryText(TenantProfile profile) {
  final end = profile.subscriptionEndDate;
  if (profile.paymentStatus == 'OVERDUE' || profile.status == 'OVERDUE') {
    return 'Tenant benefits disabled';
  }
  switch (profile.cycleStatus()) {
    case TenantCycleStatus.expired:
      return end == null ? 'Expired' : 'Expired ${_formatDateShort(end)}';
    case TenantCycleStatus.endingSoon:
      final daysLeft = daysUntilDate(end) ?? 0;
      return daysLeft == 0
          ? 'Ends today'
          : 'Ends in $daysLeft ${_plural(daysLeft, 'day')}';
    case TenantCycleStatus.onTrack:
    case TenantCycleStatus.undated:
      break;
  }
  if (profile.isActivePaid) {
    return end == null ? 'Active' : 'Valid until ${_formatDateShort(end)}';
  }
  return 'KES ${_formatAmount(profile.subscriptionFee)} required';
}

String _payCta(TenantProfile profile) {
  if (profile.paymentStatus == 'OVERDUE' || profile.status == 'OVERDUE') {
    return 'Pay To Reactivate';
  }
  if (profile.isExpired) return 'Renew Subscription';
  return 'Pay Subscription';
}

/// Card variant of [_payCta] — the list card splits its row between two
/// buttons, so the label has to survive a much narrower box.
String _payCtaShort(TenantProfile profile) {
  if (profile.paymentStatus == 'OVERDUE' || profile.status == 'OVERDUE') {
    return 'Reactivate';
  }
  if (profile.isExpired) return 'Renew';
  return 'Pay Now';
}

/// An expired cycle is a renewal, not a first payment - the icon says so.
IconData _payCtaIcon(TenantProfile profile) {
  final overdue =
      profile.paymentStatus == 'OVERDUE' || profile.status == 'OVERDUE';
  return profile.isExpired && !overdue
      ? Icons.autorenew_rounded
      : Icons.phone_android_rounded;
}

/// One plate on the tenant profile.
///
/// [onTenancy] is the fact that actually decides whether the barrier opens:
/// the tenancy covers the plate. A plate the account registered but the
/// tenancy does not know about is listed too, flagged as not covered.
class _TenantVehicleData {
  final String plate;
  final String description;
  final bool onTenancy;

  const _TenantVehicleData({
    required this.plate,
    required this.description,
    required this.onTenancy,
  });
}

/// The vehicles panel on a tenant profile.
///
/// A tenant's vehicles live on the tenancy itself (`TenantDto.plateNumbers`,
/// written by `POST /.../tenants/{id}/vehicles`), NOT in the signed-in user's
/// `GET /vehicles` collection — a plate an admin attaches to the tenancy never
/// appears there. So the tenant's own plates lead, and the account's registered
/// vehicles are folded in afterwards for the ones it also knows about.
List<_TenantVehicleData> _tenantVehicles(
  TenantProfile profile,
  List<Vehicle> registeredVehicles,
) {
  final vehicles = <_TenantVehicleData>[];
  final listedPlateKeys = <String>{};

  for (final plate in profile.plateNumbers) {
    final plateKey = Vehicle.plateKey(plate);
    if (plateKey.isEmpty || !listedPlateKeys.add(plateKey)) continue;
    final match = registeredVehicles
        .where((vehicle) => Vehicle.plateKey(vehicle.plateNumber) == plateKey)
        .firstOrNull;
    vehicles.add(
      _TenantVehicleData(
        plate: plate,
        description: _tenantPlateDescription(match),
        onTenancy: true,
      ),
    );
  }

  for (final vehicle in registeredVehicles) {
    final plateKey = Vehicle.plateKey(vehicle.plateNumber);
    if (plateKey.isEmpty || !listedPlateKeys.add(plateKey)) continue;
    vehicles.add(
      _TenantVehicleData(
        plate: vehicle.plateNumber,
        description: _vehicleDescription(vehicle, 'Not linked to this tenancy'),
        onTenancy: false,
      ),
    );
  }

  return vehicles;
}

String _tenantPlateDescription(Vehicle? registeredVehicle) {
  const relationship = 'On this tenancy';
  if (registeredVehicle == null) return relationship;
  return _vehicleDescription(registeredVehicle, relationship);
}

/// `<make> <model> - <relationship>`, falling back to the vehicle type and
/// then to the relationship alone when the account holds no descriptive fields.
String _vehicleDescription(Vehicle vehicle, String relationship) {
  final details = [
    vehicle.make.trim(),
    vehicle.model.trim(),
  ].where((part) => part.isNotEmpty).join(' ');
  final vehicleDetails = (details.isEmpty ? vehicle.type : details).trim();

  return vehicleDetails.isEmpty
      ? relationship
      : '$vehicleDetails - $relationship';
}

/// `<client> · <location>` — the two names that place a tenancy, without
/// spending a whole detail row on either.
String _tenantSubtitle(TenantProfile profile) {
  final parts = [
    profile.clientName.trim(),
    profile.locationName.trim(),
  ].where((part) => part.isNotEmpty).toList();
  if (parts.isEmpty) return profile.locationId;
  return parts.join(' · ');
}

/// The rows left once the header and the metrics have said their part: the
/// terms of the tenancy, not its status.
List<_DetailRowData> _tenancyDetailRows(
  TenantProfile profile,
  TenantSubscription? subscription,
) {
  final start = subscription?.startDate ?? profile.subscriptionStartDate;
  final end = subscription?.endDate ?? profile.subscriptionEndDate;
  final grace = subscription?.gracePeriodDays ?? 0;

  final rows = <_DetailRowData>[
    _DetailRowData('Billing cycle', _cycleText(start, end)),
    _DetailRowData('Plan', profile.pricingPlanName),
    _DetailRowData('Where you park', _slotPolicyLabel(profile)),
  ];

  if (grace > 0) {
    rows.add(
      _DetailRowData(
        'Grace period',
        '$grace ${_plural(grace, 'day')} after the cycle ends',
      ),
    );
  }
  if (profile.ownerName.trim().isNotEmpty) {
    rows.add(_DetailRowData('Account holder', profile.ownerName.trim()));
  }

  return rows;
}

String _cycleText(DateTime? start, DateTime? end) {
  if (start == null && end == null) return 'Starts after payment';
  if (start == null) return 'Ends ${_formatDate(end)}';
  if (end == null) return 'From ${_formatDate(start)}';
  return '${_formatDate(start)} - ${_formatDate(end)}';
}

/// Plain English for `slotEnforcement`, which otherwise reads as a raw enum.
String _slotPolicyLabel(TenantProfile profile) {
  switch (profile.slotEnforcement.toUpperCase()) {
    case 'ALLOCATED_SLOTS':
      final slots = profile.allocatedSlots;
      return slots > 0
          ? 'Your $slots allocated ${_plural(slots, 'slot')}'
          : 'Your allocated slots';
    case 'REGISTERED_PLATES':
      return 'Any slot, registered plates only';
    case 'ANY_SLOT':
    case 'UNRESTRICTED':
      return 'Any free slot on site';
    default:
      return _humanizeCode(profile.slotEnforcement);
  }
}

/// The subscription the profile is standing on right now.
///
/// The paid, running cycle when there is one; otherwise the newest cycle on
/// record, because for an overdue or expired tenancy that is the row whose end
/// date and grace window decide whether the barrier still opens.
TenantSubscription? _currentSubscription(
  List<TenantSubscription>? subscriptions,
) {
  if (subscriptions == null || subscriptions.isEmpty) return null;

  final active = subscriptions.where((item) => item.isActivePaid).firstOrNull;
  if (active != null) return active;

  final sorted = [...subscriptions]
    ..sort((a, b) => _subscriptionAnchor(b).compareTo(_subscriptionAnchor(a)));
  return sorted.first;
}

DateTime _subscriptionAnchor(TenantSubscription subscription) {
  return subscription.endDate ??
      subscription.startDate ??
      subscription.createdAt ??
      DateTime.fromMillisecondsSinceEpoch(0);
}

/// The headline on the profile header: the one sentence that says what this
/// tenancy means for the driver today.
class _TenantHeadline {
  final IconData icon;
  final Color color;
  final String text;

  const _TenantHeadline({
    required this.icon,
    required this.color,
    required this.text,
  });
}

_TenantHeadline _tenantHeadline(
  BuildContext context,
  TenantProfile profile,
  TenantSubscription? subscription,
) {
  final colors = context.colors;
  final fee = 'KES ${_formatAmount(profile.subscriptionFee)}';
  final end = subscription?.endDate ?? profile.subscriptionEndDate;
  final daysLeft = daysUntilDate(end);
  final cycle = profile.cycleStatus(end);

  if (profile.status == 'SUSPENDED') {
    return _TenantHeadline(
      icon: Icons.block_outlined,
      color: colors.error,
      text:
          'Tenant parking is suspended. Talk to the site manager before '
          'driving in.',
    );
  }

  if (profile.status == 'OVERDUE' || profile.paymentStatus == 'OVERDUE') {
    final graceLeft = _graceDaysLeft(subscription);
    if (graceLeft != null && graceLeft > 0) {
      return _TenantHeadline(
        icon: Icons.schedule_outlined,
        color: colors.warning,
        text:
            '$fee is overdue. You have $graceLeft ${_plural(graceLeft, 'day')} '
            'of grace left before tenant parking stops.',
      );
    }
    return _TenantHeadline(
      icon: Icons.warning_amber_rounded,
      color: colors.error,
      text: '$fee is overdue and tenant parking is off. Pay to restore it.',
    );
  }

  // From here the cycle end date has the last word, whatever the status field
  // says: once the paid-through date is gone the tenancy buys nothing, and the
  // word for that is "expired".
  if (cycle == TenantCycleStatus.expired) {
    return _TenantHeadline(
      icon: Icons.event_busy_outlined,
      color: colors.error,
      text: end == null
          ? 'This tenancy has EXPIRED. Renew for $fee to start a new cycle.'
          : 'EXPIRED on ${_formatDate(end)}. Renew for $fee to start a new '
                'cycle.',
    );
  }

  if (profile.isActivePaid) {
    if (end == null || daysLeft == null) {
      return _TenantHeadline(
        icon: Icons.check_circle_outline_rounded,
        color: colors.success,
        text:
            'Tenant parking is active. The renewal date appears once the '
            'cycle is dated.',
      );
    }
    if (daysLeft == 0) {
      return _TenantHeadline(
        icon: Icons.event_available_outlined,
        color: colors.warning,
        text: 'Last day of this cycle. Renew today to keep parking here.',
      );
    }
    if (daysLeft <= TenantProfile.expiringSoonDays) {
      return _TenantHeadline(
        icon: Icons.event_available_outlined,
        color: colors.warning,
        text:
            'Renews in $daysLeft ${_plural(daysLeft, 'day')}, on '
            '${_formatDate(end)}.',
      );
    }
    return _TenantHeadline(
      icon: Icons.check_circle_outline_rounded,
      color: colors.success,
      text:
          'Tenant parking is active for $daysLeft more days, through '
          '${_formatDate(end)}.',
    );
  }

  return _TenantHeadline(
    icon: Icons.pending_actions_outlined,
    color: colors.primary,
    text: 'Pay $fee to switch tenant parking on at this location.',
  );
}

/// The middle metric tile — how much of the cycle is left, or how far past it
/// the tenancy has slipped.
class _TenantTimeMetric {
  final String label;
  final String value;
  final String caption;
  final Color? color;

  const _TenantTimeMetric({
    required this.label,
    required this.value,
    required this.caption,
    this.color,
  });
}

_TenantTimeMetric _tenantTimeMetric(
  BuildContext context,
  TenantProfile profile,
  TenantSubscription? subscription,
) {
  final colors = context.colors;
  final end = subscription?.endDate ?? profile.subscriptionEndDate;
  final daysLeft = daysUntilDate(end);

  if (end == null || daysLeft == null) {
    return const _TenantTimeMetric(
      label: 'Cycle',
      value: 'Not set',
      caption: 'starts after payment',
    );
  }

  if (daysLeft < 0) {
    final days = -daysLeft;
    return _TenantTimeMetric(
      label: 'Expired',
      value: '$days ${_plural(days, 'day')}',
      caption: 'ago, on ${_formatDate(end)}',
      color: colors.error,
    );
  }

  return _TenantTimeMetric(
    label: 'Time left',
    value: daysLeft == 0 ? 'Today' : '$daysLeft ${_plural(daysLeft, 'day')}',
    caption: 'until ${_formatDate(end)}',
    color: daysLeft <= TenantProfile.expiringSoonDays ? colors.warning : null,
  );
}

/// Grace only means something while a payment is outstanding and the window is
/// still open, so it is computed - and shown - only then.
int? _graceDaysLeft(TenantSubscription? subscription) {
  final end = subscription?.endDate;
  if (subscription == null || end == null) return null;
  if (subscription.gracePeriodDays <= 0) return null;
  return daysUntilDate(end.add(Duration(days: subscription.gracePeriodDays)));
}

/// How far through the billing cycle today sits, or null when the cycle is not
/// dated on both ends.
double? _cycleProgress(DateTime? start, DateTime? end) {
  if (start == null || end == null) return null;
  final total = end.difference(start).inSeconds;
  if (total <= 0) return null;
  final elapsed = DateTime.now().difference(start).inSeconds;
  return (elapsed / total).clamp(0.0, 1.0);
}

String _plural(int count, String word) => count == 1 ? word : '${word}s';

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
