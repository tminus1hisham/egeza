import 'package:egesha/models/parking_session.dart';
import 'package:flutter_test/flutter_test.dart';

/// Regression cover for the three-state session lifecycle.
///
/// The dashboard used to read `!isActive` as "Paid", so a driver who exited
/// without paying was shown a green "Paid" tick on a session that still owed
/// money — and the pay flow refused to collect on it.
void main() {
  // Verbatim shape returned by /parking/sessions/by-plate/active for a plate
  // whose driver left without paying: exited, unpaid, and `amountPaid` null.
  Map<String, dynamic> exitedUnpaidJson() => <String, dynamic>{
        'sessionId': 'cfd68ee5-230a-4f2b-b161-8218f5695949',
        'plateNumber': 'KAM119E',
        'location': 'Sarit',
        'entryTime': '2026-08-15T11:52:34.7358',
        'exitTime': '2026-08-15T12:00:22.502271',
        'durationMinutes': 7,
        'amountDue': 5.00,
        'amountPaid': null,
        'status': 'EXIT_PENDING_PAYMENT',
        'discountAmount': 0.00,
      };

  group('exited but unpaid session', () {
    test('is neither active nor settled', () {
      final session = ParkingSession.fromJson(exitedUnpaidJson());

      expect(session.isActive, isFalse, reason: 'the car has left');
      expect(session.isSettled, isFalse, reason: 'the fee is still owing');
      expect(session.isAwaitingPayment, isTrue);
      expect(session.cost, 5);
    });

    test('becomes settled once the fee is collected', () {
      final session = ParkingSession.fromJson({
        ...exitedUnpaidJson(),
        'amountPaid': 5.00,
      });

      expect(session.isSettled, isTrue);
      expect(session.isAwaitingPayment, isFalse);
      expect(session.isActive, isFalse);
    });
  });

  group('settled sessions', () {
    test('a completed session with nothing to collect is settled', () {
      final session = ParkingSession.fromJson({
        ...exitedUnpaidJson(),
        'amountDue': 0.00,
        'amountPaid': 0.00,
        'status': 'COMPLETED',
      });

      expect(session.isSettled, isTrue);
      expect(session.isAwaitingPayment, isFalse);
    });

    test('a cancelled session owes nothing', () {
      final session = ParkingSession.fromJson({
        ...exitedUnpaidJson(),
        'status': 'CANCELLED',
      });

      expect(session.isSettled, isTrue);
      expect(session.isAwaitingPayment, isFalse);
    });
  });

  test('a running session is unsettled but not awaiting payment', () {
    final session = ParkingSession.fromJson({
      ...exitedUnpaidJson(),
      'exitTime': null,
      'status': 'ACTIVE',
    });

    expect(session.isActive, isTrue);
    expect(session.isSettled, isFalse);
    expect(session.isAwaitingPayment, isFalse);
  });
}
