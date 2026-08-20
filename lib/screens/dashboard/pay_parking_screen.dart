import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../blocs/app_bloc.dart';
import '../../blocs/app_event.dart';
import '../../blocs/app_state.dart';
import '../../core/error_handler.dart';
import '../../core/theme/app_colors.dart';
import '../../models/parking_session.dart';
import '../../models/vehicle.dart';
import '../../widgets/app_widgets.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/stk_confirmation_sheet.dart';

class PayParkingScreen extends StatefulWidget {
  const PayParkingScreen({super.key});

  @override
  State<PayParkingScreen> createState() => _PayParkingScreenState();
}

class _PayParkingScreenState extends State<PayParkingScreen> {
  static const Duration _routeSettleDelay = Duration(milliseconds: 300);

  final _plateController = TextEditingController();
  final _plateFocus = FocusNode();
  String? _lastShownSessionId;
  bool _waitingDialogVisible = false;
  bool _wasWaitingForPayment = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _plateFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _plateController.dispose();
    _plateFocus.dispose();
    super.dispose();
  }

  String get _plate => _plateController.text.trim().toUpperCase();

  Future<void> _waitForRouteToSettle() async {
    await WidgetsBinding.instance.endOfFrame;
    await Future<void>.delayed(_routeSettleDelay);
  }

  Future<void> _handleAppState(AppState state) async {
    if (state.isWaitingForPayment) {
      _wasWaitingForPayment = true;
      _showWaitingDialog();
      return;
    }

    await _hideWaitingDialog();
    if (!mounted) return;

    if (_wasWaitingForPayment &&
        state.selectedSession?.status == 'COMPLETED') {
      _wasWaitingForPayment = false;
      final session = state.selectedSession!;
      await _waitForRouteToSettle();
      if (mounted) _navigateToReceipt(session);
    } else {
      _wasWaitingForPayment = false;
    }

    final error = state.errorMessage;
    if (error != null && error.isNotEmpty) {
      ErrorHandler.showErrorMessage(context, error);
    }

    final status = state.statusMessage;
    if (error == null &&
        status != null &&
        status.isNotEmpty &&
        !state.isWaitingForPayment) {
      ErrorHandler.showSuccess(context, status);
    }

    final session = state.selectedSession;
    if (session != null &&
        session.id.isNotEmpty &&
        // Unsettled, not just running â€” the plate lookup now also returns
        // sessions the driver exited without paying.
        !session.isSettled &&
        !state.isWaitingForPayment &&
        _lastShownSessionId != session.id) {
      _lastShownSessionId = session.id;
      await _waitForRouteToSettle();
      if (mounted) _showSessionSheet(session);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AppBloc, AppState>(
      listenWhen: (previous, current) =>
          previous.selectedSession != current.selectedSession ||
          previous.isWaitingForPayment != current.isWaitingForPayment ||
          previous.errorMessage != current.errorMessage ||
          previous.statusMessage != current.statusMessage,
      listener: (context, state) {
        unawaited(_handleAppState(state));
      },

      child: AdaptiveStatusBar(
        child: Scaffold(
        backgroundColor: context.colors.pageGrey,
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
                  child: BlocBuilder<AppBloc, AppState>(
                    builder: (context, state) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          PageBackButton(
                            label: 'Pay parking',
                            onBack: () => Navigator.pop(context),
                          ),
                          const SizedBox(height: 12),
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
                                color: context.colors.textSecondary,
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
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
                decoration: BoxDecoration(
                  color: context.colors.surface,
                  border: Border(
                    top: BorderSide(color: context.colors.border),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 18,
                      offset: const Offset(0, -6),
                    ),
                  ],
                ),
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
      ),
    );
  }

  Widget _sectionLabel(String label, {bool compact = false}) {
    return Text(
      label,
      style: GoogleFonts.poppins(
        fontSize: compact ? 11 : 13,
        fontWeight: FontWeight.w700,
        color: compact ? context.colors.textSecondary : context.colors.textPrimary,
        letterSpacing: compact ? 0.8 : 0,
      ),
    );
  }

  InputDecoration _fieldDecoration({
    required IconData prefixIcon,
    String? hintText,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: GoogleFonts.poppins(
        color: context.colors.textMuted,
        fontSize: 14,
      ),
      prefixIcon: Icon(
        prefixIcon,
        color: context.colors.primary,
        size: 20,
      ),
      filled: true,
      fillColor: context.colors.inputFill,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: context.colors.inputBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: context.colors.inputBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: context.colors.primary, width: 1.8),
      ),
    );
  }

  Widget _plateCard() {
    return TextFormField(
      controller: _plateController,
      focusNode: _plateFocus,
      textCapitalization: TextCapitalization.characters,
      textAlign: TextAlign.center,
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9 ]')),
        LengthLimitingTextInputFormatter(10),
        TextInputFormatter.withFunction(
          (oldValue, newValue) => newValue.copyWith(
            text: newValue.text.toUpperCase(),
          ),
        ),
      ],
      style: GoogleFonts.poppins(
        fontSize: 20,
        fontWeight: FontWeight.w800,
        letterSpacing: 3,
        color: context.colors.textPrimary,
      ),
      decoration: _fieldDecoration(
        prefixIcon: Icons.directions_car_outlined,
        hintText: 'KAA 123A',
      ),
      onChanged: (_) => setState(() {}),
    );
  }

  Widget _orDivider() {
    return Row(
      children: [
        Expanded(child: Divider(color: context.colors.divider)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'or select your vehicle',
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: context.colors.textSecondary,
            ),
          ),
        ),
        Expanded(child: Divider(color: context.colors.divider)),
      ],
    );
  }

  Widget _vehicleTile(Vehicle vehicle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: () => _lookupPlate(vehicle.plateNumber),
          borderRadius: BorderRadius.circular(18),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: context.colors.border),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: context.colors.accentLight,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.directions_car_rounded,
                    color: context.colors.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 5,
                        children: [
                          Text(
                            vehicle.plateNumber,
                            style: GoogleFonts.poppins(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: context.colors.textPrimary,
                              letterSpacing: 0.5,
                            ),
                          ),
                          if (vehicle.autoPayEnabled) _autoPayBadge(),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${vehicle.make} ${vehicle.model}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: context.colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: context.colors.textMuted,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _autoPayBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: context.colors.accentLight,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.colors.accent.withValues(alpha: 0.35)),
      ),
      child: Text(
        'AutoPay',
        style: GoogleFonts.poppins(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: context.colors.primary,
        ),
      ),
    );
  }

  Widget _emptyVehicles() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.colors.border),
      ),
      child: Column(
        children: [
          Icon(
            Icons.directions_car_outlined,
            color: context.colors.textMuted,
            size: 30,
          ),
          const SizedBox(height: 10),
          Text(
            'No registered vehicles',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              color: context.colors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  void _findByTypedPlate() {
    final plate = _plate.replaceAll(' ', '');
    if (plate.length < 4) {
      ErrorHandler.showErrorMessage(context, 'Enter a valid vehicle plate number.');
      return;
    }
    _lookupPlate(plate);
  }

  void _lookupPlate(String plateNumber) {
    _lastShownSessionId = null;
    context.read<AppBloc>().add(ClearParkingSelection());
    context.read<AppBloc>().add(
          FindParkingSession(
            plateNumber.replaceAll(' ', '').toUpperCase(),
          ),
        );
  }

  void _showSessionSheet(ParkingSession session) {
    final plate = session.vehicle.plateNumber.isEmpty
        ? _plate
        : session.vehicle.plateNumber;
    final displayPlate = _formatPlate(plate);
    final colors = context.colors;

    showModalBottomSheet(
      context: context,
      // Sizes to the content (and scrolls past it) instead of being capped at
      // 9/16 of the screen, which clipped the Cancel button.
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(ctx).size.height * 0.9,
        ),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: colors.accentLight,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.local_parking_rounded,
                    color: colors.primary,
                    size: 28,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Session Found',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  displayPlate,
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: colors.primary,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${session.locationName} - ${_durationLabel(session)} - KES ${session.cost.toStringAsFixed(0)}',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: colors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: colors.background,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: colors.border),
                  ),
                  child: Column(
                    children: [
                      _billingRow(colors, 'Entry time', _formatDateTime(session.startTime)),
                      const SizedBox(height: 8),
                      _billingRow(colors, 'Grace period', '${session.gracePeriodMinutes} min free'),
                      const SizedBox(height: 8),
                      _billingRow(colors, 'Rate', 'KES ${session.ratePerHour}/hr'),
                      const SizedBox(height: 8),
                      _billingRow(colors, 'Billable hours', '${session.billableHours} billable hour(s)'),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                if (session.cost == 0)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: colors.accentLight,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: colors.mintBorder),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.check_circle_outline_rounded, color: colors.primary, size: 26),
                        const SizedBox(height: 6),
                        Text(
                          'Free Parking',
                          style: GoogleFonts.poppins(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: colors.primary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'No payment required for this session',
                          style: GoogleFonts.poppins(fontSize: 12, color: colors.textSecondary),
                        ),
                      ],
                    ),
                  )
                else
                  PrimaryButton(
                    text: 'Pay KES ${session.cost.toStringAsFixed(0)}',
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      unawaited(Future<void>(() async {
                        await _waitForRouteToSettle();
                        if (!mounted) return;
                        _showStkConfirmation(session);
                      }));
                    },
                  ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.poppins(color: colors.textSecondary),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showStkConfirmation(ParkingSession session) {
    showStkConfirmationSheet(
      context,
      session: session,
      plateOverride: _plate,
      routeSettleDelay: _routeSettleDelay,
    );
  }

  void _showWaitingDialog() {
    if (_waitingDialogVisible || !mounted) return;
    _waitingDialogVisible = true;
    final colors = context.colors;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: Dialog(
          backgroundColor: colors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 26, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: colors.primary),
                const SizedBox(height: 20),
                Text(
                  'Waiting for M-Pesa confirmation...',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Complete the prompt on your phone.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ).then((_) {
      _waitingDialogVisible = false;
    });
  }

  Future<void> _hideWaitingDialog() async {
    if (!_waitingDialogVisible || !mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
    _waitingDialogVisible = false;
    await _waitForRouteToSettle();
  }





  void _navigateToReceipt(ParkingSession session) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _PaymentReceiptPage(session: session),
      ),
    );
  }

  Widget _billingRow(AppColorsData colors, String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(fontSize: 12, color: colors.textSecondary),
        ),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: colors.textPrimary,
          ),
        ),
      ],
    );
  }

  String _formatDateTime(DateTime dt) {
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '$hh:$mm ${dt.day.toString().padLeft(2, '0')} ${months[dt.month - 1]}';
  }

  String _formatPlate(String value) => formatPlateDisplay(value);

  String _durationLabel(ParkingSession session) {
    int minutes;
    if (session.durationMinutes != null) {
      minutes = session.durationMinutes!;
    } else {
      // Normalise to UTC so local-time drift (Kenya = UTC+3) doesn't skew the display.
      DateTime toUtc(DateTime dt) => dt.isUtc
          ? dt
          : DateTime.utc(dt.year, dt.month, dt.day, dt.hour, dt.minute, dt.second);
      final start = toUtc(session.startTime);
      final end = toUtc(session.endTime ?? DateTime.now().toUtc());
      minutes = end.difference(start).inMinutes;
    }
    final hours = minutes ~/ 60;
    final remainder = minutes % 60;

    if (hours <= 0) return '${remainder}m';
    if (remainder <= 0) return '${hours}h';
    return '${hours}h ${remainder}m';
  }
}

class _PaymentReceiptPage extends StatelessWidget {
  final ParkingSession session;

  const _PaymentReceiptPage({required this.session});

  @override
  Widget build(BuildContext context) {
    final plateNumber = session.vehicle.plateNumber.isEmpty
        ? '-'
        : session.vehicle.plateNumber;
    final amount = session.amountPaid > 0 ? session.amountPaid : session.cost;
    final exitTime = session.endTime != null ? _fmt(session.endTime!) : '-';

    return Scaffold(
      backgroundColor: context.colors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),
              Container(
                width: 80,
                height: 80,
                decoration: const BoxDecoration(
                  color: Color(0xFFEFFBF4),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check_circle_rounded,
                  color: context.colors.success,
                  size: 48,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Payment Successful',
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: context.colors.textPrimary,
                ),
              ),
              const SizedBox(height: 28),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: context.colors.background,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: context.colors.border),
                ),
                child: Column(
                  children: [
                    _row(context, 'Plate number', plateNumber),
                    const SizedBox(height: 12),
                    _row(context, 'Location', session.locationName),
                    const SizedBox(height: 12),
                    if (session.discountAmount > 0) ...[
                      _row(
                        context,
                        'Promo discount',
                        '- KES ${session.discountAmount.toStringAsFixed(0)}',
                      ),
                      const SizedBox(height: 12),
                    ],
                    _row(context, 'Amount paid', 'KES ${amount.toStringAsFixed(0)}'),
                    const SizedBox(height: 12),
                    _row(context, 'Exit time', exitTime),
                  ],
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () =>
                      Navigator.of(context).popUntil((r) => r.isFirst),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context.colors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    'Done',
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
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

  Widget _row(BuildContext context, String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(fontSize: 13, color: context.colors.textSecondary),
        ),
        Flexible(
          child: Text(
            value,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.end,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: context.colors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }

  String _fmt(DateTime dt) {
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '$hh:$mm ${dt.day.toString().padLeft(2, '0')} ${months[dt.month - 1]}';
  }
}

/// The M-Pesa confirmation sheet.
///
/// A real StatefulWidget rather than a StatefulBuilder over externally-owned
/// controllers: the route's popped future completes when the pop *starts*, so
/// disposing the controllers there killed them while the sheet was still
/// mounted and animating out. The retracting keyboard then rebuilt the fields
/// against disposed controllers, which cascaded into a full-screen framework
/// assertion. Owning them here ties their lifetime to the sheet's own dispose.
