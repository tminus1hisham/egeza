import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../core/theme/app_colors.dart';

/// Logo widget used in headers
class egeshaLogo extends StatelessWidget {
  final bool dark;
  final double size;
  const egeshaLogo({super.key, this.dark = false, this.size = 40});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            gradient: dark
                ? null
                : const LinearGradient(
                    colors: [AppColors.primary, AppColors.primaryDark],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
            color: dark ? Colors.white : null,
            borderRadius: BorderRadius.circular(size * 0.28),
            boxShadow: dark
                ? null
                : [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.35),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
          ),
          child: Icon(
            Icons.local_parking_rounded,
            color: dark ? context.colors.primary : Colors.white,
            size: size * 0.56,
          ),
        ),
        const SizedBox(width: 10),
        Text(
          'egesha',
          style: GoogleFonts.poppins(
            color: dark ? Colors.white : context.colors.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: size * 0.52,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ONBOARDING STEP HEADER
// ─────────────────────────────────────────────────────────────────────────────

class OnboardingStepHeader extends StatelessWidget {
  final int step;
  final int totalSteps;
  final String title;
  final VoidCallback? onBack;
  final Widget? trailing;

  const OnboardingStepHeader({
    super.key,
    required this.step,
    required this.totalSteps,
    required this.title,
    this.onBack,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final progress = (step / totalSteps).clamp(0.0, 1.0);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.primaryDeep, Color(0xFF0B5C52), AppColors.primary],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            stops: [0.0, 0.55, 1.0],
          ),
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryDark.withValues(alpha: 0.45),
              blurRadius: 28,
              offset: const Offset(0, 10),
            ),
            BoxShadow(
              color: AppColors.accent.withValues(alpha: 0.12),
              blurRadius: 40,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.hardEdge,
        child: Stack(
          children: [
            Positioned.fill(child: CustomPaint(painter: _HeaderWavePainter())),
            _ScatteredDots(),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 20, 18, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _HeaderBackButton(
                        onPressed: onBack ?? () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.accent.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: AppColors.accent.withValues(alpha: 0.42),
                                ),
                              ),
                              child: Text(
                                'Step $step of $totalSteps',
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.accent,
                                ),
                              ),
                            ),
                            const SizedBox(height: 7),
                            Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.poppins(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                height: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (trailing != null) ...[
                        const SizedBox(width: 12),
                        trailing!,
                      ],
                    ],
                  ),
                  const SizedBox(height: 20),
                  Stack(
                    children: [
                      Container(
                        height: 5,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: progress,
                        child: Container(
                          height: 5,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [AppColors.accent, AppColors.primary],
                            ),
                            borderRadius: BorderRadius.circular(999),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.accent.withValues(alpha: 0.50),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
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
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ONBOARDING HERO ICON
// ─────────────────────────────────────────────────────────────────────────────

class OnboardingHeroIcon extends StatelessWidget {
  final IconData icon;
  final double size;

  const OnboardingHeroIcon({super.key, required this.icon, this.size = 92});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: context.colors.accentLight,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: context.colors.mintBorder, width: 1.8),
      ),
      child: Icon(icon, color: context.colors.primary, size: size * 0.34),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// APP PAGE HEADER  — premium dark card matching reference design
// ─────────────────────────────────────────────────────────────────────────────

class AppPageHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Widget? trailing;
  final bool showBackButton;
  final bool showIconWithBack;
  final VoidCallback? onBack;

  const AppPageHeader({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.trailing,
    this.showBackButton = false,
    this.showIconWithBack = false,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Padding(
        // Floating card with side margins — matches reference design
        padding: const EdgeInsets.fromLTRB(6, 0, 6, 0),
        child: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                AppColors.primaryDeep,
                Color(0xFF0B5C52),
                AppColors.primary,
              ],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              stops: [0.0, 0.52, 1.0],
            ),
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryDark.withValues(alpha: 0.50),
                blurRadius: 32,
                offset: const Offset(0, 12),
              ),
              BoxShadow(
                color: AppColors.accent.withValues(alpha: 0.10),
                blurRadius: 48,
                spreadRadius: 2,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          clipBehavior: Clip.hardEdge,
          child: Stack(
            children: [
              // Wave curves background painter
              Positioned.fill(child: CustomPaint(painter: _HeaderWavePainter())),
              // Scattered accent dots
              _ScatteredDots(),
              // Content row
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 14, 10, 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Icon / back button
                    if (showBackButton && !showIconWithBack)
                      _GlassCircleBackButton(
                        onTap: onBack ?? () => Navigator.pop(context),
                      )
                    else
                      _NeonGlowIcon(icon: icon),
                    const SizedBox(width: 20),
                    // Title + subtitle
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 18,
                              height: 1.1,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                              color: Colors.white.withValues(alpha: 0.55),
                              fontSize: 13,
                              fontWeight: FontWeight.w400,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (trailing != null) ...[
                      const SizedBox(width: 14),
                      trailing!,
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// APP HEADER BUTTON — glass style for dark headers
// ─────────────────────────────────────────────────────────────────────────────

class AppHeaderButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool active;
  final String? tooltip;

  const AppHeaderButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.active = false,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final child = Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        splashColor: Colors.white.withValues(alpha: 0.10),
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: active
                ? AppColors.accent.withValues(alpha: 0.20)
                : Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: active
                  ? AppColors.accent.withValues(alpha: 0.55)
                  : Colors.white.withValues(alpha: 0.18),
              width: 1.2,
            ),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: AppColors.accent.withValues(alpha: 0.30),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Icon(
            icon,
            color: active ? AppColors.accent : Colors.white,
            size: 21,
          ),
        ),
      ),
    );

    if (tooltip == null) return child;
    return Tooltip(message: tooltip!, child: child);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PRIVATE WIDGETS
// ─────────────────────────────────────────────────────────────────────────────

/// Circular neon-glow icon — matches reference design
class _NeonGlowIcon extends StatelessWidget {
  final IconData icon;
  const _NeonGlowIcon({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        // Dark glass background
        color: const Color(0xFF062D27).withValues(alpha: 0.65),
        border: Border.all(
          color: AppColors.accent.withValues(alpha: 0.55),
          width: 1.5,
        ),
        boxShadow: [
          // Inner tight glow
          BoxShadow(
            color: AppColors.accent.withValues(alpha: 0.38),
            blurRadius: 18,
            spreadRadius: 1,
          ),
          // Outer soft aura
          BoxShadow(
            color: AppColors.accent.withValues(alpha: 0.16),
            blurRadius: 40,
            spreadRadius: 6,
          ),
        ],
      ),
      child: Icon(icon, color: AppColors.accent, size: 20),
    );
  }
}

/// Glass circular back button for dark headers
class _GlassCircleBackButton extends StatelessWidget {
  final VoidCallback onTap;
  const _GlassCircleBackButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        splashColor: Colors.white.withValues(alpha: 0.10),
        child: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.10),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.22),
              width: 1.2,
            ),
          ),
          child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 22),
        ),
      ),
    );
  }
}

/// Glass back button used in onboarding header
class _HeaderBackButton extends StatelessWidget {
  final VoidCallback onPressed;
  const _HeaderBackButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(14),
        splashColor: Colors.white.withValues(alpha: 0.10),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.22), width: 1.2),
          ),
          child: const Icon(LucideIcons.arrowLeft, size: 20, color: Colors.white),
        ),
      ),
    );
  }
}

/// Wave curves drawn in background — matches the flowing lines in reference
class _HeaderWavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Wave 1 — mid card, sweeping left-to-right
    strokePaint
      ..color = const Color(0xFF30D68B).withValues(alpha: 0.18)
      ..strokeWidth = 1.8;
    final wave1 = Path()
      ..moveTo(size.width * 0.18, size.height * 0.85)
      ..cubicTo(
        size.width * 0.38, size.height * 0.28,
        size.width * 0.62, size.height * 0.92,
        size.width * 1.05, size.height * 0.38,
      );
    canvas.drawPath(wave1, strokePaint);

    // Wave 2 — lower, more subtle
    strokePaint
      ..color = const Color(0xFF30D68B).withValues(alpha: 0.10)
      ..strokeWidth = 1.4;
    final wave2 = Path()
      ..moveTo(-size.width * 0.05, size.height * 1.05)
      ..cubicTo(
        size.width * 0.30, size.height * 0.55,
        size.width * 0.58, size.height * 1.10,
        size.width * 1.08, size.height * 0.58,
      );
    canvas.drawPath(wave2, strokePaint);

    // Wave 3 — upper faint sweep
    strokePaint
      ..color = const Color(0xFF30D68B).withValues(alpha: 0.07)
      ..strokeWidth = 1.2;
    final wave3 = Path()
      ..moveTo(size.width * 0.42, -size.height * 0.1)
      ..cubicTo(
        size.width * 0.55, size.height * 0.45,
        size.width * 0.78, size.height * 0.20,
        size.width * 1.10, size.height * 0.65,
      );
    canvas.drawPath(wave3, strokePaint);

    // Right-side lighter region — subtle radial highlight
    final radialPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF30D68B).withValues(alpha: 0.08),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(
        center: Offset(size.width * 0.82, size.height * 0.5),
        radius: size.height * 0.9,
      ));
    canvas.drawCircle(
      Offset(size.width * 0.82, size.height * 0.5),
      size.height * 0.9,
      radialPaint,
    );
  }

  @override
  bool shouldRepaint(_HeaderWavePainter oldDelegate) => false;
}

/// Scattered small accent dots — the tiny glowing dots in the reference
class _ScatteredDots extends StatelessWidget {
  const _ScatteredDots();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: CustomPaint(painter: _DotsPainter()),
    );
  }
}

class _DotsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final dotPaint = Paint()..color = AppColors.accent.withValues(alpha: 0.55);
    final dots = [
      Offset(size.width * 0.52, size.height * 0.18),
      Offset(size.width * 0.76, size.height * 0.72),
      Offset(size.width * 0.65, size.height * 0.90),
    ];
    for (final d in dots) {
      canvas.drawCircle(d, 3.0, dotPaint);
      canvas.drawCircle(
        d,
        6.0,
        Paint()
          ..color = AppColors.accent.withValues(alpha: 0.12)
          ..style = PaintingStyle.fill,
      );
    }
  }

  @override
  bool shouldRepaint(_DotsPainter old) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
// ONBOARDING STEPPER
// ─────────────────────────────────────────────────────────────────────────────

class OnboardingStepper extends StatelessWidget {
  final int currentStep;
  final int totalSteps;
  const OnboardingStepper({
    super.key,
    required this.currentStep,
    required this.totalSteps,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(totalSteps, (i) {
        final isActive = i == currentStep;
        final isDone = i < currentStep;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: isActive ? 28 : 10,
          height: 10,
          decoration: BoxDecoration(
            color: isActive || isDone
                ? context.colors.primary
                : context.colors.border,
            borderRadius: BorderRadius.circular(5),
          ),
        );
      }),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SECTION LABEL
// ─────────────────────────────────────────────────────────────────────────────

class SectionLabel extends StatelessWidget {
  final String label;
  final String? action;
  final VoidCallback? onAction;
  const SectionLabel({
    super.key,
    required this.label,
    this.action,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: context.colors.textPrimary,
          ),
        ),
        if (action != null)
          GestureDetector(
            onTap: onAction,
            child: Text(
              action!,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: context.colors.primary,
              ),
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STATUS BADGE
// ─────────────────────────────────────────────────────────────────────────────

class StatusBadge extends StatelessWidget {
  final String label;
  final bool isActive;
  const StatusBadge({super.key, required this.label, this.isActive = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isActive
            ? context.colors.successLight
            : context.colors.border.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isActive) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: context.colors.success,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isActive
                  ? context.colors.success
                  : context.colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
