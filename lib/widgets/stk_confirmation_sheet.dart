import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../blocs/app_bloc.dart';
import '../blocs/app_event.dart';
import '../core/payment/payment_validation.dart';
import '../core/theme/app_colors.dart';
import '../models/parking_session.dart';
import '../screens/dashboard/promo_qr_scanner_screen.dart';

/// Groups a plate into the display form drivers expect (KBR 656Z).
String formatPlateDisplay(String value) {
  final compact = value.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toUpperCase();
  if (compact.length <= 3) return compact;
  if (compact.length <= 6) return '${compact.substring(0, 3)} ${compact.substring(3)}';
  return '${compact.substring(0, 3)} ${compact.substring(3, 6)}${compact.substring(6)}';
}

/// Opens the M-Pesa confirmation sheet for [session] and dispatches the
/// checkout once the driver confirms. Shared by the pay-parking flow and the
/// dashboard's active-session widget so both prompt identically.
void showStkConfirmationSheet(
  BuildContext context, {
  required ParkingSession session,
  String? plateOverride,
  Duration routeSettleDelay = const Duration(milliseconds: 300),
}) {
  final bloc = context.read<AppBloc>();
  final plateNumber = session.vehicle.plateNumber.isEmpty
      ? (plateOverride ?? '')
      : session.vehicle.plateNumber;
  final location = session.locationName;

  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (ctx) => StkConfirmationSheet(
      displayPlate: formatPlateDisplay(plateNumber),
      location: location,
      initialPhone: bloc.state.phoneNumber ?? '',
      initialAmount: session.cost,
      onConfirm: (phone, amount, promoCode) {
        final event = PayParkingSession(
          sessionId: session.id,
          useWallet: true,
          phoneNumber: phone,
          amount: promoCode.isEmpty ? amount : null,
          plateNumber: plateNumber,
          location: location,
          promoCode: promoCode.isEmpty ? null : promoCode,
        );
        Navigator.of(ctx).pop();
        unawaited(Future<void>(() async {
          // Let the sheet finish dismissing before the waiting dialog opens.
          await WidgetsBinding.instance.endOfFrame;
          await Future<void>.delayed(routeSettleDelay);
          bloc.add(event);
        }));
      },
    ),
  );
}

class StkConfirmationSheet extends StatefulWidget {
  final String displayPlate;
  final String location;
  final String initialPhone;
  final double initialAmount;
  final void Function(String phone, double amount, String promoCode) onConfirm;

  const StkConfirmationSheet({
    super.key,
    required this.displayPlate,
    required this.location,
    required this.initialPhone,
    required this.initialAmount,
    required this.onConfirm,
  });

  @override
  State<StkConfirmationSheet> createState() => _StkConfirmationSheetState();
}

class _StkConfirmationSheetState extends State<StkConfirmationSheet> {
  final _formKey = GlobalKey<FormState>();
  final _promoCtrl = TextEditingController();
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _amountCtrl;

  @override
  void initState() {
    super.initState();
    _phoneCtrl = TextEditingController(text: widget.initialPhone);
    _amountCtrl = TextEditingController(
      text: widget.initialAmount > 0
          ? widget.initialAmount.toStringAsFixed(0)
          : '',
    );
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _amountCtrl.dispose();
    _promoCtrl.dispose();
    super.dispose();
  }

  Future<void> _scanPromoCode() async {
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => const PromoQrScannerScreen(),
      ),
    );
    if (result == null || result.trim().isEmpty) return;
    if (!mounted) return;
    _promoCtrl.text = result.trim();
    setState(() {});
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    widget.onConfirm(
      _phoneCtrl.text.trim(),
      double.tryParse(_amountCtrl.text.trim()) ?? 0,
      _promoCtrl.text.trim(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final hasPromo = _promoCtrl.text.trim().isNotEmpty;
    final enteredAmt = double.tryParse(_amountCtrl.text.trim());
    final sendLabel = hasPromo
        ? 'Apply promo & send M-Pesa prompt'
        : enteredAmt != null && enteredAmt > 0
        ? 'Send KES ${enteredAmt.toStringAsFixed(0)} via M-Pesa'
        : 'Send prompt';

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          24,
          24,
          24,
          24 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
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

              // Title row
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFFBF4),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      Icons.phone_android_rounded,
                      color: colors.success,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'M-Pesa prompt',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: colors.textPrimary,
                        ),
                      ),
                      Text(
                        'Edit details then confirm',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 22),

              // Plate info (read-only pill)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Plate number',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: colors.textSecondary,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: colors.accentLight,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: colors.accent.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      widget.displayPlate,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: colors.primary,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Location',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: colors.textSecondary,
                    ),
                  ),
                  Flexible(
                    child: Text(
                      widget.location,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: colors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // M-Pesa number field
              Text(
                'M-Pesa number',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: colors.textPrimary,
                ),
                decoration: InputDecoration(
                  hintText: '07XX XXX XXX',
                  hintStyle: GoogleFonts.poppins(
                    color: colors.textMuted,
                    fontSize: 15,
                  ),
                  prefixIcon: Icon(
                    Icons.phone_outlined,
                    color: colors.primary,
                    size: 20,
                  ),
                  filled: true,
                  fillColor: colors.inputFill,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: colors.inputBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: colors.inputBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: colors.primary,
                      width: 1.8,
                    ),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: colors.error),
                  ),
                  focusedErrorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: colors.error,
                      width: 1.8,
                    ),
                  ),
                ),
                onChanged: (_) => setState(() {}),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Enter a phone number';
                  final normalized = PaymentValidation.normalizeMpesaPhone(v.trim());
                  if (normalized == null ||
                      !RegExp(r'^254(7|1)\d{8}$').hasMatch(normalized)) {
                    return 'Enter a valid Kenyan M-Pesa number (07XX or 01XX)';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Amount field
              Text(
                'Amount (KES)',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _amountCtrl,
                readOnly: true,
                keyboardType: const TextInputType.numberWithOptions(decimal: false),
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: colors.textPrimary,
                ),
                decoration: InputDecoration(
                  hintText: '0',
                  hintStyle: GoogleFonts.poppins(
                    color: colors.textMuted,
                    fontSize: 15,
                  ),
                  prefixText: 'KES  ',
                  prefixStyle: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: colors.primary,
                  ),
                  filled: true,
                  fillColor: colors.inputFill,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: colors.inputBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: colors.inputBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: colors.primary,
                      width: 1.8,
                    ),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: colors.error),
                  ),
                  focusedErrorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: colors.error,
                      width: 1.8,
                    ),
                  ),
                ),
                onChanged: (_) => setState(() {}),
                validator: (v) {
                  if (hasPromo) return null;
                  final val = double.tryParse(v?.trim() ?? '');
                  if (val == null || val <= 0) return 'Enter a valid amount';
                  return null;
                },
              ),
              const SizedBox(height: 8),
              Text(
                'Promo code',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _promoCtrl,
                      textCapitalization: TextCapitalization.characters,
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: colors.textPrimary,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Optional promo code',
                        hintStyle: GoogleFonts.poppins(
                          color: colors.textMuted,
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                        ),
                        prefixIcon: Icon(
                          Icons.confirmation_number_outlined,
                          color: colors.primary,
                          size: 20,
                        ),
                        suffixIcon: !hasPromo
                            ? null
                            : IconButton(
                                tooltip: 'Clear promo code',
                                icon: Icon(
                                  Icons.close_rounded,
                                  color: colors.textMuted,
                                  size: 18,
                                ),
                                onPressed: () {
                                  _promoCtrl.clear();
                                  setState(() {});
                                },
                              ),
                        filled: true,
                        fillColor: colors.inputFill,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: colors.inputBorder),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: colors.inputBorder),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: colors.primary,
                            width: 1.8,
                          ),
                        ),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    height: 52,
                    width: 52,
                    child: OutlinedButton(
                      onPressed: _scanPromoCode,
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.zero,
                        foregroundColor: colors.primary,
                        side: BorderSide(color: colors.inputBorder),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Icon(
                        Icons.qr_code_scanner_rounded,
                        size: 22,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                hasPromo
                    ? 'Promo will be validated before checkout.'
                    : 'Optional. Scan a promo QR code or enter the code from your tenant.',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: hasPromo ? colors.primary : colors.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'A payment prompt will be sent to the number above.',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: colors.textSecondary,
                ),
              ),
              const SizedBox(height: 24),

              // Send button label updates live with entered amount.
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton.icon(
                  onPressed: _submit,
                  icon: const Icon(Icons.bolt_outlined, size: 19),
                  label: Text(
                    sendLabel,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.poppins(
                      color: colors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
