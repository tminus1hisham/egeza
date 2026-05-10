import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../blocs/app_bloc.dart';
import '../../blocs/app_event.dart';
import '../../core/theme/app_colors.dart';
import '../../widgets/app_widgets.dart';
import '../../widgets/plate_number_input.dart';
import '../../widgets/primary_button.dart';
import 'auto_toll_screen.dart';

class PlateNumberScreen extends StatefulWidget {
  const PlateNumberScreen({super.key});

  @override
  State<PlateNumberScreen> createState() => _PlateNumberScreenState();
}

class _PlateNumberScreenState extends State<PlateNumberScreen> {
  final _makeController = TextEditingController();
  final _modelController = TextEditingController();
  String _plateNumber = '';
  String _selectedType = 'SUV / 4x4';

  int get _plateCharCount {
    // Strip spaces to count only meaningful characters
    return _plateNumber.replaceAll(' ', '').length;
  }

  @override
  void dispose() {
    _makeController.dispose();
    _modelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final counterColor = _plateCharCount == 7
        ? context.colors.success
        : context.colors.error;

    return Scaffold(
      backgroundColor: context.colors.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const OnboardingStepHeader(step: 2, totalSteps: 4, title: 'Add Your Car'),
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
              _label('Number Plate'),
              const SizedBox(height: 8),
              PlateNumberInput(
                onChanged: (value) => setState(() => _plateNumber = value),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Enter plate exactly as shown on your vehicle',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: context.colors.textMuted,
                    ),
                  ),
                  Text(
                    '$_plateCharCount / 7',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _plateNumber.isEmpty ? context.colors.textMuted : counterColor,
                    ),
                  ),
                ],
              ),
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
              const SizedBox(height: 32),
              PrimaryButton(
                text: 'Save Vehicle & Continue →',
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
    final plate = _plateNumber.trim().toUpperCase();
    if (plate.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter your plate number')),
      );
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
          ),
        );

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AutoTollScreen()),
    );
  }
}
