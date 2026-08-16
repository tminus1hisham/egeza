import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../blocs/app_bloc.dart';
import '../blocs/app_event.dart';
import '../core/theme/app_colors.dart';
import '../models/vehicle.dart';

/// Opens the add-vehicle bottom sheet.
///
/// Lives here rather than on VehiclesScreen because more than one place opens
/// it — the Vehicles page (fleet card and the add card) and the dashboard's
/// "Add Car" quick action. The sheet owns its own controllers so callers do not
/// have to hold form state they otherwise have no use for.
Future<void> showAddVehicleSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _AddVehicleSheet(),
  );
}

class _AddVehicleSheet extends StatefulWidget {
  const _AddVehicleSheet();

  @override
  State<_AddVehicleSheet> createState() => _AddVehicleSheetState();
}

class _AddVehicleSheetState extends State<_AddVehicleSheet> {
  final _plateController = TextEditingController();
  final _makeController = TextEditingController();
  final _modelController = TextEditingController();
  bool _autoPayOn = true;

  /// The API's `vehicleType` enum, in the order a Kenyan driver is likely to
  /// want it. Labels are derived rather than written out so the picker cannot
  /// drift from what `Vehicle` round-trips.
  ///
  /// The sheet used to send 'Saloon' for every car. Since the API exposes no
  /// vehicle update endpoint, a wrong type at registration could only be
  /// corrected by deleting the plate and adding it again.
  static const _typeCodes = [
    'SALOON',
    'SUV_4X4',
    'HATCHBACK',
    'PICKUP_TRUCK',
    'VAN_MINIBUS',
    'MOTORCYCLE',
  ];

  static final _types =
      _typeCodes.map(Vehicle.vehicleTypeLabel).toList(growable: false);

  String _type = Vehicle.vehicleTypeLabel(_typeCodes.first);

  @override
  void dispose() {
    _plateController.dispose();
    _makeController.dispose();
    _modelController.dispose();
    super.dispose();
  }

  void _save() {
    final plate = _plateController.text.trim().toUpperCase();
    if (plate.isEmpty) return;

    final make = _makeController.text.trim();
    final model = _modelController.text.trim();

    context.read<AppBloc>().add(
          AddVehicle(
            plateNumber: plate,
            type: _type,
            make: make.isEmpty ? 'Custom' : make,
            model: model.isEmpty ? 'Vehicle' : model,
            autoPayEnabled: _autoPayOn,
          ),
        );

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(22, 18, 22, 22),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        ),
        child: SafeArea(
          top: false,
          // The type picker made the sheet tall enough to outgrow a short phone
          // once the keyboard is up, so the form scrolls rather than overflows.
          child: SingleChildScrollView(
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
              _field(
                controller: _plateController,
                label: 'Plate number',
                hint: 'KBZ 123A',
                textCapitalization: TextCapitalization.characters,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _field(
                      controller: _makeController,
                      label: 'Make',
                      hint: 'Toyota',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _field(
                      controller: _modelController,
                      label: 'Model',
                      hint: 'Prado',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _typePicker(),
              const SizedBox(height: 14),
              _autoPayTile(),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton.icon(
                  onPressed: _save,
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
  }

  /// The type drives the parking rate the barrier applies, so it is a choice
  /// rather than an assumption. Laid out as chips because there are only six
  /// and all of them fit — a dropdown would hide the options behind a tap.
  Widget _typePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Vehicle type',
          style: GoogleFonts.poppins(
            color: context.colors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 9),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _types.map((type) {
            final selected = type == _type;

            return GestureDetector(
              onTap: () => setState(() => _type = type),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                decoration: BoxDecoration(
                  color: selected ? context.colors.primary : context.colors.inputFill,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: selected
                        ? context.colors.primary
                        : context.colors.inputBorder,
                  ),
                ),
                child: Text(
                  type,
                  style: GoogleFonts.poppins(
                    color: selected ? Colors.white : context.colors.textSecondary,
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _autoPayTile() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: context.colors.inputFill,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _autoPayOn ? context.colors.primary : context.colors.inputBorder,
          width: _autoPayOn ? 1.6 : 1,
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
                  _autoPayOn
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
            value: _autoPayOn,
            activeThumbColor: Colors.white,
            activeTrackColor: context.colors.accent,
            inactiveThumbColor: Colors.white,
            inactiveTrackColor: context.colors.inputBorder,
            onChanged: (value) => setState(() => _autoPayOn = value),
          ),
        ],
      ),
    );
  }

  Widget _field({
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
}
