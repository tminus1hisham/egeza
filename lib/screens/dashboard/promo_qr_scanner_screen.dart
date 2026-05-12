import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/theme/app_colors.dart';

class PromoQrScannerScreen extends StatefulWidget {
  const PromoQrScannerScreen({super.key});

  @override
  State<PromoQrScannerScreen> createState() => _PromoQrScannerScreenState();
}

class _PromoQrScannerScreenState extends State<PromoQrScannerScreen> {
  late final MobileScannerController _controller;
  bool _handled = false;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      formats: const [BarcodeFormat.qrCode],
      detectionSpeed: DetectionSpeed.noDuplicates,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleCapture(BarcodeCapture capture) {
    if (_handled) return;
    for (final barcode in capture.barcodes) {
      final rawValue = barcode.rawValue;
      if (rawValue == null || rawValue.trim().isEmpty) continue;
      final promoCode = promoCodeFromScanValue(rawValue);
      if (promoCode.isEmpty) continue;
      _handled = true;
      Navigator.of(context).pop(promoCode);
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _handleCapture,
            errorBuilder: (context, error) => Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Text(
                  'Camera unavailable. Enter the promo code manually.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Row(
                    children: [
                      _roundIconButton(
                        icon: Icons.close_rounded,
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      const Spacer(),
                      _roundIconButton(
                        icon: Icons.flash_on_rounded,
                        onPressed: () => _controller.toggleTorch(),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.58),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.18),
                      ),
                    ),
                    child: Text(
                      'Place the promo QR code inside the frame.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Center(
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.accent, width: 3),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _roundIconButton({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return Material(
      color: Colors.black.withValues(alpha: 0.55),
      shape: const CircleBorder(),
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, color: Colors.white),
      ),
    );
  }
}

String promoCodeFromScanValue(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return '';

  try {
    final decoded = jsonDecode(trimmed);
    if (decoded is Map<String, dynamic>) {
      for (final key in _promoCodeKeys) {
        final code = jsonString(decoded[key]);
        if (code != null) return code.trim();
      }
    }
  } catch (_) {
    // Not JSON. Continue with URL/plain text parsing.
  }

  final uri = Uri.tryParse(trimmed);
  if (uri != null) {
    for (final key in _promoCodeKeys) {
      final code = uri.queryParameters[key];
      if (code != null && code.trim().isNotEmpty) return code.trim();
    }
  }

  return trimmed;
}

const _promoCodeKeys = {
  'code',
  'promo',
  'promoCode',
  'voucher',
  'voucherCode',
  'discountCode',
};

String? jsonString(Object? value) {
  if (value == null) return null;
  final text = value.toString();
  return text.trim().isEmpty ? null : text;
}
