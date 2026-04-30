import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../blocs/app_state.dart';
import '../../core/theme/app_colors.dart';

class PersonalDetailsSettingsPage extends StatelessWidget {
  final AppState state;

  const PersonalDetailsSettingsPage({
    super.key,
    required this.state,
  });

  @override
  Widget build(BuildContext context) {
    final activeSessions = state.recentSessions.where((item) => item.isActive);

    return _SettingsSubPageScaffold(
      title: 'Personal details',
      subtitle: 'Profile and contact info',
      icon: Icons.person_outline_rounded,
      children: [
        _ProfileHero(
          name: state.userName,
          phoneNumber: state.phoneNumber,
          walletBalance: state.walletBalance,
        ),
        const SizedBox(height: 18),
        _InfoPanel(
          title: 'Account',
          children: [
            _InfoRow(
              icon: Icons.badge_outlined,
              title: 'Full name',
              value: state.userName,
            ),
            _InfoRow(
              icon: Icons.phone_android_rounded,
              title: 'Phone number',
              value: _formatPhone(state.phoneNumber),
            ),
            _InfoRow(
              icon: Icons.email_outlined,
              title: 'Email',
              value: state.email?.isNotEmpty == true
                  ? state.email!
                  : 'Not added',
            ),
          ],
        ),
        const SizedBox(height: 18),
        _InfoPanel(
          title: 'Parking profile',
          children: [
            _InfoRow(
              icon: Icons.directions_car_outlined,
              title: 'Registered vehicles',
              value: '${state.vehicles.length}',
            ),
            _InfoRow(
              icon: Icons.local_parking_outlined,
              title: 'Active sessions',
              value: '${activeSessions.length}',
            ),
            _InfoRow(
              icon: Icons.verified_user_outlined,
              title: 'Member status',
              value: state.isAuthenticated ? 'Verified' : 'Demo profile',
            ),
          ],
        ),
      ],
    );
  }
}

class SecuritySettingsPage extends StatefulWidget {
  final bool biometricsEnabled;

  const SecuritySettingsPage({
    super.key,
    required this.biometricsEnabled,
  });

  @override
  State<SecuritySettingsPage> createState() => _SecuritySettingsPageState();
}

class _SecuritySettingsPageState extends State<SecuritySettingsPage> {
  late bool _biometricsEnabled;
  bool _pinRequired = true;
  bool _trustedDevice = true;

  @override
  void initState() {
    super.initState();
    _biometricsEnabled = widget.biometricsEnabled;
  }

  @override
  Widget build(BuildContext context) {
    return _SettingsSubPageScaffold(
      title: 'Security',
      subtitle: 'PIN and device access',
      icon: Icons.lock_outline_rounded,
      onBack: () => Navigator.pop(context, _biometricsEnabled),
      footer: _PrimaryActionButton(
        icon: Icons.check_rounded,
        label: 'Save security',
        onPressed: () => Navigator.pop(context, _biometricsEnabled),
      ),
      children: [
        _SecurityHero(
          biometricsEnabled: _biometricsEnabled,
          pinRequired: _pinRequired,
        ),
        const SizedBox(height: 18),
        _InfoPanel(
          title: 'Access control',
          children: [
            _ToggleRow(
              icon: Icons.pin_outlined,
              title: 'Require PIN',
              subtitle: 'Ask for a device PIN before sensitive actions',
              value: _pinRequired,
              onChanged: (value) => setState(() => _pinRequired = value),
            ),
            _ToggleRow(
              icon: Icons.fingerprint_rounded,
              title: 'Biometric approval',
              subtitle: 'Use fingerprint or face unlock for top-ups',
              value: _biometricsEnabled,
              onChanged: (value) =>
                  setState(() => _biometricsEnabled = value),
            ),
            _ToggleRow(
              icon: Icons.phone_iphone_rounded,
              title: 'Trust this device',
              subtitle: 'Keep sign-in active on this phone',
              value: _trustedDevice,
              onChanged: (value) => setState(() => _trustedDevice = value),
            ),
          ],
        ),
        const SizedBox(height: 18),
        _InfoPanel(
          title: 'Security actions',
          children: [
            _ActionRow(
              icon: Icons.password_rounded,
              title: 'Change PIN',
              subtitle: 'Update your approval code',
              onTap: () => _showSnack(context, 'PIN setup is ready to connect.'),
            ),
            _ActionRow(
              icon: Icons.devices_other_outlined,
              title: 'Trusted devices',
              subtitle: 'Review devices linked to your account',
              onTap: () =>
                  _showSnack(context, 'Device management is ready to connect.'),
            ),
          ],
        ),
      ],
    );
  }
}

class PreferenceSettingsPage extends StatefulWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool enabled;
  final String enabledText;
  final String disabledText;
  final List<String> details;

  const PreferenceSettingsPage({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.enabled,
    required this.enabledText,
    required this.disabledText,
    required this.details,
  });

  @override
  State<PreferenceSettingsPage> createState() => _PreferenceSettingsPageState();
}

class _PreferenceSettingsPageState extends State<PreferenceSettingsPage> {
  late bool _enabled;

  @override
  void initState() {
    super.initState();
    _enabled = widget.enabled;
  }

  @override
  Widget build(BuildContext context) {
    return _SettingsSubPageScaffold(
      title: widget.title,
      subtitle: widget.subtitle,
      icon: widget.icon,
      onBack: () => Navigator.pop(context, _enabled),
      footer: _PrimaryActionButton(
        icon: Icons.check_rounded,
        label: 'Save preference',
        onPressed: () => Navigator.pop(context, _enabled),
      ),
      children: [
        _PreferenceHero(
          icon: widget.icon,
          title: widget.title,
          status: _enabled ? widget.enabledText : widget.disabledText,
          enabled: _enabled,
          onChanged: (value) => setState(() => _enabled = value),
        ),
        const SizedBox(height: 18),
        _InfoPanel(
          title: 'Details',
          children: [
            for (final detail in widget.details)
              _BulletRow(text: detail),
          ],
        ),
      ],
    );
  }
}

class MpesaNumberSettingsPage extends StatefulWidget {
  final String? phoneNumber;

  const MpesaNumberSettingsPage({
    super.key,
    required this.phoneNumber,
  });

  @override
  State<MpesaNumberSettingsPage> createState() =>
      _MpesaNumberSettingsPageState();
}

class _MpesaNumberSettingsPageState extends State<MpesaNumberSettingsPage> {
  late final TextEditingController _phoneController;

  @override
  void initState() {
    super.initState();
    _phoneController = TextEditingController(
      text: widget.phoneNumber == null ? '' : _formatPhone(widget.phoneNumber),
    );
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _SettingsSubPageScaffold(
      title: 'M-Pesa number',
      subtitle: 'Default payment phone',
      icon: Icons.phone_android_rounded,
      footer: _PrimaryActionButton(
        icon: Icons.check_rounded,
        label: 'Done',
        onPressed: () => Navigator.pop(context, _phoneController.text.trim()),
      ),
      children: [
        _InfoPanel(
          title: 'Payment details',
          children: [
            _InputRow(
              label: 'M-Pesa number',
              controller: _phoneController,
            ),
            const _InfoRow(
              icon: Icons.account_balance_wallet_outlined,
              title: 'Payment method',
              value: 'M-Pesa STK Push',
            ),
            const _InfoRow(
              icon: Icons.receipt_long_outlined,
              title: 'Receipts',
              value: 'Sent after successful payment',
            ),
          ],
        ),
        const SizedBox(height: 18),
        const _NoticeCard(
          icon: Icons.info_outline_rounded,
          title: 'Wallet top-ups',
          body:
              'This number is shown when you confirm an M-Pesa wallet top-up.',
        ),
      ],
    );
  }
}

class HelpCenterSettingsPage extends StatelessWidget {
  const HelpCenterSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return _SettingsSubPageScaffold(
      title: 'Help center',
      subtitle: 'FAQs and support',
      icon: Icons.help_outline_rounded,
      children: [
        _InfoPanel(
          title: 'Common questions',
          children: [
            _ActionRow(
              icon: Icons.local_parking_outlined,
              title: 'Parking session not showing',
              subtitle: 'Check plate number and location status',
              onTap: () => _showSnack(context, 'Session help is ready.'),
            ),
            _ActionRow(
              icon: Icons.payments_outlined,
              title: 'Payment failed',
              subtitle: 'Review wallet balance and M-Pesa prompt status',
              onTap: () => _showSnack(context, 'Payment help is ready.'),
            ),
            _ActionRow(
              icon: Icons.directions_car_outlined,
              title: 'Vehicle AutoPay',
              subtitle: 'Manage AutoPay from each vehicle profile',
              onTap: () => _showSnack(context, 'Vehicle help is ready.'),
            ),
          ],
        ),
        const SizedBox(height: 18),
        _InfoPanel(
          title: 'Contact',
          children: [
            _ActionRow(
              icon: Icons.chat_bubble_outline_rounded,
              title: 'Live chat',
              subtitle: 'Talk to ParkIQ support',
              onTap: () => _showSnack(context, 'Support chat is ready.'),
            ),
            _ActionRow(
              icon: Icons.mail_outline_rounded,
              title: 'Email support',
              subtitle: 'support@parkiq.co.ke',
              onTap: () => _showSnack(context, 'Email support is ready.'),
            ),
          ],
        ),
      ],
    );
  }
}

class PrivacyTermsSettingsPage extends StatefulWidget {
  const PrivacyTermsSettingsPage({super.key});

  @override
  State<PrivacyTermsSettingsPage> createState() =>
      _PrivacyTermsSettingsPageState();
}

class _PrivacyTermsSettingsPageState extends State<PrivacyTermsSettingsPage> {
  _LegalSection _section = _LegalSection.privacy;

  @override
  Widget build(BuildContext context) {
    return _SettingsSubPageScaffold(
      title: 'Privacy and terms',
      subtitle: 'Data, payments, and app terms',
      icon: Icons.privacy_tip_outlined,
      footer: _PrimaryActionButton(
        icon: Icons.check_rounded,
        label: 'Done',
        onPressed: () => Navigator.pop(context),
      ),
      children: [
        const _LegalHero(),
        const SizedBox(height: 18),
        _LegalSegmentedControl(
          section: _section,
          onChanged: (section) => setState(() => _section = section),
        ),
        const SizedBox(height: 18),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          child: _section == _LegalSection.privacy
              ? const _PrivacyPolicyContent(key: ValueKey('privacy'))
              : const _TermsPolicyContent(key: ValueKey('terms')),
        ),
        const SizedBox(height: 18),
        _NoticeCard(
          icon: Icons.support_agent_rounded,
          title: 'Questions about your account?',
          body:
              'For privacy requests, payment questions, or account corrections, contact support@parkiq.co.ke.',
        ),
      ],
    );
  }
}

enum _LegalSection { privacy, terms }

class _LegalHero extends StatelessWidget {
  const _LegalHero();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primaryDark,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.shield_outlined,
                  color: AppColors.accent,
                  size: 27,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Legal center',
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
                      'Privacy, payments, and fair use',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        color: Colors.white.withValues(alpha: 0.66),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            'ParkIQ keeps only the details needed to run parking sessions, process wallet payments, and support your account.',
            style: GoogleFonts.poppins(
              color: Colors.white.withValues(alpha: 0.84),
              fontSize: 12,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 16),
          const Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _LegalPill(label: 'Secure account'),
              _LegalPill(label: 'M-Pesa payments'),
              _LegalPill(label: 'Session receipts'),
            ],
          ),
        ],
      ),
    );
  }
}

class _LegalPill extends StatelessWidget {
  final String label;

  const _LegalPill({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(
          color: Colors.white.withValues(alpha: 0.82),
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _LegalSegmentedControl extends StatelessWidget {
  final _LegalSection section;
  final ValueChanged<_LegalSection> onChanged;

  const _LegalSegmentedControl({
    required this.section,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 54,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: _LegalSegmentButton(
              icon: Icons.lock_person_outlined,
              label: 'Privacy',
              selected: section == _LegalSection.privacy,
              onTap: () => onChanged(_LegalSection.privacy),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _LegalSegmentButton(
              icon: Icons.gavel_outlined,
              label: 'Terms',
              selected: section == _LegalSection.terms,
              onTap: () => onChanged(_LegalSection.terms),
            ),
          ),
        ],
      ),
    );
  }
}

class _LegalSegmentButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _LegalSegmentButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primary : Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: selected ? Colors.white : AppColors.textSecondary,
                size: 18,
              ),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    color: selected ? Colors.white : AppColors.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
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

class _PrivacyPolicyContent extends StatelessWidget {
  const _PrivacyPolicyContent({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _InfoPanel(
          title: 'Data we handle',
          children: [
            _LegalDetailRow(
              icon: Icons.person_outline_rounded,
              title: 'Account profile',
              body:
                  'Name, phone number, and optional email help identify your account and support requests.',
            ),
            _LegalDetailRow(
              icon: Icons.directions_car_outlined,
              title: 'Vehicle records',
              body:
                  'Plate numbers and vehicle preferences link parking sessions to the right account.',
            ),
            _LegalDetailRow(
              icon: Icons.account_balance_wallet_outlined,
              title: 'Wallet activity',
              body:
                  'Top-ups, deductions, balance alerts, and M-Pesa references keep payment history accurate.',
            ),
            _LegalDetailRow(
              icon: Icons.local_parking_outlined,
              title: 'Parking sessions',
              body:
                  'Entry time, exit time, car park, tariff, and receipt status help manage each visit.',
            ),
          ],
        ),
        SizedBox(height: 18),
        _InfoPanel(
          title: 'Your controls',
          children: [
            _LegalDetailRow(
              icon: Icons.edit_note_outlined,
              title: 'Update details',
              body:
                  'Correct your profile, payment phone, and vehicle details from Settings.',
            ),
            _LegalDetailRow(
              icon: Icons.notifications_none_rounded,
              title: 'Notification choices',
              body:
                  'Choose whether parking alerts and low balance reminders are active.',
            ),
            _LegalDetailRow(
              icon: Icons.receipt_long_outlined,
              title: 'Receipts and history',
              body:
                  'Review completed sessions and payment receipts from your account history.',
            ),
          ],
        ),
        SizedBox(height: 18),
        _InfoPanel(
          title: 'Sharing and retention',
          children: [
            _LegalDetailRow(
              icon: Icons.payments_outlined,
              title: 'Payment processing',
              body:
                  'Payment details may be shared with M-Pesa or parking operators only to complete transactions.',
            ),
            _LegalDetailRow(
              icon: Icons.history_rounded,
              title: 'Record keeping',
              body:
                  'Session and receipt records are retained for account support, reconciliation, and dispute review.',
            ),
          ],
        ),
      ],
    );
  }
}

class _TermsPolicyContent extends StatelessWidget {
  const _TermsPolicyContent({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _InfoPanel(
          title: 'Using ParkIQ',
          children: [
            _LegalDetailRow(
              icon: Icons.verified_user_outlined,
              title: 'Account responsibility',
              body:
                  'Keep your account details, payment phone, and registered vehicle information current.',
            ),
            _LegalDetailRow(
              icon: Icons.car_rental_outlined,
              title: 'Vehicle accuracy',
              body:
                  'Parking sessions and AutoPay depend on the plate numbers saved in your account.',
            ),
            _LegalDetailRow(
              icon: Icons.bolt_outlined,
              title: 'AutoPay',
              body:
                  'When AutoPay is enabled, eligible exit fees may be deducted from your wallet automatically.',
            ),
            _LegalDetailRow(
              icon: Icons.warning_amber_rounded,
              title: 'Fair use',
              body:
                  'Misuse, false vehicle details, or attempts to avoid parking charges may restrict account access.',
            ),
          ],
        ),
        SizedBox(height: 18),
        _InfoPanel(
          title: 'Payments',
          children: [
            _LegalDetailRow(
              icon: Icons.phone_android_rounded,
              title: 'M-Pesa top-ups',
              body:
                  'Wallet top-ups are confirmed after the M-Pesa request is approved and reconciled.',
            ),
            _LegalDetailRow(
              icon: Icons.account_balance_wallet_outlined,
              title: 'Wallet balance',
              body:
                  'Parking fees, refunds, and adjustments are reflected in your wallet and receipt history.',
            ),
            _LegalDetailRow(
              icon: Icons.report_problem_outlined,
              title: 'Disputes',
              body:
                  'Report incorrect charges with the related receipt or session details for review.',
            ),
          ],
        ),
        SizedBox(height: 18),
        _InfoPanel(
          title: 'Service terms',
          children: [
            _LegalDetailRow(
              icon: Icons.cloud_done_outlined,
              title: 'Availability',
              body:
                  'Parking and payment services may depend on network access, operator systems, and M-Pesa availability.',
            ),
            _LegalDetailRow(
              icon: Icons.privacy_tip_outlined,
              title: 'Policy updates',
              body:
                  'Important privacy or terms changes will be shown in the app before they affect your account.',
            ),
          ],
        ),
      ],
    );
  }
}

class _LegalDetailRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;

  const _LegalDetailRow({
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 15),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _RowIcon(icon),
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
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: GoogleFonts.poppins(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    height: 1.4,
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

class _SettingsSubPageScaffold extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final List<Widget> children;
  final Widget? footer;
  final VoidCallback? onBack;

  const _SettingsSubPageScaffold({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.children,
    this.footer,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: AppColors.pageGrey,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _SubPageHeader(
              title: title,
              subtitle: subtitle,
              icon: icon,
              onBack: onBack ?? () => Navigator.pop(context),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  20,
                  18,
                  20,
                  footer == null ? 30 + bottomPadding : 18,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: children,
                ),
              ),
            ),
            if (footer != null)
              Container(
                width: double.infinity,
                padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + bottomPadding),
                decoration: BoxDecoration(
                  color: AppColors.pageGrey,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 14,
                      offset: const Offset(0, -5),
                    ),
                  ],
                ),
                child: footer,
              ),
          ],
        ),
      ),
    );
  }
}

class _SubPageHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onBack;

  const _SubPageHeader({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
      child: Row(
        children: [
          _HeaderButton(icon: Icons.arrow_back_rounded, onTap: onBack),
          const SizedBox(width: 12),
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.accentLight,
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(icon, color: AppColors.primary, size: 22),
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
                    color: AppColors.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
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
        ],
      ),
    );
  }
}

class _HeaderButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _HeaderButton({
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF3F4F6),
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: SizedBox(
          width: 42,
          height: 42,
          child: Icon(icon, color: AppColors.textPrimary, size: 22),
        ),
      ),
    );
  }
}

class _ProfileHero extends StatelessWidget {
  final String name;
  final String? phoneNumber;
  final double walletBalance;

  const _ProfileHero({
    required this.name,
    required this.phoneNumber,
    required this.walletBalance,
  });

  @override
  Widget build(BuildContext context) {
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
              _initials(name),
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
                  name,
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
                  _formatPhone(phoneNumber),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    color: Colors.white.withValues(alpha: 0.66),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'KES ${_formatAmount(walletBalance)} wallet balance',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    color: Colors.white.withValues(alpha: 0.82),
                    fontSize: 12,
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

class _SecurityHero extends StatelessWidget {
  final bool biometricsEnabled;
  final bool pinRequired;

  const _SecurityHero({
    required this.biometricsEnabled,
    required this.pinRequired,
  });

  @override
  Widget build(BuildContext context) {
    final activeItems = [
      if (pinRequired) 'PIN',
      if (biometricsEnabled) 'Biometrics',
    ];

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
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.security_rounded,
              color: AppColors.accent,
              size: 25,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activeItems.isEmpty
                      ? 'Basic protection'
                      : '${activeItems.join(' + ')} active',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Payment and account safeguards',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    color: Colors.white.withValues(alpha: 0.66),
                    fontSize: 12,
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

class _PreferenceHero extends StatelessWidget {
  final IconData icon;
  final String title;
  final String status;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  const _PreferenceHero({
    required this.icon,
    required this.title,
    required this.status,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.accentLight,
              borderRadius: BorderRadius.circular(17),
            ),
            child: Icon(icon, color: AppColors.primary, size: 25),
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
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  status,
                  maxLines: 2,
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
          _StyledSwitch(value: enabled, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _InfoPanel extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _InfoPanel({
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
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
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 15),
      child: Row(
        children: [
          _RowIcon(icon),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                color: AppColors.textPrimary,
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

class _ActionRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 15, 16, 15),
          child: Row(
            children: [
              _RowIcon(icon),
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
                        color: AppColors.textPrimary,
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
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textMuted,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 15),
      child: Row(
        children: [
          _RowIcon(icon),
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
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  maxLines: 2,
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
          _StyledSwitch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _BulletRow extends StatelessWidget {
  final String text;

  const _BulletRow({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 15),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.poppins(
                color: AppColors.textSecondary,
                fontSize: 12,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InputRow extends StatelessWidget {
  final String label;
  final TextEditingController controller;

  const _InputRow({
    required this.label,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            keyboardType: TextInputType.phone,
            style: GoogleFonts.poppins(
              color: AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xFFF6F7F9),
              hintText: '0712 345 678',
              hintStyle: GoogleFonts.poppins(
                color: AppColors.textMuted,
                fontSize: 14,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 14,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(
                  color: AppColors.primary,
                  width: 1.4,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NoticeCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;

  const _NoticeCard({
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.accentLight,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.mintBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primary, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: GoogleFonts.poppins(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    height: 1.4,
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

class _RowIcon extends StatelessWidget {
  final IconData icon;

  const _RowIcon(this.icon);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: AppColors.accentLight,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(icon, color: AppColors.primary, size: 21),
    );
  }
}

class _StyledSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const _StyledSwitch({
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
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
}

class _PrimaryActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const _PrimaryActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, color: Colors.white, size: 20),
        label: Text(
          label,
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: AppColors.primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}

void _showSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.primaryDark,
      content: Text(
        message,
        style: GoogleFonts.poppins(color: Colors.white),
      ),
    ),
  );
}

String _formatPhone(String? phoneNumber) {
  if (phoneNumber == null || phoneNumber.trim().isEmpty) {
    return 'Not added';
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
