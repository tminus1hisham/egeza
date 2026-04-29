import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';
import '../../widgets/app_widgets.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/plate_number_input.dart';
import '../../widgets/primary_button.dart';
import 'auto_toll_screen.dart';

class PlateNumberScreen extends StatefulWidget {
  const PlateNumberScreen({super.key});

  @override
  State<PlateNumberScreen> createState() => _PlateNumberScreenState();
}

class _PlateNumberScreenState extends State<PlateNumberScreen> {
  String _plate = 'K3Z123A';
  String _selectedType = 'Sedan';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: const Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: AppColors.textPrimary),
                    ),
                  ),
                  const Spacer(),
                  const OnboardingStepper(currentStep: 1, totalSteps: 4),
                ],
              ),
              const SizedBox(height: 28),
              Text(
                'Plate Number',
                style: GoogleFonts.poppins(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "Enter your vehicle's registration plate number",
                style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 28),

              // Plate preview display
              _buildPlatePreview(),
              const SizedBox(height: 24),

              // Plate input
              Text(
                'Enter Plate',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              PlateNumberInput(
                initialValue: _plate,
                onChanged: (v) => setState(() => _plate = v),
              ),
              const SizedBox(height: 20),

              AppTextField(label: 'Address', hint: 'Parking address'),
              const SizedBox(height: 16),

              // Date picker row
              Row(
                children: [
                  Expanded(
                    child: AppTextField(
                      label: 'Date',
                      hint: 'MM/DD/YYYY',
                      keyboardType: TextInputType.datetime,
                      suffix: const Icon(Icons.calendar_today_outlined, size: 16, color: AppColors.textMuted),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildDropdown(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              AppTextField(label: 'Model', hint: 'e.g. Honda Civic'),
              const SizedBox(height: 32),
              PrimaryButton(
                text: 'Save Vehicle & Continue',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AutoTollScreen()),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlatePreview() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      decoration: BoxDecoration(
        color: AppColors.plateBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.plateYellow, width: 2),
      ),
      child: Center(
        child: Text(
          _plate.isEmpty ? 'K3Z 123A' : _plate.replaceRange(
            _plate.length >= 3 ? 3 : _plate.length,
            _plate.length >= 3 ? 3 : _plate.length,
            _plate.length >= 3 ? ' ' : '',
          ),
          style: GoogleFonts.poppins(
            fontSize: 32,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
            letterSpacing: 4,
          ),
        ),
      ),
    );
  }

  Widget _buildDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Vehicle Type',
          style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          value: _selectedType,
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.surface,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.inputBorder, width: 1.2),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.inputBorder, width: 1.2),
            ),
          ),
          items: ['Sedan', 'SUV', 'Truck', 'Motorcycle', 'Van'].map((v) {
            return DropdownMenuItem(value: v, child: Text(v, style: GoogleFonts.poppins(fontSize: 13)));
          }).toList(),
          onChanged: (v) => setState(() => _selectedType = v!),
        ),
      ],
    );
  }
}
