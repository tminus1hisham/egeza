import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../blocs/app_bloc.dart';
import '../blocs/app_event.dart';
import '../core/theme/app_colors.dart';
import 'dashboard/main_nav.dart';
import 'onboarding/walkthrough_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 2800), _navigate);
  }

  void _navigate() {
    if (!mounted) return;
    final bloc = context.read<AppBloc>();
    final isAuthenticated = bloc.state.isAuthenticated;
    if (isAuthenticated) {
      bloc.add(LoadDashboardData());
    }
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, animation, _) =>
            isAuthenticated ? const MainNavigation() : const WalkthroughScreen(),
        transitionsBuilder: (_, animation, _, child) => FadeTransition(
          opacity: animation,
          child: child,
        ),
        transitionDuration: const Duration(milliseconds: 600),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              context.colors.primaryDeep,
              Color(0xFF0D3D2B),
              context.colors.primary,
            ],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const Spacer(flex: 3),
              _buildLogo(),
              const SizedBox(height: 32),
              _buildAppName(),
              const SizedBox(height: 10),
              _buildTagline(),
              const Spacer(flex: 3),
              _buildDots(),
              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: context.colors.primaryDeep.withValues(alpha: 0.6),
            blurRadius: 40,
            spreadRadius: 8,
            offset: const Offset(0, 12),
          ),
          BoxShadow(
            color: context.colors.primary.withValues(alpha: 0.3),
            blurRadius: 20,
            spreadRadius: 0,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Image.asset(
          'assets/icon.png',
          fit: BoxFit.cover,
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 600.ms, curve: Curves.easeOut)
        .scale(
          begin: const Offset(0.7, 0.7),
          end: const Offset(1.0, 1.0),
          duration: 700.ms,
          curve: Curves.easeOutBack,
        );
  }

  Widget _buildAppName() {
    return Column(
      children: [
        RichText(
          text: TextSpan(
            style: GoogleFonts.poppins(
              fontSize: 38,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              height: 1.1,
            ),
            children: [
              const TextSpan(
                text: 'Park',
                style: TextStyle(
                  color: Colors.white,
                ),
              ),
              TextSpan(
                text: 'IQ',
                style: TextStyle(
                  color: context.colors.accent,
                ),
              ),
            ],
          ),
        ),
      ],
    )
        .animate(delay: 300.ms)
        .fadeIn(duration: 500.ms)
        .slideY(begin: 0.3, end: 0, duration: 500.ms, curve: Curves.easeOut);
  }

  Widget _buildTagline() {
    return Text(
      'Smart Parking, Simplified',
      style: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        color: Colors.white.withValues(alpha: 0.6),
        letterSpacing: 0.3,
      ),
    )
        .animate(delay: 500.ms)
        .fadeIn(duration: 500.ms)
        .slideY(begin: 0.3, end: 0, duration: 500.ms, curve: Curves.easeOut);
  }

  Widget _buildDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (i) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: i == 1 ? 20 : 6,
          height: 6,
          decoration: BoxDecoration(
            color: i == 1
                ? context.colors.accent
                : Colors.white.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(3),
          ),
        )
            .animate(delay: (700 + i * 100).ms)
            .fadeIn(duration: 400.ms)
            .scaleX(begin: 0, end: 1, duration: 400.ms, curve: Curves.easeOut);
      }),
    );
  }
}
