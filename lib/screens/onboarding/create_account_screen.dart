import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/api/parking_iq_api.dart';
import '../../core/theme/app_colors.dart';
import '../../widgets/app_widgets.dart';
import '../../widgets/country_code_selector.dart';
import '../../widgets/primary_button.dart';
import '../auth/sign_in_screen.dart';
import 'verify_otp_screen.dart';

class CreateAccountScreen extends StatefulWidget {
  final bool showGuideOnOpen;

  const CreateAccountScreen({
    super.key,
    this.showGuideOnOpen = true,
  });

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

  @override
  void initState() {
    super.initState();
    if (widget.showGuideOnOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showSetupGuide();
      });
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _nameController.dispose();
    _idController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              OnboardingStepHeader(
                step: 1,
                totalSteps: 2,
                title: 'Create Account',
                onBack: _goToSignIn,
                trailing: AppHeaderButton(
                  icon: LucideIcons.helpCircle,
                  onTap: _showSetupGuide,
                  tooltip: 'Setup guide',
                ),
              ),
              const SizedBox(height: 24),
              const Center(child: ParkIQLogo(size: 42)),
              const SizedBox(height: 22),
              Center(
                child: Text(
                  "Let's set up your account",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 27,
                    height: 1.12,
                    fontWeight: FontWeight.w700,
                    color: context.colors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Set up once. Park hands-free with a verified ParkIQ profile.',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  color: context.colors.textSecondary,
                ),
              ),
              const SizedBox(height: 24),
              _setupOverviewCard(),
              const SizedBox(height: 18),
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
              PrimaryButton(
                text: 'Continue to Verify OTP \u2192',
                icon: LucideIcons.messageCircle,
                isLoading: _isSendingOtp,
                onPressed: _isSendingOtp ? null : _continueToVerifyOtp,
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
    );
  }

  Widget _setupOverviewCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.colors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 16,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: context.colors.infoLight,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  LucideIcons.map,
                  color: context.colors.info,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your setup walkthrough',
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: context.colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Have these details ready before OTP verification',
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: context.colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _overviewItem(
            icon: LucideIcons.smartphone,
            title: 'Verify your phone',
            description: 'Use a number that can receive a 6-digit OTP.',
          ),
          const SizedBox(height: 12),
          _overviewItem(
            icon: LucideIcons.badgeCheck,
            title: 'Confirm your identity',
            description: 'Enter your full name, ID number, and county.',
          ),
          const SizedBox(height: 12),
          _overviewItem(
            icon: LucideIcons.car,
            title: 'Next: add your vehicle',
            description: 'Your plate connects parking sessions to your account.',
          ),
        ],
      ),
    );
  }

  Widget _overviewItem({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: context.colors.accentLight,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 16, color: context.colors.primary),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: context.colors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
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
    );
  }

  Widget _phoneCard() {
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
          _label('Phone Number'),
          const SizedBox(height: 8),
          Row(
            children: [
              CountryCodeSelector(
                selected: _selectedCountry,
                onChanged: (code) => setState(() => _selectedCountry = code),
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
          style: GoogleFonts.poppins(
            fontSize: 15,
            color: context.colors.textPrimary,
          ),
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
          initialValue: _selectedCounty,
          icon: Icon(
            LucideIcons.chevronDown,
            color: context.colors.textSecondary,
            size: 18,
          ),
          decoration: _fieldDecoration(hint: 'Select your county'),
          style: GoogleFonts.poppins(
            fontSize: 15,
            color: context.colors.textPrimary,
          ),
          dropdownColor: context.colors.surface,
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
          style: GoogleFonts.poppins(
            fontSize: 15,
            color: context.colors.textPrimary,
          ),
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
        color: muted ? context.colors.textMuted : context.colors.textSecondary,
      ),
    );
  }

  InputDecoration _fieldDecoration({String? hint}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.poppins(
        color: context.colors.textMuted,
        fontSize: 15,
      ),
      filled: true,
      fillColor: context.colors.inputFill,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
      border: _fieldBorder(context.colors.inputBorder),
      enabledBorder: _fieldBorder(context.colors.inputBorder),
      focusedBorder: _fieldBorder(context.colors.primary, width: 1.5),
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
                  description: 'Your full name, ID number, and county help secure the account.',
                ),
                _guideSheetStep(
                  icon: LucideIcons.car,
                  title: 'Add your vehicle after OTP',
                  description: 'Your plate is what ParkIQ uses to match parking sessions.',
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
    final fullName = _nameController.text.trim();
    final idNumber = _idController.text.trim();

    if (!_hasValidPhoneNumber || fullName.isEmpty || idNumber.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Complete your phone, name, and ID first')),
      );
      return;
    }

    FocusScope.of(context).unfocus();
    final phoneNumber = _normalizedPhoneNumber;
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_friendlyError(error))),
      );
    } finally {
      if (mounted) setState(() => _isSendingOtp = false);
    }
  }

  bool get _hasValidPhoneNumber {
    return _phoneController.text.replaceAll(RegExp(r'\D'), '').length >= 9;
  }

  String _friendlyError(Object error) {
    if (error is ApiException) return error.message;
    return error.toString().replaceFirst('Exception: ', '');
  }

  String get _normalizedPhoneNumber {
    final digits = _phoneController.text.replaceAll(RegExp(r'\D'), '');
    final local = digits.startsWith('0') ? digits.substring(1) : digits;
    return '${_selectedCountry.dialCode}$local';
  }
}
