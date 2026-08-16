import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
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
// PAGE CONTROLS
// ─────────────────────────────────────────────────────────────────────────────

/// A bare icon control — no fill, no border, no shadow, no label. Built on
/// InkWell rather than IconButton because the app's `iconButtonTheme` gives
/// IconButton a surface-coloured box, which is exactly what we're removing.
///
/// Screens carry no titles, so these are the only chrome on a page. Add one
/// only where nothing else already performs the action.
class PageAction extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  /// Always set this. With no visible label it is the only thing naming the
  /// control for screen readers and long-press.
  final String tooltip;

  /// Tints the icon with the brand colour, for a control that is the primary
  /// action on its row.
  final bool primary;

  /// For a control sitting on a [PageHero] rather than the page background.
  /// Still bare — this only swaps the ink, it adds no surface of its own.
  final bool onDark;

  /// Trims the tap target for a control inlined into a hero's eyebrow row,
  /// where 44px would force the whole row taller than its type.
  final bool compact;

  const PageAction({
    super.key,
    required this.icon,
    required this.onTap,
    required this.tooltip,
    this.primary = false,
    this.onDark = false,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final Color ink;
    if (onDark) {
      ink = primary ? Colors.white : Colors.white.withValues(alpha: 0.86);
    } else {
      ink = primary ? colors.primary : colors.textSecondary;
    }

    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: compact ? 34 : 44,
            height: compact ? 34 : 44,
            child: Icon(
              icon,
              size: compact ? 20 : 23,
              semanticLabel: tooltip,
              color: ink,
            ),
          ),
        ),
      ),
    );
  }
}

/// The back affordance for a pushed route. With page titles gone this is the
/// only chrome at the top of a sub-page, so it stands alone, left-aligned and
/// nudged out to put the arrow's optical edge on the page gutter rather than
/// the edge of its 44px tap target.
///
/// Pass [label] on a sub-page that has no [PageHero] to name it. The label is
/// attached to the control, on the page background, with no surface, border,
/// shadow or gradient of its own — it scrolls away with the content and costs
/// no height over the bare arrow, which already occupies a 44px row.
class PageBackButton extends StatelessWidget {
  final VoidCallback? onBack;
  final String? label;

  const PageBackButton({super.key, this.onBack, this.label});

  @override
  Widget build(BuildContext context) {
    final button = PageAction(
      icon: Icons.arrow_back_rounded,
      tooltip: 'Back',
      onTap: onBack ?? () => Navigator.pop(context),
    );

    if (label == null) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Transform.translate(offset: const Offset(-10, 0), child: button),
      );
    }

    return Transform.translate(
      offset: const Offset(-10, 0),
      child: Row(
        children: [
          button,
          Expanded(
            child: Text(
              label!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: context.colors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PAGE HERO
// ─────────────────────────────────────────────────────────────────────────────

/// One metric in a [PageHero]'s footer row.
class PageHeroMetric {
  final String label;
  final String value;

  const PageHeroMetric(this.label, this.value);
}

/// How dark the hero reads. [PageHeroTone.brand] keeps a lighter stop for the
/// money page so Wallet still reads as its own; everything else is identical.
enum PageHeroTone { deep, brand }

/// The first card on a screen, and — since the page header was removed — the
/// thing that names it.
///
/// Anatomy, fixed for every screen that uses it:
///
///   [back] eyebrow ....................... [pill]
///   value                               [trailing]
///   ──────────────────────────────────────────────
///   metric │ metric │ metric
///
/// The eyebrow is the page name ("Registered fleet", "Available balance"), so
/// on a pushed route the back arrow inlines into that row rather than floating
/// alone above the card.
class PageHero extends StatelessWidget {
  final String eyebrow;
  final String value;

  /// Small status chip on the right of the eyebrow row.
  final Widget? pill;

  /// Action sitting on the baseline of the value line, e.g. Vehicles' add.
  final Widget? trailing;

  /// Accent set immediately before the value, e.g. the plate band on Vehicle
  /// Details. Sized by the caller so it can align to the value's cap height.
  final Widget? valueLeading;

  /// Tracking for the value line. A plate is set wide so it reads as a plate;
  /// ordinary values leave this at zero.
  final double valueLetterSpacing;

  /// Up to three. Rendered under a hairline, evenly divided.
  final List<PageHeroMetric> metrics;

  /// Set on a pushed route to inline the back arrow into the eyebrow row.
  final VoidCallback? onBack;

  /// Makes the whole card tappable, for a hero that is also a link.
  final VoidCallback? onTap;

  final PageHeroTone tone;

  const PageHero({
    super.key,
    required this.eyebrow,
    required this.value,
    this.pill,
    this.trailing,
    this.valueLeading,
    this.valueLetterSpacing = 0,
    this.metrics = const [],
    this.onBack,
    this.onTap,
    this.tone = PageHeroTone.deep,
  });

  @override
  Widget build(BuildContext context) {
    final gradient = tone == PageHeroTone.brand
        ? const [AppColors.primary, AppColors.primaryDark]
        : const [AppColors.primaryDark, AppColors.primaryDeep];

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDeep.withValues(alpha: 0.3),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(24),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          splashColor: Colors.white.withValues(alpha: 0.1),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 24),
            child: _content(),
          ),
        ),
      ),
    );
  }

  Widget _content() {
    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (onBack != null) ...[
                Transform.translate(
                  offset: const Offset(-8, 0),
                  child: PageAction(
                    icon: Icons.arrow_back_rounded,
                    tooltip: 'Back',
                    onTap: onBack!,
                    onDark: true,
                    compact: true,
                  ),
                ),
                const SizedBox(width: 2),
              ],
              Expanded(
                child: Text(
                  eyebrow,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    color: Colors.white.withValues(alpha: 0.68),
                    fontSize: 13,
                  ),
                ),
              ),
              if (pill != null) ...[const SizedBox(width: 10), pill!],
            ],
          ),
          SizedBox(height: onBack == null ? 10 : 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    if (valueLeading != null) ...[
                      valueLeading!,
                      const SizedBox(width: 12),
                    ],
                    Flexible(
                      child: Text(
                        value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 32,
                          height: 1.1,
                          fontWeight: FontWeight.w700,
                          letterSpacing: valueLetterSpacing,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 10), trailing!],
            ],
          ),
          if (metrics.isNotEmpty) ...[
            Container(
              height: 1,
              margin: const EdgeInsets.only(top: 20, bottom: 14),
              color: Colors.white.withValues(alpha: 0.14),
            ),
            Row(
              children: [
                for (var i = 0; i < metrics.length; i++) ...[
                  if (i != 0)
                    Container(
                      width: 1,
                      height: 34,
                      color: Colors.white.withValues(alpha: 0.14),
                    ),
                  Expanded(child: _metric(metrics[i])),
                ],
              ],
            ),
          ],
        ],
    );
  }

  Widget _metric(PageHeroMetric metric) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          metric.label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.poppins(
            color: Colors.white.withValues(alpha: 0.56),
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          metric.value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

/// The status chip that sits at the right of a [PageHero]'s eyebrow row.
class PageHeroPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const PageHeroPill({super.key, required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white.withValues(alpha: 0.76), size: 13),
          const SizedBox(width: 5),
          Text(
            label,
            style: GoogleFonts.poppins(
              color: Colors.white.withValues(alpha: 0.82),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// Applies status bar icon colouring for a screen whose background is the page
/// tone. Wrap the `Scaffold`, not the content — it has to stay painted for the
/// whole route, which scrolling content does not.
class AdaptiveStatusBar extends StatelessWidget {
  final Widget child;
  const AdaptiveStatusBar({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
      ),
      child: child,
    );
  }
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
