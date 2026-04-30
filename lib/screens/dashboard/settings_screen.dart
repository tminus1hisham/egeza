import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../blocs/app_bloc.dart';
import '../../blocs/app_state.dart';
import '../../core/theme/app_colors.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageGrey,
      body: SafeArea(
        bottom: false,
        child: BlocBuilder<AppBloc, AppState>(
          builder: (context, state) {
            return Column(
              children: [
                _header(),
                Expanded(
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
                            ),
                            _settingsRow(
                              icon: Icons.directions_car_outlined,
                              title: 'Vehicles',
                              subtitle: '${state.vehicles.length} registered',
                            ),
                            _settingsRow(
                              icon: Icons.lock_outline_rounded,
                              title: 'Security',
                              subtitle: 'PIN and device access',
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
                              trailing: _switch(
                                value: _autoPay,
                                onChanged: (value) =>
                                    setState(() => _autoPay = value),
                              ),
                            ),
                            _settingsRow(
                              icon: Icons.notifications_none_rounded,
                              title: 'Parking alerts',
                              subtitle: 'Entry, exit, and receipt updates',
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
                              subtitle: '0712 345 678',
                            ),
                            _settingsRow(
                              icon: Icons.account_balance_wallet_outlined,
                              title: 'Low balance alert',
                              subtitle: 'Notify below KES 500',
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
                            ),
                            _settingsRow(
                              icon: Icons.privacy_tip_outlined,
                              title: 'Privacy and terms',
                              subtitle: 'Data, payments, and app terms',
                            ),
                            _settingsRow(
                              icon: Icons.logout_rounded,
                              title: 'Sign out',
                              subtitle: 'Leave this device',
                              danger: true,
                            ),
                          ],
                        ),
                      ],
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
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.accentLight,
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(
              Icons.settings_outlined,
              color: AppColors.primary,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Settings',
                  style: GoogleFonts.poppins(
                    color: AppColors.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Account, parking, and payment controls',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(
              Icons.more_horiz_rounded,
              color: AppColors.textPrimary,
              size: 22,
            ),
          ),
        ],
      ),
    );
  }

  Widget _profileCard(AppState state) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primaryDark,
        borderRadius: BorderRadius.circular(24),
      ),
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
                  'ParkIQ member',
                  style: GoogleFonts.poppins(
                    color: Colors.white.withValues(alpha: 0.66),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(
                      Icons.account_balance_wallet_outlined,
                      color: AppColors.accent,
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
    );
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
              color: AppColors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
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
                  const Divider(
                    height: 1,
                    color: AppColors.divider,
                    indent: 74,
                  ),
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
  }) {
    final color = danger ? AppColors.error : AppColors.primary;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 15),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: danger ? const Color(0xFFFFECEB) : AppColors.accentLight,
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
                    color: danger ? AppColors.error : AppColors.textPrimary,
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
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          trailing ??
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textMuted,
                size: 22,
              ),
        ],
      ),
    );
  }

  Widget _switch({
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Transform.scale(
      scale: 0.86,
      child: Switch(
        value: value,
        activeColor: Colors.white,
        activeTrackColor: AppColors.primary,
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
    return amount.toStringAsFixed(0).replaceAllMapped(
          RegExp(r'\B(?=(\d{3})+(?!\d))'),
          (match) => ',',
        );
  }
}
