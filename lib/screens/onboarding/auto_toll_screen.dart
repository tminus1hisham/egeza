import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../blocs/app_bloc.dart';
import '../../blocs/app_event.dart';
import '../../core/theme/app_colors.dart';
import '../../widgets/app_widgets.dart';
import '../../widgets/primary_button.dart';
import 'activate_autopay_screen.dart';

class AutoTollScreen extends StatefulWidget {
  const AutoTollScreen({super.key});

  @override
  State<AutoTollScreen> createState() => _AutoTollScreenState();
}

class _AutoTollScreenState extends State<AutoTollScreen> {
  int _selectedAmount = 1000;
  final _customAmountController = TextEditingController();

  @override
  void dispose() {
    _customAmountController.dispose();
    super.dispose();
  }

  String get _formattedAmount => 'KES ${_selectedAmount.toString().replaceAllMapped(
        RegExp(r'\B(?=(\d{3})+(?!\d))'),
        (match) => ',',
      )}';

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: context.colors.pageGrey,
        body: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  color: context.colors.surface,
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                  child: Column(
                    children: [
                      const SizedBox(height: 52),
                      const OnboardingHeroIcon(icon: LucideIcons.zap, size: 92),
                      const SizedBox(height: 24),
                      Text(
                        'Enable Seamless Exit',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: 24,
                          fontWeight: FontWeight.w500,
                          color: context.colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'with AutoPay',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.w400,
                          color: context.colors.primary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Add funds to your wallet. At exit, the fee is\ndeducted automatically.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          height: 1.45,
                          color: context.colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
                  child: Column(
                    children: [
                      _topUpCard(),
                      const SizedBox(height: 20),
                      _paymentCard(),
                      const SizedBox(height: 20),
                      PrimaryButton(
                        text: 'Top Up $_formattedAmount via M-Pesa',
                        icon: LucideIcons.zap,
                        onPressed: _topUpAndContinue,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        "You'll be prompted on your M-Pesa-registered phone",
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(fontSize: 12, color: context.colors.textMuted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _topUpCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Select top-up amount',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w400,
              color: context.colors.textPrimary,
            ),
          ),
          const SizedBox(height: 18),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 3.1,
            children: [
              _amountTile(500),
              _amountTile(1000),
              _amountTile(2000),
              _amountTile(5000),
            ],
          ),
          const SizedBox(height: 16),
          Divider(color: context.colors.border.withValues(alpha: 0.8), height: 1),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Or enter custom amount:',
                  style: GoogleFonts.poppins(fontSize: 13, color: context.colors.textMuted),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 132,
                height: 46,
                child: TextField(
                  controller: _customAmountController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: GoogleFonts.poppins(fontSize: 14, color: context.colors.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'KES___',
                    hintStyle: GoogleFonts.poppins(fontSize: 14, color: context.colors.textMuted),
                    filled: true,
                    fillColor: context.colors.pageGrey,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    border: _fieldBorder(context.colors.inputBorder),
                    enabledBorder: _fieldBorder(context.colors.inputBorder),
                    focusedBorder: _fieldBorder(context.colors.primary, width: 1.5),
                  ),
                  onChanged: (value) {
                    final parsed = int.tryParse(value);
                    if (parsed != null && parsed > 0) {
                      setState(() => _selectedAmount = parsed);
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _amountTile(int amount) {
    final selected = _selectedAmount == amount;
    final label = 'KES ${amount.toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (match) => ',',
    )}';

    return GestureDetector(
      onTap: () {
        _customAmountController.clear();
        setState(() => _selectedAmount = amount);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? context.colors.accentLight : context.colors.pageGrey,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? context.colors.primary : context.colors.inputBorder,
            width: selected ? 2 : 1,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w400,
            color: selected ? context.colors.primary : context.colors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _paymentCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Pay with',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w400,
              color: context.colors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: context.colors.successLight,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: context.colors.accent, width: 1),
            ),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: const Color(0xFF13A753),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(LucideIcons.smartphone, color: Colors.white, size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'M-Pesa',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: context.colors.textPrimary,
                        ),
                      ),
                      Text(
                        'Instantly funded via\nmobile money',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          height: 1.25,
                          color: context.colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(LucideIcons.checkCircle, color: context.colors.accent, size: 26),
              ],
            ),
          ),
        ],
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
          color: Colors.black.withValues(alpha: 0.035),
          blurRadius: 14,
          offset: const Offset(0, 6),
        ),
      ],
    );
  }

  OutlineInputBorder _fieldBorder(Color color, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: color, width: width),
    );
  }

  void _topUpAndContinue() {
    context.read<AppBloc>().add(TopUpWallet(_selectedAmount.toDouble()));
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ActivateAutoPayScreen()),
    );
  }
}
