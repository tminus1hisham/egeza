import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../blocs/app_bloc.dart';
import '../blocs/app_event.dart';
import '../core/theme/app_colors.dart';
import '../models/parking_session.dart';
import '../models/session_promo_hold.dart';
import '../screens/dashboard/promo_qr_scanner_screen.dart';
import 'stk_confirmation_sheet.dart' show formatPlateDisplay;

/// Opens the promo sheet for an AutoPay session and dispatches the redemption
/// once the driver confirms.
///
/// This is the AutoPay counterpart to `showStkConfirmationSheet`: the driver
/// already asked not to be prompted for money, so the only thing on offer here
/// is the code.
void showPromoCodeSheet(
  BuildContext context, {
  required ParkingSession session,
  String? plateOverride,
  Duration routeSettleDelay = const Duration(milliseconds: 300),
}) {
  final bloc = context.read<AppBloc>();
  final plateNumber = session.vehicle.plateNumber.isEmpty
      ? (plateOverride ?? '')
      : session.vehicle.plateNumber;

  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (ctx) => PromoCodeSheet(
      displayPlate: formatPlateDisplay(plateNumber),
      location: session.locationName,
      billAmount: session.cost,
      onConfirm: (code) {
        final event = ApplySessionPromo(sessionId: session.id, code: code);
        Navigator.of(ctx).pop();
        unawaited(Future<void>(() async {
          // Let the sheet finish dismissing before any snackbar lands.
          await WidgetsBinding.instance.endOfFrame;
          await Future<void>.delayed(routeSettleDelay);
          bloc.add(event);
        }));
      },
    ),
  );
}

class PromoCodeSheet extends StatefulWidget {
  final String displayPlate;
  final String location;
  final double billAmount;
  final void Function(String code) onConfirm;

  const PromoCodeSheet({
    super.key,
    required this.displayPlate,
    required this.location,
    required this.billAmount,
    required this.onConfirm,
  });

  @override
  State<PromoCodeSheet> createState() => _PromoCodeSheetState();
}

class _PromoCodeSheetState extends State<PromoCodeSheet> {
  final _formKey = GlobalKey<FormState>();
  final _promoCtrl = TextEditingController();

  @override
  void dispose() {
    _promoCtrl.dispose();
    super.dispose();
  }

  Future<void> _scanPromoCode() async {
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const PromoQrScannerScreen()),
    );
    if (result == null || result.trim().isEmpty) return;
    if (!mounted) return;
    _promoCtrl.text = result.trim().toUpperCase();
    setState(() {});
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    widget.onConfirm(_promoCtrl.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final hasPromo = _promoCtrl.text.trim().isNotEmpty;
    final billLabel = widget.billAmount > 0
        ? 'KES ${widget.billAmount.toStringAsFixed(0)}'
        : 'Free';
    final holdHours = SessionPromoHold.holdDuration.inHours;

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

              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: colors.accentLight,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      Icons.confirmation_number_outlined,
                      color: colors.primary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Use promo',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: colors.textPrimary,
                          ),
                        ),
                        Text(
                          'AutoPay covers what the promo does not',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),

              _detailRow(
                'Plate number',
                child: Container(
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
              ),
              const SizedBox(height: 12),
              _detailRow('Location', value: widget.location),
              const SizedBox(height: 12),
              _detailRow('Bill so far', value: billLabel),
              const SizedBox(height: 18),

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
                      autofocus: true,
                      textCapitalization: TextCapitalization.characters,
                      validator: (value) =>
                          (value == null || value.trim().isEmpty)
                              ? 'Enter or scan a promo code'
                              : null,
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: colors.textPrimary,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Enter promo code',
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
                      child: const Icon(Icons.qr_code_scanner_rounded, size: 22),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // The rules, said plainly — a driver should not have to guess
              // what happens to the balance.
              Container(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                decoration: BoxDecoration(
                  color: colors.inputFill,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: colors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // _ruleLine(
                    //   context,
                    //   Icons.check_circle_outline_rounded,
                    //   'Covers the bill — nothing is charged and the code is used up.',
                    // ),
                    // const SizedBox(height: 8),
                    // _ruleLine(
                    //   context,
                    //   Icons.account_balance_wallet_outlined,
                    //   'Falls short — AutoPay settles the rest at exit.',
                    // ),
                    const SizedBox(height: 4),
                    _ruleLine(
                      context,
                      Icons.schedule_rounded,
                      'An applied promo holds for $holdHours hour'
                      '${holdHours == 1 ? '' : 's'}, then lapses.',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton.icon(
                  onPressed: _submit,
                  icon: const Icon(Icons.local_offer_outlined, size: 19),
                  label: Text(
                    'Apply promo code',
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
              Center(
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: colors.textSecondary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(String label, {String? value, Widget? child}) {
    final colors = context.colors;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 13,
            color: colors.textSecondary,
          ),
        ),
        if (child != null)
          child
        else
          Flexible(
            child: Text(
              value ?? '',
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: colors.textPrimary,
              ),
            ),
          ),
      ],
    );
  }
}

Widget _ruleLine(BuildContext context, IconData icon, String text) {
  final colors = context.colors;

  return Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 15, color: colors.textSecondary),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          text,
          style: GoogleFonts.poppins(
            fontSize: 12,
            height: 1.35,
            color: colors.textSecondary,
          ),
        ),
      ),
    ],
  );
}
