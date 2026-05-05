import 'package:flutter/material.dart';

class AppColors {
  static const Color primary = Color(0xFF0F8177);
  static const Color primaryDark = Color(0xFF0D3D2B);
  static const Color primaryDeep = Color(0xFF07261A);
  static const Color accent = Color(0xFF21C875);
  static const Color accentLight = Color(0xFFEAFBF7);

  static const Color background = Color(0xFFF4F6F5);
  static const Color pageGrey = Color(0xFFF4F5F7);
  static const Color inputFill = Color(0xFFFAFBFC);
  static const Color surface = Colors.white;

  static const Color plateYellow = Color(0xFFF59E0B);
  static const Color plateBg = Color(0xFFFFF8E1);

  static const Color textPrimary = Color(0xFF0D1F17);
  static const Color textSecondary = Color(0xFF6B7E76);
  static const Color textLight = Colors.white;
  static const Color textMuted = Color(0xFFADB8B3);

  static const Color success = Color(0xFF27AE60);
  static const Color successLight = Color(0xFFE8F8EF);
  static const Color error = Color(0xFFE74C3C);
  static const Color warning = Color(0xFFF59E0B);

  static const Color border = Color(0xFFE5E7EB);
  static const Color inputBorder = Color(0xFFDDE3EA);
  static const Color mintBorder = Color(0xFF83F4DF);
  static const Color darkPanel = Color(0xFF111827);

  static const Color cardSurface = Color(0xFFFFFFFF);
  static const Color divider = Color(0xFFF0F4F2);

  // Dark Mode Colors
  static const Color darkBackground = Color(0xFF0A1210);
  static const Color darkPageGrey = Color(0xFF0D1714);
  static const Color darkSurface = Color(0xFF12201C);
  static const Color darkInputFill = Color(0xFF0F1C18);
  
  static const Color textDarkPrimary = Color(0xFFF0F4F2);
  static const Color textDarkSecondary = Color(0xFFA5B8B0);
  static const Color textDarkMuted = Color(0xFF6E857C);
  
  static const Color darkBorder = Color(0xFF223831);
  static const Color darkInputBorder = Color(0xFF2A423B);
  static const Color darkDivider = Color(0xFF182B25);
}

class AppColorsData {
  final Color primary;
  final Color primaryDark;
  final Color primaryDeep;
  final Color accent;
  final Color accentLight;
  final Color background;
  final Color pageGrey;
  final Color inputFill;
  final Color surface;
  final Color plateYellow;
  final Color plateBg;
  final Color textPrimary;
  final Color textSecondary;
  final Color textLight;
  final Color textMuted;
  final Color success;
  final Color successLight;
  final Color error;
  final Color warning;
  final Color border;
  final Color inputBorder;
  final Color mintBorder;
  final Color darkPanel;
  final Color cardSurface;
  final Color divider;

  const AppColorsData({
    required this.primary,
    required this.primaryDark,
    required this.primaryDeep,
    required this.accent,
    required this.accentLight,
    required this.background,
    required this.pageGrey,
    required this.inputFill,
    required this.surface,
    required this.plateYellow,
    required this.plateBg,
    required this.textPrimary,
    required this.textSecondary,
    required this.textLight,
    required this.textMuted,
    required this.success,
    required this.successLight,
    required this.error,
    required this.warning,
    required this.border,
    required this.inputBorder,
    required this.mintBorder,
    required this.darkPanel,
    required this.cardSurface,
    required this.divider,
  });
}

extension AppColorsExtension on BuildContext {
  AppColorsData get colors {
    final isDark = Theme.of(this).brightness == Brightness.dark;
    return AppColorsData(
      primary: AppColors.primary,
      primaryDark: AppColors.primaryDark,
      primaryDeep: AppColors.primaryDeep,
      accent: AppColors.accent,
      accentLight: isDark ? const Color(0xFF0D2A20) : AppColors.accentLight,
      background: isDark ? AppColors.darkBackground : AppColors.background,
      pageGrey: isDark ? AppColors.darkPageGrey : AppColors.pageGrey,
      inputFill: isDark ? AppColors.darkInputFill : AppColors.inputFill,
      surface: isDark ? AppColors.darkSurface : AppColors.surface,
      plateYellow: AppColors.plateYellow,
      plateBg: isDark ? const Color(0xFF2A200B) : AppColors.plateBg,
      textPrimary: isDark ? AppColors.textDarkPrimary : AppColors.textPrimary,
      textSecondary: isDark ? AppColors.textDarkSecondary : AppColors.textSecondary,
      textLight: AppColors.textLight,
      textMuted: isDark ? AppColors.textDarkMuted : AppColors.textMuted,
      success: AppColors.success,
      successLight: isDark ? const Color(0xFF0F2B1B) : AppColors.successLight,
      error: AppColors.error,
      warning: AppColors.warning,
      border: isDark ? AppColors.darkBorder : AppColors.border,
      inputBorder: isDark ? AppColors.darkInputBorder : AppColors.inputBorder,
      mintBorder: isDark ? const Color(0xFF2C5E54) : AppColors.mintBorder,
      darkPanel: isDark ? const Color(0xFF1F2937) : AppColors.darkPanel,
      cardSurface: isDark ? AppColors.darkSurface : AppColors.cardSurface,
      divider: isDark ? AppColors.darkDivider : AppColors.divider,
    );
  }
}
