import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../blocs/app_bloc.dart';
import '../../blocs/app_event.dart';
import '../../blocs/app_state.dart';
import '../../core/theme/app_colors.dart';
import '../../core/payment/payment_validation.dart';
import '../../models/parking_session.dart';
import '../../models/vehicle.dart';
import '../../widgets/app_widgets.dart';
import '../../widgets/primary_button.dart';

class PayParkingScreen extends StatefulWidget {
  const PayParkingScreen({super.key});

  @override
  State<PayParkingScreen> createState() => _PayParkingScreenState();
}

class _PayParkingScreenState extends State<PayParkingScreen> {
  static const int _plateLength = 7;

  final _locationController = TextEditingController();
  late final List<TextEditingController> _controllers;
  late final List<FocusNode> _focusNodes;
  String? _selectedLocationId;
  String? _lastShownSessionId;
  bool _waitingDialogVisible = false;
  bool _wasWaitingForPayment = false;

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
    _locationController.dispose();
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
          previous.isWaitingForPayment != current.isWaitingForPayment ||
          previous.errorMessage != current.errorMessage ||
          previous.statusMessage != current.statusMessage,
      listener: (context, state) {
        if (state.isWaitingForPayment) {
          _wasWaitingForPayment = true;
          _showWaitingDialog();
        } else {
          _hideWaitingDialog();
          if (_wasWaitingForPayment &&
              state.selectedSession?.status == 'COMPLETED') {
            _wasWaitingForPayment = false;
            final session = state.selectedSession!;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _navigateToReceipt(session);
            });
          } else {
            _wasWaitingForPayment = false;
          }
        }

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
        if (status != null && status.isNotEmpty && !state.isWaitingForPayment) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: context.colors.primaryDark,
              behavior: SnackBarBehavior.floating,
              content: Text(
                status,
                style: GoogleFonts.poppins(color: Colors.white),
              ),
            ),
          );
        }

        final session = state.selectedSession;
        if (session != null &&
            session.id.isNotEmpty &&
            session.isActive &&
            !state.isWaitingForPayment &&
            _lastShownSessionId != session.id) {
          _lastShownSessionId = session.id;
          _showSessionSheet(session);
        }
      },

      child: Scaffold(
        backgroundColor: context.colors.background,
        body: SafeArea(
          child: Column(
            children: [
              _header(context),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
                  child: BlocBuilder<AppBloc, AppState>(
                    builder: (context, state) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _sectionLabel('Parking Location'),
                          const SizedBox(height: 12),
                          _locationField(state),
                          const SizedBox(height: 20),
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
    );
  }

  Widget _header(BuildContext context) {
    return AppPageHeader(
      title: 'Pay Parking',
      subtitle: 'Enter plate to initiate payment',
      icon: Icons.local_parking_rounded,
      showBackButton: true,
      showIconWithBack: true,
      onBack: () => Navigator.pop(context),
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

  Widget _locationField(AppState state) {
    final locations = state.locations;
    if (locations.isNotEmpty) {
      final selectedValue = locations.any((item) => item.name == _locationController.text)
          ? _locationController.text
          : null;

      return DropdownButtonFormField<String>(
        initialValue: selectedValue,
        isExpanded: true,
        hint: Text(
          'Select parking location',
          style: GoogleFonts.poppins(
            fontSize: 14,
            color: context.colors.textMuted,
          ),
        ),
        decoration: _fieldDecoration(
          prefixIcon: Icons.location_on_outlined,
        ),
        items: [
          for (final location in locations)
            DropdownMenuItem<String>(
              value: location.name,
              child: Text(
                location.name,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: context.colors.textPrimary,
                ),
              ),
            ),
        ],
        onChanged: (value) {
          if (value == null) return;
          final selected = locations.firstWhere((item) => item.name == value);
          setState(() {
            _locationController.text = selected.name;
            _selectedLocationId = selected.id.isEmpty ? null : selected.id;
          });
        },
      );
    }

    return TextFormField(
      controller: _locationController,
      textCapitalization: TextCapitalization.words,
      style: GoogleFonts.poppins(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: context.colors.textPrimary,
      ),
      decoration: _fieldDecoration(
        prefixIcon: Icons.location_on_outlined,
        hintText: 'CBD Parking Zone A',
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
    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: context.colors.plateBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.colors.plateYellow, width: 2),
        boxShadow: [
          BoxShadow(
            color: context.colors.plateYellow.withValues(alpha: 0.16),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 9),
            color: context.colors.plateYellow,
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
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 19),
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
          color: context.colors.textPrimary,
        ),
        decoration: InputDecoration(
          counterText: '',
          filled: true,
          fillColor: context.colors.surface,
          contentPadding: EdgeInsets.zero,
          border: _plateBorder(context.colors.plateYellow, 1.4),
          enabledBorder: _plateBorder(context.colors.plateYellow, 1.4),
          focusedBorder: _plateBorder(context.colors.primaryDark, 2.5),
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
    if (_plate.length < _plateLength) return;
    _lookupPlate(_plate);
  }

  void _lookupPlate(String plateNumber) {
    final location = _locationController.text.trim();
    if (location.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          content: Text(
            'Select or enter the parking location',
            style: GoogleFonts.poppins(color: Colors.white),
          ),
        ),
      );
      return;
    }

    _lastShownSessionId = null;
    context.read<AppBloc>().add(ClearParkingSelection());
    context.read<AppBloc>().add(
          FindParkingSession(
            plateNumber.replaceAll(' ', '').toUpperCase(),
            location: location,
            locationId: _selectedLocationId,
          ),
        );
  }

  void _showSessionSheet(ParkingSession session) {
    final plate = session.vehicle.plateNumber.isEmpty
        ? _plate
        : session.vehicle.plateNumber;
    final displayPlate = _formatPlate(plate);

    showModalBottomSheet(
      context: context,
      backgroundColor: context.colors.surface,
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
                color: context.colors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: context.colors.accentLight,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.local_parking_rounded,
                color: context.colors.primary,
                size: 28,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Session Found',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: context.colors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              displayPlate,
              style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: context.colors.primary,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${session.locationName} - ${_durationLabel(session)} - KES ${session.cost.toStringAsFixed(0)}',
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: context.colors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: context.colors.background,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: context.colors.border),
              ),
              child: Column(
                children: [
                  _billingRow('Entry time', _formatDateTime(session.startTime)),
                  const SizedBox(height: 8),
                  _billingRow('Grace period', '${session.gracePeriodMinutes} min free'),
                  const SizedBox(height: 8),
                  _billingRow('Rate', 'KES ${session.ratePerHour}/hr'),
                  const SizedBox(height: 8),
                  _billingRow('Billable hours', '${session.billableHours} billable hour(s)'),
                ],
              ),
            ),
            const SizedBox(height: 28),
            PrimaryButton(
              text: session.cost <= 0
                  ? 'No Payment Due'
                  : 'Pay KES ${session.cost.toStringAsFixed(0)}',
              onPressed: () {
                Navigator.pop(context);
                if (session.cost <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: context.colors.primaryDark,
                      behavior: SnackBarBehavior.floating,
                      content: Text(
                        'No parking fee is due during the grace period',
                        style: GoogleFonts.poppins(color: Colors.white),
                      ),
                    ),
                  );
                } else {
                  _showStkConfirmation(session);
                }
              },
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: GoogleFonts.poppins(color: context.colors.textSecondary),
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
    final plateNumber =
        session.vehicle.plateNumber.isEmpty ? _plate : session.vehicle.plateNumber;
    final location = session.locationName == 'Parking Location'
        ? _locationController.text.trim()
        : session.locationName;

    final phoneCtrl = TextEditingController(text: initialPhone);
    final amountCtrl = TextEditingController(
      text: initialAmount > 0 ? initialAmount.toStringAsFixed(0) : '',
    );
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      backgroundColor: context.colors.surface,
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
                    plateNumber: plateNumber,
                    location: location,
                  ),
                );
            Navigator.of(ctx).pop();
            Navigator.pop(context);
          }

          return SingleChildScrollView(
            // Scrolls up when keyboard appears to prevent overflow.
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
                        color: context.colors.border,
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
                          color: context.colors.success,
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
                              color: context.colors.textPrimary,
                            ),
                          ),
                          Text(
                            'Edit details then confirm',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: context.colors.textSecondary,
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
                          color: context.colors.textSecondary,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: context.colors.accentLight,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: context.colors.accent.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          displayPlate,
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: context.colors.primary,
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
                          color: context.colors.textSecondary,
                        ),
                      ),
                      Flexible(
                        child: Text(
                          location,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: context.colors.textPrimary,
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
                      color: context.colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: phoneCtrl,
                    keyboardType: TextInputType.phone,
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: context.colors.textPrimary,
                    ),
                    decoration: InputDecoration(
                      hintText: '07XX XXX XXX',
                      hintStyle: GoogleFonts.poppins(
                        color: context.colors.textMuted,
                        fontSize: 15,
                      ),
                      prefixIcon: Icon(
                        Icons.phone_outlined,
                        color: context.colors.primary,
                        size: 20,
                      ),
                      filled: true,
                      fillColor: context.colors.inputFill,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
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
                        borderSide: BorderSide(
                          color: context.colors.primary,
                          width: 1.8,
                        ),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: context.colors.error),
                      ),
                      focusedErrorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(
                          color: context.colors.error,
                          width: 1.8,
                        ),
                      ),
                    ),
                    onChanged: (_) => setSheetState(() {}),
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
                      color: context.colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: amountCtrl,
                    readOnly: true,
                    keyboardType: const TextInputType.numberWithOptions(decimal: false),
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: context.colors.textPrimary,
                    ),
                    decoration: InputDecoration(
                      hintText: '0',
                      hintStyle: GoogleFonts.poppins(
                        color: context.colors.textMuted,
                        fontSize: 15,
                      ),
                      prefixText: 'KES  ',
                      prefixStyle: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: context.colors.primary,
                      ),
                      filled: true,
                      fillColor: context.colors.inputFill,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
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
                        borderSide: BorderSide(
                          color: context.colors.primary,
                          width: 1.8,
                        ),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: context.colors.error),
                      ),
                      focusedErrorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(
                          color: context.colors.error,
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
                      color: context.colors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Send button label updates live with entered amount.
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
                        backgroundColor: context.colors.primary,
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
                          color: context.colors.textSecondary,
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
      // Safe disposal after the sheet is fully closed.
      phoneCtrl.dispose();
      amountCtrl.dispose();
    });
  }

  void _showWaitingDialog() {
    if (_waitingDialogVisible || !mounted) return;
    _waitingDialogVisible = true;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: Dialog(
          backgroundColor: context.colors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 26, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: context.colors.primary),
                const SizedBox(height: 20),
                Text(
                  'Waiting for M-Pesa confirmation...',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: context.colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Complete the prompt on your phone.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: context.colors.textSecondary,
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

  void _hideWaitingDialog() {
    if (!_waitingDialogVisible || !mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
    _waitingDialogVisible = false;
  }





  void _navigateToReceipt(ParkingSession session) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _PaymentReceiptPage(session: session),
      ),
    );
  }

  Widget _billingRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(fontSize: 12, color: context.colors.textSecondary),
        ),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: context.colors.textPrimary,
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
