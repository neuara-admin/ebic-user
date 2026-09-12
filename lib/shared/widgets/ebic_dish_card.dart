import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/design_tokens.dart';

/// Pre-styled menu/catalogue dish card with cook time, macros, and price.
/// Part of the core component suite (Section 6.2).
class EBICDishCard extends StatelessWidget {
  final String name;
  final String? description;
  final String? imageUrl;
  final int? cookTimeMinutes;
  final int? calories;
  final String? price;
  final bool isSelected;
  final VoidCallback? onTap;
  final VoidCallback? onAdd;
  final bool showAddButton;

  const EBICDishCard({
    super.key,
    required this.name,
    this.description,
    this.imageUrl,
    this.cookTimeMinutes,
    this.calories,
    this.price,
    this.isSelected = false,
    this.onTap,
    this.onAdd,
    this.showAddButton = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      borderRadius: DesignTokens.borderRadiusMD,
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.slate900 : Colors.white,
          borderRadius: DesignTokens.borderRadiusMD,
          border: Border.all(
            color: isSelected ? AppColors.primary : (isDark ? AppColors.slate800 : AppColors.slate200),
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: DesignTokens.shadowSm,
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Image or Dish placeholder icon
              ClipRRect(
                borderRadius: DesignTokens.borderRadiusSM,
                child: imageUrl != null && imageUrl!.isNotEmpty
                    ? Image.network(
                        imageUrl!,
                        width: 76,
                        height: 76,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _buildPlaceholder(),
                      )
                    : _buildPlaceholder(),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : AppColors.slate900,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (description != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        description!,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppColors.slate400 : AppColors.slate500,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        if (cookTimeMinutes != null) ...[
                          const Icon(Icons.timer_outlined, size: 14, color: AppColors.slate400),
                          const SizedBox(width: 3),
                          Text(
                            '$cookTimeMinutes min',
                            style: const TextStyle(fontSize: 12, color: AppColors.slate500),
                          ),
                          const SizedBox(width: 10),
                        ],
                        if (calories != null) ...[
                          const Icon(Icons.local_fire_department_outlined, size: 14, color: AppColors.accent),
                          const SizedBox(width: 3),
                          Text(
                            '$calories kcal',
                            style: const TextStyle(fontSize: 12, color: AppColors.slate500),
                          ),
                        ],
                        const Spacer(),
                        if (price != null)
                          Text(
                            price!,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              if (showAddButton && onAdd != null) ...[
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(
                    isSelected ? Icons.check_circle_rounded : Icons.add_circle_outline_rounded,
                    color: isSelected ? AppColors.primary : AppColors.slate400,
                    size: 26,
                  ),
                  onPressed: onAdd,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      width: 76,
      height: 76,
      color: AppColors.primarySubtle,
      child: const Icon(Icons.restaurant_rounded, color: AppColors.primary, size: 28),
    );
  }
}
