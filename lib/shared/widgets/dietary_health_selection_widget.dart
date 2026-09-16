import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

/// Modern, elevated selection widget for Dietary Preferences, Food Allergies,
/// Primary Health Goals, and Known Medical Conditions.
class DietaryHealthSelectionWidget extends StatelessWidget {
  final List<String> selectedDietary;
  final ValueChanged<List<String>> onDietaryChanged;

  final List<String> selectedAllergies;
  final ValueChanged<List<String>> onAllergiesChanged;

  final List<String> selectedGoals;
  final ValueChanged<List<String>> onGoalsChanged;

  final List<String> selectedConditions;
  final ValueChanged<List<String>> onConditionsChanged;

  const DietaryHealthSelectionWidget({
    super.key,
    required this.selectedDietary,
    required this.onDietaryChanged,
    required this.selectedAllergies,
    required this.onAllergiesChanged,
    required this.selectedGoals,
    required this.onGoalsChanged,
    required this.selectedConditions,
    required this.onConditionsChanged,
  });

  static const List<String> dietaryOptions = [
    'Vegetarian',
    'Non-Vegetarian',
    'Eggetarian',
    'Vegan',
    'Jain',
    'Keto / Low-Carb',
    'Diabetic-Friendly',
    'High-Protein',
    'Gluten-Free',
    'Low-Sodium / Heart-Care',
  ];

  static const List<String> allergyOptions = [
    'None',
    'Lactose / Dairy',
    'Gluten / Celiac',
    'Peanuts',
    'Tree Nuts',
    'Shellfish',
    'Soy',
    'Eggs',
    'Fish',
  ];

  static const List<String> goalOptions = [
    'Weight Management',
    'Blood Sugar Control',
    'Heart Health',
    'PCOS / PCOD Support',
    'Digestive Health',
    'Muscle Gain',
    'General Vitality',
  ];

  static const List<String> conditionOptions = [
    'None',
    'Type 2 Diabetes',
    'Hypertension',
    'Hypothyroid',
    'Hyperthyroid',
    'Dyslipidemia / High Cholesterol',
    'Chronic Kidney Disease',
    'GERD / Acid Reflux',
    'Fatty Liver',
  ];

  IconData _getDietaryIcon(String name) {
    switch (name) {
      case 'Vegetarian':
        return Icons.eco_rounded;
      case 'Non-Vegetarian':
        return Icons.restaurant_rounded;
      case 'Eggetarian':
        return Icons.egg_alt_outlined;
      case 'Vegan':
        return Icons.spa_rounded;
      case 'Jain':
        return Icons.nature_people_rounded;
      case 'Keto / Low-Carb':
        return Icons.lunch_dining_rounded;
      case 'Diabetic-Friendly':
        return Icons.health_and_safety_rounded;
      case 'High-Protein':
        return Icons.fitness_center_rounded;
      case 'Gluten-Free':
        return Icons.grain_rounded;
      case 'Low-Sodium / Heart-Care':
        return Icons.favorite_rounded;
      default:
        return Icons.restaurant_menu_rounded;
    }
  }

  IconData _getAllergyIcon(String name) {
    switch (name) {
      case 'None':
        return Icons.verified_user_rounded;
      case 'Lactose / Dairy':
        return Icons.water_drop_outlined;
      case 'Gluten / Celiac':
        return Icons.grain_outlined;
      case 'Peanuts':
      case 'Tree Nuts':
        return Icons.spa_outlined;
      case 'Shellfish':
      case 'Fish':
        return Icons.set_meal_outlined;
      case 'Soy':
        return Icons.grass_outlined;
      case 'Eggs':
        return Icons.egg_outlined;
      default:
        return Icons.warning_amber_rounded;
    }
  }

  IconData _getGoalIcon(String name) {
    switch (name) {
      case 'Weight Management':
        return Icons.monitor_weight_outlined;
      case 'Blood Sugar Control':
        return Icons.bloodtype_outlined;
      case 'Heart Health':
        return Icons.favorite_outline_rounded;
      case 'PCOS / PCOD Support':
        return Icons.local_florist_outlined;
      case 'Digestive Health':
        return Icons.healing_outlined;
      case 'Muscle Gain':
        return Icons.fitness_center_rounded;
      case 'General Vitality':
        return Icons.bolt_rounded;
      default:
        return Icons.flag_outlined;
    }
  }

  IconData _getConditionIcon(String name) {
    switch (name) {
      case 'None':
        return Icons.shield_outlined;
      case 'Type 2 Diabetes':
        return Icons.medical_services_outlined;
      case 'Hypertension':
        return Icons.speed_rounded;
      case 'Hypothyroid':
      case 'Hyperthyroid':
        return Icons.biotech_outlined;
      case 'Dyslipidemia / High Cholesterol':
        return Icons.science_outlined;
      case 'Chronic Kidney Disease':
        return Icons.local_hospital_outlined;
      case 'GERD / Acid Reflux':
        return Icons.local_fire_department_outlined;
      case 'Fatty Liver':
        return Icons.healing_outlined;
      default:
        return Icons.health_and_safety_outlined;
    }
  }

  void _toggleDietary(String item) {
    final list = List<String>.from(selectedDietary);
    if (list.contains(item)) {
      list.remove(item);
    } else {
      list.add(item);
    }
    onDietaryChanged(list);
  }

  void _toggleAllergy(String item) {
    final list = List<String>.from(selectedAllergies);
    if (item == 'None') {
      if (list.contains('None')) {
        list.remove('None');
      } else {
        list.clear();
        list.add('None');
      }
    } else {
      list.remove('None');
      if (list.contains(item)) {
        list.remove(item);
      } else {
        list.add(item);
      }
    }
    onAllergiesChanged(list);
  }

  void _toggleGoal(String item) {
    final list = List<String>.from(selectedGoals);
    if (list.contains(item)) {
      list.remove(item);
    } else {
      list.add(item);
    }
    onGoalsChanged(list);
  }

  void _toggleCondition(String item) {
    final list = List<String>.from(selectedConditions);
    if (item == 'None') {
      if (list.contains('None')) {
        list.remove('None');
      } else {
        list.clear();
        list.add('None');
      }
    } else {
      list.remove('None');
      if (list.contains(item)) {
        list.remove(item);
      } else {
        list.add(item);
      }
    }
    onConditionsChanged(list);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Dietary Preferences Section
        _buildSectionCard(
          context,
          icon: Icons.restaurant_menu_rounded,
          iconColor: const Color(0xFF059669),
          iconBgColor: const Color(0xFFD1FAE5),
          title: 'Dietary Preferences',
          subtitle: 'Preferred meal styles for tailored meal plans and recipes',
          countBadgeText: selectedDietary.isEmpty
              ? 'Select'
              : '${selectedDietary.length} selected',
          countBadgeColor: selectedDietary.isEmpty
              ? AppColors.slate200
              : const Color(0xFFD1FAE5),
          countTextColor: selectedDietary.isEmpty
              ? AppColors.slate600
              : const Color(0xFF065F46),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: dietaryOptions.map((item) {
              final isSelected = selectedDietary.contains(item);
              return _buildModernChip(
                label: item,
                icon: _getDietaryIcon(item),
                isSelected: isSelected,
                activeColor: const Color(0xFF059669),
                activeBgColor: const Color(0xFFECFDF5),
                activeBorderColor: const Color(0xFF10B981),
                onTap: () => _toggleDietary(item),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 18),

        // 2. Food Allergies & Intolerances Section
        _buildSectionCard(
          context,
          icon: Icons.shield_outlined,
          iconColor: selectedAllergies.contains('None')
              ? const Color(0xFF059669)
              : (selectedAllergies.isNotEmpty ? AppColors.danger : const Color(0xFFEA580C)),
          iconBgColor: selectedAllergies.contains('None')
              ? const Color(0xFFD1FAE5)
              : (selectedAllergies.isNotEmpty ? const Color(0xFFFEE2E2) : const Color(0xFFFFEDD5)),
          title: 'Food Allergies & Intolerances',
          subtitle: 'Kitchen and chefs will strictly exclude matching ingredients',
          countBadgeText: selectedAllergies.isEmpty
              ? 'None Specified'
              : (selectedAllergies.contains('None')
                  ? 'Allergen-Free'
                  : '${selectedAllergies.length} Alert${selectedAllergies.length > 1 ? 's' : ''}'),
          countBadgeColor: selectedAllergies.contains('None')
              ? const Color(0xFFD1FAE5)
              : (selectedAllergies.isNotEmpty ? const Color(0xFFFEE2E2) : AppColors.slate200),
          countTextColor: selectedAllergies.contains('None')
              ? const Color(0xFF065F46)
              : (selectedAllergies.isNotEmpty ? AppColors.danger : AppColors.slate600),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: allergyOptions.map((item) {
              final isSelected = selectedAllergies.contains(item);
              final isNone = item == 'None';
              return _buildModernChip(
                label: isNone ? 'None (No Allergies)' : item,
                icon: _getAllergyIcon(item),
                isSelected: isSelected,
                activeColor: isNone ? const Color(0xFF059669) : AppColors.danger,
                activeBgColor: isNone ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
                activeBorderColor: isNone ? const Color(0xFF10B981) : const Color(0xFFF87171),
                onTap: () => _toggleAllergy(item),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 18),

        // 3. Primary Health Goals Section
        _buildSectionCard(
          context,
          icon: Icons.track_changes_rounded,
          iconColor: const Color(0xFF4F46E5),
          iconBgColor: const Color(0xFFEEF2FF),
          title: 'Primary Health Goals',
          subtitle: 'Guiding nutrition targets, macro ratios, and wellness advice',
          countBadgeText: selectedGoals.isEmpty
              ? 'Optional'
              : '${selectedGoals.length} goal${selectedGoals.length > 1 ? 's' : ''}',
          countBadgeColor: selectedGoals.isEmpty
              ? AppColors.slate200
              : const Color(0xFFEEF2FF),
          countTextColor: selectedGoals.isEmpty
              ? AppColors.slate600
              : const Color(0xFF4338CA),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: goalOptions.map((item) {
              final isSelected = selectedGoals.contains(item);
              return _buildModernChip(
                label: item,
                icon: _getGoalIcon(item),
                isSelected: isSelected,
                activeColor: const Color(0xFF4F46E5),
                activeBgColor: const Color(0xFFF5F3FF),
                activeBorderColor: const Color(0xFF818CF8),
                onTap: () => _toggleGoal(item),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 18),

        // 4. Known Medical Conditions Section
        _buildSectionCard(
          context,
          icon: Icons.health_and_safety_rounded,
          iconColor: selectedConditions.contains('None')
              ? const Color(0xFF059669)
              : (selectedConditions.isNotEmpty ? const Color(0xFFD97706) : const Color(0xFF0284C7)),
          iconBgColor: selectedConditions.contains('None')
              ? const Color(0xFFD1FAE5)
              : (selectedConditions.isNotEmpty ? const Color(0xFFFEF3C7) : const Color(0xFFE0F2FE)),
          title: 'Known Medical Conditions',
          subtitle: 'Assists clinical dietitians in monitoring sodium, glycemic load, etc.',
          countBadgeText: selectedConditions.isEmpty
              ? 'None Specified'
              : (selectedConditions.contains('None')
                  ? 'Healthy / None'
                  : '${selectedConditions.length} Condition${selectedConditions.length > 1 ? 's' : ''}'),
          countBadgeColor: selectedConditions.contains('None')
              ? const Color(0xFFD1FAE5)
              : (selectedConditions.isNotEmpty ? const Color(0xFFFEF3C7) : AppColors.slate200),
          countTextColor: selectedConditions.contains('None')
              ? const Color(0xFF065F46)
              : (selectedConditions.isNotEmpty ? const Color(0xFFB45309) : AppColors.slate600),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: conditionOptions.map((item) {
              final isSelected = selectedConditions.contains(item);
              final isNone = item == 'None';
              return _buildModernChip(
                label: isNone ? 'None (No Medical Conditions)' : item,
                icon: _getConditionIcon(item),
                isSelected: isSelected,
                activeColor: isNone ? const Color(0xFF059669) : const Color(0xFFB45309),
                activeBgColor: isNone ? const Color(0xFFECFDF5) : const Color(0xFFFFFBEB),
                activeBorderColor: isNone ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                onTap: () => _toggleCondition(item),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionCard(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    required String title,
    required String subtitle,
    required String countBadgeText,
    required Color countBadgeColor,
    required Color countTextColor,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.slate200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: iconBgColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppColors.slate900,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: countBadgeColor,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            countBadgeText,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: countTextColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppColors.slate500,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: AppColors.slate100),
          const SizedBox(height: 14),

          // Options Chips Wrap
          child,
        ],
      ),
    );
  }

  Widget _buildModernChip({
    required String label,
    required IconData icon,
    required bool isSelected,
    required Color activeColor,
    required Color activeBgColor,
    required Color activeBorderColor,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? activeBgColor : AppColors.slate50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? activeBorderColor : AppColors.slate200,
              width: isSelected ? 1.5 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: activeColor.withOpacity(0.08),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected ? activeColor : AppColors.slate500,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? activeColor : AppColors.slate700,
                ),
              ),
              if (isSelected) ...[
                const SizedBox(width: 4),
                Icon(
                  Icons.check_circle_rounded,
                  size: 14,
                  color: activeColor,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
