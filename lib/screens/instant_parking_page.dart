import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/api/parking_iq_api.dart';
import '../core/theme/app_colors.dart';
import '../models/parking_session.dart';
import '../models/vehicle.dart';
import '../widgets/stk_confirmation_sheet.dart' show formatPlateDisplay;
import 'auth/sign_in_screen.dart';
import 'dashboard/promo_qr_scanner_screen.dart';

class InstantParkingPage extends StatefulWidget {
  /// Injectable for widget tests; defaults to a live client.
  final ParkingIqApi? api;

  const InstantParkingPage({super.key, this.api});

  @override
  State<InstantParkingPage> createState() => _InstantParkingPageState();
}


class _InstantParkingPageState extends State<InstantParkingPage> {
  /// Shortest plate we bother looking up — anything below this is still
  /// mid-typing.
  static const _minPlateLength = 4;
  static const _lookupDelay = Duration(milliseconds: 550);

  late final ParkingIqApi _api = widget.api ?? ParkingIqApi();
  final _plateController = TextEditingController();
  final _phoneController = TextEditingController();
  final _promoController = TextEditingController();

  Timer? _debounce;

  /// Guards against a slow lookup landing after a newer one.
  int _lookupSeq = 0;

  /// Plate key the pending/last lookup was fired for, so repeated listener
  /// callbacks (cursor moves, formatting) don't re-query the same plate.
  String _queryPlate = '';

  bool _lookingUp = false;
  bool _noSession = false;
  ParkingSession? _session;
  String? _lookupError;

  bool _paying = false;
  bool _showPromo = false;
  String? _phoneError;
  String? _promoError;

  @override
  void initState() {
    super.initState();
    _plateController.addListener(_onPlateChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _plateController.removeListener(_onPlateChanged);
    _plateController.dispose();
    _phoneController.dispose();
    _promoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = _session;
    final showPay = session != null && _amountDue(session) > 0;

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
                              SizedBox(height: compact ? 24 : 34),
                              _label('Enter Your Number Plate'),
                              const SizedBox(height: 9),
                              _plateField(),
                              _resultSection(),
                              const SizedBox(height: 18),
                              _premiumNote(),
                            ],
                          ),
                        ),
                      ),
                      if (showPay)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(22, 8, 22, 22),
                          child: _payButton(session),
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

  // ---------------------------------------------------------------------------
  // Plate lookup
  // ---------------------------------------------------------------------------

  void _onPlateChanged() {
    final plate = Vehicle.plateKey(_plateController.text);
    if (plate == _queryPlate) return;
    _queryPlate = plate;

    _debounce?.cancel();
    // Whatever is on screen belongs to the previous plate — drop it, and make
    // any in-flight lookup for it land stale.
    _lookupSeq++;

    setState(() {
      _session = null;
      _noSession = false;
      _lookupError = null;
      _promoError = null;
      _phoneError = null;
      _lookingUp = plate.length >= _minPlateLength;
    });

    if (plate.length < _minPlateLength) return;
    _debounce = Timer(_lookupDelay, () => _lookupSession(plate));
  }

  Future<void> _lookupSession(String plate) async {
    final seq = ++_lookupSeq;

    ParkingSession? session;
    String? error;
    try {
      session = await _api.instantPaySession(plate);
    } on ApiException catch (e) {
      // The endpoint 404s when nothing is parked under this plate.
      if (e.statusCode != 404) error = e.message;
    } catch (_) {
      error = 'Could not check this plate. Tap to try again.';
    }

    if (!mounted || seq != _lookupSeq) return;
    setState(() {
      _lookingUp = false;
      _session = session;
      _noSession = error == null && session == null;
      _lookupError = error;
    });
  }

  void _retryLookup() {
    final plate = Vehicle.plateKey(_plateController.text);
    if (plate.length < _minPlateLength) return;
    setState(() {
      _lookupError = null;
      _lookingUp = true;
    });
    _lookupSession(plate);
  }

  // ---------------------------------------------------------------------------
  // Chrome
  // ---------------------------------------------------------------------------

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
      'Enter your number plate — we find your active session as you type.',
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

  Widget _fieldError(String? message) {
    if (message == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 7, left: 4),
      child: Text(
        message,
        style: GoogleFonts.poppins(
          color: AppColors.accent,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _glassInput({
    required TextEditingController controller,
    required IconData icon,
    required String hint,
    required TextInputType keyboardType,
    required TextInputAction textInputAction,
    required List<TextInputFormatter> inputFormatters,
    TextCapitalization textCapitalization = TextCapitalization.none,
    double letterSpacing = 0,
    VoidCallback? onSubmitted,
    Widget? trailing,
  }) {
    return _GlassField(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 20,
            color: Colors.white.withValues(alpha: 0.6),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: controller,
              enabled: !_paying,
              textCapitalization: textCapitalization,
              keyboardType: keyboardType,
              textInputAction: textInputAction,
              onSubmitted: (_) => onSubmitted?.call(),
              inputFormatters: inputFormatters,
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 16,
                letterSpacing: letterSpacing,
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
                hintText: hint,
                hintStyle: GoogleFonts.poppins(
                  color: Colors.white.withValues(alpha: 0.4),
                  fontSize: 16,
                  letterSpacing: letterSpacing,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }

  Widget _plateField() {
    return _glassInput(
      controller: _plateController,
      icon: Icons.directions_car_rounded,
      hint: 'e.g. KXX 123X',
      keyboardType: TextInputType.text,
      textInputAction: TextInputAction.done,
      textCapitalization: TextCapitalization.characters,
      letterSpacing: 1.5,
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9 ]')),
        TextInputFormatter.withFunction((oldValue, newValue) {
          return newValue.copyWith(text: newValue.text.toUpperCase());
        }),
      ],
      trailing: _lookingUp
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(AppColors.accent),
              ),
            )
          : null,
    );
  }

  Widget _phoneField() {
    return _glassInput(
      controller: _phoneController,
      icon: Icons.phone_iphone_rounded,
      hint: '07XX XXX XXX',
      keyboardType: TextInputType.phone,
      textInputAction: TextInputAction.done,
      letterSpacing: 0.6,
      onSubmitted: _payNow,
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ]')),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Everything that hangs off the lookup result
  // ---------------------------------------------------------------------------

  /// The block directly under the plate field: the session details plus the
  /// payment form once a session is found, otherwise the empty/error state.
  Widget _resultSection() {
    if (_lookupError != null) {
      return Padding(
        padding: const EdgeInsets.only(top: 16),
        child: _stateCard(
          icon: Icons.wifi_off_rounded,
          title: 'Lookup failed',
          message: _lookupError!,
          tint: AppColors.accent,
          onTap: _retryLookup,
        ),
      );
    }

    if (_lookingUp) {
      return Padding(
        padding: const EdgeInsets.only(top: 16),
        child: Row(
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 1.8,
                valueColor: AlwaysStoppedAnimation(
                  Colors.white.withValues(alpha: 0.5),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'Looking for an active session…',
              style: GoogleFonts.poppins(
                color: Colors.white.withValues(alpha: 0.55),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    if (_noSession) {
      return Padding(
        padding: const EdgeInsets.only(top: 16),
        child: _stateCard(
          icon: Icons.search_off_rounded,
          title: 'No session found',
          message: 'Nothing is parked under '
              '${formatPlateDisplay(_plateController.text)} right now. '
              'Check the plate and try again.',
          tint: Colors.white,
        ),
      );
    }

    final session = _session;
    if (session == null) return const SizedBox.shrink();

    if (_amountDue(session) <= 0) {
      return Padding(
        padding: const EdgeInsets.only(top: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _sessionCard(session),
            const SizedBox(height: 12),
            _stateCard(
              icon: Icons.verified_rounded,
              title: 'Nothing to pay',
              message: 'This session has no outstanding balance.',
              tint: AppColors.primary,
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sessionCard(session),
          const SizedBox(height: 18),
          _label('M-Pesa Number'),
          const SizedBox(height: 9),
          _phoneField(),
          _fieldError(_phoneError),
          const SizedBox(height: 14),
          _promoSection(),
          const SizedBox(height: 12),
          _helperText(),
        ],
      ),
    );
  }

  Widget _sessionCard(ParkingSession session) {
    final plate = session.vehicle.plateNumber.isEmpty
        ? _plateController.text
        : session.vehicle.plateNumber;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _statusPill(session),
              const Spacer(),
              Text(
                formatPlateDisplay(plate),
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 14,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Icon(
                Icons.location_on_rounded,
                size: 15,
                color: Colors.white.withValues(alpha: 0.5),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  session.locationName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _detail('Duration', _durationLabel(session))),
              Expanded(child: _detail('Started', _timeLabel(session.startTime))),
            ],
          ),
          if (session.discountAmount > 0) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Icon(
                  Icons.local_offer_rounded,
                  size: 14,
                  color: AppColors.accent.withValues(alpha: 0.9),
                ),
                const SizedBox(width: 7),
                Text(
                  'KES ${_money(session.discountAmount)} discount applied',
                  style: GoogleFonts.poppins(
                    color: AppColors.accent,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 14),
          Divider(color: Colors.white.withValues(alpha: 0.12), height: 1),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'Amount due',
                style: GoogleFonts.poppins(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                'KES ${_money(_amountDue(session))}',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 24,
                  height: 1,
                  letterSpacing: -0.4,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statusPill(ParkingSession session) {
    final active = session.isActive;
    final color = active ? AppColors.primary : AppColors.accent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Text(
        active ? 'ACTIVE SESSION' : 'AWAITING PAYMENT',
        style: GoogleFonts.poppins(
          color: Colors.white.withValues(alpha: 0.92),
          fontSize: 9.5,
          letterSpacing: 0.7,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _detail(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: GoogleFonts.poppins(
            color: Colors.white.withValues(alpha: 0.45),
            fontSize: 9.5,
            letterSpacing: 0.7,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.poppins(
            color: Colors.white.withValues(alpha: 0.9),
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _stateCard({
    required IconData icon,
    required String title,
    required String message,
    required Color tint,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: tint.withValues(alpha: 0.22)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: tint.withValues(alpha: 0.85)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    message,
                    style: GoogleFonts.poppins(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 11.5,
                      height: 1.4,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _promoSection() {
    if (!_showPromo) {
      return Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: _paying ? null : () => setState(() => _showPromo = true),
          style: TextButton.styleFrom(
            foregroundColor: AppColors.accent,
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            textStyle: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          icon: const Icon(Icons.local_offer_outlined, size: 15),
          label: const Text('Have a promo code?'),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _label('Promo Code'),
        const SizedBox(height: 9),
        _glassInput(
          controller: _promoController,
          icon: Icons.confirmation_number_outlined,
          hint: 'Enter promo code',
          keyboardType: TextInputType.text,
          textInputAction: TextInputAction.done,
          textCapitalization: TextCapitalization.characters,
          letterSpacing: 0.8,
          onSubmitted: _payNow,
          inputFormatters: [
            TextInputFormatter.withFunction((oldValue, newValue) {
              return newValue.copyWith(text: newValue.text.toUpperCase());
            }),
          ],
          trailing: IconButton(
            onPressed: _paying ? null : _scanPromoCode,
            style: IconButton.styleFrom(
              backgroundColor: Colors.transparent,
              foregroundColor: Colors.white.withValues(alpha: 0.7),
              disabledBackgroundColor: Colors.transparent,
              disabledForegroundColor: Colors.white.withValues(alpha: 0.3),
              shape: const CircleBorder(),
            ),
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
            icon: const Icon(Icons.qr_code_scanner_rounded, size: 20),
          ),
        ),
        _fieldError(_promoError),
      ],
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
            'Tapping Pay sends an M-Pesa STK push to the number above.',
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

  Widget _payButton(ParkingSession session) {
    return SizedBox(
      height: 54,
      child: ElevatedButton(
        onPressed: _paying ? null : _payNow,
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
        child: _paying
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
                children: [
                  Text('Pay KES ${_money(_amountDue(session))}'),
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_forward_rounded, size: 18),
                ],
              ),
      ),
    );
  }

  Future<void> _scanPromoCode() async {
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const PromoQrScannerScreen()),
    );
    if (result == null || result.trim().isEmpty || !mounted) return;
    setState(() {
      _promoController.text = result.trim().toUpperCase();
      _promoError = null;
    });
  }

  // ---------------------------------------------------------------------------
  // Formatting helpers
  // ---------------------------------------------------------------------------

  String _money(double value) => value.toStringAsFixed(0).replaceAllMapped(
        RegExp(r'\B(?=(\d{3})+(?!\d))'),
        (m) => ',',
      );

  String _timeLabel(DateTime dt) {
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  String _durationLabel(ParkingSession session) {
    int minutes;
    if (session.durationMinutes != null) {
      minutes = session.durationMinutes!;
    } else {
      // Normalise to UTC so local-time drift (Kenya = UTC+3) doesn't skew this.
      DateTime toUtc(DateTime dt) => dt.isUtc
          ? dt
          : DateTime.utc(
              dt.year, dt.month, dt.day, dt.hour, dt.minute, dt.second);
      final start = toUtc(session.startTime);
      final end = toUtc(session.endTime ?? DateTime.now().toUtc());
      minutes = end.difference(start).inMinutes;
    }
    if (minutes < 0) minutes = 0;

    final hours = minutes ~/ 60;
    final remainder = minutes % 60;
    if (hours <= 0) return '${remainder}m';
    if (remainder <= 0) return '${hours}h';
    return '${hours}h ${remainder}m';
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

  double _amountDue(ParkingSession session) {
    final due = session.cost - session.amountPaid;
    return due > 0 ? due : 0;
  }

  // ---------------------------------------------------------------------------
  // Payment
  // ---------------------------------------------------------------------------

  /// Applies any promo code to the session already on screen and fires the
  /// STK push for what is owed.
  Future<void> _payNow() async {
    final session = _session;
    if (session == null || _paying) return;

    FocusScope.of(context).unfocus();

    final plate = Vehicle.plateKey(_plateController.text);
    final phone = _normalisePhone(_phoneController.text);
    final promoCode = _showPromo ? _promoController.text.trim() : '';

    setState(() {
      _phoneError = phone == null ? 'Enter a valid Safaricom number.' : null;
      _promoError = null;
    });
    if (phone == null) return;

    setState(() => _paying = true);
    try {
      if (promoCode.isNotEmpty) {
        try {
          await _api.applyDiscount(sessionId: session.id, code: promoCode);
        } on ApiException catch (e) {
          if (mounted) setState(() => _promoError = e.message);
          return;
        } catch (_) {
          if (mounted) {
            setState(() =>
                _promoError = 'Could not apply this promo code. Try again.');
          }
          return;
        }
        if (!mounted) return;

        // The discount changes what is owed — re-read the session so the card
        // and the button agree with what M-Pesa is about to ask for.
        final refreshed = await _api.instantPaySession(plate);
        if (!mounted) return;
        if (refreshed != null) {
          setState(() => _session = refreshed);
          if (_amountDue(refreshed) <= 0) {
            _showMessage(
              'The promo code covers this session in full.',
              success: true,
            );
            return;
          }
        }
      }

      final response = await _api.instantPay(
        plateNumber: plate,
        phoneNumber: phone,
      );
      if (!mounted) return;
      _showMessage(
        response.customerMessage ??
            'STK push sent. Check your phone to authorise the payment.',
        success: true,
      );
    } on ApiException catch (e) {
      if (mounted) _showMessage(e.message);
    } catch (_) {
      if (mounted) {
        _showMessage('Could not complete the payment request. Try again.');
      }
    } finally {
      if (mounted) setState(() => _paying = false);
    }
  }

  void _showMessage(String message, {bool success = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: success ? AppColors.primary : AppColors.primaryDark,
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
