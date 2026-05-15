import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../blocs/app_bloc.dart';
import '../../blocs/app_event.dart';
import '../../core/error_handler.dart';
import '../../core/theme/app_colors.dart';
import '../../widgets/app_widgets.dart';
import '../../widgets/primary_button.dart';
import '../dashboard/main_nav.dart';

class PlateNumberScreen extends StatefulWidget {
  const PlateNumberScreen({super.key});

  @override
  State<PlateNumberScreen> createState() => _PlateNumberScreenState();
}

class _PlateNumberScreenState extends State<PlateNumberScreen> {
  final _plateController = TextEditingController();
  final _makeController = TextEditingController();
  final _modelController = TextEditingController();
  String _selectedType = 'SUV / 4x4';
  bool _autoPayOn = true;

  @override
  void dispose() {
    _plateController.dispose();
    _makeController.dispose();
    _modelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 30),
              const Center(child: OnboardingHeroIcon(icon: LucideIcons.car, size: 96)),
              const SizedBox(height: 24),
              Center(
                child: Text(
                  "What's your plate number?",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 25,
                    fontWeight: FontWeight.w500,
                    color: context.colors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Center(
                child: Text(
                  'We use this to identify your vehicle at\nANPR cameras',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    color: context.colors.textSecondary,
                    height: 1.35,
                  ),
                ),
              ),
              const SizedBox(height: 34),
              _smallField('Number Plate', _plateController, hint: 'e.g. KBZ 123A'),
              const SizedBox(height: 24),
              _label('Vehicle Type'),
              const SizedBox(height: 8),
              _vehicleTypeSelect(),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(child: _smallField('Make', _makeController, hint: 'e.g. Toyota')),
                  const SizedBox(width: 14),
                  Expanded(child: _smallField('Model', _modelController, hint: 'e.g. Prado')),
                ],
              ),
              const SizedBox(height: 24),
              _autoPayToggle(),
              const SizedBox(height: 32),
              PrimaryButton(
                text: 'Save Vehicle →',
                onPressed: _saveVehicle,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _vehicleTypeSelect() {
    return Container(
      height: 58,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: context.colors.inputFill,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.colors.inputBorder),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedType,
          isExpanded: true,
          icon: Icon(LucideIcons.chevronDown, color: context.colors.textMuted, size: 18),
          style: GoogleFonts.poppins(fontSize: 16, color: context.colors.textPrimary),
          dropdownColor: context.colors.surface,
          items: const ['Saloon', 'SUV / 4x4', 'Hatchback', 'Pickup Truck', 'Van / Minibus', 'Motorcycle']
              .map((type) => DropdownMenuItem(value: type, child: Text(type)))
              .toList(),
          onChanged: (value) => setState(() => _selectedType = value ?? _selectedType),
        ),
      ),
    );
  }

  Widget _smallField(
    String label,
    TextEditingController controller, {
    String? hint,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(label),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          style: GoogleFonts.poppins(fontSize: 15, color: context.colors.textPrimary),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.poppins(
              color: context.colors.textMuted,
              fontSize: 14,
            ),
            filled: true,
            fillColor: context.colors.inputFill,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
            border: _fieldBorder(context.colors.inputBorder),
            enabledBorder: _fieldBorder(context.colors.inputBorder),
            focusedBorder: _fieldBorder(context.colors.primary, width: 1.5),
          ),
        ),
      ],
    );
  }

  Widget _autoPayToggle() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.inputFill,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _autoPayOn ? context.colors.primary : context.colors.inputBorder,
          width: _autoPayOn ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          Icon(LucideIcons.zap, color: context.colors.primary, size: 22),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AutoPay',
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: context.colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _autoPayOn
                      ? 'Charged automatically at exit'
                      : 'Pay manually for each session',
                  style: GoogleFonts.poppins(
                    fontSize: 12.5,
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

  Widget _label(String text) {
    return Text(
      text,
      style: GoogleFonts.poppins(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: context.colors.textSecondary,
      ),
    );
  }

  OutlineInputBorder _fieldBorder(Color color, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: color, width: width),
    );
  }

  void _saveVehicle() {
    final plate = _plateController.text.trim().toUpperCase();
    if (plate.isEmpty) {
      ErrorHandler.showErrorMessage(context, 'Please enter your vehicle plate number.');
      return;
    }

    context.read<AppBloc>().add(
          AddVehicle(
            plateNumber: plate,
            type: _selectedType,
            make: _makeController.text.trim().isEmpty
                ? 'Custom'
                : _makeController.text.trim(),
            model: _modelController.text.trim().isEmpty
                ? 'Vehicle'
                : _modelController.text.trim(),
            autoPayEnabled: _autoPayOn,
          ),
        );

    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const MainNavigation()),
        (route) => false,
      );
    }
  }
}
