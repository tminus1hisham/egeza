import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_colors.dart';
import '../../widgets/app_widgets.dart';
import 'settings_detail_screen.dart';

class HelpCenterScreen extends StatelessWidget {
  const HelpCenterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _HelpScaffold(
      children: [
        const _HelpHero(
          icon: Icons.help_outline_rounded,
          title: 'Help center',
          body: 'Choose a topic for practical steps based on how egesha works.',
        ),
        const SizedBox(height: 22),
        _HelpSection(
          title: 'Common questions',
          children: [
            for (final article in _helpArticles)
              _HelpActionTile(
                icon: article.icon,
                title: article.title,
                subtitle: article.subtitle,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => _HelpArticlePage(article: article),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 18),
        _HelpSection(
          title: 'Tenancy',
          children: [
            _HelpActionTile(
              icon: Icons.domain_outlined,
              title: 'Request tenancy',
              subtitle: 'Apply for a dedicated parking space',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TenancySettingsPage()),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        _HelpSection(
          title: 'Contact',
          children: [
            _HelpActionTile(
              icon: Icons.support_agent_rounded,
              title: 'Contact support',
              subtitle: 'What to include in a support request',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const _SupportPage()),
              ),
            ),
            _HelpActionTile(
              icon: Icons.mail_outline_rounded,
              title: 'Email support',
              subtitle: _supportEmail,
              onTap: () => _launchSupportEmail(context),
            ),
          ],
        ),
      ],
    );
  }
}

class _HelpArticlePage extends StatelessWidget {
  final _HelpArticle article;

  const _HelpArticlePage({required this.article});

  @override
  Widget build(BuildContext context) {
    return _HelpScaffold(
      footer: _HelpPrimaryButton(
        icon: Icons.mail_outline_rounded,
        label: 'Email support',
        onPressed: () => _launchSupportEmail(context, subject: article.title),
      ),
      children: [
        _HelpHero(
          icon: article.icon,
          title: article.title,
          body: article.subtitle,
        ),
        const SizedBox(height: 18),
        _HelpNotice(
          icon: Icons.lightbulb_outline_rounded,
          title: 'Quick answer',
          body: article.summary,
        ),
        const SizedBox(height: 18),
        _HelpSection(
          title: 'What to do',
          children: [
            for (var index = 0; index < article.steps.length; index++)
              _HelpStepTile(
                number: index + 1,
                title: article.steps[index].title,
                body: article.steps[index].body,
              ),
          ],
        ),
        const SizedBox(height: 18),
        _HelpNotice(
          icon: Icons.support_agent_rounded,
          title: 'Still need help?',
          body: article.supportNote,
        ),
      ],
    );
  }
}

class _SupportPage extends StatelessWidget {
  const _SupportPage();

  @override
  Widget build(BuildContext context) {
    return _HelpScaffold(
      footer: _HelpPrimaryButton(
        icon: Icons.mail_outline_rounded,
        label: 'Compose email',
        onPressed: () => _launchSupportEmail(context),
      ),
      children: [
        const _HelpHero(
          icon: Icons.support_agent_rounded,
          title: 'Contact support',
          body: 'Get help with a parking, payment, or account issue.',
        ),
        const SizedBox(height: 18),
        const _HelpNotice(
          icon: Icons.mail_outline_rounded,
          title: 'Email support',
          body:
              'Send your request to $_supportEmail. The email template prompts you for the details needed to investigate.',
        ),
        const SizedBox(height: 18),
        const _HelpSection(
          title: 'Include these details',
          children: [
            _HelpBulletTile(text: 'Your registered plate number.'),
            _HelpBulletTile(
              text: 'The parking location, date, and approximate time.',
            ),
            _HelpBulletTile(
              text: 'The M-Pesa or payment reference, when relevant.',
            ),
            _HelpBulletTile(
              text: 'What you expected and what happened instead.',
            ),
          ],
        ),
        const SizedBox(height: 18),
        _HelpSection(
          title: 'Support channel',
          children: [
            _HelpActionTile(
              icon: Icons.mail_outline_rounded,
              title: _supportEmail,
              subtitle: 'Open your email app',
              onTap: () => _launchSupportEmail(context),
            ),
          ],
        ),
      ],
    );
  }
}

class _HelpScaffold extends StatelessWidget {
  final List<Widget> children;
  final Widget? footer;

  const _HelpScaffold({required this.children, this.footer});

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.paddingOf(context).bottom;

    return AdaptiveStatusBar(
      child: Scaffold(
        backgroundColor: context.colors.pageGrey,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    20,
                    22,
                    20,
                    footer == null ? 30 + bottomPadding : 18,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const PageBackButton(),
                      const SizedBox(height: 12),
                      ...children,
                    ],
                  ),
                ),
              ),
              if (footer != null)
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + bottomPadding),
                  decoration: BoxDecoration(
                    color: context.colors.pageGrey,
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
      ),
    );
  }
}

class _HelpHero extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;

  const _HelpHero({
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.colors.primaryDark,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: context.colors.accent, size: 25),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: GoogleFonts.poppins(
                    color: Colors.white.withValues(alpha: 0.72),
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

class _HelpSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _HelpSection({required this.title, required this.children});

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
          ),
          child: Column(
            children: [
              for (var index = 0; index < children.length; index++) ...[
                children[index],
                if (index != children.length - 1)
                  Divider(height: 1, color: context.colors.divider, indent: 74),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _HelpActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _HelpActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.colors.surface,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 15, 16, 15),
          child: Row(
            children: [
              _HelpIcon(icon: icon),
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
                        color: context.colors.textPrimary,
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
                        color: context.colors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
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
}

class _HelpStepTile extends StatelessWidget {
  final int number;
  final String title;
  final String body;

  const _HelpStepTile({
    required this.number,
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
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: context.colors.accentLight,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Text(
              '$number',
              style: GoogleFonts.poppins(
                color: context.colors.primary,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    color: context.colors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: GoogleFonts.poppins(
                    color: context.colors.textSecondary,
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

class _HelpBulletTile extends StatelessWidget {
  final String text;

  const _HelpBulletTile({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 15),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(top: 5),
            decoration: BoxDecoration(
              color: context.colors.primary,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.poppins(
                color: context.colors.textSecondary,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HelpNotice extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;

  const _HelpNotice({
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
        color: context.colors.accentLight,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.colors.mintBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: context.colors.primary, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    color: context.colors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: GoogleFonts.poppins(
                    color: context.colors.textSecondary,
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

class _HelpPrimaryButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const _HelpPrimaryButton({
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
          backgroundColor: context.colors.primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}

class _HelpIcon extends StatelessWidget {
  final IconData icon;

  const _HelpIcon({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: context.colors.accentLight,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(icon, color: context.colors.primary, size: 21),
    );
  }
}

class _HelpArticle {
  final IconData icon;
  final String title;
  final String subtitle;
  final String summary;
  final List<_HelpStep> steps;
  final String supportNote;

  const _HelpArticle({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.summary,
    required this.steps,
    required this.supportNote,
  });
}

class _HelpStep {
  final String title;
  final String body;

  const _HelpStep({required this.title, required this.body});
}

const _supportEmail = 'support@egesha.co.ke';

const _helpArticles = <_HelpArticle>[
  _HelpArticle(
    icon: Icons.local_parking_outlined,
    title: 'Parking session not showing',
    subtitle: 'Find a missing or delayed parking session',
    summary:
        'Pay parking searches for an active session using the vehicle plate. You do not need to choose a parking location.',
    steps: [
      _HelpStep(
        title: 'Enter the vehicle plate',
        body:
            'Open Pay parking and enter the plate letters and numbers, or select a vehicle already saved to your account.',
      ),
      _HelpStep(
        title: 'Find the active session',
        body:
            'Tap Find parking session. The app looks for an active visit linked to that plate.',
      ),
      _HelpStep(
        title: 'Check History after payment',
        body:
            'If the visit was already paid, refresh History. A completed session is no longer returned as active.',
      ),
    ],
    supportNote:
        'Email us with the plate number, parking location, and approximate entry time so the session can be traced.',
  ),
  _HelpArticle(
    icon: Icons.payments_outlined,
    title: 'Payment failed or is pending',
    subtitle: 'Check an M-Pesa payment and session status',
    summary:
        'A parking payment completes only after the M-Pesa prompt is approved and the app confirms the result.',
    steps: [
      _HelpStep(
        title: 'Check the M-Pesa number',
        body:
            'Use a valid Kenyan M-Pesa number beginning with 07 or 01, then approve the prompt on that phone.',
      ),
      _HelpStep(
        title: 'Wait for confirmation',
        body:
            'Failed, cancelled, or timed-out payments leave the session active so it can be found and retried.',
      ),
      _HelpStep(
        title: 'Avoid duplicate payments',
        body:
            'If M-Pesa was charged, refresh History before retrying. History should show the completed session and payment record.',
      ),
    ],
    supportNote:
        'If you were charged but the payment is missing, email the M-Pesa reference, plate, location, and payment time.',
  ),
  _HelpArticle(
    icon: Icons.directions_car_outlined,
    title: 'Vehicle AutoPay',
    subtitle: 'Turn automatic exit payments on or off',
    summary:
        'AutoPay is set separately for each vehicle. At supported exits, it deducts the fee from your wallet when turned on.',
    steps: [
      _HelpStep(
        title: 'Open the vehicle profile',
        body:
            'Go to Vehicles and select the plate whose AutoPay setting you want to change.',
      ),
      _HelpStep(
        title: 'Change the AutoPay switch',
        body:
            'Turn AutoPay on for automatic exit processing, or off when you prefer to pay manually.',
      ),
      _HelpStep(
        title: 'Keep the wallet funded',
        body:
            'Check your wallet before parking so an automatic charge can complete when you leave.',
      ),
    ],
    supportNote:
        'If the setting will not update, email the registered plate number and the error shown in the app.',
  ),
  _HelpArticle(
    icon: Icons.account_balance_wallet_outlined,
    title: 'Wallet top-up not showing',
    subtitle: 'Refresh a completed M-Pesa top-up',
    summary:
        'Wallet top-ups use an M-Pesa prompt. The balance updates after M-Pesa confirms the transaction.',
    steps: [
      _HelpStep(
        title: 'Confirm the prompt',
        body:
            'Check that the prompt was approved on the M-Pesa number entered in the Wallet screen.',
      ),
      _HelpStep(
        title: 'Refresh the wallet',
        body:
            'Pull down on the Wallet screen to reload your balance and recent activity.',
      ),
      _HelpStep(
        title: 'Check M-Pesa activity',
        body:
            'If there is no completed M-Pesa transaction, send a new prompt. Do not retry after a confirmed charge until you refresh.',
      ),
    ],
    supportNote:
        'For a confirmed charge that is still missing, email the M-Pesa reference, amount, phone number, and time.',
  ),
  _HelpArticle(
    icon: Icons.receipt_long_outlined,
    title: 'Receipts and parking history',
    subtitle: 'Find completed sessions and payment details',
    summary:
        'The Dashboard shows your latest parking sessions, while History shows recent session and payment records.',
    steps: [
      _HelpStep(
        title: 'Open History',
        body:
            'Use History from the main navigation to review completed and active parking sessions.',
      ),
      _HelpStep(
        title: 'Match the plate and date',
        body:
            'Use the plate number, parking location, and session date to identify the correct record.',
      ),
      _HelpStep(
        title: 'Refresh recent records',
        body:
            'Pull down on History after payment to load the latest session and payment status.',
      ),
    ],
    supportNote:
        'If a completed payment is missing, email the plate, location, date, and payment reference.',
  ),
];

Future<void> _launchSupportEmail(
  BuildContext context, {
  String? subject,
}) async {
  final uri = Uri(
    scheme: 'mailto',
    path: _supportEmail,
    queryParameters: {
      'subject': 'egesha support: ${subject ?? 'Help request'}',
      'body': '''Hello egesha support,

Please help me with the issue below.

Plate number:
Parking location:
Date and time:
M-Pesa or payment reference (if applicable):

What happened:
''',
    },
  );

  try {
    if (await launchUrl(uri)) return;
  } catch (_) {
    // The copy fallback below keeps the support address usable.
  }

  await Clipboard.setData(const ClipboardData(text: _supportEmail));
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: context.colors.primaryDark,
        content: Text(
          'No email app found. $_supportEmail was copied.',
          style: GoogleFonts.poppins(color: Colors.white),
        ),
      ),
    );
  }
}
