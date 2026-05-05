import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../core/theme/app_colors.dart';

class CountryCode {
  const CountryCode({
    required this.name,
    required this.dialCode,
    required this.flag,
  });

  final String name;
  final String dialCode;
  final String flag;
}

const List<CountryCode> kCountryCodes = [
  CountryCode(name: 'Kenya', dialCode: '+254', flag: '🇰🇪'),
  CountryCode(name: 'Uganda', dialCode: '+256', flag: '🇺🇬'),
  CountryCode(name: 'Tanzania', dialCode: '+255', flag: '🇹🇿'),
  CountryCode(name: 'Ethiopia', dialCode: '+251', flag: '🇪🇹'),
  CountryCode(name: 'Rwanda', dialCode: '+250', flag: '🇷🇼'),
  CountryCode(name: 'Nigeria', dialCode: '+234', flag: '🇳🇬'),
  CountryCode(name: 'Ghana', dialCode: '+233', flag: '🇬🇭'),
  CountryCode(name: 'South Africa', dialCode: '+27', flag: '🇿🇦'),
  CountryCode(name: 'Egypt', dialCode: '+20', flag: '🇪🇬'),
  CountryCode(name: 'Morocco', dialCode: '+212', flag: '🇲🇦'),
  CountryCode(name: 'Senegal', dialCode: '+221', flag: '🇸🇳'),
  CountryCode(name: 'Cameroon', dialCode: '+237', flag: '🇨🇲'),
  CountryCode(name: 'Zambia', dialCode: '+260', flag: '🇿🇲'),
  CountryCode(name: 'Zimbabwe', dialCode: '+263', flag: '🇿🇼'),
  CountryCode(name: 'Mozambique', dialCode: '+258', flag: '🇲🇿'),
  CountryCode(name: 'United States', dialCode: '+1', flag: '🇺🇸'),
  CountryCode(name: 'Canada', dialCode: '+1', flag: '🇨🇦'),
  CountryCode(name: 'United Kingdom', dialCode: '+44', flag: '🇬🇧'),
  CountryCode(name: 'Germany', dialCode: '+49', flag: '🇩🇪'),
  CountryCode(name: 'France', dialCode: '+33', flag: '🇫🇷'),
  CountryCode(name: 'Italy', dialCode: '+39', flag: '🇮🇹'),
  CountryCode(name: 'Spain', dialCode: '+34', flag: '🇪🇸'),
  CountryCode(name: 'Netherlands', dialCode: '+31', flag: '🇳🇱'),
  CountryCode(name: 'India', dialCode: '+91', flag: '🇮🇳'),
  CountryCode(name: 'China', dialCode: '+86', flag: '🇨🇳'),
  CountryCode(name: 'Japan', dialCode: '+81', flag: '🇯🇵'),
  CountryCode(name: 'Australia', dialCode: '+61', flag: '🇦🇺'),
  CountryCode(name: 'Brazil', dialCode: '+55', flag: '🇧🇷'),
  CountryCode(name: 'Mexico', dialCode: '+52', flag: '🇲🇽'),
  CountryCode(name: 'Saudi Arabia', dialCode: '+966', flag: '🇸🇦'),
  CountryCode(name: 'UAE', dialCode: '+971', flag: '🇦🇪'),
];

class CountryCodeSelector extends StatelessWidget {
  const CountryCodeSelector({
    super.key,
    required this.selected,
    required this.onChanged,
    this.height = 54,
    this.decoration,
  });

  final CountryCode selected;
  final ValueChanged<CountryCode> onChanged;
  final double height;
  final BoxDecoration? decoration;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showPicker(context),
      child: Container(
        height: height,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.center,
        decoration: decoration ??
            BoxDecoration(
              color: context.colors.inputFill,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: context.colors.inputBorder),
            ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(selected.flag, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 6),
            Text(
              selected.dialCode,
              style: GoogleFonts.poppins(
                fontSize: 15,
                color: context.colors.textPrimary,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              LucideIcons.chevronDown,
              size: 14,
              color: context.colors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }

  void _showPicker(BuildContext context) {
    showModalBottomSheet<CountryCode>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _CountryPickerSheet(
        selected: selected,
        onSelected: (code) {
          Navigator.pop(context);
          onChanged(code);
        },
      ),
    );
  }
}

class _CountryPickerSheet extends StatefulWidget {
  const _CountryPickerSheet({
    required this.selected,
    required this.onSelected,
  });

  final CountryCode selected;
  final ValueChanged<CountryCode> onSelected;

  @override
  State<_CountryPickerSheet> createState() => _CountryPickerSheetState();
}

class _CountryPickerSheetState extends State<_CountryPickerSheet> {
  final _searchController = TextEditingController();
  List<CountryCode> _filtered = kCountryCodes;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearch(String query) {
    final q = query.toLowerCase();
    setState(() {
      _filtered = kCountryCodes
          .where((c) =>
              c.name.toLowerCase().contains(q) ||
              c.dialCode.contains(q))
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.92,
      minChildSize: 0.4,
      builder: (context, scrollController) {
        return Padding(
          padding: EdgeInsets.only(bottom: bottomInset),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: context.colors.inputBorder,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'Select Country',
                  style: GoogleFonts.poppins(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: context.colors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: TextField(
                  controller: _searchController,
                  autofocus: true,
                  onChanged: _onSearch,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: context.colors.textPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Search country or code…',
                    hintStyle: GoogleFonts.poppins(
                      fontSize: 14,
                      color: context.colors.textMuted,
                    ),
                    prefixIcon: Icon(
                      LucideIcons.search,
                      size: 18,
                      color: context.colors.textMuted,
                    ),
                    filled: true,
                    fillColor: context.colors.pageGrey,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: context.colors.primary,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Divider(height: 1),
              Expanded(
                child: _filtered.isEmpty
                    ? Center(
                        child: Text(
                          'No countries found',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: context.colors.textMuted,
                          ),
                        ),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        itemCount: _filtered.length,
                        itemBuilder: (_, i) {
                          final code = _filtered[i];
                          final isSelected =
                              code.dialCode == widget.selected.dialCode &&
                                  code.name == widget.selected.name;
                          return InkWell(
                            onTap: () => widget.onSelected(code),
                            child: Container(
                              color: isSelected
                                  ? context.colors.accentLight
                                  : Colors.transparent,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 13,
                              ),
                              child: Row(
                                children: [
                                  Text(
                                    code.flag,
                                    style: const TextStyle(fontSize: 22),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Text(
                                      code.name,
                                      style: GoogleFonts.poppins(
                                        fontSize: 15,
                                        color: context.colors.textPrimary,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    code.dialCode,
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      color: context.colors.textSecondary,
                                    ),
                                  ),
                                  if (isSelected) ...[
                                    const SizedBox(width: 10),
                                    Icon(
                                      LucideIcons.check,
                                      size: 16,
                                      color: context.colors.primary,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
