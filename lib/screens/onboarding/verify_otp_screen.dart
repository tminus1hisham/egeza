import 'dart:async';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../blocs/app_bloc.dart';
import '../../blocs/app_event.dart';
import '../../blocs/app_state.dart';
import '../../core/api/parking_iq_api.dart';
import '../../core/theme/app_colors.dart';
import '../../widgets/app_widgets.dart';
import '../../widgets/primary_button.dart';
import '../dashboard/main_nav.dart';

class VerifyOtpScreen extends StatefulWidget {
  final String phoneNumber;
  final String fullName;
  final String idNumber;
  final String county;
  final String? email;

  const VerifyOtpScreen({
    super.key,
    required this.phoneNumber,
    required this.fullName,
    required this.idNumber,
    required this.county,
    this.email,
  });

  @override
  State<VerifyOtpScreen> createState() => _VerifyOtpScreenState();
}

class _VerifyOtpScreenState extends State<VerifyOtpScreen> {
  final List<TextEditingController> _otpControllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _otpFocusNodes = List.generate(6, (_) => FocusNode());
  final _api = ParkingIqApi();

  Timer? _resendTimer;
  int _resendCountdown = 60;
  bool _resendingOtp = false;
  bool _fetchingLatestOtp = false;
  bool _navigatedAfterAuth = false;
  String? _pendingAction;

  @override
  void initState() {
    super.initState();
    _startResendTimer();
    if (kDebugMode) _fetchLatestOtp();
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    for (final controller in _otpControllers) {
      controller.dispose();
    }
    for (final node in _otpFocusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AppBloc, AppState>(
      listenWhen: (previous, current) =>
          previous.authToken != current.authToken ||
          previous.errorMessage != current.errorMessage ||
          previous.isLoading != current.isLoading,
      listener: _onRegistrationStateChanged,
      builder: (context, state) {
        final isVerifying =
            state.isLoading && _pendingAction == _OtpAction.verify;

        return Scaffold(
          backgroundColor: context.colors.surface,
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const OnboardingStepHeader(
                    step: 2,
                    totalSteps: 2,
                    title: 'Verify OTP',
                  ),
                  const SizedBox(height: 30),
                  const Center(
                    child: OnboardingHeroIcon(
                      icon: LucideIcons.shieldCheck,
                      size: 96,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Verify your phone',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 25,
                      fontWeight: FontWeight.w500,
                      color: context.colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Enter the 6-digit code sent to ${_maskedPhoneNumber}',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      color: context.colors.textSecondary,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 30),
                  _otpCard(
                    isBusy: state.isLoading,
                    isVerifying: isVerifying,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _otpCard({
    required bool isBusy,
    required bool isVerifying,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.accentLight,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.colors.mintBorder, width: 1.3),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                LucideIcons.keyRound,
                color: context.colors.primary,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Verification Code',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: context.colors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final boxWidth = ((constraints.maxWidth - 50) / 6)
                  .clamp(40.0, 56.0)
                  .toDouble();

              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(
                  6,
                  (index) => _otpBox(index, boxWidth),
                ),
              );
            },
          ),
          if (kDebugMode) ...[
            const SizedBox(height: 12),
            _debugOtpAction(),
          ],
          const SizedBox(height: 18),
          PrimaryButton(
            text: 'Verify Account',
            icon: LucideIcons.checkCircle,
            isLoading: isVerifying,
            onPressed: isBusy ? null : _verifyOtp,
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              onPressed: (isBusy || _resendingOtp || _resendCountdown > 0)
                  ? null
                  : _resendOtp,
              icon: _resendingOtp
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: context.colors.primary,
                      ),
                    )
                  : const Icon(LucideIcons.refreshCw, size: 16),
              label: Text(
                _resendCountdown > 0
                    ? 'Resend in ${_resendCountdown}s'
                    : 'Resend Code',
              ),
              style: TextButton.styleFrom(
                foregroundColor: context.colors.primary,
                textStyle: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _otpBox(int index, double width) {
    final filled = _otpControllers[index].text.isNotEmpty;

    return SizedBox(
      width: width,
      height: 52,
      child: TextField(
        controller: _otpControllers[index],
        focusNode: _otpFocusNodes[index],
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        autofillHints: index == 0 ? const [AutofillHints.oneTimeCode] : null,
        inputFormatters: [
          LengthLimitingTextInputFormatter(1),
          FilteringTextInputFormatter.digitsOnly,
        ],
        style: GoogleFonts.poppins(
          fontSize: 20,
          fontWeight: FontWeight.w500,
          color: context.colors.textPrimary,
        ),
        onChanged: (value) => _onOtpDigit(value, index),
        decoration: InputDecoration(
          filled: true,
          fillColor: context.colors.inputFill,
          counterText: '',
          contentPadding: EdgeInsets.zero,
          enabledBorder: _otpBorder(
            filled ? context.colors.primary : context.colors.inputBorder,
            width: filled ? 2 : 1,
          ),
          focusedBorder: _otpBorder(context.colors.primary, width: 2),
        ),
      ),
    );
  }

  Widget _debugOtpAction() {
    return InkWell(
      onTap: _fetchingLatestOtp ? null : _fetchLatestOtp,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            if (_fetchingLatestOtp)
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: context.colors.primary,
                ),
              )
            else
              Icon(
                LucideIcons.wand2,
                size: 16,
                color: context.colors.primary,
              ),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                'Debug: tap to auto-fill latest OTP',
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: context.colors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onRegistrationStateChanged(BuildContext context, AppState state) {
    if (!state.isLoading && _pendingAction != null && mounted) {
      setState(() => _pendingAction = null);
    }

    final error = state.errorMessage;
    if (error != null && error.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error)),
      );
      return;
    }

    if (!_navigatedAfterAuth && state.isAuthenticated) {
      _navigatedAfterAuth = true;
      context.read<AppBloc>().add(LoadDashboardData());
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const MainNavigation()),
        (route) => false,
      );
    }
  }

  void _onOtpDigit(String value, int index) {
    if (value.length == 1 && index < 5) {
      _otpFocusNodes[index + 1].requestFocus();
    } else if (value.isEmpty && index > 0) {
      _otpFocusNodes[index - 1].requestFocus();
    } else if (_isOtpComplete) {
      FocusScope.of(context).unfocus();
    }

    setState(() {});
  }

  void _verifyOtp() {
    final otp = _otp;
    if (otp.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter the 6-digit code')),
      );
      return;
    }

    setState(() => _pendingAction = _OtpAction.verify);
    context.read<AppBloc>().add(
          RegisterAccount(
            phoneNumber: widget.phoneNumber,
            otp: otp,
            fullName: widget.fullName,
            idNumber: widget.idNumber,
            county: widget.county,
            email: widget.email,
          ),
        );
  }

  Future<void> _resendOtp() async {
    setState(() => _resendingOtp = true);
    try {
      await _api.sendOtp(widget.phoneNumber);
      if (!mounted) return;

      _clearOtp();
      _startResendTimer();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Verification code sent')),
      );

      if (kDebugMode) await _fetchLatestOtp();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_friendlyError(error))),
      );
    } finally {
      if (mounted) setState(() => _resendingOtp = false);
    }
  }

  Future<void> _fetchLatestOtp() async {
    if (_fetchingLatestOtp) return;
    setState(() => _fetchingLatestOtp = true);
    try {
      final otp = await _api.latestOtp(widget.phoneNumber);
      if (otp != null && otp.length >= 6 && mounted) {
        for (var i = 0; i < 6; i++) {
          _otpControllers[i].text = otp[i];
        }
        setState(() {});
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _fetchingLatestOtp = false);
    }
  }

  void _startResendTimer() {
    _resendTimer?.cancel();
    setState(() => _resendCountdown = 60);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        _resendCountdown--;
        if (_resendCountdown <= 0) timer.cancel();
      });
    });
  }

  void _clearOtp() {
    for (final controller in _otpControllers) {
      controller.clear();
    }
    _otpFocusNodes.first.requestFocus();
    setState(() {});
  }

  OutlineInputBorder _otpBorder(Color color, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: color, width: width),
    );
  }

  String _friendlyError(Object error) {
    if (error is ApiException) return error.message;
    return error.toString().replaceFirst('Exception: ', '');
  }

  String get _otp {
    return _otpControllers.map((controller) => controller.text).join();
  }

  bool get _isOtpComplete {
    return _otpControllers.every((controller) => controller.text.isNotEmpty);
  }

  String get _maskedPhoneNumber {
    final digits = widget.phoneNumber.replaceAll(RegExp(r'\D'), '');
    if (digits.length <= 6) return widget.phoneNumber;
    return '+${digits.substring(0, digits.length - 6)} *** ${digits.substring(digits.length - 3)}';
  }
}

class _OtpAction {
  static const verify = 'verify';
}
