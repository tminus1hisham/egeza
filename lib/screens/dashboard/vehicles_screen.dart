import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../blocs/app_bloc.dart';
import '../../blocs/app_event.dart';
import '../../blocs/app_state.dart';
import '../../core/theme/app_colors.dart';
import '../../models/parking_session.dart';
import '../../models/vehicle.dart';
import '../../widgets/app_widgets.dart';
import '../../widgets/primary_button.dart';
import '../onboarding/plate_number_screen.dart';
import 'vehicle_detail_screen.dart';

class VehiclesScreen extends StatefulWidget {
  final bool showBackButton;

  const VehiclesScreen({super.key, this.showBackButton = false});

  @override
  State<VehiclesScreen> createState() => _VehiclesScreenState();
}

class _VehiclesScreenState extends State<VehiclesScreen> {
  int _filterIndex = 0;
  final _plateController = TextEditingController();
  final _makeController = TextEditingController();
  final _modelController = TextEditingController();
  bool _sheetAutoPayOn = true;
  static const _filters = ['All', 'AutoPay', 'Manual'];

  @override
  void dispose() {
    _plateController.dispose();
    _makeController.dispose();
    _modelController.dispose();
    super.dispose();
  }

  Future<void> _onRefresh() async {
    context.read<AppBloc>().add(LoadDashboardData());
    await Future.delayed(const Duration(milliseconds: 800));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.pageGrey,
      body: SafeArea(
        bottom: false,
        child: BlocBuilder<AppBloc, AppState>(
          builder: (context, state) {
            final vehicles = _filteredVehicles(state.vehicles);

            return Column(
              children: [
                _header(context),
                Expanded(
                  child: RefreshIndicator(
                    color: context.colors.primary,
                    onRefresh: _onRefresh,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 30),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _fleetCard(state),
                          const SizedBox(height: 18),
                          _filterBar(),
                          const SizedBox(height: 18),
                          _vehicleList(
                            context,
                            vehicles,
                            state.recentSessions,
                            noVehiclesAtAll: state.vehicles.isEmpty,
                          ),
                          const SizedBox(height: 18),
                          _addVehicleCard(context),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    return AppPageHeader(
      title: 'Vehicles',
      subtitle: 'Plates, AutoPay, and parking status',
      icon: Icons.directions_car_outlined,
      showBackButton: widget.showBackButton,
      onBack: () => Navigator.pop(context),
      trailing: AppHeaderButton(
        icon: Icons.add_rounded,
        tooltip: 'Add vehicle',
        active: true,
        onTap: () => _showAddVehicleSheet(context),
      ),
    );
  }

  Widget _fleetCard(AppState state) {
    final autoPayCount = state.vehicles.where((v) => v.autoPayEnabled).length;
    final activeCount = state.recentSessions.where((s) => s.isActive).length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 24),
      decoration: BoxDecoration(
        color: context.colors.primaryDark,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: context.colors.primaryDark.withValues(alpha: 0.15),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Registered fleet',
                  style: GoogleFonts.poppins(
                    color: Colors.white.withValues(alpha: 0.68),
                    fontSize: 13,
                  ),
                ),
              ),
              _darkPill(Icons.camera_alt_outlined, 'ANPR ready'),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '${state.vehicles.length} vehicles',
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 32,
              height: 1.1,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(child: _fleetMetric('AutoPay on', '$autoPayCount')),
              _metricDivider(),
              Expanded(child: _fleetMetric('Manual', '${state.vehicles.length - autoPayCount}')),
              _metricDivider(),
              Expanded(child: _fleetMetric('Parked now', '$activeCount')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _filterBar() {
    return Container(
      height: 46,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(16),
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
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _filters[index],
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

  Widget _vehicleList(
    BuildContext context,
    List<Vehicle> vehicles,
    List<ParkingSession> sessions, {
    required bool noVehiclesAtAll,
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
                  fontSize: 16,
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
        const SizedBox(height: 12),
        if (vehicles.isEmpty)
          _emptyVehicles(noVehiclesAtAll: noVehiclesAtAll)
        else
          ...vehicles.map((vehicle) {
            final vehicleSessions = sessions
                .where((session) =>
                    session.vehicle.plateNumber == vehicle.plateNumber)
                .toList();
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
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

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: context.colors.cardSurface,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => VehicleDetailScreen(vehicle: vehicle),
            ),
          ),
          borderRadius: BorderRadius.circular(24),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          context.colors.primary.withValues(alpha: 0.15),
                          context.colors.primary.withValues(alpha: 0.05),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: context.colors.primary.withValues(alpha: 0.1),
                      ),
                    ),
                    child: Icon(
                      Icons.directions_car_rounded,
                      color: context.colors.primary,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _plateTag(vehicle.plateNumber),
                        const SizedBox(height: 8),
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
                  const SizedBox(width: 10),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: context.colors.textMuted,
                    size: 22,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _statusChip(
                    vehicle.autoPayEnabled ? 'AutoPay on' : 'Manual pay',
                    vehicle.autoPayEnabled,
                  ),
                  const SizedBox(width: 8),
                  _statusChip(
                    sessions.any((session) => session.isActive)
                        ? 'Parked now'
                        : 'Clear',
                    sessions.any((session) => session.isActive),
                    soft: true,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _vehicleMetric(
                      'Sessions',
                      '${sessions.length}',
                      Icons.history_rounded,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _vehicleMetric(
                      'Last seen',
                      lastSeen,
                      Icons.schedule_rounded,
                    ),
                  ),
                  const SizedBox(width: 10),
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

  Widget _addVehicleCard(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: context.colors.cardSurface,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          onTap: () => _showAddVehicleSheet(context),
          borderRadius: BorderRadius.circular(24),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
            ),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      context.colors.warning.withValues(alpha: 0.18),
                      context.colors.warning.withValues(alpha: 0.10),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.add_rounded,
                  color: context.colors.warning,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Add vehicle',
                      style: GoogleFonts.poppins(
                        color: context.colors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Register another plate for ANPR',
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
              Icon(
                Icons.chevron_right_rounded,
                color: context.colors.textMuted,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    ));
  }

  Widget _emptyVehicles({required bool noVehiclesAtAll}) {
    if (!noVehiclesAtAll) {
      // Filter returned no results, but user does have vehicles
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(26),
        decoration: BoxDecoration(
          color: context.colors.cardSurface,
          borderRadius: BorderRadius.circular(24),
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
      padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.directions_car_outlined,
            size: 64,
            color: context.colors.textMuted,
          ),
          const SizedBox(height: 24),
          Text(
            'No vehicles yet',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: context.colors.textPrimary,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Add your first vehicle to start parking',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: context.colors.textMuted,
            ),
          ),
          const SizedBox(height: 24),
          PrimaryButton(
            text: 'Add Vehicle',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PlateNumberScreen()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _plateTag(String plate) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: context.colors.plateBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: context.colors.plateYellow.withValues(alpha: 0.35)),
      ),
      child: Text(
        plate,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.poppins(
          color: isDark ? context.colors.plateYellow : const Color(0xFF573A05),
          fontSize: 14,
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

  Widget _vehicleMetric(String label, String value, IconData icon) {
    return Container(
      height: 76,
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 11),
      decoration: BoxDecoration(
        color: context.colors.surfaceRaised,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.colors.border.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: context.colors.textMuted, size: 15),
          const Spacer(),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              color: context.colors.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              color: context.colors.textSecondary,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _darkPill(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white.withValues(alpha: 0.78), size: 13),
          const SizedBox(width: 5),
          Text(
            label,
            style: GoogleFonts.poppins(
              color: Colors.white.withValues(alpha: 0.82),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _fleetMetric(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.poppins(
            color: Colors.white.withValues(alpha: 0.58),
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _metricDivider() {
    return Container(
      width: 1,
      height: 34,
      margin: const EdgeInsets.symmetric(horizontal: 14),
      color: Colors.white.withValues(alpha: 0.14),
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

  void _showAddVehicleSheet(BuildContext context) {
    _plateController.clear();
    _makeController.clear();
    _modelController.clear();
    _sheetAutoPayOn = true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
          ),
          child: Container(
            padding: const EdgeInsets.fromLTRB(22, 18, 22, 22),
            decoration: BoxDecoration(
              color: context.colors.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: context.colors.border,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  Text(
                    'Add vehicle',
                    style: GoogleFonts.poppins(
                      color: context.colors.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _sheetField(
                    controller: _plateController,
                    label: 'Plate number',
                    hint: 'KBZ 123A',
                    textCapitalization: TextCapitalization.characters,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _sheetField(
                          controller: _makeController,
                          label: 'Make',
                          hint: 'Toyota',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _sheetField(
                          controller: _modelController,
                          label: 'Model',
                          hint: 'Prado',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _sheetAutoPayTile(setSheetState),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton.icon(
                      onPressed: () => _saveVehicle(context, sheetContext),
                      icon: const Icon(Icons.check_circle_outline_rounded),
                      label: Text(
                        'Save Vehicle',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: context.colors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          ),
        );
      },
    );
  }

  Widget _sheetAutoPayTile(StateSetter setSheetState) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: context.colors.inputFill,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _sheetAutoPayOn
              ? context.colors.primary
              : context.colors.inputBorder,
          width: _sheetAutoPayOn ? 1.6 : 1,
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.bolt_rounded, color: context.colors.primary, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AutoPay',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: context.colors.textPrimary,
                  ),
                ),
                Text(
                  _sheetAutoPayOn
                      ? 'Charged automatically at exit'
                      : 'Pay manually for each session',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: context.colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: _sheetAutoPayOn,
            activeThumbColor: Colors.white,
            activeTrackColor: context.colors.accent,
            inactiveThumbColor: Colors.white,
            inactiveTrackColor: context.colors.inputBorder,
            onChanged: (value) =>
                setSheetState(() => _sheetAutoPayOn = value),
          ),
        ],
      ),
    );
  }

  Widget _sheetField({
    required TextEditingController controller,
    required String label,
    required String hint,
    TextCapitalization textCapitalization = TextCapitalization.words,
  }) {
    return TextField(
      controller: controller,
      textCapitalization: textCapitalization,
      style: GoogleFonts.poppins(
        color: context.colors.textPrimary,
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: context.colors.inputFill,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: context.colors.inputBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: context.colors.inputBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: context.colors.primary, width: 1.6),
        ),
      ),
    );
  }

  void _saveVehicle(BuildContext context, BuildContext sheetContext) {
    final plate = _plateController.text.trim().toUpperCase();
    if (plate.isEmpty) {
      return;
    }

    final make = _makeController.text.trim();
    final model = _modelController.text.trim();

    context.read<AppBloc>().add(
          AddVehicle(
            plateNumber: plate,
            type: 'Saloon',
            make: make.isEmpty ? 'Custom' : make,
            model: model.isEmpty ? 'Vehicle' : model,
            autoPayEnabled: _sheetAutoPayOn,
          ),
        );

    Navigator.pop(sheetContext);
  }
}
