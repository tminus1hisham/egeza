import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../core/theme/app_colors.dart';

/// Logo widget used in headers
class ParkIQLogo extends StatelessWidget {
  final bool dark;
  final double size;
  const ParkIQLogo({super.key, this.dark = false, this.size = 40});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: dark ? Colors.white : context.colors.primary,
            borderRadius: BorderRadius.circular(size * 0.28),
          ),
          child: Icon(
            LucideIcons.camera,
            color: dark ? context.colors.primary : Colors.white,
            size: size * 0.48,
          ),
        ),
        const SizedBox(width: 10),
        Text(
          'ParkIQ',
          style: GoogleFonts.poppins(
            color: dark ? Colors.white : context.colors.textPrimary,
            fontWeight: FontWeight.w500,
            fontSize: size * 0.52,
          ),
        ),
      ],
    );
  }
}

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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            _HeaderBackButton(onPressed: onBack ?? () => Navigator.pop(context)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Step $step of $totalSteps',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: context.colors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.w500,
                      color: context.colors.textPrimary,
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
        const SizedBox(height: 22),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 4,
            color: context.colors.primary,
            backgroundColor: context.colors.border.withValues(alpha: 0.65),
          ),
        ),
      ],
    );
  }
}

class OnboardingHeroIcon extends StatelessWidget {
  final IconData icon;
  final double size;

  const OnboardingHeroIcon({
    super.key,
    required this.icon,
    this.size = 92,
  });

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

class _HeaderBackButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _HeaderBackButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.colors.pageGrey,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          width: 46,
          height: 46,
          child: Icon(
            LucideIcons.arrowLeft,
            size: 20,
            color: context.colors.textPrimary,
          ),
        ),
      ),
    );
  }
}

/// Onboarding progress stepper
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
            color: isActive || isDone ? context.colors.primary : context.colors.border,
            borderRadius: BorderRadius.circular(5),
          ),
        );
      }),
    );
  }
}

/// Section label used in lists
class SectionLabel extends StatelessWidget {
  final String label;
  final String? action;
  final VoidCallback? onAction;
  const SectionLabel({super.key, required this.label, this.action, this.onAction});

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

/// Status badge chip
class StatusBadge extends StatelessWidget {
  final String label;
  final bool isActive;
  const StatusBadge({super.key, required this.label, this.isActive = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isActive ? context.colors.successLight : context.colors.border.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isActive) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: context.colors.success, shape: BoxShape.circle),
            ),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isActive ? context.colors.success : context.colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
