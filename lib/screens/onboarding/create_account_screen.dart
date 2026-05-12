import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/api/parking_iq_api.dart';
import '../../core/error_handler.dart';
import '../../core/theme/app_colors.dart';
import '../../widgets/country_code_selector.dart';
import '../../widgets/primary_button.dart';
import '../auth/sign_in_screen.dart';
import 'verify_otp_screen.dart';

class CreateAccountScreen extends StatefulWidget {
  final bool showGuideOnOpen;

  const CreateAccountScreen({super.key, this.showGuideOnOpen = true});

  @override
  State<CreateAccountScreen> createState() => _CreateAccountScreenState();
}

class _CreateAccountScreenState extends State<CreateAccountScreen> {
  final _phoneController = TextEditingController();
  final _nameController = TextEditingController();
  final _idController = TextEditingController();
  final _emailController = TextEditingController();
  final _api = ParkingIqApi();

  CountryCode _selectedCountry = kCountryCodes.first;
  String? _selectedCounty;
  bool _isSendingOtp = false;

  // Validation errors
  String? _phoneError;
  String? _nameError;
  String? _idError;
  String? _countyError;
  String? _emailError;

  static final _emailRegExp = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  @override
  void initState() {
    super.initState();
    if (widget.showGuideOnOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showSetupGuide();
      });
    }
    _phoneController.addListener(_clearPhoneError);
    _nameController.addListener(_clearNameError);
    _idController.addListener(_clearIdError);
    _emailController.addListener(_clearEmailError);
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _nameController.dispose();
    _idController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  void _clearPhoneError() {
    if (_phoneError != null) setState(() => _phoneError = null);
  }

  void _clearNameError() {
    if (_nameError != null) setState(() => _nameError = null);
  }

  void _clearIdError() {
    if (_idError != null) setState(() => _idError = null);
  }

  void _clearEmailError() {
    if (_emailError != null) setState(() => _emailError = null);
  }

  bool _validate() {
    final digits = _phoneController.text.replaceAll(RegExp(r'\D'), '');
    final localDigits = digits.startsWith('0') ? digits.substring(1) : digits;
    final fullName = _nameController.text.trim();
    final idNumber = _idController.text.trim();
    final email = _emailController.text.trim();

    String? phoneErr;
    String? nameErr;
    String? idErr;
    String? countyErr;
    String? emailErr;

    if (localDigits.length < 9 || localDigits.length > 12) {
      phoneErr = 'Enter a valid phone number (9–12 digits)';
    }

    final nameParts = fullName.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (fullName.isEmpty) {
      nameErr = 'Full name is required';
    } else if (nameParts.length < 2) {
      nameErr = 'Enter at least two names';
    } else if (!RegExp(r'^[a-zA-Z\s]+$').hasMatch(fullName)) {
      nameErr = 'Name must contain letters and spaces only';
    }

    if (idNumber.isEmpty) {
      idErr = 'ID number is required';
    } else if (!RegExp(r'^\d{7,8}$').hasMatch(idNumber)) {
      idErr = 'Enter a valid 7–8 digit ID number';
    }

    if (_selectedCounty == null) {
      countyErr = 'Please select your county';
    }

    if (email.isNotEmpty && !_emailRegExp.hasMatch(email)) {
      emailErr = 'Enter a valid email address';
    }

    setState(() {
      _phoneError = phoneErr;
      _nameError = nameErr;
      _idError = idErr;
      _countyError = countyErr;
      _emailError = emailErr;
    });

    return phoneErr == null &&
        nameErr == null &&
        idErr == null &&
        countyErr == null &&
        emailErr == null;
  }

  bool get _canSubmit {
    if (_isSendingOtp) return false;
    final digits = _phoneController.text.replaceAll(RegExp(r'\D'), '');
    final local = digits.startsWith('0') ? digits.substring(1) : digits;
    return local.length >= 9 &&
        _nameController.text.trim().isNotEmpty &&
        _idController.text.trim().isNotEmpty &&
        _selectedCounty != null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      body: Stack(
        children: [
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Text(
                      'Create your account',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 27,
                        height: 1.12,
                        fontWeight: FontWeight.w700,
                        color: context.colors.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  _phoneCard(),
                  const SizedBox(height: 18),
                  _validatedField(
                    label: 'Full Name',
                    controller: _nameController,
                    error: _nameError,
                    readOnly: _isSendingOtp,
                  ),
                  const SizedBox(height: 16),
                  _validatedField(
                    label: 'ID Number',
                    controller: _idController,
                    error: _idError,
                    keyboardType: TextInputType.number,
                    readOnly: _isSendingOtp,
                  ),
                  const SizedBox(height: 16),
                  _countyDropdown(),
                  const SizedBox(height: 16),
                  _emailField(),
                  const SizedBox(height: 26),
                  PrimaryButton(
                    text: 'Continue to Verify OTP →',
                    icon: LucideIcons.messageCircle,
                    isLoading: _isSendingOtp,
                    onPressed: _canSubmit ? _continueToVerifyOtp : null,
                  ),
                  const SizedBox(height: 18),
                  GestureDetector(
                    onTap: _goToSignIn,
                    child: RichText(
                      text: TextSpan(
                        text: 'Already a member? ',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: context.colors.textMuted,
                        ),
                        children: [
                          TextSpan(
                            text: 'Sign in',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: context.colors.textSecondary,
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
          // Loading overlay
          if (_isSendingOtp)
            Positioned.fill(
              child: Container(
                color: Colors.black26,
                child: const Center(
                  child: CircularProgressIndicator(),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _phoneCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.accentLight,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: _phoneError != null
              ? context.colors.error
              : context.colors.mintBorder,
          width: 1.3,
        ),
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
                onChanged: _isSendingOtp
                    ? (_) {}
                    : (code) => setState(() {
                          _selectedCountry = code;
                          _clearPhoneError();
                        }),
                decoration: _inputBoxDecoration(context.colors.inputFill),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  height: 54,
                  decoration: _inputBoxDecoration(context.colors.inputFill),
                  child: TextField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    readOnly: _isSendingOtp,
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
                      hintText: '7XX XXX XXX',
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
          if (_phoneError != null) ...[
            const SizedBox(height: 6),
            _errorText(_phoneError!),
          ] else ...[
            const SizedBox(height: 13),
            Row(
              children: [
                Icon(
                  LucideIcons.shieldCheck,
                  size: 16,
                  color: context.colors.primary,
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    'We will send a 6-digit code to verify this number',
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: context.colors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _validatedField({
    required String label,
    required TextEditingController controller,
    String? error,
    TextInputType keyboardType = TextInputType.text,
    bool readOnly = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(label),
        const SizedBox(height: 7),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          readOnly: readOnly,
          style: GoogleFonts.poppins(
            fontSize: 15,
            color: context.colors.textPrimary,
          ),
          decoration: _fieldDecoration(hasError: error != null),
        ),
        if (error != null) ...[
          const SizedBox(height: 4),
          _errorText(error),
        ],
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
          icon: Icon(
            LucideIcons.chevronDown,
            color: context.colors.textSecondary,
            size: 18,
          ),
          decoration: _fieldDecoration(
            hint: 'Select your county',
            hasError: _countyError != null,
          ),
          style: GoogleFonts.poppins(
            fontSize: 15,
            color: context.colors.textPrimary,
          ),
          dropdownColor: context.colors.surface,
          items: [
            'Nairobi',
            'Mombasa',
            'Kisumu',
            'Nakuru',
            'Eldoret',
            'Thika',
            'Nyeri',
          ]
              .map(
                (county) =>
                    DropdownMenuItem(value: county, child: Text(county)),
              )
              .toList(),
          onChanged: _isSendingOtp
              ? null
              : (value) => setState(() {
                    _selectedCounty = value;
                    _countyError = null;
                  }),
        ),
        if (_countyError != null) ...[
          const SizedBox(height: 4),
          _errorText(_countyError!),
        ],
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
                color: context.colors.pageGrey,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                'Optional',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: context.colors.textMuted,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 7),
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          readOnly: _isSendingOtp,
          style: GoogleFonts.poppins(
            fontSize: 15,
            color: context.colors.textPrimary,
          ),
          decoration: _fieldDecoration(
            hint: 'your@email.com',
            hasError: _emailError != null,
          ),
        ),
        if (_emailError != null) ...[
          const SizedBox(height: 4),
          _errorText(_emailError!),
        ],
      ],
    );
  }

  Widget _label(String text, {bool muted = false}) {
    return Text(
      text,
      style: GoogleFonts.poppins(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: muted ? context.colors.textMuted : context.colors.textSecondary,
      ),
    );
  }

  Widget _errorText(String message) {
    return Row(
      children: [
        Icon(Icons.error_outline, size: 14, color: context.colors.error),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            message,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: context.colors.error,
            ),
          ),
        ),
      ],
    );
  }

  InputDecoration _fieldDecoration({String? hint, bool hasError = false}) {
    final borderColor =
        hasError ? context.colors.error : context.colors.inputBorder;
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.poppins(
        color: context.colors.textMuted,
        fontSize: 15,
      ),
      filled: true,
      fillColor: context.colors.inputFill,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
      border: _fieldBorder(borderColor),
      enabledBorder: _fieldBorder(
        hasError ? context.colors.error : context.colors.inputBorder,
      ),
      focusedBorder: _fieldBorder(
        hasError ? context.colors.error : context.colors.primary,
        width: 1.5,
      ),
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
      border: Border.all(color: context.colors.inputBorder),
    );
  }

  void _showSetupGuide() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
            decoration: BoxDecoration(
              color: context.colors.surface,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: context.colors.border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.14),
                  blurRadius: 32,
                  offset: const Offset(0, 18),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 46,
                    height: 5,
                    decoration: BoxDecoration(
                      color: context.colors.border,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            context.colors.primary,
                            context.colors.primaryDark,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Icon(
                        LucideIcons.sparkles,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Before you create your account',
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              height: 1.18,
                              fontWeight: FontWeight.w800,
                              color: context.colors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'The setup takes about two minutes.',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              color: context.colors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _guideSheetStep(
                  icon: LucideIcons.phoneCall,
                  title: 'Use your active phone number',
                  description: 'We send an OTP before saving your account.',
                ),
                _guideSheetStep(
                  icon: LucideIcons.contact,
                  title: 'Enter matching personal details',
                  description:
                      'Your full name, ID number, and county help secure the account.',
                ),
                _guideSheetStep(
                  icon: LucideIcons.car,
                  title: 'Add your vehicle after OTP',
                  description:
                      'Your plate is what egesha uses to match parking sessions.',
                ),
                const SizedBox(height: 18),
                PrimaryButton(
                  text: 'Start Account Setup',
                  icon: LucideIcons.checkCircle2,
                  onPressed: () => Navigator.pop(sheetContext),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _guideSheetStep({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: context.colors.accentLight,
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: context.colors.mintBorder),
            ),
            child: Icon(icon, size: 18, color: context.colors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: context.colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  description,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    height: 1.35,
                    color: context.colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _goToSignIn() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const SignInScreen()),
    );
  }

  Future<void> _continueToVerifyOtp() async {
    if (!_validate()) return;

    FocusScope.of(context).unfocus();
    final phoneNumber = _normalizedPhoneNumber;
    final fullName = _nameController.text.trim();
    final idNumber = _idController.text.trim();
    final email = _emailController.text.trim();

    setState(() => _isSendingOtp = true);
    try {
      await _api.sendOtp(phoneNumber);
      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => VerifyOtpScreen(
            phoneNumber: phoneNumber,
            fullName: fullName,
            idNumber: idNumber,
            county: _selectedCounty ?? 'Nairobi',
            email: email.isEmpty ? null : email,
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ErrorHandler.showError(context, error);
    } finally {
      if (mounted) setState(() => _isSendingOtp = false);
    }
  }

  String get _normalizedPhoneNumber {
    final digits = _phoneController.text.replaceAll(RegExp(r'\D'), '');
    final local = digits.startsWith('0') ? digits.substring(1) : digits;
    return '${_selectedCountry.dialCode}$local';
  }
}
