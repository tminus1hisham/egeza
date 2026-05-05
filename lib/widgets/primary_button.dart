import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme/app_colors.dart';

class PrimaryButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isOutlined;
  final double? width;
  final IconData? icon;

  const PrimaryButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.isLoading = false,
    this.isOutlined = false,
    this.width,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    if (isOutlined) {
      return SizedBox(
        width: width ?? double.infinity,
        height: 52,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            foregroundColor: context.colors.primary,
            elevation: 0,
            side: BorderSide(color: context.colors.primary, width: 1.5),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          onPressed: isLoading ? null : onPressed,
          child: _buildChild(context),
        ),
      );
    }

    final isDisabled = isLoading || onPressed == null;

    return SizedBox(
      width: width ?? double.infinity,
      height: 52,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDisabled
                ? [const Color(0xFFB8C4C0), const Color(0xFFA8B5B0)]
                : [AppColors.primary, const Color(0xFF096B5D)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: isDisabled
              ? []
              : [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.38),
                    blurRadius: 14,
                    offset: const Offset(0, 5),
                  ),
                ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            onTap: isDisabled ? null : onPressed,
            borderRadius: BorderRadius.circular(14),
            splashColor: Colors.white.withValues(alpha: 0.18),
            highlightColor: Colors.white.withValues(alpha: 0.08),
            child: Center(child: _buildChild(context)),
          ),
        ),
      ),
    );
  }

  Widget _buildChild(BuildContext context) {
    if (isLoading) {
      return const SizedBox(
        height: 20,
        width: 20,
        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
      );
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(
            icon,
            size: 18,
            color: isOutlined ? context.colors.primary : Colors.white,
          ),
          const SizedBox(width: 8),
        ],
        Flexible(
          child: Text(
            text,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: isOutlined ? context.colors.primary : Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}
