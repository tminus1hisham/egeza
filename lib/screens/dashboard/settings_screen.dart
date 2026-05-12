import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../blocs/app_bloc.dart';
import '../../blocs/app_event.dart';
import '../../blocs/app_state.dart';
import '../../core/theme/app_colors.dart';
import '../../widgets/app_widgets.dart';
import '../auth/sign_in_screen.dart';
import 'settings_detail_screen.dart';
import 'tenancy_screen.dart';
import 'vehicles_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _autoPay = true;
  bool _pushAlerts = true;
  bool _biometrics = false;
  bool _lowBalance = true;
  String? _paymentPhoneNumber;

  Future<void> _onRefresh() async {
    context.read<AppBloc>().add(LoadDashboardData());
    await Future.delayed(const Duration(milliseconds: 800));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.pageGrey,
      body: SafeArea(
        bottom: false,
        child: BlocBuilder<AppBloc, AppState>(
          builder: (context, state) {
            return Column(
              children: [
                _header(),
                Expanded(
                  child: RefreshIndicator(
                    color: context.colors.primary,
                    onRefresh: _onRefresh,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 30),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _profileCard(state),
                          const SizedBox(height: 22),
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
                              _settingsRow(
                                icon: Icons.brightness_6_outlined,
                                title: 'App Theme',
                                subtitle: state.themeMode == ThemeMode.system
                                    ? 'System default'
                                    : state.themeMode == ThemeMode.dark
                                    ? 'Dark mode'
                                    : 'Light mode',
                                onTap: null, // the trailing widget handles it
                                trailing: SegmentedButton<ThemeMode>(
                                  segments: const [
                                    ButtonSegment<ThemeMode>(
                                      value: ThemeMode.light,
                                      icon: Icon(Icons.light_mode, size: 16),
                                    ),
                                    ButtonSegment<ThemeMode>(
                                      value: ThemeMode.system,
                                      icon: Icon(
                                        Icons.brightness_auto,
                                        size: 16,
                                      ),
                                    ),
                                    ButtonSegment<ThemeMode>(
                                      value: ThemeMode.dark,
                                      icon: Icon(Icons.dark_mode, size: 16),
                                    ),
                                  ],
                                  selected: {state.themeMode},
                                  onSelectionChanged:
                                      (Set<ThemeMode> newSelection) {
                                        context.read<AppBloc>().add(
                                          ChangeThemeMode(newSelection.first),
                                        );
                                      },
                                  style: SegmentedButton.styleFrom(
                                    backgroundColor: context.colors.background,
                                    selectedBackgroundColor:
                                        context.colors.primary,
                                    selectedForegroundColor: Colors.white,
                                    visualDensity: VisualDensity.compact,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
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
                                  enabledText:
                                      'Entry, exit, and receipt updates',
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
                              _settingsRow(
                                icon: Icons.fingerprint_rounded,
                                title: 'Biometric approval',
                                subtitle: 'Require biometrics for top-ups',
                                onTap: () => _openPreferencePage(
                                  title: 'Biometric approval',
                                  subtitle: 'Top-up confirmation security',
                                  icon: Icons.fingerprint_rounded,
                                  value: _biometrics,
                                  enabledText:
                                      'Biometrics required for top-ups',
                                  disabledText:
                                      'Top-ups use device unlock only',
                                  details: const [
                                    'Add an extra approval step before wallet top-ups.',
                                    'Uses the biometric method configured on this device.',
                                    'You can still approve payments with your device passcode.',
                                  ],
                                  onSaved: (value) => _biometrics = value,
                                ),
                                trailing: _switch(
                                  value: _biometrics,
                                  onChanged: (value) =>
                                      setState(() => _biometrics = value),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
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
                          const SizedBox(height: 18),
                          _settingsSection(
                            title: 'Support',
                            children: [
                              _settingsRow(
                                icon: Icons.help_outline_rounded,
                                title: 'Help center',
                                subtitle: 'FAQs and contact support',
                                onTap: () =>
                                    _openPage(const HelpCenterSettingsPage()),
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

  Widget _header() {
    return AppPageHeader(
      title: 'Settings',
      subtitle: 'Manage your preferences',
      icon: Icons.settings_outlined,
      trailing: AppHeaderButton(
        icon: Icons.more_horiz_rounded,
        tooltip: 'More settings',
        onTap: () {},
      ),
    );
  }

  Widget _profileCard(AppState state) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.28),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(24),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _openPage(PersonalDetailsSettingsPage(state: state)),
          splashColor: Colors.white.withValues(alpha: 0.1),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 58,
                  height: 58,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(19),
                  ),
                  child: Text(
                    _initials(state.userName),
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        state.userName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        state.isTenant ? 'egesha tenant' : 'egesha member',
                        style: GoogleFonts.poppins(
                          color: Colors.white.withValues(alpha: 0.66),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(
                            Icons.account_balance_wallet_outlined,
                            color: context.colors.accent,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              'KES ${_formatAmount(state.walletBalance)} wallet balance',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.poppins(
                                color: Colors.white.withValues(alpha: 0.82),
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (state.shouldShowTenancy) ...[
                        const SizedBox(height: 7),
                        Row(
                          children: [
                            Icon(
                              Icons.domain_outlined,
                              color: context.colors.accent,
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                _tenancyProfileSummary(state),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.poppins(
                                  color: Colors.white.withValues(alpha: 0.82),
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.edit_outlined,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
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

  Future<void> _openSecurityPage() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => SecuritySettingsPage(biometricsEnabled: _biometrics),
      ),
    );

    if (!mounted || result == null) return;
    setState(() => _biometrics = result);
  }

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
          padding: const EdgeInsets.only(left: 2, bottom: 10),
          child: Text(
            title,
            style: GoogleFonts.poppins(
              color: context.colors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: context.colors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: context.colors.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.025),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                children[i],
                if (i != children.length - 1)
                  Divider(height: 1, color: context.colors.divider, indent: 74),
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
          padding: const EdgeInsets.fromLTRB(16, 15, 16, 15),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: danger
                      ? const Color(0xFFFFECEB)
                      : context.colors.accentLight,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color, size: 21),
              ),
              const SizedBox(width: 14),
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
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
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
              const SizedBox(width: 12),
              trailing ??
                  Icon(
                    Icons.chevron_right_rounded,
                    color: context.colors.textMuted,
                    size: 22,
                  ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _switch({required bool value, required ValueChanged<bool> onChanged}) {
    return Transform.scale(
      scale: 0.86,
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

  String _initials(String name) {
    final pieces = name.trim().split(RegExp(r'\s+'));
    if (pieces.isEmpty || pieces.first.isEmpty) return 'PI';
    if (pieces.length == 1) return pieces.first.substring(0, 1).toUpperCase();
    return '${pieces.first.substring(0, 1)}${pieces.last.substring(0, 1)}'
        .toUpperCase();
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

  String _tenancyProfileSummary(AppState state) {
    if (state.isTenant) {
      if (state.hasActiveTenancy) {
        return '${state.activeTenantProfileCount} active tenant profile';
      }
      if (state.hasPayableTenancy) {
        return '${state.payableTenantProfileCount} subscription payment pending';
      }
      if (state.visibleTenantProfiles.isEmpty) return 'Tenant access enabled';
      return '${state.visibleTenantProfiles.length} tenant profile';
    }

    return '${state.tenancyRequests.length} tenancy request';
  }
}
