import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../blocs/app_bloc.dart';
import '../../blocs/app_event.dart';
import '../../blocs/app_state.dart';
import '../../core/theme/app_colors.dart';
import '../../models/parking_session.dart';
import '../../models/vehicle.dart';
import '../../widgets/primary_button.dart';

class PayParkingScreen extends StatefulWidget {
  const PayParkingScreen({super.key});

  @override
  State<PayParkingScreen> createState() => _PayParkingScreenState();
}

class _PayParkingScreenState extends State<PayParkingScreen> {
  static const int _plateLength = 7;

  late final List<TextEditingController> _controllers;
  late final List<FocusNode> _focusNodes;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(_plateLength, (_) => TextEditingController());
    _focusNodes = List.generate(_plateLength, (_) => FocusNode());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNodes.first.requestFocus();
    });
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    for (final node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  String get _plate => _controllers.map((c) => c.text.toUpperCase()).join();

  bool _isLetter(int index) => index < 3 || index == 6;

  @override
  Widget build(BuildContext context) {
    return BlocListener<AppBloc, AppState>(
      listenWhen: (previous, current) =>
          previous.selectedSession != current.selectedSession ||
          previous.errorMessage != current.errorMessage ||
          previous.statusMessage != current.statusMessage,
      listener: (context, state) {
        final error = state.errorMessage;
        if (error != null && error.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: Colors.red.shade700,
              behavior: SnackBarBehavior.floating,
              content: Text(
                error,
                style: GoogleFonts.poppins(color: Colors.white),
              ),
            ),
          );
        }

        final status = state.statusMessage;
        if (status != null && status.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppColors.primaryDark,
              behavior: SnackBarBehavior.floating,
              content: Text(
                status,
                style: GoogleFonts.poppins(color: Colors.white),
              ),
            ),
          );
        }

        final session = state.selectedSession;
        if (session != null && session.id.isNotEmpty) {
          _showSessionSheet(session);
        }
      },

      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Column(
            children: [
              _header(context),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                  child: BlocBuilder<AppBloc, AppState>(
                    builder: (context, state) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _sectionLabel('Vehicle Plate Number'),
                          const SizedBox(height: 12),
                          _plateCard(),
                          const SizedBox(height: 10),
                          Center(
                            child: Text(
                              'Type the plate number exactly as shown on the vehicle',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          _orDivider(),
                          const SizedBox(height: 20),
                          _sectionLabel('MY REGISTERED VEHICLES', compact: true),
                          const SizedBox(height: 10),
                          if (state.vehicles.isEmpty)
                            _emptyVehicles()
                          else
                            ...state.vehicles.map(_vehicleTile),
                          const SizedBox(height: 100),
                        ],
                      );
                    },
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                child: BlocBuilder<AppBloc, AppState>(
                  builder: (context, state) {
                    return PrimaryButton(
                      text: 'Find Parking Session',
                      isLoading: state.isLoading,
                      onPressed: state.isLoading ? null : _findByTypedPlate,
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

  Widget _header(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFF4F6F5),
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.border),
              ),
              child: const Icon(
                Icons.arrow_back_rounded,
                size: 18,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Pay Parking',
                style: GoogleFonts.poppins(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                'Enter plate to initiate payment',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String label, {bool compact = false}) {
    return Text(
      label,
      style: GoogleFonts.poppins(
        fontSize: compact ? 11 : 13,
        fontWeight: FontWeight.w700,
        color: compact ? AppColors.textSecondary : AppColors.textPrimary,
        letterSpacing: compact ? 0.8 : 0,
      ),
    );
  }

  Widget _plateCard() {
    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF59E0B), width: 2),
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8),
            color: AppColors.plateYellow,
            child: Center(
              child: Text(
                'K E N Y A',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: 4,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 18),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_plateLength, (index) {
                  return Row(
                    children: [
                      _plateBox(index),
                      if (index == 2) const SizedBox(width: 14),
                    ],
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _plateBox(int index) {
    return Container(
      width: 40,
      height: 52,
      margin: const EdgeInsets.symmetric(horizontal: 3),
      child: TextFormField(
        controller: _controllers[index],
        focusNode: _focusNodes[index],
        textAlign: TextAlign.center,
        textCapitalization: TextCapitalization.characters,
        maxLength: 1,
        inputFormatters: [
          FilteringTextInputFormatter.allow(
            _isLetter(index) ? RegExp(r'[a-zA-Z]') : RegExp(r'[0-9]'),
          ),
        ],
        style: GoogleFonts.poppins(
          fontSize: 24,
          fontWeight: FontWeight.w800,
          color: AppColors.textPrimary,
        ),
        decoration: InputDecoration(
          counterText: '',
          filled: true,
          fillColor: Colors.white,
          contentPadding: EdgeInsets.zero,
          border: _plateBorder(const Color(0xFFF59E0B), 1.5),
          enabledBorder: _plateBorder(const Color(0xFFF59E0B), 1.5),
          focusedBorder: _plateBorder(AppColors.primaryDark, 2.5),
        ),
        onChanged: (value) {
          if (value.isNotEmpty && index < _plateLength - 1) {
            _focusNodes[index + 1].requestFocus();
          }
          setState(() {});
        },
      ),
    );
  }

  OutlineInputBorder _plateBorder(Color color, double width) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: color, width: width),
    );
  }

  Widget _orDivider() {
    return Row(
      children: [
        const Expanded(child: Divider(color: Color(0xFFE0E8E4))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'or select your vehicle',
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        const Expanded(child: Divider(color: Color(0xFFE0E8E4))),
      ],
    );
  }

  Widget _vehicleTile(Vehicle vehicle) {
    return GestureDetector(
      onTap: () => _lookupPlate(vehicle.plateNumber),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.accentLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.directions_car_rounded,
                color: AppColors.primary,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        vehicle.plateNumber,
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (vehicle.autoPayEnabled) _autoPayBadge(),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${vehicle.make} ${vehicle.model}',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textMuted,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _autoPayBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.accentLight,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.35)),
      ),
      child: Text(
        'AutoPay',
        style: GoogleFonts.poppins(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: AppColors.primary,
        ),
      ),
    );
  }

  Widget _emptyVehicles() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Center(
        child: Text(
          'No registered vehicles',
          style: GoogleFonts.poppins(
            color: AppColors.textSecondary,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  void _findByTypedPlate() {
    if (_plate.length < _plateLength) return;
    _lookupPlate(_plate);
  }

  void _lookupPlate(String plateNumber) {
    context.read<AppBloc>().add(ClearParkingSelection());
    context.read<AppBloc>().add(
          FindParkingSession(plateNumber.replaceAll(' ', '').toUpperCase()),
        );
  }

  void _showSessionSheet(ParkingSession session) {
    final plate = session.vehicle.plateNumber.isEmpty
        ? _plate
        : session.vehicle.plateNumber;
    final displayPlate = _formatPlate(plate);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.accentLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.local_parking_rounded,
                color: AppColors.primary,
                size: 28,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Session Found',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              displayPlate,
              style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${session.locationName} · ${_durationLabel(session)} · KES ${session.cost.toStringAsFixed(0)}',
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            PrimaryButton(
              text: 'Pay KES ${session.cost.toStringAsFixed(0)}',
              onPressed: () {
                Navigator.pop(context);
                _showStkConfirmation(session);
              },
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: GoogleFonts.poppins(color: AppColors.textSecondary),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showStkConfirmation(ParkingSession session) {
    final appState = context.read<AppBloc>().state;
    final initialPhone = appState.phoneNumber ?? '';
    final initialAmount = session.cost > 0 ? session.cost : (session.amountPaid > 0 ? session.amountPaid : 0.0);
    final displayPlate = _formatPlate(
      session.vehicle.plateNumber.isEmpty ? _plate : session.vehicle.plateNumber,
    );

    final phoneCtrl = TextEditingController(text: initialPhone);
    final amountCtrl = TextEditingController(
      text: initialAmount > 0 ? initialAmount.toStringAsFixed(0) : '',
    );
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          void submit() {
            if (!formKey.currentState!.validate()) return;
            final phone = phoneCtrl.text.trim();
            final amount = double.tryParse(amountCtrl.text.trim()) ?? 0;
            context.read<AppBloc>().add(
                  PayParkingSession(
                    sessionId: session.id,
                    useWallet: true,
                    phoneNumber: phone,
                    amount: amount,
                  ),
                );
            Navigator.of(ctx).pop();
            Navigator.pop(context);
          }

          return SingleChildScrollView(
            // Scrolls up when keyboard appears — prevents overflow
            padding: EdgeInsets.fromLTRB(
              24,
              24,
              24,
              24 + MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: Form(
              key: formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.border,
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
                        child: const Icon(
                          Icons.phone_android_rounded,
                          color: AppColors.success,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'M-Pesa STK Push',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            'Edit details then confirm',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: AppColors.textSecondary,
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
                          color: AppColors.textSecondary,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.accentLight,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppColors.accent.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          displayPlate,
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                            letterSpacing: 1,
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
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: phoneCtrl,
                    keyboardType: TextInputType.phone,
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                    ),
                    decoration: InputDecoration(
                      hintText: '07XX XXX XXX',
                      hintStyle: GoogleFonts.poppins(
                        color: AppColors.textMuted,
                        fontSize: 15,
                      ),
                      prefixIcon: const Icon(
                        Icons.phone_outlined,
                        color: AppColors.primary,
                        size: 20,
                      ),
                      filled: true,
                      fillColor: AppColors.inputFill,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: AppColors.inputBorder),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: AppColors.inputBorder),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(
                          color: AppColors.primary,
                          width: 1.8,
                        ),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: AppColors.error),
                      ),
                      focusedErrorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(
                          color: AppColors.error,
                          width: 1.8,
                        ),
                      ),
                    ),
                    onChanged: (_) => setSheetState(() {}),
                    validator: (v) {
                      final digits = v?.replaceAll(RegExp(r'\D'), '') ?? '';
                      if (digits.isEmpty) return 'Enter a phone number';
                      if (digits.length < 9 || digits.length > 12) {
                        return 'Enter a valid Kenyan number';
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
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: amountCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: false),
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                    ),
                    decoration: InputDecoration(
                      hintText: '0',
                      hintStyle: GoogleFonts.poppins(
                        color: AppColors.textMuted,
                        fontSize: 15,
                      ),
                      prefixText: 'KES  ',
                      prefixStyle: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                      filled: true,
                      fillColor: AppColors.inputFill,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: AppColors.inputBorder),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: AppColors.inputBorder),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(
                          color: AppColors.primary,
                          width: 1.8,
                        ),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: AppColors.error),
                      ),
                      focusedErrorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(
                          color: AppColors.error,
                          width: 1.8,
                        ),
                      ),
                    ),
                    onChanged: (_) => setSheetState(() {}),
                    validator: (v) {
                      final val = double.tryParse(v?.trim() ?? '');
                      if (val == null || val <= 0) return 'Enter a valid amount';
                      return null;
                    },
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'A payment prompt will be sent to the number above.',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Send button — label updates live with entered amount
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton.icon(
                      onPressed: submit,
                      icon: const Icon(Icons.bolt_outlined, size: 19),
                      label: Builder(
                        builder: (_) {
                          final enteredAmt = double.tryParse(amountCtrl.text.trim());
                          final label = enteredAmt != null && enteredAmt > 0
                              ? 'Send KES ${enteredAmt.toStringAsFixed(0)} via M-Pesa'
                              : 'Send STK Push';
                          return Text(
                            label,
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          );
                        },
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
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
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: Text(
                        'Cancel',
                        style: GoogleFonts.poppins(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          );
        },
      ),
    ).then((_) {
      // Safe disposal — only runs after the sheet is fully closed
      phoneCtrl.dispose();
      amountCtrl.dispose();
    });
  }





  String _formatPlate(String value) {
    final compact = value.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toUpperCase();
    if (compact.length <= 3) return compact;
    if (compact.length <= 6) return '${compact.substring(0, 3)} ${compact.substring(3)}';
    return '${compact.substring(0, 3)} ${compact.substring(3, 6)}${compact.substring(6)}';
  }

  String _durationLabel(ParkingSession session) {
    final minutes = session.durationMinutes ??
        (session.endTime ?? DateTime.now()).difference(session.startTime).inMinutes;
    final hours = minutes ~/ 60;
    final remainder = minutes % 60;

    if (hours <= 0) return '${remainder}m';
    if (remainder <= 0) return '${hours}h';
    return '${hours}h ${remainder}m';
  }
}
