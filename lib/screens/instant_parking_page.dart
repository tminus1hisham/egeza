import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/api/parking_iq_api.dart';
import '../core/theme/app_colors.dart';
import '../models/parking_session.dart';
import 'auth/sign_in_screen.dart';

class InstantParkingPage extends StatefulWidget {
  const InstantParkingPage({super.key});

  @override
  State<InstantParkingPage> createState() => _InstantParkingPageState();
}

class _InstantParkingPageState extends State<InstantParkingPage> {
  final _api = ParkingIqApi();
  final _plateController = TextEditingController();

  bool _loadingSessions = false;

  @override
  void dispose() {
    _plateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.primaryDeep,
        body: Stack(
          children: [
            Positioned.fill(child: _InstantParkingBackground()),
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxHeight < 690;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          padding: EdgeInsets.fromLTRB(
                            22,
                            compact ? 14 : 20,
                            22,
                            16,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _topBar(),
                              SizedBox(height: compact ? 14 : 22),
                              _title(compact: compact),
                              const SizedBox(height: 8),
                              _subtitle(),
                              SizedBox(height: compact ? 30 : 40),
                              _label('Enter Your Number Plate'),
                              const SizedBox(height: 9),
                              _plateField(),
                              const SizedBox(height: 10),
                              _helperText(),
                              const SizedBox(height: 18),
                              _premiumNote(),
                            ],
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(22, 8, 22, 22),
                        child: _payButton(),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _topBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextButton(
          onPressed: _openLogin,
          style: TextButton.styleFrom(
            foregroundColor: AppColors.accent,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            backgroundColor: Colors.white.withValues(alpha: 0.08),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            textStyle: GoogleFonts.poppins(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          child: const Text('Login'),
        ),
      ],
    );
  }

  Widget _title({required bool compact}) {
    return Text(
      'Pay for\nparking',
      maxLines: 2,
      overflow: TextOverflow.visible,
      style: GoogleFonts.poppins(
        color: Colors.white,
        fontSize: compact ? 38 : 44,
        height: 1.05,
        letterSpacing: -0.5,
        fontWeight: FontWeight.w800,
      ),
    );
  }

  Widget _subtitle() {
    return Text(
      'Enter your plate and we\'ll find your parking session.',
      style: GoogleFonts.poppins(
        color: Colors.white.withValues(alpha: 0.6),
        fontSize: 12.5,
        height: 1.4,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  Widget _label(String text) {
    return Text(
      text.toUpperCase(),
      style: GoogleFonts.poppins(
        color: Colors.white.withValues(alpha: 0.55),
        fontSize: 11,
        letterSpacing: 0.8,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  Widget _plateField() {
    return _GlassField(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            Icons.directions_car_rounded,
            size: 20,
            color: Colors.white.withValues(alpha: 0.6),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _plateController,
              textCapitalization: TextCapitalization.characters,
              keyboardType: TextInputType.text,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _continueToPayment(),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9 ]')),
                TextInputFormatter.withFunction((oldValue, newValue) {
                  return newValue.copyWith(text: newValue.text.toUpperCase());
                }),
              ],
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 16,
                letterSpacing: 1.5,
                fontWeight: FontWeight.w600,
              ),
              cursorColor: AppColors.accent,
              decoration: InputDecoration(
                filled: false,
                fillColor: Colors.transparent,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                isCollapsed: true,
                contentPadding: EdgeInsets.zero,
                hintText: 'e.g. KXX 123X',
                hintStyle: GoogleFonts.poppins(
                  color: Colors.white.withValues(alpha: 0.4),
                  fontSize: 16,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _helperText() {
    return Row(
      children: [
        Icon(
          Icons.info_outline_rounded,
          size: 13,
          color: Colors.white.withValues(alpha: 0.4),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            'You\'ll pay via M-Pesa STK push on the next step.',
            style: GoogleFonts.poppins(
              color: Colors.white.withValues(alpha: 0.4),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _premiumNote() {
    return GestureDetector(
      onTap: _openLogin,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.accent.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.accent.withValues(alpha: 0.22),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.workspace_premium_rounded,
              size: 16,
              color: AppColors.accent.withValues(alpha: 0.9),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'To access wallet and other premium features login to your account',
                style: GoogleFonts.poppins(
                  color: Colors.white.withValues(alpha: 0.78),
                  fontSize: 11.5,
                  height: 1.35,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _payButton() {
    return SizedBox(
      height: 54,
      child: ElevatedButton(
        onPressed: _loadingSessions ? null : _continueToPayment,
        style: ElevatedButton.styleFrom(
          elevation: 0,
          shadowColor: Colors.transparent,
          backgroundColor: Colors.white,
          foregroundColor: AppColors.primaryDeep,
          disabledBackgroundColor: Colors.white.withValues(alpha: 0.6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: GoogleFonts.poppins(
            fontSize: 15,
            letterSpacing: 0.2,
            fontWeight: FontWeight.w700,
          ),
        ).copyWith(
          overlayColor: WidgetStatePropertyAll(
            AppColors.accent.withValues(alpha: 0.12),
          ),
        ),
        child: _loadingSessions
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  valueColor: AlwaysStoppedAnimation(AppColors.primaryDeep),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Text('Pay Now'),
                  SizedBox(width: 8),
                  Icon(Icons.arrow_forward_rounded, size: 18),
                ],
              ),
      ),
    );
  }

  Future<void> _continueToPayment() async {
    FocusScope.of(context).unfocus();
    final plate = _plateController.text.replaceAll(' ', '').trim();
    if (plate.isEmpty) {
      _showMessage('Enter your number plate to continue.');
      return;
    }

    setState(() => _loadingSessions = true);
    try {
      var sessions = await _api.activeParkingSessionsForPlate(plate);
      if (sessions.isEmpty) {
        sessions = await _api.parkingSessionsForPlate(plate);
      }
      if (!mounted) return;

      final unpaid = sessions.where((s) => _amountDue(s) > 0).toList();
      if (unpaid.isEmpty) {
        _showMessage(
          sessions.isEmpty
              ? 'No parking session found for $plate.'
              : 'No outstanding balance for $plate.',
        );
        return;
      }

      // Pay the most recent unpaid session.
      unpaid.sort((a, b) => b.startTime.compareTo(a.startTime));
      _showPaymentSheet(unpaid.first, plate);
    } on ApiException catch (e) {
      if (mounted) _showMessage(e.message);
    } catch (_) {
      if (mounted) {
        _showMessage('Could not look up your parking session. Try again.');
      }
    } finally {
      if (mounted) setState(() => _loadingSessions = false);
    }
  }

  double _amountDue(ParkingSession session) {
    final due = session.cost - session.amountPaid;
    return due > 0 ? due : 0;
  }

  void _showPaymentSheet(ParkingSession session, String plate) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.colors.surface,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _MpesaPaymentSheet(
        api: _api,
        session: session,
        plate: plate,
        amountDue: _amountDue(session),
      ),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.primaryDark,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );
  }

  void _openLogin() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const SignInScreen()),
    );
  }
}

class _MpesaPaymentSheet extends StatefulWidget {
  final ParkingIqApi api;
  final ParkingSession session;
  final String plate;
  final double amountDue;

  const _MpesaPaymentSheet({
    required this.api,
    required this.session,
    required this.plate,
    required this.amountDue,
  });

  @override
  State<_MpesaPaymentSheet> createState() => _MpesaPaymentSheetState();
}

class _MpesaPaymentSheetState extends State<_MpesaPaymentSheet> {
  final _phoneController = TextEditingController();
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  /// Normalises a Kenyan number to the 2547XXXXXXXX / 2541XXXXXXXX format.
  String? _normalisePhone(String raw) {
    var digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.startsWith('0')) {
      digits = '254${digits.substring(1)}';
    } else if (digits.startsWith('7') || digits.startsWith('1')) {
      digits = '254$digits';
    } else if (digits.startsWith('254')) {
      // already normalised
    } else {
      return null;
    }
    return digits.length == 12 ? digits : null;
  }

  Future<void> _sendStkPush() async {
    final phone = _normalisePhone(_phoneController.text);
    if (phone == null) {
      setState(() => _error = 'Enter a valid Safaricom number.');
      return;
    }

    setState(() {
      _sending = true;
      _error = null;
    });

    try {
      final response = await widget.api.startSessionStkPush(
        phoneNumber: phone,
        amount: widget.amountDue,
        sessionId: widget.session.id,
        plateNumber: widget.plate,
        location: widget.session.locationName,
      );
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            response.customerMessage ??
                'STK push sent. Check your phone to authorise the payment.',
          ),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      );
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _sending = false;
          _error = e.message;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _sending = false;
          _error = 'Could not send the payment request. Try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        22,
        4,
        22,
        MediaQuery.of(context).viewInsets.bottom + 22,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Pay with M-Pesa',
            style: GoogleFonts.poppins(
              color: colors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'An STK push will be sent to authorise the payment.',
            style: GoogleFonts.poppins(
              color: colors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          _summary(colors),
          const SizedBox(height: 16),
          Text(
            'M-PESA NUMBER',
            style: GoogleFonts.poppins(
              color: colors.textSecondary,
              fontSize: 10.5,
              letterSpacing: 0.8,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            enabled: !_sending,
            style: GoogleFonts.poppins(
              color: colors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ]')),
            ],
            decoration: InputDecoration(
              hintText: '07XX XXX XXX',
              hintStyle: GoogleFonts.poppins(
                color: colors.textSecondary.withValues(alpha: 0.6),
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
              prefixIcon: Icon(Icons.phone_iphone_rounded,
                  size: 19, color: colors.textSecondary),
              isDense: true,
              filled: true,
              fillColor: colors.textPrimary.withValues(alpha: 0.04),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              errorText: _error,
              errorStyle: GoogleFonts.poppins(fontSize: 11),
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: _sending ? null : _sendStkPush,
              style: ElevatedButton.styleFrom(
                elevation: 0,
                backgroundColor: colors.primary,
                foregroundColor: Colors.white,
                disabledBackgroundColor: colors.primary.withValues(alpha: 0.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                textStyle: GoogleFonts.poppins(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              child: _sending
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        valueColor: AlwaysStoppedAnimation(Colors.white),
                      ),
                    )
                  : Text('Pay KES ${widget.amountDue.toStringAsFixed(0)}'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summary(dynamic colors) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.textPrimary.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          _summaryRow(colors, 'Plate', widget.plate),
          const SizedBox(height: 8),
          _summaryRow(colors, 'Location', widget.session.locationName),
          const Divider(height: 22),
          _summaryRow(
            colors,
            'Amount due',
            'KES ${widget.amountDue.toStringAsFixed(0)}',
            emphasise: true,
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(dynamic colors, String label, String value,
      {bool emphasise = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            color: colors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: GoogleFonts.poppins(
              color: emphasise ? colors.primary : colors.textPrimary,
              fontSize: emphasise ? 15 : 12.5,
              fontWeight: emphasise ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _GlassField extends StatelessWidget {
  final Widget child;

  const _GlassField({required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          constraints: const BoxConstraints(minHeight: 56),
          width: double.infinity,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: 0.16),
                Colors.white.withValues(alpha: 0.06),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.18),
              width: 1,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _InstantParkingBackground extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primaryDeep,
            Color(0xFF083831),
            AppColors.primaryDark,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: CustomPaint(
        painter: _InstantParkingPainter(),
        size: Size.infinite,
      ),
    );
  }
}

class _InstantParkingPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 42
      ..color = Colors.white.withValues(alpha: 0.035);

    for (final lane in const [0.08, 0.34, 0.6, 0.86]) {
      final start = Offset(size.width * (lane - 0.24), size.height + 90);
      final end = Offset(size.width * (lane + 0.34), -90);
      canvas.drawLine(start, end, linePaint);
    }

    final markPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2.8
      ..color = AppColors.accent.withValues(alpha: 0.14);

    final parkingPath = Path()
      ..moveTo(size.width * 0.62, size.height * 0.42)
      ..lineTo(size.width * 0.82, size.height * 0.72)
      ..lineTo(size.width * 1.04, size.height * 0.64);
    canvas.drawPath(parkingPath, markPaint);

    final pPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 18
      ..strokeCap = StrokeCap.square
      ..strokeJoin = StrokeJoin.round
      ..color = Colors.white.withValues(alpha: 0.035);

    final pSize = math.min(size.width, size.height) * 0.34;
    final pLeft = size.width * 0.09;
    final pTop = size.height * 0.08;
    canvas.drawLine(
      Offset(pLeft, pTop),
      Offset(pLeft, pTop + pSize),
      pPaint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(pLeft, pTop)
        ..lineTo(pLeft + pSize * 0.52, pTop)
        ..lineTo(pLeft + pSize * 0.52, pTop + pSize * 0.42)
        ..lineTo(pLeft, pTop + pSize * 0.42),
      pPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
