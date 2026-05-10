import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/theme/app_colors.dart';
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
      title: 'Create your egesha profile',
      description:
          'Verify your phone, add your account details, and keep your parking identity ready whenever you arrive.',
      label: 'Account setup',
      detail: 'Phone, name, ID, county',
      visualType: _WalkthroughVisualType.profile,
      buttonColor: Color(0xFF42DCC4),
      buttonForeground: AppColors.primaryDeep,
    ),
    _WalkthroughStep(
      icon: LucideIcons.car,
      title: 'Connect your vehicle',
      description:
          'Register your plate once so supported parking locations can recognize your car at entry and exit.',
      label: 'Vehicle link',
      detail: 'Plate, type, make, model',
      visualType: _WalkthroughVisualType.vehicle,
      buttonColor: AppColors.primaryDeep,
      buttonForeground: Colors.white,
    ),
    _WalkthroughStep(
      icon: LucideIcons.walletCards,
      title: 'Park, pay, and move faster',
      description:
          'Use your wallet and AutoPay to handle parking charges without queues, paper tickets, or last-minute searches.',
      label: 'Smart payments',
      detail: 'Wallet, M-Pesa, AutoPay',
      visualType: _WalkthroughVisualType.payment,
      buttonColor: Color(0xFF0BAE9B),
      buttonForeground: Colors.white,
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
    final step = _steps[_currentPage];

    return Scaffold(
      backgroundColor: context.colors.background,
      body: SafeArea(
        child: Column(
          children: [
            // _header(),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _steps.length,
                onPageChanged: (page) => setState(() => _currentPage = page),
                itemBuilder: (context, index) {
                  return _WalkthroughPage(
                    key: ValueKey(index),
                    step: _steps[index],
                    pageNumber: index + 1,
                    totalPages: _steps.length,
                  );
                },
              ),
            ),
            _footer(step),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
      child: Row(
        children: [
          const Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: _WalkthroughWordmark(),
            ),
          ),
          const SizedBox(width: 16),
          TextButton(
            onPressed: _openSignIn,
            style: TextButton.styleFrom(
              foregroundColor: context.colors.primaryDeep,
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              textStyle: GoogleFonts.poppins(
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
            child: const Text('Sign In'),
          ),
        ],
      ),
    );
  }

  Widget _footer(_WalkthroughStep step) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 10, 24, 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _WalkthroughActionButton(
            text: _isLastPage ? 'Create Account' : 'Continue',
            icon: _isLastPage ? LucideIcons.userPlus : LucideIcons.arrowRight,
            iconAfterText: !_isLastPage,
            backgroundColor: step.buttonColor,
            foregroundColor: step.buttonForeground,
            onPressed: _isLastPage ? _openCreateAccount : _nextPage,
          ),
          const SizedBox(height: 12),
          _SecondaryWalkthroughAction(
            label: _isLastPage ? 'Start from step 1' : 'Create account now',
            icon: _isLastPage ? LucideIcons.refreshCcw : null,
            color: _isLastPage
                ? context.colors.primaryDeep
                : context.colors.textSecondary,
            onPressed: _isLastPage ? _restartWalkthrough : _openCreateAccount,
          ),
        ],
      ),
    );
  }

  void _nextPage() {
    _controller.nextPage(
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeOutCubic,
    );
  }

  void _restartWalkthrough() {
    _controller.animateToPage(
      0,
      duration: const Duration(milliseconds: 360),
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

class _WalkthroughWordmark extends StatelessWidget {
  const _WalkthroughWordmark();

  @override
  Widget build(BuildContext context) {
    return Row(
      // mainAxisSize: MainAxisSize.min,
      // children: [
      //   Icon(
      //     Icons.local_parking_rounded,
      //     color: context.colors.primaryDeep,
      //     size: 28,
      //   ),
        // const SizedBox(width: 10),
        // Text(
        //   'Egesha',
        //   style: GoogleFonts.poppins(
        //     color: context.colors.primaryDeep,
        //     fontSize: 32,
        //     height: 1,
        //     fontWeight: FontWeight.w700,
        //   ),
        // ),
      // ],
    );
  }
}

class _WalkthroughPage extends StatelessWidget {
  final _WalkthroughStep step;
  final int pageNumber;
  final int totalPages;

  const _WalkthroughPage({
    super.key,
    required this.step,
    required this.pageNumber,
    required this.totalPages,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxHeight < 610;
        if (step.visualType == _WalkthroughVisualType.payment) {
          return _buildPaymentLayout(context, constraints, isCompact);
        }
        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(24, isCompact ? 8 : 14, 24, 18),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _SegmentedProgress(
                  currentStep: pageNumber,
                  totalSteps: totalPages,
                ),
                SizedBox(height: isCompact ? 22 : 30),
                Text(
                  step.title,
                  style: GoogleFonts.poppins(
                    fontSize: 28,
                    height: 1.16,
                    fontWeight: FontWeight.w700,
                    color: context.colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  step.description,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    height: 1.45,
                    fontWeight: FontWeight.w400,
                    color: context.colors.textSecondary,
                  ),
                ),
                SizedBox(height: isCompact ? 22 : 28),
                _WalkthroughVisual(step: step, compact: isCompact)
                    .animate()
                    .fadeIn(duration: 380.ms)
                    .slideY(
                      begin: 0.04,
                      end: 0,
                      duration: 380.ms,
                      curve: Curves.easeOutCubic,
                    ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPaymentLayout(
    BuildContext context,
    BoxConstraints constraints,
    bool isCompact,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: 46,
          child: _PaymentHeroWithProgress(
            step: step,
            compact: isCompact,
            pageNumber: pageNumber,
            totalPages: totalPages,
          )
              .animate()
              .fadeIn(duration: 380.ms)
              .slideY(
                begin: 0.04,
                end: 0,
                duration: 380.ms,
                curve: Curves.easeOutCubic,
              ),
        ),
        Expanded(
          flex: 54,
          child: Padding(
            padding: EdgeInsets.fromLTRB(24, isCompact ? 14 : 18, 24, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  step.title,
                  style: GoogleFonts.poppins(
                    fontSize: isCompact ? 22 : 26,
                    height: 1.16,
                    fontWeight: FontWeight.w700,
                    color: context.colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  step.description,
                  style: GoogleFonts.poppins(
                    fontSize: isCompact ? 13 : 14,
                    height: 1.4,
                    fontWeight: FontWeight.w400,
                    color: context.colors.textSecondary,
                  ),
                ),
                const Spacer(),
                _PaymentFeatureStrip(step: step),
                SizedBox(height: isCompact ? 10 : 12),
                Row(
                  children: [
                    const Expanded(child: _MiniPaymentPreview()),
                    const SizedBox(width: 14),
                    Expanded(child: _ZeroQueueTile(compact: isCompact)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SegmentedProgress extends StatelessWidget {
  final int currentStep;
  final int totalSteps;

  const _SegmentedProgress({
    required this.currentStep,
    required this.totalSteps,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Step $currentStep of $totalSteps',
          style: GoogleFonts.poppins(
            fontSize: 13,
            height: 1.1,
            fontWeight: FontWeight.w700,
            color: context.colors.textSecondary,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: List.generate(totalSteps, (index) {
            final isFilled = index < currentStep;
            return Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 260),
                height: 6,
                margin: EdgeInsets.only(right: index == totalSteps - 1 ? 0 : 10),
                decoration: BoxDecoration(
                  color: isFilled
                      ? context.colors.primaryDeep
                      : context.colors.border.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}

class _WalkthroughVisual extends StatelessWidget {
  final _WalkthroughStep step;
  final bool compact;

  const _WalkthroughVisual({required this.step, required this.compact});

  @override
  Widget build(BuildContext context) {
    switch (step.visualType) {
      case _WalkthroughVisualType.profile:
        return _ProfileVisual(step: step, compact: compact);
      case _WalkthroughVisualType.vehicle:
        return _VehicleVisual(compact: compact);
      case _WalkthroughVisualType.payment:
        return _PaymentVisual(step: step, compact: compact);
    }
  }
}

class _ProfileVisual extends StatelessWidget {
  final _WalkthroughStep step;
  final bool compact;

  const _ProfileVisual({required this.step, required this.compact});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _ProfileIconHero(compact: compact),
        SizedBox(height: compact ? 24 : 32),
        _ProfileStepsCard(),
      ],
    );
  }
}

class _ProfileIconHero extends StatelessWidget {
  final bool compact;

  const _ProfileIconHero({required this.compact});

  @override
  Widget build(BuildContext context) {
    final size = compact ? 120.0 : 148.0;
    return Center(
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF62EFD2).withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
            ),
            Container(
              width: size * 0.64,
              height: size * 0.64,
              decoration: BoxDecoration(
                color: const Color(0xFF62EFD2).withValues(alpha: 0.20),
                shape: BoxShape.circle,
              ),
            ),
            Icon(
              LucideIcons.userCheck,
              size: size * 0.30,
              color: context.colors.primaryDeep,
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileStepsCard extends StatelessWidget {
  const _ProfileStepsCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.colors.border),
      ),
      child: Column(
        children: [
          _ProfileStepRow(
            icon: LucideIcons.phone,
            label: 'Phone verified',
            done: true,
          ),
          const SizedBox(height: 14),
          _ProfileStepRow(
            icon: LucideIcons.user,
            label: 'Personal details',
            done: false,
          ),
          const SizedBox(height: 14),
          _ProfileStepRow(
            icon: LucideIcons.creditCard,
            label: 'ID & county',
            done: false,
          ),
        ],
      ),
    );
  }
}

class _ProfileStepRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool done;

  const _ProfileStepRow({
    required this.icon,
    required this.label,
    required this.done,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: done
                ? const Color(0xFF62EFD2).withValues(alpha: 0.18)
                : context.colors.pageGrey,
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(
            icon,
            size: 18,
            color: done ? context.colors.primaryDeep : context.colors.textMuted,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: done
                  ? context.colors.textPrimary
                  : context.colors.textSecondary,
            ),
          ),
        ),
        if (done)
          const Icon(
            LucideIcons.checkCircle2,
            size: 18,
            color: Color(0xFF27D8C0),
          )
        else
          Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: context.colors.border,
                width: 1.5,
              ),
            ),
          ),
      ],
    );
  }
}

class _VehicleVisual extends StatelessWidget {
  final bool compact;

  const _VehicleVisual({required this.compact});

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      padding: EdgeInsets.all(compact ? 16 : 22),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: context.colors.primaryDeep.withValues(alpha: 0.055),
            blurRadius: 20,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -96,
            top: -110,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                color: context.colors.accentLight.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _VehicleField(
                label: 'License Plate',
                value: 'XYZ 9876',
                icon: LucideIcons.checkCircle2,
                isLarge: true,
              ),
              SizedBox(height: compact ? 14 : 18),
              Row(
                children: const [
                  Expanded(
                    child: _VehicleField(label: 'Make', value: 'e.g. Toyota'),
                  ),
                  SizedBox(width: 14),
                  Expanded(
                    child: _VehicleField(label: 'Model', value: 'e.g. Camry'),
                  ),
                ],
              ),
              SizedBox(height: compact ? 14 : 18),
              const _VehicleField(
                label: 'Vehicle Type',
                value: 'Select type',
                icon: LucideIcons.car,
                isLarge: true,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _VehicleField extends StatelessWidget {
  final String label;
  final String value;
  final IconData? icon;
  final bool isLarge;

  const _VehicleField({
    required this.label,
    required this.value,
    this.icon,
    this.isLarge = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: context.colors.textSecondary,
          ),
        ),
        const SizedBox(height: 7),
        Container(
          height: isLarge ? 60 : 58,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          decoration: BoxDecoration(
            color: context.colors.pageGrey.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: isLarge ? 18 : 16,
                    fontWeight: FontWeight.w400,
                    color: value.startsWith('e.g.')
                        ? const Color(0xFF6B7280)
                        : context.colors.textPrimary,
                  ),
                ),
              ),
              if (icon != null) ...[
                const SizedBox(width: 12),
                Icon(icon, size: 23, color: context.colors.primaryDeep),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _PaymentVisual extends StatelessWidget {
  final _WalkthroughStep step;
  final bool compact;

  const _PaymentVisual({required this.step, required this.compact});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _PaymentHero(step: step, compact: compact),
        SizedBox(height: compact ? 16 : 22),
        Row(
          children: [
            const Expanded(child: _MiniPaymentPreview()),
            const SizedBox(width: 16),
            Expanded(child: _ZeroQueueTile(compact: compact)),
          ],
        ),
      ],
    );
  }
}

class _PaymentHero extends StatelessWidget {
  final _WalkthroughStep step;
  final bool compact;

  const _PaymentHero({required this.step, required this.compact});

  @override
  Widget build(BuildContext context) {
    final height = compact ? 156.0 : 180.0;

    return SizedBox(
      height: height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: Opacity(
              opacity: 0.62,
              child: _PaymentBackdrop(height: compact ? 112 : 130),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _PaymentFeatureStrip(step: step),
          ),
        ],
      ),
    );
  }
}

class _PaymentBackdrop extends StatelessWidget {
  final double height;

  const _PaymentBackdrop({required this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            context.colors.primaryDeep,
            const Color(0xFF12656D),
            context.colors.plateYellow.withValues(alpha: 0.78),
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(31),
      ),
      child: Stack(
        children: [
          Positioned(
            top: 20,
            left: 48,
            right: 48,
            child: _ReadyToParkPill(
              backgroundColor: context.colors.primaryDeep.withValues(
                alpha: 0.88,
              ),
            ),
          ),
          Positioned(
            left: 28,
            bottom: 22,
            child: _SoftBadge(
              icon: LucideIcons.clock3,
              label: 'No queues',
            ),
          ),
          Positioned(
            right: 28,
            bottom: 22,
            child: _SoftBadge(
              icon: LucideIcons.receipt,
              label: 'Clear fees',
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentFeatureStrip extends StatelessWidget {
  final _WalkthroughStep step;

  const _PaymentFeatureStrip({required this.step});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: const Color(0xFF62EFD2),
              borderRadius: BorderRadius.circular(17),
            ),
            child: Icon(
              step.icon,
              color: context.colors.primaryDeep,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  step.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    height: 1.1,
                    fontWeight: FontWeight.w700,
                    color: context.colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  step.detail,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: context.colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: context.colors.primaryDeep,
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Icon(LucideIcons.check, color: Colors.white, size: 21),
          ),
        ],
      ),
    );
  }
}

class _MiniPaymentPreview extends StatelessWidget {
  const _MiniPaymentPreview();

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1.62,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.065),
              blurRadius: 14,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Stack(
          children: [
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primaryDeep,
                      Color(0xFF12656D),
                      Color(0xFF2563EB),
                    ],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                ),
              ),
            ),
            Positioned(
              top: 14,
              left: 18,
              right: 18,
              child: _ReadyToParkPill(
                backgroundColor: context.colors.primaryDeep,
                compact: true,
              ),
            ),
            Positioned(
              left: 14,
              right: 14,
              bottom: 12,
              child: Text(
                'Seamless profile',
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  height: 0.96,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ZeroQueueTile extends StatelessWidget {
  final bool compact;

  const _ZeroQueueTile({required this.compact});

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1.62,
      child: Container(
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.colors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.035),
              blurRadius: 14,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              LucideIcons.zap,
              color: context.colors.primary,
              size: compact ? 25 : 29,
            ),
            const SizedBox(height: 10),
            Text(
              'Zero\nQueues',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: compact ? 14 : 16,
                height: 1.25,
                fontWeight: FontWeight.w500,
                color: context.colors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaymentHeroWithProgress extends StatelessWidget {
  final _WalkthroughStep step;
  final bool compact;
  final int pageNumber;
  final int totalPages;

  const _PaymentHeroWithProgress({
    required this.step,
    required this.compact,
    required this.pageNumber,
    required this.totalPages,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: _PaymentPreviewBackdrop(step: step),
        ),
        Positioned(
          bottom: 18,
          left: 24,
          child: _CompactStepPill(
            pageNumber: pageNumber,
            totalPages: totalPages,
          ),
        ),
      ],
    );
  }
}

class _PaymentPreviewBackdrop extends StatelessWidget {
  final _WalkthroughStep step;

  const _PaymentPreviewBackdrop({required this.step});

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            context.colors.primaryDeep,
            const Color(0xFF0D5C54),
            context.colors.plateYellow.withValues(alpha: 0.78),
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
      ),
      child: Stack(
        clipBehavior: Clip.antiAlias,
        children: [
          // Decorative glow top-right
          Positioned(
            top: -50,
            right: -50,
            child: Container(
              width: 190,
              height: 190,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.07),
                shape: BoxShape.circle,
              ),
            ),
          ),
          // Decorative glow bottom-left
          Positioned(
            bottom: -60,
            left: -30,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                shape: BoxShape.circle,
              ),
            ),
          ),
          // Flexible column layout for main content
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 22, 24, 50),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: _ReadyToParkPill(
                      backgroundColor: context.colors.primaryDeep.withValues(
                        alpha: 0.88,
                      ),
                    ),
                  ),
                  const Spacer(),
                  const _PaymentFloatingCard(),
                  const Spacer(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _SoftBadge(
                        icon: LucideIcons.clock3,
                        label: 'No queues',
                      ),
                      _SoftBadge(
                        icon: LucideIcons.receipt,
                        label: 'Clear fees',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          // Bottom fade
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    context.colors.background.withValues(alpha: 0.22),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentFloatingCard extends StatelessWidget {
  const _PaymentFloatingCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: const Color(0xFF62EFD2),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              LucideIcons.walletCards,
              color: AppColors.primaryDeep,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AutoPay Active',
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    height: 1.1,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Wallet · M-Pesa',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withValues(alpha: 0.72),
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Icon(
              LucideIcons.check,
              color: Colors.white,
              size: 17,
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactStepPill extends StatelessWidget {
  final int pageNumber;
  final int totalPages;

  const _CompactStepPill({
    required this.pageNumber,
    required this.totalPages,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Step $pageNumber of $totalPages',
            style: GoogleFonts.poppins(
              fontSize: 12,
              height: 1,
              fontWeight: FontWeight.w700,
              color: context.colors.textSecondary,
            ),
          ),
          const SizedBox(width: 10),
          ...List.generate(totalPages, (index) {
            final isActive = index == pageNumber - 1;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 260),
              width: isActive ? 18 : 6,
              height: 6,
              margin: EdgeInsets.only(left: index == 0 ? 0 : 4),
              decoration: BoxDecoration(
                color: isActive
                    ? context.colors.primaryDeep
                    : context.colors.border.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(999),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _ReadyToParkPill extends StatelessWidget {
  final Color backgroundColor;
  final bool compact;

  const _ReadyToParkPill({
    required this.backgroundColor,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 9 : 15,
        vertical: compact ? 7 : 9,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            LucideIcons.sparkles,
            color: const Color(0xFF62EFD2),
            size: compact ? 12 : 14,
          ),
          SizedBox(width: compact ? 6 : 8),
          Flexible(
            child: Text(
              'Ready to park',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                fontSize: compact ? 9 : 11,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SoftBadge extends StatelessWidget {
  final IconData icon;
  final String label;

  const _SoftBadge({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 12),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _WalkthroughActionButton extends StatelessWidget {
  final String text;
  final IconData icon;
  final bool iconAfterText;
  final Color backgroundColor;
  final Color foregroundColor;
  final VoidCallback onPressed;

  const _WalkthroughActionButton({
    required this.text,
    required this.icon,
    required this.iconAfterText,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(999);
    final iconWidget = Icon(icon, color: foregroundColor, size: 22);
    final textWidget = Flexible(
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.poppins(
          fontSize: 18,
          letterSpacing: 0,
          height: 1,
          fontWeight: FontWeight.w700,
          color: foregroundColor,
        ),
      ),
    );

    return SizedBox(
      height: 58,
      width: double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: radius,
          boxShadow: [
            BoxShadow(
              color: backgroundColor.withValues(alpha: 0.18),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            foregroundColor: foregroundColor,
            shadowColor: Colors.transparent,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 22),
            shape: RoundedRectangleBorder(borderRadius: radius),
          ).copyWith(
            overlayColor: WidgetStatePropertyAll(
              foregroundColor.withValues(alpha: 0.08),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: iconAfterText
                ? [
                    textWidget,
                    const SizedBox(width: 12),
                    iconWidget,
                  ]
                : [
                    iconWidget,
                    const SizedBox(width: 10),
                    textWidget,
                  ],
          ),
        ),
      ),
    );
  }
}

class _SecondaryWalkthroughAction extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color color;
  final VoidCallback onPressed;

  const _SecondaryWalkthroughAction({
    required this.label,
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: color,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        textStyle: GoogleFonts.poppins(
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum _WalkthroughVisualType { profile, vehicle, payment }

class _WalkthroughStep {
  final IconData icon;
  final String title;
  final String description;
  final String label;
  final String detail;
  final _WalkthroughVisualType visualType;
  final Color buttonColor;
  final Color buttonForeground;

  const _WalkthroughStep({
    required this.icon,
    required this.title,
    required this.description,
    required this.label,
    required this.detail,
    required this.visualType,
    required this.buttonColor,
    required this.buttonForeground,
  });
}
