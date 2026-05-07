import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/theme/app_colors.dart';
import '../../widgets/app_widgets.dart';
import '../../widgets/primary_button.dart';
import '../auth/sign_in_screen.dart';
import 'create_account_screen.dart';

class WalkthroughScreen extends StatefulWidget {
  const WalkthroughScreen({super.key});

  @override
  State<WalkthroughScreen> createState() => _WalkthroughScreenState();
}

class _WalkthroughScreenState extends State<WalkthroughScreen> {
  final _controller = PageController();
  int _currentPage = 0;

  static const _steps = [
    _WalkthroughStep(
      icon: LucideIcons.userCheck,
      title: 'Create your ParkIQ profile',
      description:
          'Verify your phone, add your account details, and keep your parking identity ready whenever you arrive.',
      label: 'Account setup',
      detail: 'Phone, name, ID, county',
      accentColor: Color(0xFF2563EB),
    ),
    _WalkthroughStep(
      icon: LucideIcons.car,
      title: 'Connect your vehicle',
      description:
          'Register your plate once so supported parking locations can recognize your car at entry and exit.',
      label: 'Vehicle link',
      detail: 'Plate, type, make, model',
      accentColor: Color(0xFFF59E0B),
    ),
    _WalkthroughStep(
      icon: LucideIcons.walletCards,
      title: 'Park, pay, and move faster',
      description:
          'Use your wallet and AutoPay to handle parking charges without queues, paper tickets, or last-minute searches.',
      label: 'Smart payments',
      detail: 'Wallet, M-Pesa, AutoPay',
      accentColor: Color(0xFF0EA5E9),
    ),
  ];

  bool get _isLastPage => _currentPage == _steps.length - 1;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      body: SafeArea(
        child: Column(
          children: [
            _header(),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _steps.length,
                onPageChanged: (page) => setState(() => _currentPage = page),
                itemBuilder: (context, index) {
                  return _WalkthroughPage(
                    step: _steps[index],
                    pageNumber: index + 1,
                    totalPages: _steps.length,
                  );
                },
              ),
            ),
            _footer(),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 8),
      child: Row(
        children: [
          const ParkIQLogo(size: 44),
          const Spacer(),
          TextButton.icon(
            onPressed: _openSignIn,
            icon: const Icon(LucideIcons.logIn, size: 16),
            label: const Text('Sign in'),
            style: TextButton.styleFrom(
              foregroundColor: context.colors.textSecondary,
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

  Widget _footer() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 10, 24, 24),
      child: Column(
        children: [
          OnboardingStepper(
            currentStep: _currentPage,
            totalSteps: _steps.length,
          ),
          const SizedBox(height: 20),
          PrimaryButton(
            text: _isLastPage ? 'Create Account' : 'Continue',
            icon: _isLastPage ? LucideIcons.userPlus : LucideIcons.arrowRight,
            onPressed: _isLastPage ? _openCreateAccount : _nextPage,
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              onPressed: _openCreateAccount,
              icon: const Icon(LucideIcons.userPlus, size: 16),
              label: Text(_isLastPage ? 'Start from step 1' : 'Create account now'),
              style: TextButton.styleFrom(
                foregroundColor: context.colors.primary,
                textStyle: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _nextPage() {
    _controller.nextPage(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  void _openCreateAccount() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => const CreateAccountScreen(showGuideOnOpen: false),
      ),
    );
  }

  void _openSignIn() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const SignInScreen()),
    );
  }
}

class _WalkthroughPage extends StatelessWidget {
  final _WalkthroughStep step;
  final int pageNumber;
  final int totalPages;

  const _WalkthroughPage({
    required this.step,
    required this.pageNumber,
    required this.totalPages,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _WalkthroughVisual(step: step)
                    .animate()
                    .fadeIn(duration: 450.ms)
                    .slideY(
                      begin: 0.05,
                      end: 0,
                      duration: 450.ms,
                      curve: Curves.easeOut,
                    ),
                const SizedBox(height: 28),
                Text(
                  'Step $pageNumber of $totalPages',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: step.accentColor,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  step.title,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 27,
                    height: 1.12,
                    fontWeight: FontWeight.w800,
                    color: context.colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  step.description,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    height: 1.45,
                    color: context.colors.textSecondary,
                  ),
                ),
                const SizedBox(height: 22),
                _ReadinessStrip(step: step),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _WalkthroughVisual extends StatelessWidget {
  final _WalkthroughStep step;

  const _WalkthroughVisual({required this.step});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final height = (constraints.maxWidth * 0.88).clamp(260.0, 340.0);

        return Container(
          height: height,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                context.colors.primaryDeep,
                context.colors.primaryDark,
                step.accentColor.withValues(alpha: 0.84),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: context.colors.primaryDeep.withValues(alpha: 0.22),
                blurRadius: 28,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                left: 22,
                top: 22,
                child: _glassBadge(
                  context,
                  icon: step.icon,
                  label: step.label,
                ),
              ),
              Positioned(
                right: 24,
                top: 26,
                child: _signalDots(),
              ),
              Center(
                child: Container(
                  width: 168,
                  height: height - 62,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: context.colors.surface,
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.36),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.18),
                        blurRadius: 24,
                        offset: const Offset(0, 16),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: context.colors.accentLight,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              step.icon,
                              color: context.colors.primary,
                              size: 17,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'ParkIQ',
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: context.colors.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _phoneTile(
                        context,
                        icon: LucideIcons.shieldCheck,
                        title: 'Verified',
                        subtitle: 'Secure setup',
                      ),
                      const SizedBox(height: 10),
                      _phoneTile(
                        context,
                        icon: LucideIcons.car,
                        title: 'KBZ 123A',
                        subtitle: 'Plate ready',
                      ),
                      const Spacer(),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 11,
                        ),
                        decoration: BoxDecoration(
                          color: context.colors.primaryDeep,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              LucideIcons.sparkles,
                              color: context.colors.accent,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Ready to park',
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: 24,
                bottom: 24,
                child: _miniPanel(
                  context,
                  icon: LucideIcons.clock3,
                  label: 'No queue',
                ),
              ),
              Positioned(
                right: 24,
                bottom: 24,
                child: _miniPanel(
                  context,
                  icon: LucideIcons.receipt,
                  label: 'Clear fees',
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _glassBadge(
    BuildContext context, {
    required IconData icon,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 15),
          const SizedBox(width: 7),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _signalDots() {
    return Row(
      children: List.generate(3, (index) {
        return Container(
          width: 7,
          height: 7,
          margin: const EdgeInsets.only(left: 5),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: index == 2 ? 0.95 : 0.46),
            borderRadius: BorderRadius.circular(999),
          ),
        );
      }),
    );
  }

  Widget _phoneTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: context.colors.pageGrey,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.colors.border),
      ),
      child: Row(
        children: [
          Icon(icon, size: 17, color: context.colors.primary),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: context.colors.textPrimary,
                  ),
                ),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    color: context.colors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniPanel(
    BuildContext context, {
    required IconData icon,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 14),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReadinessStrip extends StatelessWidget {
  final _WalkthroughStep step;

  const _ReadinessStrip({required this.step});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
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
              color: step.accentColor.withValues(alpha: 0.11),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(step.icon, color: step.accentColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  step.label,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: context.colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  step.detail,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: context.colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            LucideIcons.checkCircle2,
            size: 20,
            color: context.colors.success,
          ),
        ],
      ),
    );
  }
}

class _WalkthroughStep {
  final IconData icon;
  final String title;
  final String description;
  final String label;
  final String detail;
  final Color accentColor;

  const _WalkthroughStep({
    required this.icon,
    required this.title,
    required this.description,
    required this.label,
    required this.detail,
    required this.accentColor,
  });
}
