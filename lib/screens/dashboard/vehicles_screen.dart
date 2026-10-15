import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../blocs/app_bloc.dart';
import '../../blocs/app_event.dart';
import '../../blocs/app_state.dart';
import '../../core/theme/app_colors.dart';
import '../../models/api_models.dart';
import '../../models/parking_session.dart';
import '../../models/vehicle.dart';
import '../../widgets/add_vehicle_sheet.dart';
import '../../widgets/app_widgets.dart';
import '../../widgets/primary_button.dart';
import 'history_screen.dart';
import 'vehicle_detail_screen.dart';

class VehiclesScreen extends StatefulWidget {
  final bool showBackButton;

  const VehiclesScreen({super.key, this.showBackButton = false});

  @override
  State<VehiclesScreen> createState() => _VehiclesScreenState();
}

class _VehiclesScreenState extends State<VehiclesScreen> {
  int _filterIndex = 0;
  static const _filters = ['All', 'AutoPay', 'AutoPay off'];

  Future<void> _onRefresh() async {
    context.read<AppBloc>().add(LoadDashboardData());
    await Future.delayed(const Duration(milliseconds: 800));
  }

  @override
  Widget build(BuildContext context) {
    return AdaptiveStatusBar(
      child: Scaffold(
        backgroundColor: context.colors.pageGrey,
        body: SafeArea(
          bottom: false,
          child: BlocBuilder<AppBloc, AppState>(
            builder: (context, state) {
              final vehicles = _filteredVehicles(state.vehicles);
              final tenantPlates = _tenantPlates(state);

              return RefreshIndicator(
                color: context.colors.primary,
                onRefresh: _onRefresh,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _fleetCard(state),
                      const SizedBox(height: 14),
                      _filterBar(),
                      const SizedBox(height: 14),
                      _vehicleList(
                        context,
                        vehicles,
                        state.recentSessions,
                        noVehiclesAtAll: state.vehicles.isEmpty,
                        hasTenantPlates: tenantPlates.isNotEmpty,
                      ),
                      // AutoPay on/off is a property of a registered vehicle,
                      // which a tenancy plate is not — it only ever belongs
                      // under 'All'.
                      if (_filterIndex == 0 && tenantPlates.isNotEmpty) ...[
                        const SizedBox(height: 22),
                        _tenantVehicleList(
                          context,
                          tenantPlates,
                          state.recentSessions,
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _fleetCard(AppState state) {
    final autoPayCount = state.vehicles.where((v) => v.autoPayEnabled).length;
    final activeCount = state.recentSessions.where((s) => s.isActive).length;

    return PageHero(
      eyebrow: 'Registered fleet',
      value: '${state.vehicles.length} vehicles',
      onBack: widget.showBackButton ? () => Navigator.pop(context) : null,
      pill: const PageHeroPill(
        icon: Icons.camera_alt_outlined,
        label: 'ANPR ready',
      ),
      // The single persistent way to add a car. It never scrolls out of reach,
      // which is why the duplicate card at the foot of the page is gone.
      trailing: _addVehicleButton(),
      metrics: [
        PageHeroMetric('AutoPay on', '$autoPayCount'),
        PageHeroMetric('AutoPay off', '${state.vehicles.length - autoPayCount}'),
        PageHeroMetric('Parked now', '$activeCount'),
      ],
    );
  }

  Widget _filterBar() {
    return Container(
      height: 40,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.colors.border),
      ),
      child: Row(
        children: List.generate(_filters.length, (index) {
          final selected = index == _filterIndex;

          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _filterIndex = index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 170),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected ? context.colors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Text(
                  _filters[index],
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    color: selected ? Colors.white : context.colors.textSecondary,
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  /// Plates that belong to the user's tenancies rather than to the user.
  ///
  /// A tenant's vehicles live on `TenantDto.plateNumbers` and are never part of
  /// `GET /vehicles`, so a plate an admin attaches to the tenancy would show
  /// nowhere in the app without this. Plates the account has also registered
  /// itself are dropped — those already have a real card above.
  List<_TenantPlate> _tenantPlates(AppState state) {
    final seen = {
      for (final vehicle in state.vehicles)
        Vehicle.plateKey(vehicle.plateNumber),
    }..remove('');
    final plates = <_TenantPlate>[];

    for (final profile in state.visibleTenantProfiles) {
      for (final plate in profile.plateNumbers) {
        final plateKey = Vehicle.plateKey(plate);
        if (plateKey.isEmpty || !seen.add(plateKey)) continue;
        plates.add(_TenantPlate(plateNumber: plate, profile: profile));
      }
    }

    return plates;
  }

  Widget _tenantVehicleList(
    BuildContext context,
    List<_TenantPlate> plates,
    List<ParkingSession> sessions,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Tenancy vehicles',
                style: GoogleFonts.poppins(
                  color: context.colors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text(
              '${plates.length} shown',
              style: GoogleFonts.poppins(
                color: context.colors.textMuted,
                fontSize: 12,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Plates registered on your tenancy, not on this account.',
          style: GoogleFonts.poppins(
            color: context.colors.textMuted,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 10),
        ...plates.map((plate) {
          final plateKey = Vehicle.plateKey(plate.plateNumber);
          final parkedNow = sessions.any(
            (session) =>
                session.isActive &&
                Vehicle.plateKey(session.vehicle.plateNumber) == plateKey,
          );
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _tenantVehicleCard(context, plate, parkedNow: parkedNow),
          );
        }),
      ],
    );
  }

  Widget _tenantVehicleCard(
    BuildContext context,
    _TenantPlate plate, {
    required bool parkedNow,
  }) {
    final location = plate.profile.locationName.trim();
    final subtitle = location.isEmpty
        ? plate.profile.name
        : '${plate.profile.name} - $location';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 15),
      decoration: BoxDecoration(
        color: context.colors.cardSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: context.colors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: context.colors.primary.withValues(alpha: 0.1),
                  ),
                ),
                child: Icon(
                  Icons.domain_rounded,
                  color: context.colors.primary,
                  size: 23,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _plateTag(plate.plateNumber),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        color: context.colors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _statusChip('On your tenancy', true),
              // Nothing is said when the plate is not parked — an absent chip
              // reads as "not here" without another word to decode.
              if (parkedNow) ...[
                const SizedBox(width: 8),
                _statusChip('Parked now', true, soft: true),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _vehicleList(
    BuildContext context,
    List<Vehicle> vehicles,
    List<ParkingSession> sessions, {
    required bool noVehiclesAtAll,
    bool hasTenantPlates = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'My vehicles',
                style: GoogleFonts.poppins(
                  color: context.colors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text(
              '${vehicles.length} shown',
              style: GoogleFonts.poppins(
                color: context.colors.textMuted,
                fontSize: 12,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (vehicles.isEmpty)
          _emptyVehicles(
            noVehiclesAtAll: noVehiclesAtAll,
            hasTenantPlates: hasTenantPlates,
          )
        else
          ...vehicles.map((vehicle) {
            final plateKey = Vehicle.plateKey(vehicle.plateNumber);
            final vehicleSessions = sessions
                .where((session) =>
                    Vehicle.plateKey(session.vehicle.plateNumber) == plateKey)
                .toList();
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _vehicleCard(context, vehicle, vehicleSessions),
            );
          }),
      ],
    );
  }

  Widget _vehicleCard(
    BuildContext context,
    Vehicle vehicle,
    List<ParkingSession> sessions,
  ) {
    final totalSpend = sessions.fold<double>(0, (sum, item) => sum + item.cost);
    final lastSeen = sessions.isEmpty ? 'No sessions' : _dateLabel(sessions.first.startTime);
    final parkedNow = sessions.any((session) => session.isActive);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: context.colors.cardSurface,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => VehicleDetailScreen(vehicle: vehicle),
            ),
          ),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 15),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          context.colors.primary.withValues(alpha: 0.15),
                          context.colors.primary.withValues(alpha: 0.05),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: context.colors.primary.withValues(alpha: 0.1),
                      ),
                    ),
                    child: Icon(
                      Icons.directions_car_rounded,
                      color: context.colors.primary,
                      size: 23,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _plateTag(vehicle.plateNumber),
                        const SizedBox(height: 6),
                        Text(
                          '${vehicle.make} ${vehicle.model} - ${vehicle.type}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            color: context.colors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: context.colors.textMuted,
                    size: 20,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _statusChip(
                    vehicle.autoPayEnabled ? 'AutoPay on' : 'AutoPay off',
                    vehicle.autoPayEnabled,
                  ),
                  if (parkedNow) ...[
                    const SizedBox(width: 8),
                    _statusChip('Parked now', true, soft: true),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _vehicleMetric(
                      'Sessions',
                      '${sessions.length}',
                      Icons.history_rounded,
                      // The count is the summary; the history screen is the
                      // detail behind it, so the tile is the way through.
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              const HistoryScreen(showBackButton: true),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _vehicleMetric(
                      'Last seen',
                      lastSeen,
                      Icons.schedule_rounded,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _vehicleMetric(
                      'Spend',
                      'KES ${_formatCompact(totalSpend)}',
                      Icons.receipt_long_outlined,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ));
  }

  Widget _emptyVehicles({
    required bool noVehiclesAtAll,
    bool hasTenantPlates = false,
  }) {
    if (!noVehiclesAtAll) {
      // Filter returned no results, but user does have vehicles
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: context.colors.cardSurface,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          'No vehicles match this filter',
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            color: context.colors.textSecondary,
            fontSize: 13,
          ),
        ),
      );
    }

    // True empty state — no vehicles registered at all
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.directions_car_outlined,
            size: 46,
            color: context.colors.textMuted,
          ),
          const SizedBox(height: 14),
          Text(
            'No vehicles yet',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: context.colors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            hasTenantPlates
                ? 'Your tenancy plates are listed below. Add your own '
                    'vehicle to use AutoPay.'
                : 'Add your first vehicle to start parking',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: context.colors.textMuted,
            ),
          ),
          const SizedBox(height: 18),
          PrimaryButton(
            text: 'Add Vehicle',
            onPressed: () => showAddVehicleSheet(context),
          ),
        ],
      ),
    );
  }

  Widget _plateTag(String plate) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: context.colors.plateBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: context.colors.plateYellow.withValues(alpha: 0.35)),
      ),
      child: Text(
        plate,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.poppins(
          color: isDark ? context.colors.plateYellow : const Color(0xFF573A05),
          fontSize: 13,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _statusChip(String label, bool active, {bool soft = false}) {
    final color = active
        ? context.colors.success
        : soft
            ? context.colors.textSecondary
            : context.colors.warning;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: active
            ? context.colors.successLight
            : soft
                ? context.colors.surfaceRaised
                : context.colors.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _vehicleMetric(
    String label,
    String value,
    IconData icon, {
    VoidCallback? onTap,
  }) {
    final tile = Container(
      height: 66,
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      decoration: BoxDecoration(
        color: onTap == null ? context.colors.surfaceRaised : null,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.colors.border.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                color: onTap == null
                    ? context.colors.textMuted
                    : context.colors.primary,
                size: 13,
              ),
              const Spacer(),
              // A tappable tile needs to look tappable next to two that
              // aren't — the chevron is the only thing separating them.
              if (onTap != null)
                Icon(
                  Icons.chevron_right_rounded,
                  color: context.colors.primary,
                  size: 14,
                ),
            ],
          ),
          const Spacer(),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              color: context.colors.textPrimary,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              color: onTap == null
                  ? context.colors.textSecondary
                  : context.colors.primary,
              fontSize: 9.5,
              fontWeight: onTap == null ? FontWeight.w400 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return tile;

    // Sits inside the card's own InkWell; the nested one takes the tap first,
    // so the tile routes to history while the rest of the card opens the car.
    return Material(
      color: context.colors.surfaceRaised,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: tile,
      ),
    );
  }

  /// Compact add control sitting inside the fleet card, beside the vehicle
  /// count. Styled for the dark card, so it uses translucent white rather than
  /// the brand colour.
  Widget _addVehicleButton() {
    return Material(
      color: Colors.white.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: () => showAddVehicleSheet(context),
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 6, 12, 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withValues(alpha: 0.24)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.add_rounded, color: Colors.white, size: 16),
              const SizedBox(width: 4),
              Text(
                'Add',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Vehicle> _filteredVehicles(List<Vehicle> vehicles) {
    if (_filterIndex == 1) {
      return vehicles.where((vehicle) => vehicle.autoPayEnabled).toList();
    }
    if (_filterIndex == 2) {
      return vehicles.where((vehicle) => !vehicle.autoPayEnabled).toList();
    }
    return vehicles;
  }

  String _dateLabel(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final sessionDay = DateTime(dateTime.year, dateTime.month, dateTime.day);
    final diff = today.difference(sessionDay).inDays;

    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (diff < 7) return '${diff}d ago';

    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${dateTime.day} ${months[dateTime.month - 1]}';
  }

  String _formatCompact(double amount) {
    if (amount >= 1000) {
      final value = amount / 1000;
      return '${value.toStringAsFixed(value >= 10 ? 0 : 1)}k';
    }
    return amount.toStringAsFixed(0);
  }

}

/// One plate carried by a tenancy the user belongs to, kept with the profile it
/// came from so the card can name the site.
class _TenantPlate {
  final String plateNumber;
  final TenantProfile profile;

  const _TenantPlate({required this.plateNumber, required this.profile});
}
