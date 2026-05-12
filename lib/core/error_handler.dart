import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'api/parking_iq_api.dart';

/// Maps exceptions and API errors to user-friendly messages and shows them
/// as consistently-styled snackbars.
abstract final class ErrorHandler {
  /// Converts any exception to a short, human-readable message.
  static String toMessage(Object error) {
    if (error is ApiException) return _fromApiException(error);
    if (error is SocketException) return _noInternet;
    if (error is HandshakeException) return 'Secure connection failed. Please try again.';
    if (error is TlsException) return 'Secure connection failed. Please try again.';

    final raw = error.toString();
    if (_hasKeyword(raw, ['SocketException', 'NetworkException'])) return _noInternet;
    if (_hasKeyword(raw, ['TimeoutException', 'timed out', 'timeout'])) return _timeout;
    return raw.replaceFirst('Exception: ', '');
  }

  // ─── API exception mapping ────────────────────────────────────────────────

  static String _fromApiException(ApiException e) {
    final code = e.statusCode;
    final msg = e.message.toLowerCase();

    // ── Network / connectivity clues in message ───────────────────────────
    if (_hasKeyword(msg, ['no internet', 'network', 'connection refused', 'unreachable'])) {
      return _noInternet;
    }
    if (_hasKeyword(msg, ['timed out', 'timeout', 'took too long'])) return _timeout;

    // ── OTP / verification ────────────────────────────────────────────────
    if (_hasKeyword(msg, ['invalid otp', 'wrong otp', 'incorrect otp', 'invalid code',
        'wrong code', 'incorrect code', 'otp mismatch', 'verification failed',
        'invalid verification'])) {
      return 'Incorrect verification code. Please try again.';
    }
    if (_hasKeyword(msg, ['expired otp', 'otp expired', 'code expired', 'expired code',
        'token expired', 'link expired'])) {
      return 'Verification code has expired. Please request a new one.';
    }
    if (_hasKeyword(msg, ['otp not found', 'no otp', 'code not found'])) {
      return 'Verification code not found. Please request a new one.';
    }
    if (_hasKeyword(msg, ['too many', 'rate limit', 'too many attempts', 'too many requests',
        'maximum attempts'])) {
      return 'Too many attempts. Please wait a moment and try again.';
    }

    // ── Phone / account ───────────────────────────────────────────────────
    if (_hasKeyword(msg, ['phone not found', 'phone not registered', 'user not found',
        'account not found', 'no account', 'not registered'])) {
      return 'Phone number not found. Please check and try again.';
    }
    if (_hasKeyword(msg, ['already registered', 'phone in use', 'already exists',
        'duplicate phone', 'phone taken'])) {
      return 'This phone number is already registered. Please sign in instead.';
    }
    if (_hasKeyword(msg, ['invalid phone', 'invalid number', 'not a valid phone'])) {
      return 'Invalid phone number. Please enter a valid Kenyan mobile number.';
    }
    if (_hasKeyword(msg, ['invalid id', 'id number'])) {
      return 'Invalid ID number. Please check and try again.';
    }

    // ── Wallet / payment ──────────────────────────────────────────────────
    if (_hasKeyword(msg, ['insufficient', 'balance', 'not enough funds', 'low balance'])) {
      return 'Insufficient wallet balance. Please top up and try again.';
    }
    if (_hasKeyword(msg, ['stk push failed', 'stk failed', 'mpesa failed', 'mpesa error',
        'payment failed', 'payment error', 'transaction failed'])) {
      return 'M-Pesa payment could not be processed. Please try again.';
    }
    if (_hasKeyword(msg, ['invalid amount', 'amount mismatch', 'wrong amount'])) {
      return 'Payment amount does not match. Please refresh and try again.';
    }

    // ── Parking session ───────────────────────────────────────────────────
    if (_hasKeyword(msg, ['session not found', 'no active session', 'no session',
        'session does not exist'])) {
      return 'No active parking session found for this plate number.';
    }
    if (_hasKeyword(msg, ['session already paid', 'already paid', 'already completed',
        'session completed'])) {
      return 'This parking session has already been paid.';
    }
    if (_hasKeyword(msg, ['plate not found', 'vehicle not found', 'invalid plate'])) {
      return 'Vehicle not found. Please check the plate number and try again.';
    }
    if (_hasKeyword(msg, ['discount', 'promo', 'coupon', 'invalid code'])) {
      return 'Promo code is invalid or has already been used.';
    }

    // ── HTTP status code fallbacks ────────────────────────────────────────
    return switch (code) {
      400 => _cleanServerMessage(e.message, fallback: 'Invalid request. Please check your details and try again.'),
      401 => 'Incorrect verification code. Please try again.',
      403 => 'Access denied. Please sign in again.',
      404 => 'Not found. Please check your details and try again.',
      408 || 504 => _timeout,
      409 => 'This already exists. Please check your details and try again.',
      422 => _cleanServerMessage(e.message, fallback: 'Your details could not be validated. Please check and try again.'),
      429 => 'Too many attempts. Please wait a moment and try again.',
      500 || 502 || 503 => 'Our servers are temporarily unavailable. Please try again later.',
      _ => _cleanServerMessage(e.message, fallback: 'Something went wrong. Please try again.'),
    };
  }

  // ─── Snackbar helpers ─────────────────────────────────────────────────────

  static void showError(BuildContext context, Object error) {
    _show(context, toMessage(error), isError: true);
  }

  static void showErrorMessage(BuildContext context, String message) {
    _show(context, message, isError: true);
  }

  static void showSuccess(BuildContext context, String message) {
    _show(context, message, isError: false);
  }

  static void _show(BuildContext context, String message, {required bool isError}) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: isError ? Colors.red.shade700 : const Color(0xFF1A2340),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          content: Row(
            children: [
              Icon(
                isError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
  }

  // ─── Private helpers ──────────────────────────────────────────────────────

  static const _noInternet =
      'No internet connection. Please check your network and try again.';
  static const _timeout =
      'Request timed out. Please check your connection and try again.';

  static bool _hasKeyword(String text, List<String> keywords) =>
      keywords.any((k) => text.contains(k));

  /// Returns the server message if it looks safe/short for users, else fallback.
  static String _cleanServerMessage(String message, {required String fallback}) {
    final trimmed = message.trim();
    // Show server message only if it's short and readable — not a stack trace or JSON blob
    if (trimmed.isNotEmpty && trimmed.length <= 120 && !trimmed.startsWith('{') &&
        !trimmed.contains('\n') && !trimmed.startsWith('HTTP ')) {
      final friendly = _capitalise(trimmed);
      return friendly.endsWith('.') ? friendly : '$friendly.';
    }
    return fallback;
  }

  static String _capitalise(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}
