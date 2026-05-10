import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../blocs/app_bloc.dart';
import '../../core/api/parking_iq_api.dart';
import '../../core/theme/app_colors.dart';
import '../../models/api_models.dart';
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
  bool _showTenancyTab = false;

  late final ParkingIqApi _api;
  late final Widget _dashboardScreen;

  @override
  void initState() {
    super.initState();
    _api = ParkingIqApi(token: context.read<AppBloc>().state.authToken);
    _dashboardScreen = DashboardScreen(
      onVehiclesTap: () => _selectTab('vehicles'),
      onWalletTap: () => _selectTab('wallet'),
      onHistoryTap: () => _selectTab('history'),
    );
    _loadTenantAccess();
  }

  List<_NavTab> get _tabs => [
        _NavTab(
          id: 'home',
          activeIcon: Icons.home_rounded,
          inactiveIcon: Icons.home_outlined,
          label: 'Home',
          screen: _dashboardScreen,
        ),
        const _NavTab(
          id: 'vehicles',
          activeIcon: Icons.directions_car_rounded,
          inactiveIcon: Icons.directions_car_outlined,
          label: 'Vehicle',
          screen: VehiclesScreen(),
        ),
        const _NavTab(
          id: 'wallet',
          activeIcon: Icons.account_balance_wallet_rounded,
          inactiveIcon: Icons.account_balance_wallet_outlined,
          label: 'Wallet',
          screen: WalletScreen(),
        ),
        if (_showTenancyTab)
          const _NavTab(
            id: 'tenancy',
            activeIcon: Icons.domain_rounded,
            inactiveIcon: Icons.domain_outlined,
            label: 'Tenancy',
            screen: TenancyScreen(),
          ),
        const _NavTab(
          id: 'history',
          activeIcon: Icons.history_rounded,
          inactiveIcon: Icons.history_outlined,
          label: 'History',
          screen: HistoryScreen(),
        ),
        const _NavTab(
          id: 'settings',
          activeIcon: Icons.settings_rounded,
          inactiveIcon: Icons.settings_outlined,
          label: 'Settings',
          screen: SettingsScreen(),
        ),
      ];

  Future<void> _loadTenantAccess() async {
    try {
      final profiles = await _api.fetchMyTenantProfiles();
      final hasApprovedTenancy = profiles.any(_isApprovedTenantProfile);
      if (!mounted) return;
      setState(() {
        _showTenancyTab = hasApprovedTenancy;
        if (!hasApprovedTenancy && _selectedTabId == 'tenancy') {
          _selectedTabId = 'home';
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _showTenancyTab = false;
        if (_selectedTabId == 'tenancy') _selectedTabId = 'home';
      });
    }
  }

  bool _isApprovedTenantProfile(TenantProfile profile) {
    const blockedStatuses = {
      'REJECTED',
      'DECLINED',
      'CANCELLED',
      'CANCELED',
    };
    // Approved tenancy requests become tenant profiles. A PENDING profile means
    // the subscription/payment is pending, not that the original request is.
    return profile.id.isNotEmpty && !blockedStatuses.contains(profile.status);
  }

  @override
  Widget build(BuildContext context) {
    final tabs = _tabs;
    final selectedIndex = tabs.indexWhere((tab) => tab.id == _selectedTabId);
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
  }

  void _selectTab(String tabId) {
    if (!_tabs.any((tab) => tab.id == tabId)) return;
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

  const _NavTab({
    required this.id,
    required this.activeIcon,
    required this.inactiveIcon,
    required this.label,
    required this.screen,
  });
}
