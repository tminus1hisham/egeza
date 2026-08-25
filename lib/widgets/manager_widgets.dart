import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/theme/app_colors.dart';

/// The pieces the owner-side screens are built from — reports and the property
/// sessions list share every one of them, so a plate reads as the same plate
/// and a state chip means the same thing on both.

/// Kenyan-shilling amounts, grouped and without decimals. Parking fees are
/// whole shillings, and a trailing `.00` on every figure only adds noise.
String formatMoney(double amount) {
  return amount
      .roundToDouble()
      .toStringAsFixed(0)
      .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (match) => ',');
}

/// Short form for axis labels and chips, where the full figure will not fit.
String compactMoney(double amount) {
  if (amount.abs() >= 1000000) {
    return '${(amount / 1000000).toStringAsFixed(1)}M';
  }
  if (amount.abs() >= 1000) {
    final thousands = amount / 1000;
    return '${thousands.toStringAsFixed(thousands >= 100 ? 0 : 1)}k';
  }
  return amount.round().toString();
}

String durationLabel(int minutes) {
  if (minutes < 1) return 'just now';
  if (minutes < 60) return '${minutes}m';
  final hours = minutes ~/ 60;
  final rest = minutes % 60;
  return rest == 0 ? '${hours}h' : '${hours}h ${rest}m';
}

String clockLabel(DateTime moment) {
  final local = moment.toLocal();
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

/// Number-plate band, written the way the gate cameras write it.
class PlateTag extends StatelessWidget {
  final String plate;

  const PlateTag(this.plate, {super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: context.colors.plateBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: context.colors.plateYellow.withValues(alpha: 0.35),
        ),
      ),
      child: Text(
        plate.isEmpty ? 'UNKNOWN' : plate,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.poppins(
          color: isDark ? context.colors.plateYellow : const Color(0xFF573A05),
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.1,
        ),
      ),
    );
  }
}

enum ChipTone { good, alert, warn, neutral, brand }

/// The small state pill: Paid, Owes, Running, AutoPay.
class ToneChip extends StatelessWidget {
  final String label;
  final ChipTone tone;
  final IconData? icon;

  const ToneChip(this.label, {super.key, this.tone = ChipTone.neutral, this.icon});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final foreground = switch (tone) {
      ChipTone.good => colors.success,
      ChipTone.alert => colors.error,
      ChipTone.warn => colors.warning,
      ChipTone.neutral => colors.textSecondary,
      ChipTone.brand => colors.primary,
    };
    final background = switch (tone) {
      ChipTone.good => colors.successLight,
      ChipTone.alert => colors.errorLight,
      ChipTone.warn => colors.warning.withValues(alpha: 0.12),
      ChipTone.neutral => colors.surfaceRaised,
      ChipTone.brand => colors.accentLight,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 10, color: foreground),
            const SizedBox(width: 3),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                color: foreground,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The plain card every block on these screens sits in.
class SurfaceCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;

  const SurfaceCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(14, 14, 14, 15),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: context.colors.cardSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.colors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

class SectionHeading extends StatelessWidget {
  final String title;

  /// Muted text on the right — a count, or what the block covers.
  final String? trailing;

  /// A link on the right instead of [trailing], e.g. "See all".
  final String? actionLabel;
  final VoidCallback? onAction;

  /// Tinted badge before the title. Gives a page of stacked cards something
  /// to scan by other than the wording of each heading.
  final IconData? icon;

  /// Tint for [icon]. Defaults to the brand colour; a card about money left
  /// on the table can set the alert colour instead.
  final Color? iconColor;

  /// A second line under the title, for the fact that will not fit beside it.
  final String? subtitle;

  const SectionHeading(
    this.title, {
    super.key,
    this.trailing,
    this.actionLabel,
    this.onAction,
    this.icon,
    this.iconColor,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final tint = iconColor ?? context.colors.primary;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (icon != null) ...[
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: tint.withValues(alpha: 0.11),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 15, color: tint),
          ),
          const SizedBox(width: 10),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: GoogleFonts.poppins(
                  color: context.colors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: GoogleFonts.poppins(
                    color: context.colors.textSecondary,
                    fontSize: 11.5,
                    height: 1.3,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (actionLabel != null && onAction != null)
          GestureDetector(
            onTap: onAction,
            behavior: HitTestBehavior.opaque,
            child: Row(
              children: [
                Text(
                  actionLabel!,
                  style: GoogleFonts.poppins(
                    color: context.colors.primary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 16,
                  color: context.colors.primary,
                ),
              ],
            ),
          )
        else if (trailing != null)
          // Flexible, because the title is the thing that has to be readable:
          // a long trailing note gives way rather than pushing the row past
          // the edge of a narrow phone.
          Flexible(
            child: Text(
              trailing!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
              style: GoogleFonts.poppins(
                color: context.colors.textMuted,
                fontSize: 12,
              ),
            ),
          ),
      ],
    );
  }
}

/// One reading in a card: an icon, the figure, and what it is.
class MetricTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  /// Lifts the tile onto the brand tint — one per card at most, for the figure
  /// the card is actually about.
  final bool emphasis;

  /// Colours the figure itself, for a reading that is bad news on sight —
  /// money left uncollected reads red whether or not it is the card's subject.
  final Color? valueColor;

  const MetricTile({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.emphasis = false,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 11),
      decoration: BoxDecoration(
        color: emphasis
            ? context.colors.accentLight
            : context.colors.surfaceRaised,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: emphasis
              ? context.colors.mintBorder
              : context.colors.border.withValues(alpha: 0.6),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 14,
            color:
                valueColor ??
                (emphasis ? context.colors.primary : context.colors.textMuted),
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              style: GoogleFonts.poppins(
                color: valueColor ?? context.colors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              color: context.colors.textSecondary,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class EmptyStateCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const EmptyStateCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 20),
      decoration: BoxDecoration(
        color: context.colors.cardSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.colors.border),
      ),
      child: Column(
        children: [
          Icon(icon, size: 32, color: context.colors.textMuted),
          const SizedBox(height: 10),
          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              color: context.colors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              color: context.colors.textMuted,
              fontSize: 12,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

/// One row of filter pills that scrolls sideways.
///
/// Scrolls rather than wraps because the number of filters differs per screen
/// and a wrapping row changes the height of the page as the user types.
class FilterPills extends StatelessWidget {
  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  /// Marks pills that are doing something beyond "show everything", so a page
  /// scrolled away from the filter bar still hints that a filter is on.
  final Set<int> highlighted;

  const FilterPills({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onSelected,
    this.highlighted = const {},
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: labels.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final selected = index == selectedIndex;
          return Material(
            color: selected ? context.colors.primary : context.colors.surface,
            borderRadius: BorderRadius.circular(999),
            child: InkWell(
              onTap: () => onSelected(index),
              borderRadius: BorderRadius.circular(999),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: selected
                        ? context.colors.primary
                        : context.colors.border,
                  ),
                ),
                child: Text(
                  labels[index],
                  style: GoogleFonts.poppins(
                    color: selected
                        ? Colors.white
                        : highlighted.contains(index)
                        ? context.colors.primary
                        : context.colors.textSecondary,
                    fontSize: 12.5,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Loud on purpose: a plausible invented number that is not labelled is worse
/// than no number at all.
class SampleDataBanner extends StatelessWidget {
  const SampleDataBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: context.colors.infoLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.colors.info.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(Icons.science_outlined, size: 15, color: context.colors.info),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Sample data — every figure below is generated for layout '
              'preview. Nothing here came from a real site.',
              style: GoogleFonts.poppins(
                color: context.colors.textSecondary,
                fontSize: 11.5,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Shown when a refresh could not reach the API but there are still figures on
/// screen from the last one that could.
class StaleDataBanner extends StatelessWidget {
  final String message;

  const StaleDataBanner(this.message, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: context.colors.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: context.colors.warning.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.cloud_off_rounded,
            size: 15,
            color: context.colors.warning,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.poppins(
                color: context.colors.textSecondary,
                fontSize: 11.5,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The explanatory line at the foot of a card.
///
/// Set below a hairline and behind an icon so it reads as an annotation on the
/// figures above it rather than as another paragraph of them — these cards
/// carry a lot of prose, and none of it should compete with the numbers.
class CardNote extends StatelessWidget {
  final String text;
  final IconData icon;

  const CardNote(
    this.text, {
    super.key,
    this.icon = Icons.info_outline_rounded,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 1,
          margin: const EdgeInsets.only(top: 13, bottom: 10),
          color: context.colors.divider,
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 13, color: context.colors.textMuted),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                text,
                style: GoogleFonts.poppins(
                  color: context.colors.textMuted,
                  fontSize: 11,
                  height: 1.45,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// A filled bar that grows into place, used everywhere this side of the app
/// shows a share of something.
///
/// Replaces `LinearProgressIndicator` so the track, the radius and the run-up
/// animation are the same on every card instead of Material's defaults.
class MeterBar extends StatelessWidget {
  /// 0–1. Values outside that are clamped rather than overflowing the track.
  final double value;
  final Color color;
  final double height;

  /// Track behind the fill. Defaults to the page's border tone.
  final Color? trackColor;

  const MeterBar({
    super.key,
    required this.value,
    required this.color,
    this.height = 7,
    this.trackColor,
  });

  @override
  Widget build(BuildContext context) {
    final target = value.isFinite ? value.clamp(0.0, 1.0) : 0.0;
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: Container(
        height: height,
        color: trackColor ?? context.colors.border,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: target),
          duration: const Duration(milliseconds: 620),
          curve: Curves.easeOutCubic,
          builder: (context, drawn, _) => FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: drawn,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color.withValues(alpha: 0.72), color],
                ),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The occupancy dial: one figure that has to be readable from arm's length,
/// drawn as a ring so it does not read as one more bar on a page of bars.
class RingGauge extends StatelessWidget {
  final double value;
  final Color color;
  final String centerLabel;
  final String? caption;
  final double size;

  const RingGauge({
    super.key,
    required this.value,
    required this.color,
    required this.centerLabel,
    this.caption,
    this.size = 78,
  });

  @override
  Widget build(BuildContext context) {
    final target = value.isFinite ? value.clamp(0.0, 1.0) : 0.0;
    return SizedBox(
      width: size,
      height: size,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: target),
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeOutCubic,
        builder: (context, drawn, _) => CustomPaint(
          painter: _RingPainter(
            value: drawn,
            color: color,
            track: context.colors.border,
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  centerLabel,
                  style: GoogleFonts.poppins(
                    color: context.colors.textPrimary,
                    fontSize: 19,
                    height: 1.1,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (caption != null)
                  Text(
                    caption!,
                    style: GoogleFonts.poppins(
                      color: context.colors.textMuted,
                      fontSize: 9.5,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double value;
  final Color color;
  final Color track;

  _RingPainter({required this.value, required this.color, required this.track});

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 8.0;
    final rect = Offset.zero & size;
    final circle = rect.deflate(stroke / 2);
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = track;
    canvas.drawArc(circle, 0, 6.2831853, false, base);

    if (value <= 0) return;
    final fill = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        startAngle: 0,
        endAngle: 6.2831853,
        colors: [color.withValues(alpha: 0.55), color],
        transform: const GradientRotation(-1.5707963),
      ).createShader(circle);
    canvas.drawArc(circle, -1.5707963, 6.2831853 * value, false, fill);
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.value != value || old.color != color || old.track != track;
}

/// A grey block that breathes, for the shape of a card that has not arrived.
///
/// A spinner on a screen this tall says only "wait"; the blocks say what is
/// coming and stop the page jumping into place around the reader.
class SkeletonBlock extends StatefulWidget {
  final double height;
  final double? width;
  final double radius;

  const SkeletonBlock({
    super.key,
    required this.height,
    this.width,
    this.radius = 10,
  });

  @override
  State<SkeletonBlock> createState() => _SkeletonBlockState();
}

class _SkeletonBlockState extends State<SkeletonBlock>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(
        begin: 0.45,
        end: 1,
      ).animate(CurvedAnimation(parent: _pulse, curve: Curves.easeInOut)),
      child: Container(
        width: widget.width ?? double.infinity,
        height: widget.height,
        decoration: BoxDecoration(
          color: context.colors.border.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(widget.radius),
        ),
      ),
    );
  }
}
