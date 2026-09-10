import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

enum EbicButtonVariant { primary, outline, ghost, danger }

class EbicButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;
  final bool isFullWidth;
  final bool isOutlined;
  final EbicButtonVariant variant;
  final Color? color;

  const EbicButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.icon,
    this.isFullWidth = true,
    this.isOutlined = false,
    this.variant = EbicButtonVariant.primary,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveVariant = isOutlined ? EbicButtonVariant.outline : variant;

    Color textColor;
    Color? borderColor;
    Color? bgColor;
    Gradient? gradient;

    switch (effectiveVariant) {
      case EbicButtonVariant.outline:
        textColor = color ?? AppColors.primary;
        borderColor = color ?? AppColors.primary;
        bgColor = Colors.transparent;
        gradient = null;
        break;
      case EbicButtonVariant.ghost:
        textColor = color ?? AppColors.slate700;
        borderColor = AppColors.slate200;
        bgColor = Colors.white;
        gradient = null;
        break;
      case EbicButtonVariant.danger:
        textColor = Colors.white;
        borderColor = null;
        bgColor = AppColors.danger;
        gradient = null;
        break;
      case EbicButtonVariant.primary:
        textColor = Colors.white;
        borderColor = null;
        bgColor = onPressed == null ? Colors.grey.shade400 : null;
        gradient = onPressed == null ? null : AppColors.primaryGradient;
        break;
    }

    Widget child = Row(
      mainAxisSize: isFullWidth ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (isLoading) ...[
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(
                effectiveVariant == EbicButtonVariant.outline ? AppColors.primary : Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 10),
        ] else if (icon != null) ...[
          Icon(icon, size: 18, color: textColor),
          const SizedBox(width: 8),
        ],
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
      ],
    );

    return Container(
      width: isFullWidth ? double.infinity : null,
      height: 48,
      decoration: BoxDecoration(
        color: bgColor,
        gradient: gradient,
        borderRadius: BorderRadius.circular(12),
        border: borderColor != null ? Border.all(color: borderColor, width: 1.5) : null,
        boxShadow: effectiveVariant == EbicButtonVariant.primary && onPressed != null
            ? [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.25),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: isLoading ? null : onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: child,
          ),
        ),
      ),
    );
  }
}
