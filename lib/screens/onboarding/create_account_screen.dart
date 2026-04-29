import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/primary_button.dart';
import 'package:google_fonts/google_fonts.dart';
import 'plate_number_screen.dart';
import 'package:lucide_icons/lucide_icons.dart';

class CreateAccountScreen extends StatelessWidget {
  const CreateAccountScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(LucideIcons.parkingCircle, color: Colors.white, size: 16),
            ),
            const SizedBox(width: 8),
            Text(
              'Park IQ',
              style: GoogleFonts.poppins(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
          ],
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            Text(
              'Create Account',
              style: GoogleFonts.poppins(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Enter your details below to get started',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 32),
            const CustomTextField(
              label: 'Full Name',
              hintText: 'John Doe',
            ),
            const SizedBox(height: 20),
            const CustomTextField(
              label: 'Phone Number',
              hintText: '+254 700 000 000',
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 20),
            const CustomTextField(
              label: 'Email Address',
              hintText: 'john@example.com',
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 20),
            const CustomTextField(
              label: 'Location / City',
              hintText: 'Nairobi',
            ),
            const SizedBox(height: 20),
            const CustomTextField(
              label: 'Password',
              hintText: '••••••••',
              isPassword: true,
              suffixIcon: Icon(LucideIcons.eyeOff, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 40),
            PrimaryButton(
              text: 'Create Account & Continue',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PlateNumberScreen()),
                );
              },
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Already have an account? ',
                  style: GoogleFonts.poppins(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                  ),
                ),
                Text(
                  'Log In',
                  style: GoogleFonts.poppins(
                    color: AppColors.primary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
