import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../blocs/app_bloc.dart';
import '../../blocs/app_event.dart';
import '../../blocs/app_state.dart';
import '../../core/theme/app_colors.dart';
import '../../models/vehicle.dart';
import '../../widgets/app_widgets.dart';
import '../../widgets/primary_button.dart';
import '../dashboard/main_nav.dart';

class ActivateAutoPayScreen extends StatefulWidget {
  const ActivateAutoPayScreen({super.key});

  @override
  State<ActivateAutoPayScreen> createState() => _ActivateAutoPayScreenState();
}

class _ActivateAutoPayScreenState extends State<ActivateAutoPayScreen> {
  bool _autoPayOn = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.pageGrey,
      body: SafeArea(
        child: BlocBuilder<AppBloc, AppState>(
          builder: (context, state) {
            final vehicle = state.vehicles.isEmpty ? null : state.vehicles.last;

            return SingleChildScrollView(
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    color: context.colors.surface,
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                    child: Column(
                      children: [
                        OnboardingStepHeader(
                          step: 4,
                          totalSteps: 4,
                          title: 'Activate AutoPay',
                          trailing: _lastStepBadge(),
                        ),
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            'Almost there!',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              color: context.colors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 22, 24, 20),
                    child: Column(
                      children: [
                        _vehicleCard(vehicle),
                        const SizedBox(height: 20),
                        _autoPayCard(),
                        const SizedBox(height: 22),
                        _howItWorksCard(),
                        const SizedBox(height: 22),
                        PrimaryButton(
                          text: "I'm All Set \u2014 Go to Dashboard",
                          icon: LucideIcons.checkCircle,
                          onPressed: _finishOnboarding,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'You can manage AutoPay anytime in Settings',
                          style: GoogleFonts.poppins(fontSize: 12, color: context.colors.textMuted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _lastStepBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: context.colors.successLight,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.zap, size: 13, color: context.colors.success),
          const SizedBox(width: 5),
          Text(
            'Last step!',
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: context.colors.success,
            ),
          ),
        ],
      ),
    );
  }

  Widget _vehicleCard(Vehicle? vehicle) {
    final plate = vehicle?.plateNumber ?? 'KBZ 123A';
    final make = vehicle?.make ?? 'Toyota';
    final model = vehicle?.model ?? 'Prado';
    final type = vehicle?.type ?? 'SUV';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'REGISTERED VEHICLE',
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: context.colors.textSecondary,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              _softIcon(LucideIcons.car, size: 70),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      plate,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 23,
                        fontWeight: FontWeight.w400,
                        color: context.colors.textPrimary,
                        letterSpacing: 3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$make $model \u00B7 $type',
                      style: GoogleFonts.poppins(fontSize: 13, color: context.colors.textSecondary),
                    ),
                  ],
                ),
              ),
              _anprBadge(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _autoPayCard() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Container(
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: context.colors.primary, width: 2),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 26),
              child: Row(
                children: [
                  _softIcon(LucideIcons.zap, size: 66),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'AutoPay',
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                            color: context.colors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Auto-charge on every exit',
                          style: GoogleFonts.poppins(fontSize: 13, color: context.colors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _autoPayOn,
                    activeThumbColor: Colors.white,
                    activeTrackColor: context.colors.accent,
                    inactiveThumbColor: Colors.white,
                    inactiveTrackColor: context.colors.inputBorder,
                    onChanged: (value) => setState(() => _autoPayOn = value),
                  ),
                ],
              ),
            ),
            Container(
              width: double.infinity,
              color: context.colors.successLight,
              padding: const EdgeInsets.fromLTRB(28, 14, 28, 16),
              child: Row(
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: context.colors.accent,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _autoPayOn
                          ? 'AutoPay is ON \u00B7 Payments happen\nautomatically at exit'
                          : 'AutoPay is OFF \u00B7 You can turn it on anytime',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        height: 1.25,
                        color: context.colors.success,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _howItWorksCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 24),
      decoration: BoxDecoration(
        color: context.colors.darkPanel,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.shield, size: 17, color: context.colors.accent),
              const SizedBox(width: 10),
              Text(
                'How it works',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          _howStep(
            number: '01',
            title: 'Drive In',
            desc: 'ANPR camera reads your plate at the\nbarrier automatically',
          ),
          const SizedBox(height: 24),
          _howStep(
            number: '02',
            title: 'Park Freely',
            desc: 'No tickets, no apps \u2014 just park and go\nabout your day',
          ),
          const SizedBox(height: 24),
          _howStep(
            number: '03',
            title: 'Exit & Pay',
            desc: 'Camera reads plate at exit, wallet is\ncharged instantly',
          ),
        ],
      ),
    );
  }

  Widget _howStep({
    required String number,
    required String title,
    required String desc,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.07),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Text(
            number,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: context.colors.accent,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                desc,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  height: 1.45,
                  color: Colors.white.withValues(alpha: 0.62),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _softIcon(IconData icon, {required double size}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: context.colors.accentLight,
        borderRadius: BorderRadius.circular(size * 0.24),
      ),
      child: Icon(icon, color: context.colors.primary, size: size * 0.34),
    );
  }

  Widget _anprBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: context.colors.pageGrey,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: context.colors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.camera, size: 13, color: context.colors.textSecondary),
          const SizedBox(width: 5),
          Text(
            'ANPR',
            style: GoogleFonts.poppins(fontSize: 12, color: context.colors.textSecondary),
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

  void _finishOnboarding() {
    final bloc = context.read<AppBloc>();
    final vehicles = bloc.state.vehicles;
    if (_autoPayOn && vehicles.isNotEmpty) {
      final vehicle = vehicles.last;
      bloc.add(
        SetVehicleAutoPay(
          vehicleId: vehicle.id,
          plateNumber: vehicle.plateNumber,
          enabled: true,
        ),
      );
    }
    bloc.add(LoadDashboardData());

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const MainNavigation()),
      (route) => false,
    );
  }
}
