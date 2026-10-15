import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter, FontFeature;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/theme/app_colors.dart';

/// How long a driver has to clear the barrier after paying before the meter
/// starts again. Shared by every flow that shows the countdown so they cannot
/// drift apart.
const Duration kExitGraceWindow = Duration(minutes: 30);

/// Everything the success moment needs to describe the payment that just
/// landed. Built by whichever flow paid — instant pay has no account behind it,
/// the dashboard flows do — so every field beyond the amount is optional.
class PaymentSuccessDetails {
  final double amountPaid;
  final String? transactionId;
  final DateTime paidAt;
  final String? siteName;
  final String? plateNumber;
  final double discountAmount;

  /// How long the driver has to clear the barrier before the meter restarts.
  /// Null hides the countdown entirely.
  final Duration? exitWindow;

  const PaymentSuccessDetails({
    required this.amountPaid,
    required this.paidAt,
    this.transactionId,
    this.siteName,
    this.plateNumber,
    this.discountAmount = 0,
    this.exitWindow,
  });

  /// The wall-clock instant the driver must be past the gate by.
  DateTime? get exitBy => exitWindow == null ? null : paidAt.add(exitWindow!);
}

/// The screen drivers land on the moment a parking payment clears.
///
/// Deliberately full-bleed on the brand gradient rather than the app's light
/// surfaces: this is a confirmation moment, not another page in the stack, and
/// the same screen serves the signed-out instant-pay flow (dark throughout)
/// and the signed-in ones.
class PaymentSuccessScreen extends StatefulWidget {
  final PaymentSuccessDetails details;

  /// Where "Done" goes. Defaults to popping back to the first route.
  final VoidCallback? onDone;

  /// Overrides the built-in receipt sheet when a flow has its own receipt.
  final VoidCallback? onViewReceipt;

  const PaymentSuccessScreen({
    super.key,
    required this.details,
    this.onDone,
    this.onViewReceipt,
  });

  @override
  State<PaymentSuccessScreen> createState() => _PaymentSuccessScreenState();
}

class _PaymentSuccessScreenState extends State<PaymentSuccessScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1150),
  );

  late final Animation<double> _ring = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0, 0.55, curve: Curves.easeOutCubic),
  );

  late final Animation<double> _tick = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.38, 0.8, curve: Curves.easeOutBack),
  );

  late final Animation<double> _content = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.3, 1, curve: Curves.easeOut),
  );

  @override
  void initState() {
    super.initState();
    _controller.forward();
    HapticFeedback.mediumImpact();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _done() {
    final onDone = widget.onDone;
    if (onDone != null) {
      onDone();
      return;
    }
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  void _viewReceipt() {
    final custom = widget.onViewReceipt;
    if (custom != null) {
      custom();
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ReceiptSheet(details: widget.details),
    );
  }

  @override
  Widget build(BuildContext context) {
    final details = widget.details;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      // The session is paid for — swiping back into the pay form would only
      // offer to charge the driver twice.
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _done();
        },
        child: Scaffold(
          backgroundColor: AppColors.primaryDeep,
          body: Stack(
            children: [
              const Positioned.fill(child: _SuccessBackground()),
              SafeArea(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxHeight < 700;

                    return Column(
                      children: [
                        Expanded(
                          child: SingleChildScrollView(
                            padding: EdgeInsets.fromLTRB(
                              22,
                              compact ? 18 : 34,
                              22,
                              12,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Center(
                                  child: _SuccessSeal(
                                    ring: _ring,
                                    tick: _tick,
                                    size: compact ? 96 : 118,
                                  ),
                                ),
                                SizedBox(height: compact ? 20 : 28),
                                _fadeUp(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Text(
                                        'Payment Successful',
                                        textAlign: TextAlign.center,
                                        style: GoogleFonts.poppins(
                                          fontSize: compact ? 25 : 29,
                                          height: 1.15,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Your parking fee has been paid successfully',
                                        textAlign: TextAlign.center,
                                        style: GoogleFonts.poppins(
                                          fontSize: 13.5,
                                          height: 1.45,
                                          color:
                                              Colors.white.withValues(alpha: 0.68),
                                        ),
                                      ),
                                      SizedBox(height: compact ? 22 : 30),
                                      _SummaryCard(details: details),
                                      if (details.exitBy != null) ...[
                                        const SizedBox(height: 16),
                                        ExitWindowCard(exitBy: details.exitBy!),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        _fadeUp(
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(
                              22,
                              4,
                              22,
                              compact ? 12 : 20,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: _GhostButton(
                                    label: 'View Receipt',
                                    onPressed: _viewReceipt,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _SolidButton(
                                    label: 'Done',
                                    onPressed: _done,
                                  ),
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
            ],
          ),
        ),
      ),
    );
  }

  /// Slides the copy up under the seal once the tick has landed.
  Widget _fadeUp({required Widget child}) {
    return AnimatedBuilder(
      animation: _content,
      builder: (context, inner) => Opacity(
        opacity: _content.value,
        child: Transform.translate(
          offset: Offset(0, 18 * (1 - _content.value)),
          child: inner,
        ),
      ),
      child: child,
    );
  }
}

// -----------------------------------------------------------------------------
// Seal
// -----------------------------------------------------------------------------

/// A ring that draws itself around a check mark: the ring sweeps first, the
/// tick pops in behind it.
class _SuccessSeal extends StatelessWidget {
  final Animation<double> ring;
  final Animation<double> tick;
  final double size;

  const _SuccessSeal({
    required this.ring,
    required this.tick,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: AnimatedBuilder(
        animation: ring,
        builder: (context, _) {
          return CustomPaint(
            painter: _SealPainter(progress: ring.value),
            child: Center(
              child: ScaleTransition(
                scale: tick,
                child: Icon(
                  Icons.check_rounded,
                  size: size * 0.44,
                  color: AppColors.accent,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SealPainter extends CustomPainter {
  final double progress;

  const _SealPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 4;

    // Halo that widens as the ring completes.
    canvas.drawCircle(
      center,
      radius * (0.82 + 0.34 * progress),
      Paint()..color = AppColors.accent.withValues(alpha: 0.10 * progress),
    );
    canvas.drawCircle(
      center,
      radius * 0.86,
      Paint()..color = AppColors.accent.withValues(alpha: 0.14),
    );

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = Colors.white.withValues(alpha: 0.10),
    );

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 3
        ..color = AppColors.accent,
    );
  }

  @override
  bool shouldRepaint(covariant _SealPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

// -----------------------------------------------------------------------------
// Summary
// -----------------------------------------------------------------------------

class _SummaryCard extends StatelessWidget {
  final PaymentSuccessDetails details;

  const _SummaryCard({required this.details});

  @override
  Widget build(BuildContext context) {
    return _Glass(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Amount Paid',
                    style: GoogleFonts.poppins(
                      fontSize: 13.5,
                      color: Colors.white.withValues(alpha: 0.66),
                    ),
                  ),
                ),
                Text(
                  'KES ${formatMoney(details.amountPaid)}',
                  style: GoogleFonts.poppins(
                    fontSize: 21,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          Divider(
            height: 1,
            thickness: 1,
            color: Colors.white.withValues(alpha: 0.10),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
            child: Column(
              children: [
                if (details.discountAmount > 0)
                  _DetailRow(
                    icon: Icons.local_offer_outlined,
                    label: 'Promo discount',
                    value: '- KES ${formatMoney(details.discountAmount)}',
                    highlight: true,
                  ),
                if (details.transactionId != null &&
                    details.transactionId!.isNotEmpty)
                  _DetailRow(
                    icon: Icons.receipt_long_outlined,
                    label: 'Transaction ID',
                    value: details.transactionId!,
                  ),
                _DetailRow(
                  icon: Icons.schedule_rounded,
                  label: 'Time',
                  value: formatStamp(details.paidAt),
                ),
                if (details.siteName != null && details.siteName!.isNotEmpty)
                  _DetailRow(
                    icon: Icons.location_on_outlined,
                    label: 'Parking Site',
                    value: details.siteName!,
                  ),
                if (details.plateNumber != null &&
                    details.plateNumber!.isNotEmpty)
                  _DetailRow(
                    icon: Icons.directions_car_outlined,
                    label: 'Vehicle',
                    value: details.plateNumber!,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool highlight;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Colors.white.withValues(alpha: 0.52)),
          const SizedBox(width: 10),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 12.5,
              color: Colors.white.withValues(alpha: 0.62),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: highlight ? AppColors.accent : Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Exit window
// -----------------------------------------------------------------------------

/// Live countdown to the moment the meter restarts. Green while there is room,
/// amber inside the last five minutes, red once the window has closed.
class ExitWindowCard extends StatefulWidget {
  final DateTime exitBy;

  const ExitWindowCard({super.key, required this.exitBy});

  @override
  State<ExitWindowCard> createState() => _ExitWindowCardState();
}

class _ExitWindowCardState extends State<ExitWindowCard> {
  static const _warnAt = Duration(minutes: 5);

  Timer? _ticker;
  late Duration _remaining = _timeLeft();

  @override
  void initState() {
    super.initState();
    _startTicker();
  }

  @override
  void didUpdateWidget(covariant ExitWindowCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.exitBy != widget.exitBy) {
      setState(() => _remaining = _timeLeft());
      _startTicker();
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _startTicker() {
    _ticker?.cancel();
    if (_remaining <= Duration.zero) return;
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      final left = _timeLeft();
      if (!mounted) return;
      setState(() => _remaining = left);
      if (left <= Duration.zero) _ticker?.cancel();
    });
  }

  Duration _timeLeft() {
    final left = widget.exitBy.difference(DateTime.now());
    return left.isNegative ? Duration.zero : left;
  }

  @override
  Widget build(BuildContext context) {
    final expired = _remaining <= Duration.zero;
    final urgent = !expired && _remaining <= _warnAt;
    final tone = expired
        ? AppColors.error
        : urgent
            ? AppColors.warning
            : AppColors.accent;

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 15, 18, 16),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: tone.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            expired ? 'EXIT WINDOW ENDED' : 'PLEASE EXIT BY',
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.1,
              color: Colors.white.withValues(alpha: 0.72),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.timer_outlined, size: 26, color: tone),
              const SizedBox(width: 12),
              Text(
                formatClock(widget.exitBy),
                style: GoogleFonts.poppins(
                  fontSize: 25,
                  fontWeight: FontWeight.w700,
                  height: 1,
                  color: tone,
                ),
              ),
              const Spacer(),
              if (!expired)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: tone.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Text(
                    '${formatCountdown(_remaining)} left',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: tone,
                      // Keeps the pill from jittering as the digits change.
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            expired
                ? 'Additional charges may now apply for this session.'
                : 'To avoid additional charges',
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.60),
            ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Receipt sheet
// -----------------------------------------------------------------------------

class _ReceiptSheet extends StatelessWidget {
  final PaymentSuccessDetails details;

  const _ReceiptSheet({required this.details});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final exitBy = details.exitBy;
    final gross = details.amountPaid + details.discountAmount;

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Parking receipt',
              style: GoogleFonts.poppins(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              formatStamp(details.paidAt),
              style: GoogleFonts.poppins(
                fontSize: 12.5,
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(height: 18),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: colors.pageGrey,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: colors.border),
              ),
              child: Column(
                children: [
                  if (details.plateNumber != null &&
                      details.plateNumber!.isNotEmpty)
                    _receiptRow(colors, 'Plate number', details.plateNumber!),
                  if (details.siteName != null && details.siteName!.isNotEmpty)
                    _receiptRow(colors, 'Parking site', details.siteName!),
                  if (details.transactionId != null &&
                      details.transactionId!.isNotEmpty)
                    _receiptRow(
                      colors,
                      'Transaction ID',
                      details.transactionId!,
                    ),
                  if (details.discountAmount > 0) ...[
                    _receiptRow(
                      colors,
                      'Parking fee',
                      'KES ${formatMoney(gross)}',
                    ),
                    _receiptRow(
                      colors,
                      'Promo discount',
                      '- KES ${formatMoney(details.discountAmount)}',
                    ),
                  ],
                  if (exitBy != null)
                    _receiptRow(colors, 'Exit by', formatClock(exitBy)),
                  Divider(height: 22, color: colors.divider),
                  _receiptRow(
                    colors,
                    'Amount paid',
                    'KES ${formatMoney(details.amountPaid)}',
                    emphasise: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                style: TextButton.styleFrom(
                  backgroundColor: colors.pageGrey,
                  foregroundColor: colors.textPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  'Close',
                  style: GoogleFonts.poppins(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _receiptRow(
    AppColorsData colors,
    String label,
    String value, {
    bool emphasise = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 12.5,
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                fontSize: emphasise ? 15 : 12.5,
                fontWeight: emphasise ? FontWeight.w700 : FontWeight.w600,
                color: emphasise ? colors.primary : colors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Chrome
// -----------------------------------------------------------------------------

class _Glass extends StatelessWidget {
  final Widget child;

  const _Glass({required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: 0.14),
                Colors.white.withValues(alpha: 0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _SolidButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const _SolidButton({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: AppColors.primaryDeep,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class _GhostButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const _GhostButton({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white.withValues(alpha: 0.10),
          foregroundColor: Colors.white,
          side: BorderSide(color: Colors.white.withValues(alpha: 0.22)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

class _SuccessBackground extends StatelessWidget {
  const _SuccessBackground();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primaryDeep,
            Color(0xFF083831),
            AppColors.primaryDark,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: CustomPaint(
        painter: _SuccessBackgroundPainter(),
        size: Size.infinite,
      ),
    );
  }
}

/// A wash of light behind the seal so the top of the screen lifts.
class _SuccessBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final glowCentre = Offset(size.width / 2, size.height * 0.18);
    canvas.drawCircle(
      glowCentre,
      size.width * 0.72,
      Paint()
        ..shader = RadialGradient(
          colors: [
            AppColors.accent.withValues(alpha: 0.16),
            AppColors.accent.withValues(alpha: 0),
          ],
        ).createShader(
          Rect.fromCircle(center: glowCentre, radius: size.width * 0.72),
        ),
    );

    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 42
      ..color = Colors.white.withValues(alpha: 0.03);

    for (final lane in const [0.14, 0.5, 0.88]) {
      canvas.drawLine(
        Offset(size.width * (lane - 0.24), size.height + 90),
        Offset(size.width * (lane + 0.34), -90),
        linePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// -----------------------------------------------------------------------------
// Formatting
// -----------------------------------------------------------------------------

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// Whole shillings with thousands separators — 1234.0 becomes "1,234".
String formatMoney(double value) => value.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (match) => ',',
    );

/// "09:49 AM" — the 12-hour clock drivers read off a barrier.
String formatClock(DateTime dt) {
  final hour12 = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
  final minute = dt.minute.toString().padLeft(2, '0');
  final meridiem = dt.hour < 12 ? 'AM' : 'PM';
  return '${hour12.toString().padLeft(2, '0')}:$minute $meridiem';
}

/// "Aug 28, 2026 at 9:19 AM".
String formatStamp(DateTime dt) {
  final hour12 = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
  final minute = dt.minute.toString().padLeft(2, '0');
  final meridiem = dt.hour < 12 ? 'AM' : 'PM';
  return '${_months[dt.month - 1]} ${dt.day}, ${dt.year} '
      'at $hour12:$minute $meridiem';
}

/// "29:41", or "1:04:12" once the window runs past an hour.
String formatCountdown(Duration left) {
  final total = left.isNegative ? 0 : left.inSeconds;
  final hours = total ~/ 3600;
  final minutes = (total % 3600) ~/ 60;
  final seconds = total % 60;
  final mm = minutes.toString().padLeft(2, '0');
  final ss = seconds.toString().padLeft(2, '0');
  return hours > 0 ? '$hours:$mm:$ss' : '$mm:$ss';
}
