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
import '../../widgets/country_code_selector.dart';
import '../../widgets/primary_button.dart';
import '../auth/sign_in_screen.dart';
import 'plate_number_screen.dart';

class CreateAccountScreen extends StatefulWidget {
  const CreateAccountScreen({super.key});

  @override
  State<CreateAccountScreen> createState() => _CreateAccountScreenState();
}

class _CreateAccountScreenState extends State<CreateAccountScreen> {
  final _phoneController = TextEditingController();
  final _nameController = TextEditingController();
  final _idController = TextEditingController();
  final _emailController = TextEditingController();
  final List<TextEditingController> _otpControllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _otpFocusNodes = List.generate(6, (_) => FocusNode());
  CountryCode _selectedCountry = kCountryCodes.first;
  String? _selectedCounty;
  bool _otpVerified = false;
  bool _navigatedAfterAuth = false;
  bool _fetchingOtp = false;
  final _api = ParkingIqApi();

  @override
  void initState() {
    super.initState();
    if (kDebugMode) _fetchLatestOtp();
  }

  Future<void> _fetchLatestOtp() async {
    if (_fetchingOtp) return;
    setState(() => _fetchingOtp = true);
    try {
      final otp = await _api.latestOtp(_normalizedPhoneNumber);
      if (otp != null && otp.length == 6 && mounted) {
        for (var i = 0; i < 6; i++) {
          _otpControllers[i].text = otp[i];
        }
        setState(() => _otpVerified = true);
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _fetchingOtp = false);
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _nameController.dispose();
    _idController.dispose();
    _emailController.dispose();
    for (final c in _otpControllers) {
      c.dispose();
    }
    for (final f in _otpFocusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  void _onOtpDigit(String value, int index) {
    if (value.length == 1 && index < 5) {
      _otpFocusNodes[index + 1].requestFocus();
    } else if (value.isEmpty && index > 0) {
      _otpFocusNodes[index - 1].requestFocus();
    }

    final allFilled = _otpControllers.every((c) => c.text.isNotEmpty);
    setState(() => _otpVerified = allFilled);
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AppBloc, AppState>(
      listenWhen: (previous, current) =>
          previous.authToken != current.authToken ||
          previous.errorMessage != current.errorMessage,
      listener: (context, state) {
        final error = state.errorMessage;
        if (error != null && error.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(error)),
          );
        }

        if (!_navigatedAfterAuth && state.isAuthenticated) {
          _navigatedAfterAuth = true;
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const PlateNumberScreen()),
          );
        }
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 32),
                const ParkIQLogo(),
                const SizedBox(height: 24),
                Text(
                  'Create Account',
                  style: GoogleFonts.poppins(
                    fontSize: 28,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Set up once. Park hands-free forever.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 24),
                _phoneCard(),
                const SizedBox(height: 18),
                _field(label: 'Full Name', controller: _nameController),
                const SizedBox(height: 16),
                _field(
                  label: 'ID Number',
                  controller: _idController,
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                _countyDropdown(),
                const SizedBox(height: 16),
                _emailField(),
                const SizedBox(height: 26),
                BlocBuilder<AppBloc, AppState>(
                  builder: (context, state) {
                    return PrimaryButton(
                      text: 'Continue to Add Your Car \u2192',
                      isLoading: state.isLoading,
                      onPressed: state.isLoading ? null : _registerAccount,
                    );
                  },
                ),
                const SizedBox(height: 18),
                GestureDetector(
                  onTap: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const SignInScreen()),
                    );
                  },
                  child: RichText(
                    text: TextSpan(
                      text: 'Already a member? ',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: AppColors.textMuted,
                      ),
                      children: [
                        TextSpan(
                          text: 'Sign in',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 34),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _phoneCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.accentLight,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.mintBorder, width: 1.3),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label('Phone Number'),
          const SizedBox(height: 8),
          Row(
            children: [
              CountryCodeSelector(
                selected: _selectedCountry,
                onChanged: (code) => setState(() => _selectedCountry = code),
                decoration: _inputBoxDecoration(Colors.white),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  height: 54,
                  decoration: _inputBoxDecoration(Colors.white),
                  child: TextField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    style: GoogleFonts.poppins(fontSize: 15, color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
                      hintText: '712 345 678',
                      hintStyle: GoogleFonts.poppins(color: AppColors.textMuted, fontSize: 15),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          GestureDetector(
            onTap: kDebugMode ? _fetchLatestOtp : null,
            child: Row(
              children: [
                if (_fetchingOtp)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  Icon(
                    LucideIcons.checkCircle,
                    size: 16,
                    color: _otpVerified ? AppColors.accent : AppColors.textMuted,
                  ),
                const SizedBox(width: 7),
                Text(
                  _otpVerified ? 'OTP verified' : 'Enter code',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: _otpVerified ? AppColors.accent : AppColors.textSecondary,
                  ),
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    kDebugMode
                        ? '\u00B7 Tap to auto-fill OTP'
                        : '\u00B7 Code sent to your number',
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final boxWidth = ((constraints.maxWidth - 50) / 6).clamp(40.0, 56.0);
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(6, (i) => _otpBox(i, boxWidth)),
              );
            },
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
        inputFormatters: [
          LengthLimitingTextInputFormatter(1),
          FilteringTextInputFormatter.digitsOnly,
        ],
        style: GoogleFonts.poppins(
          fontSize: 20,
          fontWeight: FontWeight.w500,
          color: AppColors.textPrimary,
        ),
        onChanged: (v) => _onOtpDigit(v, index),
        decoration: InputDecoration(
          filled: true,
          fillColor: Colors.white,
          counterText: '',
          contentPadding: EdgeInsets.zero,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: filled ? AppColors.primary : AppColors.inputBorder,
              width: filled ? 2 : 1,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.primary, width: 2),
          ),
        ),
      ),
    );
  }

  Widget _field({
    required String label,
    required TextEditingController controller,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(label),
        const SizedBox(height: 7),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          style: GoogleFonts.poppins(fontSize: 15, color: AppColors.textPrimary),
          decoration: _fieldDecoration(),
        ),
      ],
    );
  }

  Widget _countyDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('County'),
        const SizedBox(height: 7),
        DropdownButtonFormField<String>(
          value: _selectedCounty,
          icon: const Icon(LucideIcons.chevronDown, color: AppColors.textSecondary, size: 18),
          decoration: _fieldDecoration(hint: 'Select your county'),
          style: GoogleFonts.poppins(fontSize: 15, color: AppColors.textPrimary),
          dropdownColor: Colors.white,
          items: ['Nairobi', 'Mombasa', 'Kisumu', 'Nakuru', 'Eldoret', 'Thika', 'Nyeri']
              .map((county) => DropdownMenuItem(value: county, child: Text(county)))
              .toList(),
          onChanged: (value) => setState(() => _selectedCounty = value),
        ),
      ],
    );
  }

  Widget _emailField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _label('Email Address', muted: true),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.pageGrey,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                'Optional',
                style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textMuted),
              ),
            ),
          ],
        ),
        const SizedBox(height: 7),
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          style: GoogleFonts.poppins(fontSize: 15, color: AppColors.textPrimary),
          decoration: _fieldDecoration(hint: 'your@email.com'),
        ),
      ],
    );
  }

  Widget _label(String text, {bool muted = false}) {
    return Text(
      text,
      style: GoogleFonts.poppins(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: muted ? AppColors.textMuted : AppColors.textSecondary,
      ),
    );
  }

  InputDecoration _fieldDecoration({String? hint}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.poppins(color: AppColors.textMuted, fontSize: 15),
      filled: true,
      fillColor: AppColors.inputFill,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
      border: _fieldBorder(AppColors.inputBorder),
      enabledBorder: _fieldBorder(AppColors.inputBorder),
      focusedBorder: _fieldBorder(AppColors.primary, width: 1.5),
    );
  }

  OutlineInputBorder _fieldBorder(Color color, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: color, width: width),
    );
  }

  BoxDecoration _inputBoxDecoration(Color color) {
    return BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.inputBorder),
    );
  }

  void _registerAccount() {
    final fullName = _nameController.text.trim();
    final idNumber = _idController.text.trim();
    final otp = _otpControllers.map((controller) => controller.text).join();

    if (fullName.isEmpty || idNumber.isEmpty || otp.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Complete your details and OTP first')),
      );
      return;
    }

    context.read<AppBloc>().add(
          RegisterAccount(
            phoneNumber: _normalizedPhoneNumber,
            otp: otp,
            fullName: fullName,
            idNumber: idNumber,
            county: _selectedCounty ?? 'Nairobi',
            email: _emailController.text.trim().isEmpty
                ? null
                : _emailController.text.trim(),
          ),
        );
  }

  String get _normalizedPhoneNumber {
    final digits = _phoneController.text.replaceAll(RegExp(r'\D'), '');
    final local = digits.startsWith('0') ? digits.substring(1) : digits;
    return '${_selectedCountry.dialCode}$local';
  }
}
