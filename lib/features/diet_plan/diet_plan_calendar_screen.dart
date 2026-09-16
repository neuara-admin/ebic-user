import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/ebic_card.dart';
import 'diet_plan_service.dart';
import 'diet_plan_meal_detail_screen.dart';
import 'models/diet_plan_models.dart';

class DietPlanCalendarScreen extends StatefulWidget {
  final String dietPlanId;
  final String planName;

  const DietPlanCalendarScreen({
    super.key,
    required this.dietPlanId,
    required this.planName,
  });

  @override
  State<DietPlanCalendarScreen> createState() => _DietPlanCalendarScreenState();
}

class _DietPlanCalendarScreenState extends State<DietPlanCalendarScreen> {
  final DietPlanService _service = DietPlanService();
  bool _isLoading = true;
  Map<String, dynamic>? _calendarData;
  int _selectedDayIndex = 0;

  final List<String> _days = [
    'MONDAY',
    'TUESDAY',
    'WEDNESDAY',
    'THURSDAY',
    'FRIDAY',
    'SATURDAY',
    'SUNDAY',
  ];

  final List<String> _dayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  void initState() {
    super.initState();
    // Default selected day to today
    final todayIndex = (DateTime.now().weekday - 1) % 7;
    _selectedDayIndex = todayIndex;
    _fetchCalendar();
  }

  Future<void> _fetchCalendar() async {
    setState(() => _isLoading = true);
    final data = await _service.getCalendar(widget.dietPlanId);
    if (mounted) {
      setState(() {
        _calendarData = data;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          widget.planName,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : Column(
              children: [
                _buildDaySelector(),
                Expanded(child: _buildDayMealList()),
              ],
            ),
    );
  }

  Widget _buildDaySelector() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(_days.length, (index) {
          final isSelected = index == _selectedDayIndex;
          final isToday = index == ((DateTime.now().weekday - 1) % 7);

          return GestureDetector(
            onTap: () => setState(() => _selectedDayIndex = index),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary
                    : isToday
                        ? AppColors.primary.withOpacity(0.1)
                        : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? AppColors.primary
                      : isToday
                          ? AppColors.primary.withOpacity(0.3)
                          : Colors.transparent,
                ),
              ),
              child: Column(
                children: [
                  Text(
                    _dayLabels[index],
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                  if (isToday)
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.white : AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildDayMealList() {
    final selectedDay = _days[_selectedDayIndex];
    final calendarList = _calendarData?['calendar'] as List<dynamic>? ?? [];
    final dayData = calendarList.firstWhere(
      (element) => element['dayOfWeek'] == selectedDay,
      orElse: () => null,
    );

    final meals = (dayData?['meals'] as List<dynamic>?) ?? [];
    final totalNutrition = dayData?['totalNutrition'] as Map<String, dynamic>?;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Day summary header
        if (totalNutrition != null)
          Container(
            padding: const EdgeInsets.all(14),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withOpacity(0.08),
                  AppColors.primary.withOpacity(0.02),
                ],
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.primary.withOpacity(0.2)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildMacroItem('Calories', '${totalNutrition['calories'] ?? 0} kcal'),
                _buildMacroItem('Protein', '${totalNutrition['proteinG'] ?? 0}g'),
                _buildMacroItem('Carbs', '${totalNutrition['carbsG'] ?? 0}g'),
                _buildMacroItem('Fat', '${totalNutrition['fatG'] ?? 0}g'),
              ],
            ),
          ),

        if (meals.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Column(
                children: [
                  Icon(Icons.restaurant_menu, size: 48, color: Colors.grey.shade400),
                  const SizedBox(height: 12),
                  Text(
                    'No meals scheduled for this day',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 15),
                  ),
                ],
              ),
            ),
          )
        else
          ...meals.map((m) {
            final mealModel = DietPlanMealModel.fromJson(m as Map<String, dynamic>);
            return _buildMealCard(mealModel);
          }),
      ],
    );
  }

  Widget _buildMacroItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
        ),
      ],
    );
  }

  Widget _buildMealCard(DietPlanMealModel meal) {
    final occasionColor = _getOccasionColor(meal.occasion);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      child: EbicCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: occasionColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    meal.occasion.replaceAll('_', ' '),
                    style: TextStyle(
                      color: occasionColor,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (meal.isCheatMeal)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade100,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.amber.shade400),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.stars, size: 12, color: Colors.amber.shade800),
                        const SizedBox(width: 4),
                        Text(
                          'CHEAT MEAL',
                          style: TextStyle(
                            color: Colors.amber.shade900,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              meal.title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            if (meal.guidance != null && meal.guidance!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                meal.guidance!,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontStyle: FontStyle.italic),
              ),
            ],
            const SizedBox(height: 12),
            if (meal.plannedNutrition != null)
              Row(
                children: [
                  _buildNutritionChip('${meal.plannedNutrition!.calories} kcal'),
                  const SizedBox(width: 8),
                  _buildNutritionChip('${meal.plannedNutrition!.proteinG}g Protein'),
                  const SizedBox(width: 8),
                  _buildNutritionChip('${meal.plannedNutrition!.carbsG}g Carbs'),
                ],
              ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${meal.dishes.length} item${meal.dishes.length == 1 ? '' : 's'}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => DietPlanMealDetailScreen(
                          planId: widget.dietPlanId,
                          mealId: meal.id,
                        ),
                      ),
                    );
                  },
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'View Meal',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      Icon(Icons.arrow_forward_ios, size: 12, color: AppColors.primary),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNutritionChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 11, color: Colors.grey.shade700, fontWeight: FontWeight.w500),
      ),
    );
  }

  Color _getOccasionColor(String occasion) {
    switch (occasion.toUpperCase()) {
      case 'BREAKFAST':
        return Colors.orange.shade700;
      case 'MID_MORNING':
        return Colors.amber.shade700;
      case 'LUNCH':
        return Colors.teal.shade700;
      case 'EVENING_SNACK':
        return Colors.purple.shade600;
      case 'DINNER':
        return Colors.indigo.shade700;
      default:
        return AppColors.primary;
    }
  }
}
