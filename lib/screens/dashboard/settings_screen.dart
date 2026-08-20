import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../blocs/app_bloc.dart';
import '../../blocs/app_event.dart';
import '../../blocs/app_state.dart';
import '../../core/theme/app_colors.dart';
import '../../widgets/app_widgets.dart';
import '../auth/sign_in_screen.dart';
import 'help_center_screen.dart';
import 'manager_screen.dart';
import 'settings_detail_screen.dart';
import 'tenancy_screen.dart';
import 'vehicles_screen.dart';

/// Whether the Developer section appears at all.
///
/// Debug and profile builds only, so a Play Store release never ships a control
/// that changes which half of the app the user sees. Flip this to `true` if you
/// need the switch in a release build you are testing by hand.
const bool kShowDeveloperSettings = !kReleaseMode;

class SettingsScreen extends StatefulWidget {
  final bool showBackButton;

  const SettingsScreen({super.key, this.showBackButton = false});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _autoPay = true;
  bool _pushAlerts = true;
  bool _lowBalance = true;
  String? _paymentPhoneNumber;

  Future<void> _onRefresh() async {
    context.read<AppBloc>().add(LoadDashboardData());
    await Future.delayed(const Duration(milliseconds: 800));
  }

  @override
  Widget build(BuildContext context) {
    return AdaptiveStatusBar(
      child: Scaffold(
        backgroundColor: context.colors.pageGrey,
        body: SafeArea(
          bottom: false,
          child: BlocBuilder<AppBloc, AppState>(
            builder: (context, state) {
              return RefreshIndicator(
                color: context.colors.primary,
                onRefresh: _onRefresh,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (widget.showBackButton) ...[
                        const PageBackButton(),
                        const SizedBox(height: 8),
                      ],
                      _profileCard(state),
                      const SizedBox(height: 16),
                      if (state.isManager) ...[
                        _settingsSection(
                          title: 'Management',
                          children: [
                            _settingsRow(
                              icon: Icons.insights_rounded,
                              title: 'Manager view',
                              subtitle: 'Live takings, vehicles and occupancy',
                              onTap: () => _openPage(
                                ManagerScreen(
                                  api: context.read<AppBloc>().api,
                                  useSampleData: state.debugSampleData,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                      ],
                      _settingsSection(
                        title: 'Account',
                        children: [
                          _settingsRow(
                            icon: Icons.person_outline_rounded,
                            title: 'Personal details',
                            subtitle: state.userName,
                            onTap: () => _openPage(
                              PersonalDetailsSettingsPage(state: state),
                            ),
                          ),
                          _settingsRow(
                            icon: Icons.directions_car_outlined,
                            title: 'Vehicles',
                            subtitle: '${state.vehicles.length} registered',
                            onTap: () => _openPage(
                              const VehiclesScreen(showBackButton: true),
                            ),
                          ),
                          _settingsRow(
                            icon: Icons.lock_outline_rounded,
                            title: 'Security',
                            subtitle: 'PIN and device access',
                            onTap: _openSecurityPage,
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      _settingsSection(
                        title: 'Parking',
                        children: [
                          _settingsRow(
                            icon: Icons.bolt_outlined,
                            title: 'AutoPay',
                            subtitle: _autoPay
                                ? 'Automatic exit payments'
                                : 'Manual payments',
                            onTap: () => _openPreferencePage(
                              title: 'AutoPay',
                              subtitle: 'Automatic parking payments',
                              icon: Icons.bolt_outlined,
                              value: _autoPay,
                              enabledText: 'Automatic exit payments',
                              disabledText: 'Manual parking payments',
                              details: const [
                                'Use your wallet balance for eligible exits.',
                                'Vehicle-specific AutoPay can still be changed from Vehicles.',
                                'Receipts stay available in parking history.',
                              ],
                              onSaved: (value) => _autoPay = value,
                            ),
                            trailing: _switch(
                              value: _autoPay,
                              onChanged: (value) =>
                                  setState(() => _autoPay = value),
                            ),
                          ),
                          _settingsRow(
                            icon: Icons.domain_outlined,
                            title: state.isTenant
                                ? 'Tenant parking'
                                : 'Request tenancy',
                            subtitle: _tenancySettingsSubtitle(state),
                            onTap: () => _openPage(
                              const TenancyScreen(showBackButton: true),
                            ),
                          ),
                          _settingsRow(
                            icon: Icons.notifications_none_rounded,
                            title: 'Parking alerts',
                            subtitle: 'Entry, exit, and receipt updates',
                            onTap: () => _openPreferencePage(
                              title: 'Parking alerts',
                              subtitle: 'Session and payment notifications',
                              icon: Icons.notifications_none_rounded,
                              value: _pushAlerts,
                              enabledText: 'Entry, exit, and receipt updates',
                              disabledText: 'Alerts are muted',
                              details: const [
                                'Get updates when a parking session starts.',
                                'Know when payment is completed or needs action.',
                                'Keep receipt notifications visible after exit.',
                              ],
                              onSaved: (value) => _pushAlerts = value,
                            ),
                            trailing: _switch(
                              value: _pushAlerts,
                              onChanged: (value) =>
                                  setState(() => _pushAlerts = value),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      _settingsSection(
                        title: 'Payments',
                        children: [
                          _settingsRow(
                            icon: Icons.phone_android_rounded,
                            title: 'M-Pesa number',
                            subtitle: _displayPhone(
                              _paymentPhoneNumber ?? state.phoneNumber,
                            ),
                            onTap: () => _openMpesaNumberPage(
                              _paymentPhoneNumber ?? state.phoneNumber,
                            ),
                          ),
                          _settingsRow(
                            icon: Icons.account_balance_wallet_outlined,
                            title: 'Low balance alert',
                            subtitle: 'Notify below KES 500',
                            onTap: () => _openPreferencePage(
                              title: 'Low balance alert',
                              subtitle: 'Wallet balance reminders',
                              icon: Icons.account_balance_wallet_outlined,
                              value: _lowBalance,
                              enabledText: 'Notify below KES 500',
                              disabledText: 'Low balance reminders are off',
                              details: const [
                                'Warn before wallet funds are too low for AutoPay.',
                                'Alert threshold is set to KES 500.',
                                'Top up from Wallet when the alert appears.',
                              ],
                              onSaved: (value) => _lowBalance = value,
                            ),
                            trailing: _switch(
                              value: _lowBalance,
                              onChanged: (value) =>
                                  setState(() => _lowBalance = value),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      _settingsSection(
                        title: 'Support',
                        children: [
                          _settingsRow(
                            icon: Icons.help_outline_rounded,
                            title: 'Help center',
                            subtitle: 'FAQs and contact support',
                            onTap: () => _openPage(const HelpCenterScreen()),
                          ),
                          _settingsRow(
                            icon: Icons.privacy_tip_outlined,
                            title: 'Privacy and terms',
                            subtitle: 'Data, payments, and app terms',
                            onTap: () =>
                                _openPage(const PrivacyTermsSettingsPage()),
                          ),
                          _settingsRow(
                            icon: Icons.logout_rounded,
                            title: 'Sign out',
                            subtitle: 'Leave this device',
                            danger: true,
                            onTap: _confirmSignOut,
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      // Its own section rather than a row in Account: a
                      // three-way control crowds a row, and the row it sat on
                      // looked tappable while doing nothing.
                      _themeSection(state),
                      if (kShowDeveloperSettings) ...[
                        const SizedBox(height: 14),
                        _developerSection(state),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _themeSection(AppState state) {
    final label = switch (state.themeMode) {
      ThemeMode.system => 'System default',
      ThemeMode.dark => 'Dark mode',
      ThemeMode.light => 'Light mode',
    };

    return _settingsSection(
      title: 'Appearance',
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.brightness_6_outlined,
                    size: 18,
                    color: context.colors.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'App theme',
                      style: GoogleFonts.poppins(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: context.colors.textPrimary,
                      ),
                    ),
                  ),
                  Text(
                    label,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: context.colors.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<ThemeMode>(
                  segments: const [
                    ButtonSegment<ThemeMode>(
                      value: ThemeMode.light,
                      icon: Icon(Icons.light_mode, size: 15),
                      label: Text('Light'),
                    ),
                    ButtonSegment<ThemeMode>(
                      value: ThemeMode.system,
                      icon: Icon(Icons.brightness_auto, size: 15),
                      label: Text('Auto'),
                    ),
                    ButtonSegment<ThemeMode>(
                      value: ThemeMode.dark,
                      icon: Icon(Icons.dark_mode, size: 15),
                      label: Text('Dark'),
                    ),
                  ],
                  selected: {state.themeMode},
                  showSelectedIcon: false,
                  onSelectionChanged: (Set<ThemeMode> newSelection) {
                    context.read<AppBloc>().add(
                      ChangeThemeMode(newSelection.first),
                    );
                  },
                  style: SegmentedButton.styleFrom(
                    backgroundColor: context.colors.background,
                    selectedBackgroundColor: context.colors.primary,
                    selectedForegroundColor: Colors.white,
                    visualDensity: VisualDensity.compact,
                    textStyle: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Debug-only. Flips the app between the driver side and the manager side
  /// without touching the account's role in the backend.
  ///
  /// The switch shows the *effective* mode, so it reads correctly whether that
  /// came from the account role or from an override.
  Widget _developerSection(AppState state) {
    final roleLabel = state.hasManagerRole ? 'manager' : 'driver';

    return _settingsSection(
      title: 'Developer',
      children: [
        _settingsRow(
          icon: Icons.science_outlined,
          title: 'Manager mode',
          subtitle: state.isManager
              ? 'Showing the manager view'
              : 'Showing the driver view',
          onTap: () => _setDebugManagerMode(!state.isManager),
          trailing: _switch(
            value: state.isManager,
            onChanged: _setDebugManagerMode,
          ),
        ),
        if (state.isDebugModeOverridden)
          _settingsRow(
            icon: Icons.restart_alt_rounded,
            title: 'Follow account role',
            subtitle: 'Your account is a $roleLabel account',
            onTap: () => _setDebugManagerMode(null),
          ),
        _settingsRow(
          icon: Icons.dataset_outlined,
          title: 'Sample data',
          subtitle: state.debugSampleData
              ? 'Manager view shows generated figures'
              : 'Manager view reads your real sites',
          onTap: () => _setDebugSampleData(!state.debugSampleData),
          trailing: _switch(
            value: state.debugSampleData,
            onChanged: _setDebugSampleData,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 2, 14, 12),
          child: Text(
            'Debug builds only. Manager mode changes what the app offers, not '
            'what the API allows — on a driver account the manager view finds '
            'no sites assigned to it, which is what sample data is for.',
            style: GoogleFonts.poppins(
              color: context.colors.textMuted,
              fontSize: 11,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }

  void _setDebugManagerMode(bool? enabled) {
    context.read<AppBloc>().add(SetDebugManagerMode(enabled));
  }

  void _setDebugSampleData(bool enabled) {
    context.read<AppBloc>().add(SetDebugSampleData(enabled));
  }

  Widget _profileCard(AppState state) {
    final activeSessions = state.recentSessions.where((s) => s.isActive).length;

    return PageHero(
      eyebrow: 'Signed in as',
      value: state.userName.isEmpty ? 'egesha account' : state.userName,
      tone: PageHeroTone.brand,
      onBack: widget.showBackButton ? () => Navigator.pop(context) : null,
      onTap: () => _openPage(PersonalDetailsSettingsPage(state: state)),
      pill: PageHeroPill(
        icon: state.isTenant ? Icons.domain_rounded : Icons.verified_outlined,
        label: state.isTenant ? 'Tenant' : 'Member',
      ),
      trailing: PageAction(
        icon: Icons.edit_outlined,
        tooltip: 'Edit personal details',
        onDark: true,
        compact: true,
        onTap: () => _openPage(PersonalDetailsSettingsPage(state: state)),
      ),
      metrics: [
        PageHeroMetric('Wallet', 'KES ${_formatAmount(state.walletBalance)}'),
        PageHeroMetric('Vehicles', '${state.vehicles.length}'),
        PageHeroMetric('Parked now', '$activeSessions'),
      ],
    );
  }

  Future<void> _openPage<T>(Widget page) {
    return Navigator.push<T>(context, MaterialPageRoute(builder: (_) => page));
  }

  Future<void> _openPreferencePage({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool value,
    required String enabledText,
    required String disabledText,
    required List<String> details,
    required ValueChanged<bool> onSaved,
  }) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => PreferenceSettingsPage(
          title: title,
          subtitle: subtitle,
          icon: icon,
          enabled: value,
          enabledText: enabledText,
          disabledText: disabledText,
          details: details,
        ),
      ),
    );

    if (!mounted || result == null) return;
    setState(() => onSaved(result));
  }

  void _openSecurityPage() => _openPage(const SecuritySettingsPage());

  Future<void> _openMpesaNumberPage(String? phoneNumber) async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => MpesaNumberSettingsPage(phoneNumber: phoneNumber),
      ),
    );

    if (!mounted || result == null || result.trim().isEmpty) return;
    setState(() => _paymentPhoneNumber = result.trim());
  }

  Future<void> _confirmSignOut() async {
    final shouldSignOut = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'Sign out?',
            style: GoogleFonts.poppins(
              color: context.colors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          content: Text(
            'You will need to sign in again to manage parking and payments.',
            style: GoogleFonts.poppins(
              color: context.colors.textSecondary,
              fontSize: 13,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(
                'Cancel',
                style: GoogleFonts.poppins(color: context.colors.textSecondary),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(
                'Sign out',
                style: GoogleFonts.poppins(
                  color: context.colors.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (shouldSignOut != true || !mounted) return;
    context.read<AppBloc>().add(SignOut());
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const SignInScreen()),
      (route) => false,
    );
  }

  String _displayPhone(String? phoneNumber) {
    if (phoneNumber == null || phoneNumber.trim().isEmpty) {
      return 'Add payment number';
    }

    final digits = phoneNumber.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 12 && digits.startsWith('254')) {
      return '0${digits.substring(3, 6)} ${digits.substring(6, 9)} ${digits.substring(9)}';
    }
    if (digits.length == 10 && digits.startsWith('0')) {
      return '${digits.substring(0, 4)} ${digits.substring(4, 7)} ${digits.substring(7)}';
    }
    return phoneNumber;
  }

  Widget _settingsSection({
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 8),
          child: Text(
            title,
            style: GoogleFonts.poppins(
              color: context.colors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: context.colors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: context.colors.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.025),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                children[i],
                if (i != children.length - 1)
                  Divider(height: 1, color: context.colors.divider, indent: 64),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _settingsRow({
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? trailing,
    bool danger = false,
    VoidCallback? onTap,
  }) {
    final color = danger ? context.colors.error : context.colors.primary;

    return Material(
      color: context.colors.surface,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: danger
                      ? const Color(0xFFFFECEB)
                      : context.colors.accentLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 19),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        color: danger
                            ? context.colors.error
                            : context.colors.textPrimary,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
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
              trailing ??
                  Icon(
                    Icons.chevron_right_rounded,
                    color: context.colors.textMuted,
                    size: 20,
                  ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _switch({required bool value, required ValueChanged<bool> onChanged}) {
    return Transform.scale(
      scale: 0.78,
      child: Switch(
        value: value,
        activeThumbColor: Colors.white,
        activeTrackColor: context.colors.primary,
        inactiveThumbColor: Colors.white,
        inactiveTrackColor: const Color(0xFFD8DEE8),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
        onChanged: onChanged,
      ),
    );
  }

  String _formatAmount(num amount) {
    return amount
        .toStringAsFixed(0)
        .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (match) => ',');
  }

  String _tenancySettingsSubtitle(AppState state) {
    if (state.isTenant) {
      if (state.hasActiveTenancy) {
        return '${state.activeTenantProfileCount} active tenant ${state.activeTenantProfileCount == 1 ? 'profile' : 'profiles'}';
      }
      if (state.hasPayableTenancy) {
        return '${state.payableTenantProfileCount} subscription ${state.payableTenantProfileCount == 1 ? 'needs' : 'need'} payment';
      }
      if (state.visibleTenantProfiles.isEmpty) return 'Tenant access enabled';
      return '${state.visibleTenantProfiles.length} tenant ${state.visibleTenantProfiles.length == 1 ? 'profile' : 'profiles'}';
    }

    if (state.hasTenancyRequests) {
      return '${state.tenancyRequests.length} submitted ${state.tenancyRequests.length == 1 ? 'request' : 'requests'}';
    }

    return 'Apply for dedicated parking';
  }

}
