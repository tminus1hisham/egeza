import '../../models/parking_session.dart';

class PaymentValidationException implements Exception {
  final String message;

  const PaymentValidationException(this.message);

  @override
  String toString() => message;
}

class PaymentValidation {
  const PaymentValidation._();

  static String normalizePlateNumber(String value) {
    return value.replaceAll(RegExp(r'\s+'), '').toUpperCase();
  }

  static String? normalizeMpesaPhone(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length == 12 && digits.startsWith('254')) return digits;
    if (digits.length == 10 && digits.startsWith('0')) {
      return '254${digits.substring(1)}';
    }
    if (digits.length == 9) return '254$digits';
    return digits.isEmpty ? null : digits;
  }

  static void validatePlateNumber(String plateNumber) {
    final normalized = normalizePlateNumber(plateNumber);
    if (normalized.isEmpty) {
      throw const PaymentValidationException('Plate number is required');
    }
    if (normalized.length < 6 || normalized.length > 10) {
      throw const PaymentValidationException('Enter a valid plate number');
    }
  }

  static void validateLocation(String location) {
    if (location.trim().isEmpty) {
      throw const PaymentValidationException('Parking location is required');
    }
  }

  static void validateSessionId(String sessionId) {
    if (sessionId.trim().isEmpty) {
      throw const PaymentValidationException('Parking session is required');
    }
  }

  static void validateAmount(num amount) {
    if (amount <= 0) {
      throw const PaymentValidationException('Payment amount must be greater than zero');
    }
  }

  static String requireValidMpesaPhone(String? raw) {
    final normalized = normalizeMpesaPhone(raw);
    if (normalized == null || normalized.isEmpty) {
      throw const PaymentValidationException('M-Pesa phone number is required');
    }
    if (!RegExp(r'^254(7|1)\d{8}$').hasMatch(normalized)) {
      throw const PaymentValidationException('Enter a valid Kenyan M-Pesa number');
    }
    return normalized;
  }

  static void validateSessionCanBePaid(ParkingSession session) {
    // Payable means unsettled, not "still running" — a session the driver
    // exited without paying (EXIT_PENDING_PAYMENT) is inactive and is exactly
    // the one we most need to collect on.
    if (session.isSettled) {
      throw const PaymentValidationException('This parking session is already completed');
    }
  }

  static void validateAmountMatches({
    required num providedAmount,
    required num calculatedAmount,
  }) {
    if (providedAmount.toInt() != calculatedAmount.toInt()) {
      throw const PaymentValidationException(
        'Payment amount does not match the calculated parking fee',
      );
    }
  }
}
