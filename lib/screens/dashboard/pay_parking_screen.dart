import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';
import '../../widgets/primary_button.dart';


class PayParkingScreen extends StatefulWidget {
  const PayParkingScreen({super.key});

  @override
  State<PayParkingScreen> createState() => _PayParkingScreenState();
}

class _PayParkingScreenState extends State<PayParkingScreen> {
  late List<TextEditingController> _controllers;
  late List<FocusNode> _focusNodes;

  // Kenyan plate: 3 letters + 3 digits + 1 letter = 7 chars
  static const int _len = 7;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(_len, (_) => TextEditingController());
    _focusNodes = List.generate(_len, (_) => FocusNode());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNodes[0].requestFocus();
    });
  }

  @override
  void dispose() {
    for (final c in _controllers) { c.dispose(); }
    for (final f in _focusNodes) { f.dispose(); }
    super.dispose();
  }

  bool _isLetter(int i) => i < 3 || i == 6;

  String get _plate {
    return _controllers.map((c) => c.text.toUpperCase()).join();
  }

  String get _plateFormatted {
    final raw = _plate;
    if (raw.length >= 3) return '${raw.substring(0, 3)} ${raw.substring(3)}';
    return raw;
  }

  void _onFind() {
    if (_plate.length < 7) return;
    // Show a found-session bottom sheet
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            Text('Session Found', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            Text('$_plateFormatted · Garden City Mall · 2h 15m · KES 225',
              style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textSecondary), textAlign: TextAlign.center),
            const SizedBox(height: 24),
            PrimaryButton(text: 'Pay KES 225', onPressed: () { Navigator.pop(context); Navigator.pop(context); }),
            const SizedBox(height: 10),
            TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel', style: GoogleFonts.poppins(color: AppColors.textSecondary))),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override

  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 16,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Text(
                    'Pay Parking',
                    style: GoogleFonts.poppins(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const SizedBox(height: 16),

                    // Yellow plate entry area
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(20, 28, 20, 28),
                      decoration: BoxDecoration(
                        color: AppColors.plateBg,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.plateYellow, width: 2),
                      ),
                      child: Column(
                        children: [
                          Text(
                            'KENYA',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textMuted,
                              letterSpacing: 3,
                            ),
                          ),
                          const SizedBox(height: 12),

                          // 7 character boxes
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              ...List.generate(_len, (i) {
                                final items = [_plateBox(i)];
                                if (i == 2) {
                                  items.add(const SizedBox(width: 12));
                                }
                                return Row(children: items);
                              }),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Enter plate to initiate payment',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 36),

                    PrimaryButton(
                      text: 'Find Parking Session →',
                      onPressed: _onFind,
                    ),
                    const SizedBox(height: 20),

                    // Hint
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.accentLight,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline_rounded,
                              color: AppColors.primary, size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Enter the plate number as shown on the vehicle (e.g. KBZ 123A)',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: AppColors.primary,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _plateBox(int i) {
    return Container(
      width: 38,
      height: 50,
      margin: const EdgeInsets.symmetric(horizontal: 3),
      child: TextFormField(
        controller: _controllers[i],
        focusNode: _focusNodes[i],
        textAlign: TextAlign.center,
        textCapitalization: TextCapitalization.characters,
        maxLength: 1,
        inputFormatters: [
          FilteringTextInputFormatter.allow(
            _isLetter(i) ? RegExp(r'[a-zA-Z]') : RegExp(r'[0-9]'),
          ),
        ],
        style: GoogleFonts.poppins(
          fontSize: 22,
          fontWeight: FontWeight.w800,
          color: AppColors.textPrimary,
        ),
        decoration: InputDecoration(
          counterText: '',
          filled: true,
          fillColor: Colors.white,
          contentPadding: EdgeInsets.zero,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppColors.plateYellow, width: 1.5),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppColors.plateYellow, width: 1.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppColors.primaryDark, width: 2.5),
          ),
        ),
        onChanged: (val) {
          if (val.isNotEmpty && i < _len - 1) {
            _focusNodes[i + 1].requestFocus();
          }
          setState(() {});
        },
      ),
    );
  }
}
