import 'package:equatable/equatable.dart';

/// A promo code the driver applied to a running session.
///
/// A promo only ever *holds* for an hour. AutoPay settles at the gate, which
/// can be long after the code was punched in, so the app has to know whether
/// the discount is still live when the car finally leaves — the redemption the
/// API returns carries no expiry of its own (`DiscountRedemptionDto` has
/// `appliedAt` but nothing to expire against), so the window is tracked here.
///
/// A hold that covered the whole bill is born already expired: the bill was
/// sorted on the spot and the code is spent.
class SessionPromoHold extends Equatable {
  /// How long an applied promo stays good for.
  static const Duration holdDuration = Duration(hours: 1);

  final String sessionId;
  final String code;

  /// What the promo knocked off the bill.
  final double discountAmount;

  /// The bill before the promo was applied.
  final double originalAmount;

  /// What is left for AutoPay to collect at the gate. Zero when the promo
  /// covered everything.
  final double remainingDue;

  final DateTime appliedAt;

  /// The moment the hold lapses. Equal to [appliedAt] when the promo was spent
  /// outright on a bill it fully covered.
  final DateTime expiresAt;

  /// The promo paid the whole bill, so nothing was left for AutoPay.
  final bool coveredBill;

  const SessionPromoHold({
    required this.sessionId,
    required this.code,
    required this.discountAmount,
    required this.originalAmount,
    required this.remainingDue,
    required this.appliedAt,
    required this.expiresAt,
    required this.coveredBill,
  });

  /// A promo that settled the bill in full: spent immediately, so it never
  /// holds.
  factory SessionPromoHold.spent({
    required String sessionId,
    required String code,
    required double discountAmount,
    required double originalAmount,
    required DateTime appliedAt,
  }) {
    return SessionPromoHold(
      sessionId: sessionId,
      code: code,
      discountAmount: discountAmount,
      originalAmount: originalAmount,
      remainingDue: 0,
      appliedAt: appliedAt,
      expiresAt: appliedAt,
      coveredBill: true,
    );
  }

  /// A promo that covered part of the bill and holds for [holdDuration] while
  /// AutoPay waits to pick up the rest.
  factory SessionPromoHold.holding({
    required String sessionId,
    required String code,
    required double discountAmount,
    required double originalAmount,
    required double remainingDue,
    required DateTime appliedAt,
  }) {
    return SessionPromoHold(
      sessionId: sessionId,
      code: code,
      discountAmount: discountAmount,
      originalAmount: originalAmount,
      remainingDue: remainingDue,
      appliedAt: appliedAt,
      expiresAt: appliedAt.add(holdDuration),
      coveredBill: false,
    );
  }

  bool isExpiredAt(DateTime now) => !now.isBefore(expiresAt);

  bool isLiveAt(DateTime now) => !isExpiredAt(now);

  /// Time left on the hold, floored at zero.
  Duration remainingAt(DateTime now) {
    final left = expiresAt.difference(now);
    return left.isNegative ? Duration.zero : left;
  }

  /// Short countdown for the session card: `59m`, then `48s` in the last
  /// minute.
  String countdownLabelAt(DateTime now) {
    final left = remainingAt(now);
    if (left.inMinutes >= 1) return '${left.inMinutes}m';
    return '${left.inSeconds}s';
  }

  @override
  List<Object?> get props => [
        sessionId,
        code,
        discountAmount,
        originalAmount,
        remainingDue,
        appliedAt,
        expiresAt,
        coveredBill,
      ];
}
