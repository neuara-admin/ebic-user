import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_colors.dart';

class EbicCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;
  final Color? backgroundColor;
  final Gradient? gradient;
  final Border? border;
  final double borderRadius;

  const EbicCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding,
    this.backgroundColor,
    this.gradient,
    this.border,
    this.borderRadius = 20,
  });

  @override
  State<EbicCard> createState() => _EbicCardState();
}

class _EbicCardState extends State<EbicCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    const defaultBg = Colors.white;
    final defaultBorder = Border.all(
      color: AppColors.hairlineBorder,
      width: 1.0,
    );

    return AnimatedScale(
      scale: (_isPressed && widget.onTap != null) ? 0.978 : 1.0,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOutCubic,
      child: Container(
        decoration: BoxDecoration(
          color: widget.gradient == null ? (widget.backgroundColor ?? defaultBg) : null,
          gradient: widget.gradient,
          borderRadius: BorderRadius.circular(widget.borderRadius),
          border: widget.border ?? defaultBorder,
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withValues(alpha: 0.035),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
            BoxShadow(
              color: const Color(0xFF0F172A).withValues(alpha: 0.015),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(widget.borderRadius),
          child: InkWell(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            onTap: widget.onTap != null
                ? () {
                    HapticFeedback.lightImpact();
                    widget.onTap!();
                  }
                : null,
            onHighlightChanged: widget.onTap != null
                ? (highlighted) {
                    setState(() => _isPressed = highlighted);
                  }
                : null,
            highlightColor: Colors.transparent,
            focusColor: Colors.transparent,
            splashColor: AppColors.primary.withOpacity(0.06),
            child: Padding(
              padding: widget.padding ?? const EdgeInsets.all(16),
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}

/// Typedef matching Section 6.2 specification naming.
typedef EBICCard = EbicCard;
