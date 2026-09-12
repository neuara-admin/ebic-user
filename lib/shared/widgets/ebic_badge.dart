import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/design_tokens.dart';

/// Small decorative tag / badge for numbers, counts, or categories.
/// Part of the core component suite (Section 6.2).
class EBICBadge extends StatelessWidget {
  final String text;
  final Color backgroundColor;
  final Color textColor;
  final double fontSize;
  final EdgeInsetsGeometry padding;

  const EBICBadge({
    super.key,
    required this.text,
    this.backgroundColor = AppColors.primarySubtle,
    this.textColor = AppColors.primary,
    this.fontSize = 11.0,
    this.padding = const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
  });

  factory EBICBadge.counter(int count, {Color? color}) {
    return EBICBadge(
      text: count > 99 ? '99+' : count.toString(),
      backgroundColor: color ?? AppColors.danger,
      textColor: Colors.white,
      fontSize: 10.0,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    );
  }

  factory EBICBadge.pill(String label, {Color? color}) {
    final bg = color ?? AppColors.primary;
    return EBICBadge(
      text: label,
      backgroundColor: bg.withOpacity(0.12),
      textColor: bg,
      fontSize: 11.0,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: DesignTokens.borderRadiusPill,
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          color: textColor,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}
