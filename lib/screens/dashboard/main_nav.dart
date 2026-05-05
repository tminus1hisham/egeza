import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';
import 'dashboard_screen.dart';
import 'history_screen.dart';
import 'settings_screen.dart';
import 'vehicles_screen.dart';
import 'wallet_screen.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _index = 0;

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      DashboardScreen(
        onVehiclesTap: () => _selectTab(1),
        onWalletTap: () => _selectTab(2),
        onHistoryTap: () => _selectTab(3),
      ),
      const VehiclesScreen(),
      const WalletScreen(),
      const HistoryScreen(),
      const SettingsScreen(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _screens),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: context.colors.surface,
          border: Border(
            top: BorderSide(color: context.colors.border, width: 1),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.07),
              blurRadius: 16,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: SafeArea(
          child: SizedBox(
            height: 64,
            child: Row(
              children: [
                _navItem(0, Icons.home_rounded, Icons.home_outlined, 'Home'),
                _navItem(1, Icons.directions_car_rounded, Icons.directions_car_outlined, 'Vehicle'),
                _navItem(
                  2,
                  Icons.account_balance_wallet_rounded,
                  Icons.account_balance_wallet_outlined,
                  'Wallet',
                ),
                _navItem(3, Icons.history_rounded, Icons.history_rounded, 'History'),
                _navItem(4, Icons.settings_rounded, Icons.settings_outlined, 'Settings'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _selectTab(int index) {
    setState(() => _index = index);
  }

  Widget _navItem(int idx, IconData activeIcon, IconData inactiveIcon, String label) {
    final isActive = _index == idx;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _index = idx),
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
              decoration: BoxDecoration(
                color: isActive ? context.colors.accentLight : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                isActive ? activeIcon : inactiveIcon,
                color: isActive ? context.colors.primary : context.colors.textMuted,
                size: 21,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 10,
                height: 1,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                color: isActive ? context.colors.primary : context.colors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
