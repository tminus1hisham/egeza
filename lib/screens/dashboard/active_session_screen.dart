import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../blocs/app_bloc.dart';
import '../../blocs/app_event.dart';
import '../../blocs/app_state.dart';
import '../../core/error_handler.dart';
import '../../core/theme/app_colors.dart';
import '../../models/parking_session.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/app_widgets.dart';
import 'promo_qr_scanner_screen.dart';

class ActiveSessionScreen extends StatefulWidget {
  final ParkingSession session;
  const ActiveSessionScreen({super.key, required this.session});

  @override
  State<ActiveSessionScreen> createState() => _ActiveSessionScreenState();
}

class _ActiveSessionScreenState extends State<ActiveSessionScreen> {
  late Timer _timer;
  late Duration _elapsed;
  bool _waitingDialogVisible = false;
  bool _wasWaitingForPayment = false;

  // Treat naive (non-UTC) API datetimes as UTC to match server intent
  DateTime get _startUtc {
    final dt = widget.session.startTime;
    return dt.isUtc
        ? dt
        : DateTime.utc(dt.year, dt.month, dt.day, dt.hour, dt.minute, dt.second);
  }

  @override
  void initState() {
    super.initState();
    _elapsed = DateTime.now().toUtc().difference(_startUtc);
    // Update display every 5s; elapsed is computed from real start time so accuracy is maintained
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      setState(() => _elapsed = DateTime.now().toUtc().difference(_startUtc));
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  bool get _isFree => widget.session.cost == 0;

  String get _formattedTime {
    final h = _elapsed.inHours.toString().padLeft(2, '0');
    final m = (_elapsed.inMinutes % 60).toString().padLeft(2, '0');
    final s = (_elapsed.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
                  style: GoogleFonts.poppins(fontSize: 12, color: context.colors.textSecondary),
                ),
              ],
            ),
          ),
        ),
      ),
    ).then((_) => _waitingDialogVisible = false);
  }

  void _hideWaitingDialog() {
    if (!_waitingDialogVisible || !mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
    _waitingDialogVisible = false;
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AppBloc, AppState>(
      listenWhen: (prev, curr) =>
          prev.isWaitingForPayment != curr.isWaitingForPayment ||
          prev.errorMessage != curr.errorMessage ||
          prev.selectedSession != curr.selectedSession,
      listener: (context, state) {
        if (state.isWaitingForPayment) {
          _wasWaitingForPayment = true;
          _showWaitingDialog();
          return;
        }
        _hideWaitingDialog();
        final completedCheckout =
            state.selectedSession?.id == widget.session.id &&
            state.selectedSession?.status == 'COMPLETED';
        if (!_wasWaitingForPayment && !completedCheckout) return;
        _wasWaitingForPayment = false;

        final error = state.errorMessage;
        if (error != null && error.isNotEmpty) {
          ErrorHandler.showErrorMessage(context, error);
          return;
        }

        // Payment succeeded — pop back to the dashboard.
        if (mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
      backgroundColor: context.colors.background,
      body: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  context.colors.primaryDeep,
                  context.colors.primaryDark,
                  context.colors.primary,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(32),
                bottomRight: Radius.circular(32),
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryDeep.withValues(alpha: 0.26),
                  blurRadius: 28,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Material(
                          color: Colors.white.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14),
                          child: InkWell(
                            onTap: () => Navigator.pop(context),
                            borderRadius: BorderRadius.circular(14),
                            child: const SizedBox(
                              width: 40,
                              height: 40,
                              child: Icon(
                                Icons.arrow_back_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Active Session',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                _isFree ? 'No charge — free parking' : 'Live billing in progress',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.poppins(
                                  color: Colors.white.withValues(alpha: 0.62),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const StatusBadge(label: 'Active Now', isActive: true),
                      ],
                    ),
                    const SizedBox(height: 28),
                    Text(
                      widget.session.locationName,
                      style: GoogleFonts.poppins(color: Colors.white70, fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _isFree ? 'FREE' : 'KES ${widget.session.cost.toStringAsFixed(2)}',
                      style: GoogleFonts.poppins(color: Colors.white, fontSize: 44, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Duration: $_formattedTime',
                      style: GoogleFonts.poppins(color: Colors.white54, fontSize: 13),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.1),
                        ),
                      ),
                      child: Text(
                        '${widget.session.vehicle.plateNumber} - ${widget.session.vehicle.make}',
                        style: GoogleFonts.poppins(color: Colors.white70, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Session Details',
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: context.colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: context.colors.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: context.colors.border),
                    ),
                    child: Column(
                      children: [
                        _detailRow('Rate', 'KES ${widget.session.ratePerHour}/hr'),
                        _detailRow('Started', _formatTime(widget.session.startTime)),
                        _detailRow('Location', widget.session.locationName),
                        _detailRow('Vehicle', '${widget.session.vehicle.make} ${widget.session.vehicle.model}'),
                      ],
                    ),
                  ),
                  if (!_isFree) ...[
                    const SizedBox(height: 28),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: context.colors.accentLight,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: context.colors.mintBorder),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline_rounded, color: context.colors.primary, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'You will receive an M-Pesa prompt to complete payment when you end this session.',
                              style: GoogleFonts.poppins(fontSize: 12, color: context.colors.primary, height: 1.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),
                    PrimaryButton(
                      text: 'End Session & Pay',
                      onPressed: () => _showEndDialog(context),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: context.colors.divider))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.poppins(fontSize: 13, color: context.colors.textSecondary)),
          const SizedBox(width: 16),
          Flexible(
            child: Text(
              value,
              maxLines: 1,
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
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final eat = (dt.isUtc ? dt : DateTime.utc(
      dt.year, dt.month, dt.day, dt.hour, dt.minute, dt.second,
    )).add(const Duration(hours: 3));
    final hour = eat.hour == 0 ? 12 : eat.hour > 12 ? eat.hour - 12 : eat.hour;
    final minute = eat.minute.toString().padLeft(2, '0');
    final period = eat.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  void _showEndDialog(BuildContext context) {
    final promoCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      backgroundColor: context.colors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          Future<void> scanPromoCode() async {
            final result = await Navigator.of(context).push<String>(
              MaterialPageRoute(
                builder: (_) => const PromoQrScannerScreen(),
              ),
            );
            if (result == null || result.trim().isEmpty) return;
            promoCtrl.text = result.trim();
            setSheetState(() {});
          }

          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              24,
              24,
              24,
              24 + MediaQuery.of(sheetContext).viewInsets.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 40, height: 4, decoration: BoxDecoration(color: context.colors.border, borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 20),
                Text('End Session?', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700, color: context.colors.textPrimary)),
                const SizedBox(height: 8),
                Text(
                  'An M-Pesa prompt for KES ${widget.session.cost.toStringAsFixed(2)} will be sent to your phone.',
                  style: GoogleFonts.poppins(fontSize: 13, color: context.colors.textSecondary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 22),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Promo code',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: context.colors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: promoCtrl,
                        textCapitalization: TextCapitalization.characters,
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: context.colors.textPrimary,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Optional promo code',
                          hintStyle: GoogleFonts.poppins(
                            color: context.colors.textMuted,
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                          ),
                          prefixIcon: Icon(
                            Icons.confirmation_number_outlined,
                            color: context.colors.primary,
                            size: 20,
                          ),
                          suffixIcon: promoCtrl.text.trim().isEmpty
                              ? null
                              : IconButton(
                                  tooltip: 'Clear promo code',
                                  icon: Icon(
                                    Icons.close_rounded,
                                    color: context.colors.textMuted,
                                    size: 18,
                                  ),
                                  onPressed: () {
                                    promoCtrl.clear();
                                    setSheetState(() {});
                                  },
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
                        ),
                        onChanged: (_) => setSheetState(() {}),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      height: 52,
                      width: 52,
                      child: OutlinedButton(
                        onPressed: scanPromoCode,
                        style: OutlinedButton.styleFrom(
                          padding: EdgeInsets.zero,
                          foregroundColor: context.colors.primary,
                          side: BorderSide(color: context.colors.inputBorder),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Icon(Icons.qr_code_scanner_rounded, size: 22),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  promoCtrl.text.trim().isEmpty
                      ? 'Scan a promo QR code or enter the tenant promo code before checkout.'
                      : 'Promo will be validated before checkout.',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: promoCtrl.text.trim().isEmpty
                        ? context.colors.textSecondary
                        : context.colors.primary,
                  ),
                ),
                const SizedBox(height: 24),
                PrimaryButton(
                  text: promoCtrl.text.trim().isEmpty
                      ? 'Confirm & Pay'
                      : 'Apply Promo & Pay',
                  onPressed: () {
                    final promoCode = promoCtrl.text.trim();
                    context.read<AppBloc>().add(
                          PayParkingSession(
                            sessionId: widget.session.id,
                            promoCode: promoCode.isEmpty ? null : promoCode,
                          ),
                        );
                    Navigator.pop(sheetContext);
                  },
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () => Navigator.pop(sheetContext),
                  child: Text('Cancel', style: GoogleFonts.poppins(color: context.colors.textSecondary)),
                ),
                const SizedBox(height: 8),
              ],
            ),
          );
        },
      ),
    ).then((_) => promoCtrl.dispose());
  }
}
