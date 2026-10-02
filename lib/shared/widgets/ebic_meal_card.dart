import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import 'ebic_card.dart';
import 'ebic_badge.dart';

/// Pre-styled bespoke diet plan meal card for assigned normal and cheat meals.
/// Follows flutter-bespoke-ui design principles:
/// - Editorial meal occasion capsule with tinted background
/// - Cheat meal accent glow & badge
/// - Numbers-as-heroes calorie capsule
/// - Tactile spring card feedback
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

  IconData _getMealIcon(String type) {
    switch (type.toLowerCase()) {
      case 'breakfast':
        return Icons.wb_twilight_rounded;
      case 'lunch':
        return Icons.wb_sunny_rounded;
      case 'dinner':
        return Icons.nightlight_round;
      case 'snack':
      case 'snacks':
        return Icons.apple_rounded;
      default:
        return Icons.restaurant_rounded;
    }
  }

  Color _getMealColor(String type) {
    switch (type.toLowerCase()) {
      case 'breakfast':
        return const Color(0xFFD97706);
      case 'lunch':
        return const Color(0xFF059669);
      case 'dinner':
        return const Color(0xFF4F46E5);
      case 'snack':
      case 'snacks':
        return const Color(0xFF0D9488);
      default:
        return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final mealColor = _getMealColor(mealType);

    return EbicCard(
      onTap: onTap,
      border: isCheatMeal
          ? Border.all(color: AppColors.accent.withOpacity(0.6), width: 1.2)
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Meal Occasion Capsule
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                decoration: BoxDecoration(
                  color: mealColor.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: mealColor.withOpacity(0.20), width: 0.8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_getMealIcon(mealType), size: 12, color: mealColor),
                    const SizedBox(width: 4),
                    Text(
                      mealType.toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                        color: mealColor,
                      ),
                    ),
                  ],
                ),
              ),
              if (isCheatMeal)
                EBICBadge.pill('CHEAT MEAL', color: AppColors.accent)
              else if (isPrepared)
                EBICBadge.pill('PREPARED', color: AppColors.primary),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            dishName,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
              color: AppColors.slate900,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (portion != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.slate100,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.scale_outlined, size: 12, color: AppColors.slate500),
                      const SizedBox(width: 4),
                      Text(
                        portion!,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.slate700,
                        ),
                      ),
                    ],
                  ),
                ),
              if (calories != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7).withOpacity(0.8),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.local_fire_department_rounded, size: 12, color: Color(0xFFD97706)),
                      const SizedBox(width: 3),
                      Text(
                        '$calories kcal',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFB45309),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
