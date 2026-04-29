import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/plate_number_input.dart';
import 'package:google_fonts/google_fonts.dart';
import 'auto_toll_screen.dart';

class PlateNumberScreen extends StatelessWidget {
  const PlateNumberScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.directions_car, color: AppColors.primary, size: 40),
              ),
            ),
            const SizedBox(height: 24),
            Center(
              child: Text(
                "What's your plate number?",
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                'We use this to identify your vehicle at partner parking lots.',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 40),
            Text(
              'License Plate',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const PlateNumberInput(initialValue: 'KBZ123A'),
            const SizedBox(height: 24),
            Text(
              'Vehicle Type',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              decoration: InputDecoration(
                filled: true,
                fillColor: AppColors.inputFill,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
              ),
              items: ['Sedan', 'SUV', 'Truck', 'Motorcycle'].map((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value, style: GoogleFonts.poppins()),
                );
              }).toList(),
              onChanged: (_) {},
              hint: Text('Select Type', style: GoogleFonts.poppins()),
            ),
            const SizedBox(height: 20),
            Row(
              children: const [
                Expanded(
                  child: CustomTextField(
                    label: 'Brand',
                    hintText: 'Honda',
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: CustomTextField(
                    label: 'Model',
                    hintText: 'Civic',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 40),
            PrimaryButton(
              text: 'Save Vehicle & Continue',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AutoTollScreen()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
