import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import 'ebic_card.dart';
import 'ebic_badge.dart';

/// Pre-styled customer address card.
/// Part of the core component suite (Section 6.2).
class EBICAddressCard extends StatelessWidget {
  final String label; // e.g. "Home", "Work"
  final String addressLine;
  final String? cityPincode;
  final bool isDefault;
  final bool isSelected;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;

  const EBICAddressCard({
    super.key,
    required this.label,
    required this.addressLine,
    this.cityPincode,
    this.isDefault = false,
    this.isSelected = false,
    this.onTap,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return EbicCard(
      onTap: onTap,
      border: isSelected
          ? Border.all(color: AppColors.primary, width: 1.5)
          : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primary.withOpacity(0.1) : AppColors.slate100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              label.toLowerCase() == 'home' ? Icons.home_rounded : Icons.location_on_rounded,
              size: 20,
              color: isSelected ? AppColors.primary : AppColors.slate600,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.slate900,
                      ),
                    ),
                    if (isDefault) ...[
                      const SizedBox(width: 8),
                      EBICBadge.pill('DEFAULT', color: AppColors.primary),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  addressLine,
                  style: const TextStyle(fontSize: 13, color: AppColors.slate600, height: 1.4),
                ),
                if (cityPincode != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    cityPincode!,
                    style: const TextStyle(fontSize: 12, color: AppColors.slate400),
                  ),
                ],
              ],
            ),
          ),
          if (onEdit != null)
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.slate400),
              onPressed: onEdit,
            ),
        ],
      ),
    );
  }
}
