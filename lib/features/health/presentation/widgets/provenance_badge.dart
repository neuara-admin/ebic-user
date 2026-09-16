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
    Color bg;
    Color fg;
    IconData icon;
    String label;

    switch (source.toUpperCase()) {
      case 'DIETITIAN_CONFIRMED':
      case 'DIETITIAN':
        bg = const Color(0xFFF3E8FF);
        fg = const Color(0xFF7E22CE);
        icon = Icons.verified_user_rounded;
        label = 'Dietitian Confirmed';
        break;
      case 'DERIVED':
        bg = const Color(0xFFE0F2FE);
        fg = const Color(0xFF0369A1);
        icon = Icons.calculate_rounded;
        label = 'Derived Calculation';
        break;
      case 'WEARABLE':
      case 'APPLE_HEALTH':
      case 'HEALTH_CONNECT':
        bg = const Color(0xFFECFDF5);
        fg = const Color(0xFF047857);
        icon = Icons.watch_rounded;
        label = 'Device Synced';
        break;
      case 'CUSTOMER_REPORTED':
      case 'MANUAL':
      case 'CUSTOMER':
      default:
        bg = AppColors.slate100;
        fg = AppColors.slate700;
        icon = Icons.person_outline_rounded;
        label = 'Customer Reported';
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
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: fg,
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
