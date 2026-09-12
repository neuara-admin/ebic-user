import 'package:flutter/material.dart';
import '../../core/config/app_config.dart';
import '../../core/theme/app_colors.dart';

/// User / Chef / Member avatar with image and initials fallback.
/// Part of the core component suite (Section 6.2).
class EBICAvatar extends StatelessWidget {
  final String? name;
  final String? imageUrl;
  final double radius;
  final Color? backgroundColor;
  final Color? textColor;

  const EBICAvatar({
    super.key,
    this.name,
    this.imageUrl,
    this.radius = 20.0,
    this.backgroundColor,
    this.textColor,
  });

  String _getInitials(String? text) {
    if (text == null || text.trim().isEmpty) return 'U';
    final parts = text.trim().split(RegExp(r'\s+'));
    if (parts.length > 1) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return parts[0][0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final bg = backgroundColor ?? AppColors.primarySubtle;
    final fg = textColor ?? AppColors.primary;

    final resolved = AppConfig.resolveMediaUrl(imageUrl);
    if (resolved != null && resolved.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: bg,
        backgroundImage: NetworkImage(resolved),
        onBackgroundImageError: (_, __) {},
        child: null,
      );
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: bg,
      child: Text(
        _getInitials(name),
        style: TextStyle(
          fontSize: radius * 0.8,
          fontWeight: FontWeight.bold,
          color: fg,
        ),
      ),
    );
  }
}
