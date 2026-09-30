import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

class ProvenanceBadge extends StatelessWidget {
  final String? source;
  final bool isCompact;

  const ProvenanceBadge({
    super.key,
    this.source,
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

    final effectiveSource = (source != null && source!.isNotEmpty) ? source! : 'MANUAL';

    switch (effectiveSource.toUpperCase()) {
      case 'DIETITIAN_CONFIRMED':
      case 'DIETITIAN':
        bg = isDark ? const Color(0xFF3B0764) : const Color(0xFFF3E8FF);
        fg = isDark ? const Color(0xFFD8B4FE) : const Color(0xFF7E22CE);
        icon = Icons.verified_user_rounded;
        label = 'Dietitian Confirmed';
        compactLabel = 'Clinical';
        break;
      case 'DERIVED':
        bg = isDark ? const Color(0xFF0C4A6E) : const Color(0xFFE0F2FE);
        fg = isDark ? const Color(0xFF7DD3FC) : const Color(0xFF0369A1);
        icon = Icons.calculate_rounded;
        label = 'Calculated (BMI)';
        compactLabel = 'Calc';
        break;
      case 'HEALTH_CONNECT':
      case 'GOOGLE_HEALTH_CONNECT':
      case 'GOOGLE_FIT':
        bg = isDark ? const Color(0xFF064E3B) : const Color(0xFFECFDF5);
        fg = isDark ? const Color(0xFF34D399) : const Color(0xFF059669);
        icon = Icons.sync_rounded;
        label = 'Health Connect';
        compactLabel = 'Health Connect';
        break;
      case 'APPLE_HEALTH':
      case 'HEALTHKIT':
        bg = isDark ? const Color(0xFF4C0519) : const Color(0xFFFFF1F2);
        fg = isDark ? const Color(0xFFFB7185) : const Color(0xFFE11D48);
        icon = Icons.favorite_rounded;
        label = 'Apple Health';
        compactLabel = 'Apple Health';
        break;
      case 'WEARABLE':
      case 'SMARTWATCH':
      case 'DEVICE':
        bg = isDark ? const Color(0xFF164E63) : const Color(0xFFECFEFF);
        fg = isDark ? const Color(0xFF22D3EE) : const Color(0xFF0891B2);
        icon = Icons.watch_rounded;
        label = 'Device Synced';
        compactLabel = 'Device Synced';
        break;
      case 'CUSTOMER_REPORTED':
      case 'MANUAL':
      case 'CUSTOMER':
      default:
        bg = isDark ? AppColors.slate800 : const Color(0xFFF1F5F9);
        fg = isDark ? AppColors.slate300 : const Color(0xFF475569);
        icon = Icons.edit_note_rounded;
        label = 'Manually Added';
        compactLabel = 'Manual';
        break;
    }

    if (isCompact) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 10.5, color: fg),
            const SizedBox(width: 4),
            Text(
              compactLabel,
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
