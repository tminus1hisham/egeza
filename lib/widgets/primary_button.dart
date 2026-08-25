import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme/app_colors.dart';

class PrimaryButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isOutlined;
  final double? width;
  final double? height;
  final double? fontSize;
  final IconData? icon;

  const PrimaryButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.isLoading = false,
    this.isOutlined = false,
    this.width,
    this.height,
    this.fontSize,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final isDisabled = isLoading || onPressed == null;
    final radius = BorderRadius.circular(16);
    // A floor, not a fixed height: the button grows past it when the device
    // text scale makes the label taller than the box.
    final minHeight = height ?? 52;

    if (isOutlined) {
      return SizedBox(
        width: width ?? double.infinity,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            minimumSize: Size(0, minHeight),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            backgroundColor: context.colors.surface,
            disabledBackgroundColor: context.colors.surface,
            foregroundColor: isDisabled
                ? context.colors.textMuted
                : context.colors.primary,
            disabledForegroundColor: context.colors.textMuted,
            elevation: 0,
            shadowColor: Colors.transparent,
            side: BorderSide(
              color: isDisabled
                  ? context.colors.border
                  : context.colors.primary.withValues(alpha: 0.7),
              width: 1.4,
            ),
            shape: RoundedRectangleBorder(borderRadius: radius),
          ),
          onPressed: isDisabled ? null : onPressed,
          child: _buildChild(context, disabled: isDisabled),
        ),
      );
    }

    return SizedBox(
      width: width ?? double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDisabled
                ? [const Color(0xFFB8C4C0), const Color(0xFFA8B5B0)]
                : [const Color(0xFF0B8A7A), AppColors.primaryDark],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: radius,
          boxShadow: isDisabled
              ? []
              : [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.28),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
        ),
        child: ElevatedButton(
          onPressed: isDisabled ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            disabledBackgroundColor: Colors.transparent,
            foregroundColor: Colors.white,
            disabledForegroundColor: Colors.white,
            shadowColor: Colors.transparent,
            elevation: 0,
            minimumSize: Size(0, minHeight),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            shape: RoundedRectangleBorder(borderRadius: radius),
          ).copyWith(
            overlayColor: WidgetStatePropertyAll(
              Colors.white.withValues(alpha: 0.12),
            ),
          ),
          child: _buildChild(context, disabled: isDisabled),
        ),
      ),
    );
  }

  Widget _buildChild(BuildContext context, {required bool disabled}) {
    if (isLoading) {
      return SizedBox(
        height: 20,
        width: 20,
        child: CircularProgressIndicator(
          color: isOutlined ? context.colors.primary : Colors.white,
          strokeWidth: 2,
        ),
      );
    }
    final foreground = isOutlined
        ? disabled
            ? context.colors.textMuted
            : context.colors.primary
        : Colors.white;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(
            icon,
            size: (fontSize ?? 15) + 3,
            color: foreground,
          ),
          SizedBox(width: (fontSize ?? 15) < 14 ? 5.0 : 8.0),
        ],
        Flexible(
          child: Text(
            text,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              fontSize: fontSize ?? 15,
              fontWeight: FontWeight.w600,
              color: foreground,
            ),
          ),
        ),
      ],
    );
  }
}
