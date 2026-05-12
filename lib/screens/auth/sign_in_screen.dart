import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../blocs/app_bloc.dart';
import '../../blocs/app_event.dart';
import '../../blocs/app_state.dart';
import '../../core/error_handler.dart';
import '../../core/theme/app_colors.dart';
import '../../widgets/app_widgets.dart';
import '../../widgets/country_code_selector.dart';
import '../../widgets/primary_button.dart';
import '../dashboard/main_nav.dart';
import '../onboarding/create_account_screen.dart';
import '../onboarding/plate_number_screen.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _phoneController = TextEditingController();
  final List<TextEditingController> _otpControllers = List.generate(
    6,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _otpFocusNodes = List.generate(6, (_) => FocusNode());

  CountryCode _selectedCountry = kCountryCodes.first;
  bool _otpRequested = false;
  bool _navigatedAfterAuth = false;
  String? _pendingAction;
  int _resendCountdown = 0;
  Timer? _resendTimer;

  // Inline OTP error shown below OTP boxes
  String? _otpError;

  @override
  void dispose() {
    _resendTimer?.cancel();
    _phoneController.dispose();
    for (final c in _otpControllers) {
      c.dispose();
    }
    for (final n in _otpFocusNodes) {
      n.dispose();
    }
    super.dispose();
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

  void _clearOtpAndRefocus() {
    for (final c in _otpControllers) {
      c.clear();
    }
    _otpFocusNodes.first.requestFocus();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AppBloc, AppState>(
      listenWhen: (previous, current) =>
          previous.authToken != current.authToken ||
          previous.errorMessage != current.errorMessage ||
          previous.statusMessage != current.statusMessage ||
          previous.isLoading != current.isLoading,
      listener: _onAuthStateChanged,
      builder: (context, state) {
        final isBusy = state.isLoading;

        return Scaffold(
          backgroundColor: context.colors.background,
          body: Stack(
            children: [
              // Subtle gradient wash
              Container(
                height: 280,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primary.withValues(alpha: 0.09),
                      Colors.transparent,
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
              SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 40),
                      const Center(child: egeshaLogo(size: 46)),
                      const SizedBox(height: 36),
                      Text(
                        'Sign in',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: 30,
                          fontWeight: FontWeight.w700,
                          color: context.colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Continue with your egesha account',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          color: context.colors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 32),
                      _phoneCard(
                        isBusy: isBusy,
                        isRequestingOtp:
                            isBusy && _pendingAction == _SignInAction.requestOtp,
                      ),
                      const SizedBox(height: 18),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        child: _otpRequested
                            ? _otpCard(
                                key: const ValueKey('otp-card'),
                                isBusy: isBusy,
                                isSigningIn:
                                    isBusy &&
                                    _pendingAction == _SignInAction.signIn,
                                phoneNumber: _normalizedPhoneNumber,
                              )
                            : const SizedBox.shrink(
                                key: ValueKey('otp-empty'),
                              ),
                      ),
                      const SizedBox(height: 24),
                      _createAccountLink(),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
              // Loading overlay
              if (isBusy)
                Positioned.fill(
                  child: Container(
                    color: Colors.black26,
                    child: const Center(child: CircularProgressIndicator()),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _phoneCard({required bool isBusy, required bool isRequestingOtp}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label('Phone Number'),
          const SizedBox(height: 8),
          Row(
            children: [
              CountryCodeSelector(
                selected: _selectedCountry,
                onChanged: isBusy
                    ? (_) {}
                    : (code) => setState(() => _selectedCountry = code),
                decoration: _inputBoxDecoration(null),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  height: 54,
                  decoration: _inputBoxDecoration(null),
                  child: TextField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.done,
                    readOnly: isBusy,
                    inputFormatters: [_PhoneSpaceFormatter()],
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      color: context.colors.textPrimary,
                    ),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 15,
                      ),
                      hintText: '712 345 678',
                      hintStyle: GoogleFonts.poppins(
                        color: context.colors.textMuted,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          PrimaryButton(
            text: _otpRequested
                ? (_resendCountdown > 0
                      ? 'Resend in ${_resendCountdown}s'
                      : 'Resend Code')
                : 'Send OTP',
            icon: LucideIcons.messageCircle,
            isLoading: isRequestingOtp,
            onPressed: (isBusy || _resendCountdown > 0) ? null : _requestOtp,
          ),
        ],
      ),
    );
  }

  Widget _otpCard({
    required Key key,
    required bool isBusy,
    required bool isSigningIn,
    required String phoneNumber,
  }) {
    return Container(
      key: key,
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
                LucideIcons.shieldCheck,
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
          const SizedBox(height: 10),
          Text(
            'Enter the 6-digit code sent to $phoneNumber',
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: context.colors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final boxWidth = ((constraints.maxWidth - 50) / 6)
                  .clamp(40.0, 56.0)
                  .toDouble();

              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(6, (index) {
                  return Semantics(
                    label: 'OTP digit ${index + 1} of 6',
                    child: _otpBox(index, boxWidth, isBusy: isBusy),
                  );
                }),
              );
            },
          ),
          // Inline OTP error
          if (_otpError != null) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.close_rounded,
                    size: 16,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _otpError!,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 18),
          PrimaryButton(
            text: 'Sign In',
            icon: LucideIcons.logIn,
            isLoading: isSigningIn,
            onPressed: isBusy ? null : _signIn,
          ),
        ],
      ),
    );
  }

  Widget _otpBox(int index, double width, {required bool isBusy}) {
    final filled = _otpControllers[index].text.isNotEmpty;
    final hasError = _otpError != null;

    return SizedBox(
      width: width,
      height: 52,
      child: TextField(
        controller: _otpControllers[index],
        focusNode: _otpFocusNodes[index],
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        readOnly: isBusy,
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
          fillColor: context.colors.surface,
          counterText: '',
          contentPadding: EdgeInsets.zero,
          enabledBorder: _otpBorder(
            hasError
                ? context.colors.error
                : filled
                    ? context.colors.primary
                    : context.colors.inputBorder,
            width: (filled || hasError) ? 2 : 1,
          ),
          focusedBorder: _otpBorder(
            hasError ? context.colors.error : context.colors.primary,
            width: 2,
          ),
        ),
      ),
    );
  }

  Widget _createAccountLink() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const CreateAccountScreen()),
        );
      },
      child: Center(
        child: RichText(
          text: TextSpan(
            text: 'New to egesha? ',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: context.colors.textMuted,
            ),
            children: [
              TextSpan(
                text: 'Create account',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: context.colors.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _onAuthStateChanged(BuildContext context, AppState state) {
    if (!state.isLoading && _pendingAction != null && mounted) {
      setState(() => _pendingAction = null);
    }

    final error = state.errorMessage;
    if (error != null && error.isNotEmpty) {
      if (_otpRequested) {
        // OTP submission failed — show inline error and clear boxes
        setState(() => _otpError = error);
        _clearOtpAndRefocus();
      } else {
        // OTP send failed — reset so the user stays on the phone step
        setState(() => _otpRequested = false);
        ErrorHandler.showErrorMessage(context, error);
      }
      return;
    }

    if (!_navigatedAfterAuth && state.isAuthenticated) {
      _navigatedAfterAuth = true;
      final destination = state.requiresVehicleSetup
          ? const PlateNumberScreen()
          : const MainNavigation();

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => destination),
        (route) => false,
      );
      return;
    }

    final message = state.statusMessage;
    if (message != null && message.isNotEmpty && !state.isAuthenticated) {
      // OTP was sent successfully — now reveal the OTP card
      if (_pendingAction == _SignInAction.requestOtp) {
        setState(() => _otpRequested = true);
      }
      ErrorHandler.showSuccess(context, message);
    }
  }

  void _onOtpDigit(String value, int index) {
    // Clear inline error as soon as user starts typing
    if (_otpError != null) setState(() => _otpError = null);

    if (value.length == 1 && index < 5) {
      _otpFocusNodes[index + 1].requestFocus();
    } else if (value.isEmpty && index > 0) {
      _otpFocusNodes[index - 1].requestFocus();
    }

    setState(() {});
  }

  void _requestOtp() {
    if (!_hasValidPhoneNumber) {
      ErrorHandler.showErrorMessage(context, 'Please enter a valid phone number.');
      return;
    }

    setState(() {
      _pendingAction = _SignInAction.requestOtp;
      _otpError = null;
    });
    _startResendTimer();
    context.read<AppBloc>().add(RequestLoginOtp(_normalizedPhoneNumber));
  }

  void _signIn() {
    final otp = _otpControllers.map((c) => c.text).join();
    if (otp.length < 6) {
      ErrorHandler.showErrorMessage(context, 'Please enter the 6-digit verification code.');
      return;
    }

    setState(() {
      _pendingAction = _SignInAction.signIn;
      _otpError = null;
    });
    context.read<AppBloc>().add(
          SignInWithOtp(phoneNumber: _normalizedPhoneNumber, otp: otp),
        );
  }

  bool get _hasValidPhoneNumber {
    return _phoneController.text.replaceAll(RegExp(r'\D'), '').length >= 9;
  }

  String get _normalizedPhoneNumber {
    final digits = _phoneController.text.replaceAll(RegExp(r'\D'), '');
    final local = digits.startsWith('0') ? digits.substring(1) : digits;
    return '${_selectedCountry.dialCode}$local';
  }

  Widget _label(String text) {
    return Text(
      text,
      style: GoogleFonts.poppins(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: context.colors.textSecondary,
      ),
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: context.colors.surface,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: context.colors.border),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 16,
          offset: const Offset(0, 6),
        ),
      ],
    );
  }

  BoxDecoration _inputBoxDecoration(Color? color) {
    return BoxDecoration(
      color: color ?? context.colors.inputFill,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: context.colors.inputBorder),
    );
  }

  OutlineInputBorder _otpBorder(Color color, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: color, width: width),
    );
  }
}

/// Formats phone digits as "712 345 678" (space after every 3rd digit, max 9 digits).
class _PhoneSpaceFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final capped = digits.length > 9 ? digits.substring(0, 9) : digits;
    final buffer = StringBuffer();
    for (var i = 0; i < capped.length; i++) {
      if (i == 3 || i == 6) buffer.write(' ');
      buffer.write(capped[i]);
    }
    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class _SignInAction {
  static const requestOtp = 'requestOtp';
  static const signIn = 'signIn';
}
