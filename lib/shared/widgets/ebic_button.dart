import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_colors.dart';

enum EbicButtonVariant { primary, outline, ghost, danger }

class EbicButton extends StatefulWidget {
  final String label;
  final String? text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;
  final bool isFullWidth;
  final bool isOutlined;
  final EbicButtonVariant variant;
  final Color? color;
  final double height;
  final double borderRadius;

  const EbicButton({
    super.key,
    this.label = '',
    this.text,
    required this.onPressed,
    this.isLoading = false,
    this.icon,
    this.isFullWidth = true,
    this.isOutlined = false,
    this.variant = EbicButtonVariant.primary,
    this.color,
    this.height = 48,
    this.borderRadius = 14,
  });

  @override
  State<EbicButton> createState() => _EbicButtonState();
}

class _EbicButtonState extends State<EbicButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final effectiveVariant = widget.isOutlined ? EbicButtonVariant.outline : widget.variant;

    Color textColor;
    Color? borderColor;
    Color? bgColor;
    Gradient? gradient;

    switch (effectiveVariant) {
      case EbicButtonVariant.outline:
        textColor = widget.color ?? AppColors.primary;
        borderColor = widget.color ?? AppColors.primary;
        bgColor = Colors.transparent;
        gradient = null;
        break;
      case EbicButtonVariant.ghost:
        textColor = widget.color ?? AppColors.slate700;
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
        bgColor = widget.onPressed == null ? Colors.grey.shade400 : null;
        gradient = widget.onPressed == null ? null : AppColors.primaryGradient;
        break;
    }

    Widget child = Row(
      mainAxisSize: widget.isFullWidth ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.isLoading) ...[
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
        ] else if (widget.icon != null) ...[
          Icon(widget.icon, size: 18, color: textColor),
          const SizedBox(width: 8),
        ],
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.center,
            child: Text(
              widget.text ?? widget.label,
              maxLines: 1,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.1,
                color: textColor,
              ),
            ),
          ),
        ),
      ],
    );

    return AnimatedScale(
      scale: (_isPressed && widget.onPressed != null && !widget.isLoading) ? 0.965 : 1.0,
      duration: const Duration(milliseconds: 100),
      curve: Curves.easeOutCubic,
      child: Container(
        width: widget.isFullWidth ? double.infinity : null,
        height: widget.height,
        decoration: BoxDecoration(
          color: bgColor,
          gradient: gradient,
          borderRadius: BorderRadius.circular(widget.borderRadius),
          border: borderColor != null ? Border.all(color: borderColor, width: 1.2) : null,
          boxShadow: effectiveVariant == EbicButtonVariant.primary && widget.onPressed != null && !widget.isLoading
              ? [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.25),
                    blurRadius: 14,
                    offset: const Offset(0, 5),
                  ),
                ]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(widget.borderRadius),
          child: InkWell(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            onTap: (widget.isLoading || widget.onPressed == null)
                ? null
                : () {
                    HapticFeedback.lightImpact();
                    widget.onPressed!();
                  },
            onHighlightChanged: (highlighted) {
              if (widget.onPressed != null && !widget.isLoading) {
                setState(() => _isPressed = highlighted);
              }
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

/// Typedef matching Section 6.2 specification naming.
typedef EBICButton = EbicButton;
