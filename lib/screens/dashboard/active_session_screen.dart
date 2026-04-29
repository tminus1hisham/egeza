import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../models/parking_session.dart';
import '../../widgets/primary_button.dart';
import 'package:google_fonts/google_fonts.dart';

class ActiveSessionScreen extends StatelessWidget {
  final ParkingSession session;

  const ActiveSessionScreen({super.key, required this.session});

  @override
  Widget build(BuildContext context) {
    final duration = DateTime.now().difference(session.startTime);
    final hours = duration.inHours.toString().padLeft(2, '0');
    final minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Active Session',
          style: GoogleFonts.poppins(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: AppColors.primaryDark,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                children: [
                  const Icon(Icons.local_parking, color: AppColors.textLight, size: 48),
                  const SizedBox(height: 16),
                  Text(
                    session.locationName,
                    style: GoogleFonts.poppins(
                      color: AppColors.textLight,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${session.vehicle.plateNumber} • ${session.vehicle.make}',
                    style: GoogleFonts.poppins(
                      color: AppColors.textLight.withValues(alpha: 0.8),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 32),
                  Text(
                    'Current Session',
                    style: GoogleFonts.poppins(
                      color: AppColors.textLight.withValues(alpha: 0.8),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$hours:$minutes:$seconds',
                    style: GoogleFonts.poppins(
                      color: AppColors.textLight,
                      fontSize: 40,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Accrued Cost',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    color: AppColors.textSecondary,
                  ),
                ),
                Text(
                  'KES ${session.cost.toStringAsFixed(0)}',
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 40),
            PrimaryButton(
              text: 'End Session & Pay',
              onPressed: () {
                // Handle end session logic
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }
}
