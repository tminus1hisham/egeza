import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme/app_colors.dart';

class PlateNumberInput extends StatefulWidget {
  final ValueChanged<String> onChanged;
  final String initialValue;

  const PlateNumberInput({
    super.key,
    required this.onChanged,
    this.initialValue = 'KBZ 123A',
  });

  @override
  State<PlateNumberInput> createState() => _PlateNumberInputState();
}

class _PlateNumberInputState extends State<PlateNumberInput> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _formatPlate(widget.initialValue));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onChanged(_controller.text);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _formatPlate(String value) {
    final compact = value.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toUpperCase();
    final limited = compact.length > 7 ? compact.substring(0, 7) : compact;
    if (limited.length <= 3) {
      return limited;
    }
    return '${limited.substring(0, 3)} ${limited.substring(3)}';
  }

  void _handleChanged(String value) {
    final formatted = _formatPlate(value);
    if (formatted != value) {
      _controller.value = TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
    }
    widget.onChanged(formatted);
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.plateBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.plateYellow, width: 2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              height: 32,
              alignment: Alignment.center,
              color: AppColors.plateYellow,
              child: Text(
                'KENYA',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                  letterSpacing: 5,
                ),
              ),
            ),
            TextField(
              controller: _controller,
              textAlign: TextAlign.center,
              textCapitalization: TextCapitalization.characters,
              keyboardType: TextInputType.text,
              maxLength: 8,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9 ]')),
              ],
              style: GoogleFonts.poppins(
                fontSize: 34,
                fontWeight: FontWeight.w400,
                color: AppColors.textPrimary,
                letterSpacing: 10,
              ),
              decoration: const InputDecoration(
                counterText: '',
                filled: true,
                fillColor: AppColors.plateBg,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 18, vertical: 20),
              ),
              onChanged: _handleChanged,
            ),
          ],
        ),
      ),
    );
  }
}
