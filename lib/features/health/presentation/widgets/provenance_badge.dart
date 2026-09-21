import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

class ProvenanceBadge extends StatelessWidget {
  final String source;
  final bool isCompact;

  const ProvenanceBadge({
    super.key,
    required this.source,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    Color bg;
    Color fg;
    IconData icon;
    String label;

    String compactLabel;

    switch (source.toUpperCase()) {
      case 'DIETITIAN_CONFIRMED':
      case 'DIETITIAN':
        bg = isDark ? const Color(0xFF3B0764) : const Color(0xFFF3E8FF);
        fg = isDark ? const Color(0xFFD8B4FE) : const Color(0xFF7E22CE);
        icon = Icons.verified_user_rounded;
        label = 'Dietitian Confirmed';
        compactLabel = 'Dietitian';
        break;
      case 'DERIVED':
        bg = isDark ? const Color(0xFF0C4A6E) : const Color(0xFFE0F2FE);
        fg = isDark ? const Color(0xFF7DD3FC) : const Color(0xFF0369A1);
        icon = Icons.calculate_rounded;
        label = 'Derived Calculation';
        compactLabel = 'Derived';
        break;
      case 'WEARABLE':
      case 'APPLE_HEALTH':
      case 'HEALTH_CONNECT':
        bg = isDark ? const Color(0xFF064E3B) : const Color(0xFFECFDF5);
        fg = isDark ? const Color(0xFF6EE7B7) : const Color(0xFF047857);
        icon = Icons.watch_rounded;
        label = 'Device Synced';
        compactLabel = 'Synced';
        break;
      case 'CUSTOMER_REPORTED':
      case 'MANUAL':
      case 'CUSTOMER':
      default:
        bg = isDark ? AppColors.slate800 : AppColors.slate100;
        fg = isDark ? AppColors.slate200 : AppColors.slate700;
        icon = Icons.person_outline_rounded;
        label = 'Customer Reported';
        compactLabel = 'Reported';
        break;
    }

    if (isCompact) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 11, color: fg),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                compactLabel,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: fg,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: fg.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: fg),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}
