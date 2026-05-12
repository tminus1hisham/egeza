import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../blocs/app_bloc.dart';
import '../../blocs/app_state.dart';
import '../../core/theme/app_colors.dart';
import '../onboarding/walkthrough_screen.dart';
import 'dashboard_screen.dart';
import 'history_screen.dart';
import 'settings_screen.dart';
import 'tenancy_screen.dart';
import 'vehicles_screen.dart';
import 'wallet_screen.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  String _selectedTabId = 'home';

  late final Widget _dashboardScreen;

  @override
  void initState() {
    super.initState();
    _dashboardScreen = DashboardScreen(
      onVehiclesTap: () => _selectTab('vehicles'),
      onWalletTap: () => _selectTab('wallet'),
      onHistoryTap: () => _selectTab('history'),
      onTenancyTap: () => _selectTab('tenancy'),
      onSettingsTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const SettingsScreen(showBackButton: true),
        ),
      ),
    );
  }

  List<_NavTab> _tabsFor(AppState state) {
    final homeTab = _NavTab(
      id: 'home',
      activeIcon: Icons.home_rounded,
      inactiveIcon: Icons.home_outlined,
      label: 'Home',
      screen: _dashboardScreen,
    );
    const vehiclesTab = _NavTab(
      id: 'vehicles',
      activeIcon: Icons.directions_car_rounded,
      inactiveIcon: Icons.directions_car_outlined,
      label: 'Vehicles',
      screen: VehiclesScreen(),
    );
    const walletTab = _NavTab(
      id: 'wallet',
      activeIcon: Icons.account_balance_wallet_rounded,
      inactiveIcon: Icons.account_balance_wallet_outlined,
      label: 'Wallet',
      screen: WalletScreen(),
    );
    const historyTab = _NavTab(
      id: 'history',
      activeIcon: Icons.history_rounded,
      inactiveIcon: Icons.history_outlined,
      label: 'History',
      screen: HistoryScreen(),
    );

    if (state.shouldShowTenancy) {
      return [
        homeTab,
        _NavTab(
          id: 'tenancy',
          activeIcon: Icons.domain_rounded,
          inactiveIcon: Icons.domain_outlined,
          label: 'Tenancy',
          screen: const TenancyScreen(),
          showBadge: state.payableTenantProfileCount > 0,
        ),
        walletTab,
        vehiclesTab,
        historyTab,
      ];
    }
    return [homeTab, vehiclesTab, walletTab, historyTab];
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AppBloc, AppState>(
      listenWhen: (prev, curr) =>
          (!prev.sessionExpired && curr.sessionExpired) ||
          (prev.shouldShowTenancy && !curr.shouldShowTenancy),
      listener: (context, state) {
        if (state.sessionExpired) {
          _showSessionExpiredDialog(context);
        }
        if (!state.shouldShowTenancy && _selectedTabId == 'tenancy') {
          setState(() => _selectedTabId = 'home');
        }
      },
      builder: (context, state) {
        final tabs = _tabsFor(state);
        final selectedIndex =
            tabs.indexWhere((tab) => tab.id == _selectedTabId);
        final effectiveIndex = selectedIndex < 0 ? 0 : selectedIndex;

        return Scaffold(
          body: IndexedStack(
            index: effectiveIndex,
            children: [for (final tab in tabs) tab.screen],
          ),
          bottomNavigationBar: SafeArea(
            top: false,
            minimum: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            child: Container(
              height: 72,
              decoration: BoxDecoration(
                color: context.colors.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: context.colors.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.09),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Row(
                children: [
                  for (final tab in tabs) _navItem(tab),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showSessionExpiredDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.65),
      builder: (_) => const _SessionExpiredDialog(),
    );
  }

  void _selectTab(String tabId) {
    if (!_tabsFor(context.read<AppBloc>().state).any((tab) => tab.id == tabId)) {
      return;
    }
    setState(() => _selectedTabId = tabId);
  }

  Widget _navItem(_NavTab tab) {
    final isActive = _selectedTabId == tab.id;
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _selectTab(tab.id),
          borderRadius: BorderRadius.circular(22),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeInOut,
                    width: isActive ? 42 : 34,
                    height: 30,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isActive ? context.colors.accentLight : Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      isActive ? tab.activeIcon : tab.inactiveIcon,
                      color: isActive ? context.colors.primary : context.colors.textMuted,
                      size: 21,
                    ),
                  ),
                  if (tab.showBadge)
                    Positioned(
                      right: -2,
                      top: -2,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: context.colors.error,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: context.colors.surface,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                tab.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  height: 1,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                  color: isActive ? context.colors.primary : context.colors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavTab {
  final String id;
  final IconData activeIcon;
  final IconData inactiveIcon;
  final String label;
  final Widget screen;
  final bool showBadge;

  const _NavTab({
    required this.id,
    required this.activeIcon,
    required this.inactiveIcon,
    required this.label,
    required this.screen,
    this.showBadge = false,
  });
}

class _SessionExpiredDialog extends StatelessWidget {
  const _SessionExpiredDialog();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = context.colors;

    return PopScope(
      canPop: false,
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 28),
        child: Container(
          padding: const EdgeInsets.fromLTRB(28, 36, 28, 28),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A2420) : Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 40,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.lock_outline_rounded,
                  size: 34,
                  color: colors.primary,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Session Expired',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                'Your session has expired. Please sign in again to continue.',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: colors.textSecondary,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: colors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    textStyle: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onPressed: () {
                    Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
                      PageRouteBuilder(
                        pageBuilder: (_, animation, _) =>
                            const WalkthroughScreen(),
                        transitionsBuilder: (_, animation, _, child) =>
                            FadeTransition(opacity: animation, child: child),
                        transitionDuration: const Duration(milliseconds: 400),
                      ),
                      (_) => false,
                    );
                  },
                  child: const Text('Sign In Again'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
