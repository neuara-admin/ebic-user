import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';

/// Reusable Human-Crafted Bespoke UI Kit for EBIC User App.
/// Adheres strictly to the 7 core pillars:
/// 1. Warm porcelain canvas & 1px hairline borders
/// 2. Tactile spring physics & micro-scale (0.978)
/// 3. Framed icon capsules (no naked icons)
/// 4. Numbers as heroes (bold 30sp stats)
/// 5. Live pulsing status pills
class BespokeCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final Gradient? gradient;
  final double borderRadius;
  final Border? border;
  final bool hasShadow;

  const BespokeCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(18),
    this.color,
    this.gradient,
    this.borderRadius = 20,
    this.border,
    this.hasShadow = true,
  });

  @override
  State<BespokeCard> createState() => _BespokeCardState();
}

class _BespokeCardState extends State<BespokeCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final defaultBorder = Border.all(
      color: AppColors.hairlineBorder,
      width: 1.0,
    );

    return GestureDetector(
      onTapDown: widget.onTap != null
          ? (_) {
              setState(() => _pressed = true);
              HapticFeedback.lightImpact();
            }
          : null,
      onTapUp: widget.onTap != null
          ? (_) => setState(() => _pressed = false)
          : null,
      onTapCancel: widget.onTap != null
          ? () => setState(() => _pressed = false)
          : null,
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.978 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        child: Container(
          padding: widget.padding,
          decoration: BoxDecoration(
            color: widget.gradient == null ? (widget.color ?? Colors.white) : null,
            gradient: widget.gradient,
            borderRadius: BorderRadius.circular(widget.borderRadius),
            border: widget.border ?? defaultBorder,
            boxShadow: widget.hasShadow
                ? [
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
                  ]
                : null,
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

/// Framed Icon Capsule — wraps icons in a soft-tinted squircle container.
/// Eliminates naked floating icons for a cohesive, human-crafted design.
Widget iconCapsule({
  required IconData icon,
  required Color color,
  double size = 42,
  double iconSize = 20,
}) {
  return Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(size * 0.32),
      border: Border.all(
        color: color.withValues(alpha: 0.22),
        width: 0.8,
      ),
    ),
    child: Icon(icon, color: color, size: iconSize),
  );
}

/// Live Pulsing Status Pill — for live order tracking, chef dispatch, and consultations.
Widget liveStatusPill(
  String label,
  Color color, {
  bool isPulsing = false,
  double fontSize = 10,
}) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(
        color: color.withValues(alpha: 0.22),
        width: 0.8,
      ),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: isPulsing
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.5),
                      blurRadius: 6,
                      spreadRadius: 1.5,
                    ),
                  ]
                : null,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label.toUpperCase(),
          style: GoogleFonts.plusJakartaSans(
            color: color,
            fontSize: fontSize,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.1,
          ),
        ),
      ],
    ),
  );
}

/// Bento Metric Tile — shows stats with prominent "numbers as heroes".
class BentoMetricTile extends StatelessWidget {
  final String label;
  final String value;
  final String? unit;
  final IconData icon;
  final Color iconColor;
  final VoidCallback? onTap;
  final Widget? subtitle;

  const BentoMetricTile({
    super.key,
    required this.label,
    required this.value,
    this.unit,
    required this.icon,
    required this.iconColor,
    this.onTap,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return BespokeCard(
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              iconCapsule(icon: icon, color: iconColor, size: 36, iconSize: 18),
              if (onTap != null)
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 13,
                  color: AppColors.slate400,
                ),
            ],
          ),
          const SizedBox(height: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    value,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: AppColors.slate900,
                      letterSpacing: -0.5,
                    ),
                  ),
                  if (unit != null) ...[
                    const SizedBox(width: 4),
                    Text(
                      unit!,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.slate500,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.slate500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                subtitle!,
              ],
            ],
          ),
        ],
      ),
    );
  }
}

