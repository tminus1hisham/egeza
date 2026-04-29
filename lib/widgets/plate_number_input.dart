import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme/app_colors.dart';

/// The iconic yellow Kenyan-style license plate input widget.
class PlateNumberInput extends StatefulWidget {
  final String? initialValue;
  final ValueChanged<String>? onChanged;

  const PlateNumberInput({super.key, this.initialValue, this.onChanged});

  @override
  State<PlateNumberInput> createState() => _PlateNumberInputState();
}

class _PlateNumberInputState extends State<PlateNumberInput> {
  late List<TextEditingController> _controllers;
  late List<FocusNode> _focusNodes;

  // Kenyan plate: 3 letters + 3 numbers + 1 letter = 7 chars
  static const int _length = 7;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(_length, (i) {
      final c = TextEditingController();
      if (widget.initialValue != null && i < widget.initialValue!.length) {
        c.text = widget.initialValue![i];
      }
      return c;
    });
    _focusNodes = List.generate(_length, (_) => FocusNode());
  }

  @override
  void dispose() {
    for (final c in _controllers) { c.dispose(); }
    for (final f in _focusNodes) { f.dispose(); }
    super.dispose();
  }

  bool _isLetter(int index) => index < 3 || index == 6;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.plateBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.plateYellow, width: 2),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(_length, (i) {
          return _buildBox(i);
        }),
      ),
    );
  }

  Widget _buildBox(int index) {
    return SizedBox(
      width: 38,
      height: 50,
      child: TextFormField(
        controller: _controllers[index],
        focusNode: _focusNodes[index],
        textAlign: TextAlign.center,
        textCapitalization: TextCapitalization.characters,
        maxLength: 1,
        inputFormatters: [
          FilteringTextInputFormatter.allow(
            _isLetter(index) ? RegExp(r'[a-zA-Z]') : RegExp(r'[0-9]'),
          ),
        ],
        style: GoogleFonts.poppins(
          fontSize: 20,
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
            borderSide: const BorderSide(color: AppColors.primary, width: 2),
          ),
        ),
        onChanged: (val) {
          if (val.isNotEmpty && index < _length - 1) {
            _focusNodes[index + 1].requestFocus();
          }
          final plate = _controllers.map((c) => c.text.toUpperCase()).join();
          widget.onChanged?.call(plate);
        },
      ),
    );
  }
}
