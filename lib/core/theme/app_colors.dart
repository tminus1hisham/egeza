import 'package:flutter/material.dart';

class AppColors {
  static const Color primary = Color(0xFF087C72);
  static const Color primaryDark = Color(0xFF0A4A3F);
  static const Color primaryDeep = Color(0xFF062D27);
  static const Color accent = Color(0xFF30D68B);
  static const Color accentLight = Color(0xFFE9FBF3);

  static const Color background = Color(0xFFF7F9F8);
  static const Color pageGrey = Color(0xFFF0F4F2);
  static const Color inputFill = Color(0xFFFAFBFC);
  static const Color surface = Colors.white;
  static const Color surfaceRaised = Color(0xFFFFFFFF);
  static const Color surfaceTint = Color(0xFFF7FCFA);

  static const Color plateYellow = Color(0xFFF59E0B);
  static const Color plateBg = Color(0xFFFFF8E1);

  static const Color textPrimary = Color(0xFF10231D);
  static const Color textSecondary = Color(0xFF667A72);
  static const Color textLight = Colors.white;
  static const Color textMuted = Color(0xFF9AA9A3);

  static const Color success = Color(0xFF27AE60);
  static const Color successLight = Color(0xFFE8F8EF);
  static const Color error = Color(0xFFE74C3C);
  static const Color errorLight = Color(0xFFFDECEA);
  static const Color warning = Color(0xFFF59E0B);
  static const Color info = Color(0xFF2563EB);
  static const Color infoLight = Color(0xFFEAF1FF);

  static const Color border = Color(0xFFE2E8E5);
  static const Color inputBorder = Color(0xFFDDE3EA);
  static const Color mintBorder = Color(0xFFA9ECD9);
  static const Color darkPanel = Color(0xFF111827);

  // Disabled buttons: muted fill with text dark enough to stay readable
  // (white-on-grey was failing contrast).
  static const Color disabledFill = Color(0xFFCAD3D0);
  static const Color disabledText = Color(0xFF3F4F4A);

  static const Color cardSurface = Color(0xFFFFFFFF);
  static const Color divider = Color(0xFFEAF0ED);

  // Dark Mode Colors
  static const Color darkBackground = Color(0xFF08120F);
  static const Color darkPageGrey = Color(0xFF0C1815);
  static const Color darkSurface = Color(0xFF12221D);
  static const Color darkInputFill = Color(0xFF0E1B17);
  
  static const Color textDarkPrimary = Color(0xFFF0F4F2);
  static const Color textDarkSecondary = Color(0xFFA5B8B0);
  static const Color textDarkMuted = Color(0xFF6E857C);
  
  static const Color darkBorder = Color(0xFF223831);
  static const Color darkInputBorder = Color(0xFF2A423B);
  static const Color darkDivider = Color(0xFF182B25);

  static const Color darkDisabledFill = Color(0xFF2E423C);
  static const Color darkDisabledText = Color(0xFFBFD0C9);
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
  final Color errorLight;
  final Color warning;
  final Color info;
  final Color infoLight;
  final Color border;
  final Color inputBorder;
  final Color mintBorder;
  final Color darkPanel;
  final Color cardSurface;
  final Color divider;
  final Color surfaceRaised;
  final Color surfaceTint;
  final Color disabledFill;
  final Color disabledText;

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
    required this.errorLight,
    required this.warning,
    required this.info,
    required this.infoLight,
    required this.border,
    required this.inputBorder,
    required this.mintBorder,
    required this.darkPanel,
    required this.cardSurface,
    required this.divider,
    required this.surfaceRaised,
    required this.surfaceTint,
    required this.disabledFill,
    required this.disabledText,
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
      errorLight: isDark ? const Color(0xFF3A1714) : AppColors.errorLight,
      warning: AppColors.warning,
      info: AppColors.info,
      infoLight: isDark ? const Color(0xFF10244A) : AppColors.infoLight,
      border: isDark ? AppColors.darkBorder : AppColors.border,
      inputBorder: isDark ? AppColors.darkInputBorder : AppColors.inputBorder,
      mintBorder: isDark ? const Color(0xFF2C5E54) : AppColors.mintBorder,
      darkPanel: isDark ? const Color(0xFF1F2937) : AppColors.darkPanel,
      cardSurface: isDark ? AppColors.darkSurface : AppColors.cardSurface,
      divider: isDark ? AppColors.darkDivider : AppColors.divider,
      surfaceRaised: isDark ? const Color(0xFF172A24) : AppColors.surfaceRaised,
      surfaceTint: isDark ? const Color(0xFF10251F) : AppColors.surfaceTint,
      disabledFill: isDark ? AppColors.darkDisabledFill : AppColors.disabledFill,
      disabledText: isDark ? AppColors.darkDisabledText : AppColors.disabledText,
    );
  }
}
