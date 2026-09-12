import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import 'ebic_card.dart';
import 'ebic_badge.dart';

/// Pre-styled diet plan meal card for assigned normal and cheat meals.
/// Adheres to Section 3.3 and 6.2.
class EBICMealCard extends StatelessWidget {
  final String mealType; // "Breakfast", "Lunch", "Dinner", "Snack"
  final String dishName;
  final String? portion;
  final int? calories;
  final bool isCheatMeal;
  final bool isPrepared;
  final VoidCallback? onTap;

  const EBICMealCard({
    super.key,
    required this.mealType,
    required this.dishName,
    this.portion,
    this.calories,
    this.isCheatMeal = false,
    this.isPrepared = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return EbicCard(
      onTap: onTap,
      border: isCheatMeal
          ? Border.all(color: AppColors.accent, width: 1.2)
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                mealType.toUpperCase(),
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                  color: AppColors.slate400,
                ),
              ),
              if (isCheatMeal)
                EBICBadge.pill('CHEAT MEAL', color: AppColors.accent)
              else if (isPrepared)
                EBICBadge.pill('PREPARED', color: AppColors.primary),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            dishName,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.slate900,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              if (portion != null) ...[
                const Icon(Icons.scale_outlined, size: 13, color: AppColors.slate400),
                const SizedBox(width: 4),
                Text(
                  portion!,
                  style: const TextStyle(fontSize: 12, color: AppColors.slate500),
                ),
                const SizedBox(width: 12),
              ],
              if (calories != null) ...[
                const Icon(Icons.local_fire_department_outlined, size: 13, color: AppColors.accent),
                const SizedBox(width: 4),
                Text(
                  '$calories kcal',
                  style: const TextStyle(fontSize: 12, color: AppColors.slate500),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
