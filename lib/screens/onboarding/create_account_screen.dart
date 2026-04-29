import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';
import '../../widgets/app_widgets.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/primary_button.dart';
import 'plate_number_screen.dart';

class CreateAccountScreen extends StatelessWidget {
  const CreateAccountScreen({super.key});

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
              // Header row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const ParkIQLogo(),
                  const OnboardingStepper(currentStep: 0, totalSteps: 4),
                ],
              ),
              const SizedBox(height: 28),
              Text(
                'Create Account',
                style: GoogleFonts.poppins(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Fill in your details to get started with Park IQ',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 28),
              const AppTextField(label: 'Address', hint: 'e.g. 123 Westlands, Nairobi'),
              const SizedBox(height: 16),
              const AppTextField(
                label: 'Email',
                hint: 'john@email.com',
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              const AppTextField(label: 'First name', hint: 'John'),
              const SizedBox(height: 16),
              const AppTextField(
                label: 'Phone',
                hint: '+254 700 000 000',
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),
              const AppTextField(
                label: 'Password',
                hint: '••••••••',
                obscure: true,
              ),
              const SizedBox(height: 32),
              PrimaryButton(
                text: 'Create Account & Continue',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PlateNumberScreen()),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Already have an account? ',
                    style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textSecondary),
                  ),
                  GestureDetector(
                    onTap: () {},
                    child: Text(
                      'Sign In',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
