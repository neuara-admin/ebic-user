import 'package:flutter/material.dart';
import '../../core/routing/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/ebic_button.dart';
import '../../shared/widgets/ebic_dish_image.dart';
import '../../shared/widgets/dish_video_modal.dart';
import '../catalogue/dish_detail_screen.dart';
import 'diet_plan_service.dart';
import 'models/diet_plan_models.dart';

class DietPlanMealDetailScreen extends StatefulWidget {
  final String planId;
  final String mealId;

  const DietPlanMealDetailScreen({
    super.key,
    required this.planId,
    required this.mealId,
  });

  @override
  State<DietPlanMealDetailScreen> createState() =>
      _DietPlanMealDetailScreenState();
}

class _DietPlanMealDetailScreenState extends State<DietPlanMealDetailScreen> {
  final DietPlanService _service = DietPlanService();
  bool _isLoading = true;
  DietPlanMealModel? _meal;
  String _adherenceStatus = 'PLANNED';
  bool _isSavingAdherence = false;

  @override
  void initState() {
    super.initState();
    _fetchDetails();
  }

  Future<void> _fetchDetails() async {
    setState(() => _isLoading = true);
    final meal = await _service.getMealDetails(widget.planId, widget.mealId);
    if (mounted) {
      setState(() {
        _meal = meal;
        _adherenceStatus = meal?.adherenceStatus ?? 'PLANNED';
        _isLoading = false;
      });
    }
  }

  Future<void> _updateAdherence(String status) async {
    if (_isSavingAdherence) return;
    setState(() => _isSavingAdherence = true);

    final success = await _service.recordMealAdherence(
      widget.planId,
      widget.mealId,
      status: status,
    );

    if (mounted) {
      setState(() {
        _isSavingAdherence = false;
        if (success) {
          _adherenceStatus = status;
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            status == 'CONFIRMED_CONSUMED'
                ? 'Great job! Logged as consumed.'
                : 'Meal marked as skipped.',
          ),
          backgroundColor: status == 'CONFIRMED_CONSUMED'
              ? Colors.green
              : Colors.grey.shade800,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _showFeedbackModal() {
    String selectedFeedback = 'LIKED';
    final notesController = TextEditingController();

    final options = [
      {
        'key': 'LIKED',
        'label': 'Meal liked',
        'icon': Icons.thumb_up_alt_outlined,
      },
      {
        'key': 'DISLIKED',
        'label': 'Meal disliked',
        'icon': Icons.thumb_down_alt_outlined,
      },
      {
        'key': 'UNABLE_TO_FOLLOW',
        'label': 'Unable to follow',
        'icon': Icons.schedule,
      },
      {
        'key': 'INGREDIENT_UNAVAILABLE',
        'label': 'Ingredient unavailable',
        'icon': Icons.shopping_basket_outlined,
      },
      {
        'key': 'PREFERENCE_CHANGED',
        'label': 'Meal preference changed',
        'icon': Icons.tune,
      },
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Meal Feedback for Dietitian',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const Text(
                    'Your feedback helps your dietitian adjust upcoming meal plans.',
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  ...options.map((opt) {
                    final isSel = selectedFeedback == opt['key'];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        opt['icon'] as IconData,
                        color: isSel ? AppColors.primary : Colors.grey,
                      ),
                      title: Text(
                        opt['label'] as String,
                        style: TextStyle(
                          fontWeight:
                              isSel ? FontWeight.bold : FontWeight.normal,
                          color: isSel ? AppColors.primary : AppColors.textPrimary,
                        ),
                      ),
                      trailing: isSel
                          ? const Icon(Icons.check, color: AppColors.primary)
                          : null,
                      onTap: () {
                        setModalState(() {
                          selectedFeedback = opt['key'] as String;
                        });
                      },
                    );
                  }),
                  const SizedBox(height: 12),
                  TextField(
                    controller: notesController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText: 'Additional notes for your dietitian (optional)',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      contentPadding: const EdgeInsets.all(12),
                    ),
                  ),
                  const SizedBox(height: 16),
                  EbicButton(
                    label: 'Submit Feedback',
                    onPressed: () async {
                      Navigator.pop(ctx);
                      final ok = await _service.recordMealFeedback(
                        widget.planId,
                        widget.mealId,
                        feedbackType: selectedFeedback,
                        notes: notesController.text.trim().isNotEmpty
                            ? notesController.text.trim()
                            : null,
                      );
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              ok
                                  ? 'Feedback submitted to your dietitian.'
                                  : 'Could not submit feedback.',
                            ),
                          ),
                        );
                      }
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Color _getOccasionColor(String occasion) {
    switch (occasion.toUpperCase()) {
      case 'BREAKFAST':
        return Colors.orange.shade700;
      case 'LUNCH':
        return Colors.amber.shade800;
      case 'DINNER':
        return Colors.indigo.shade600;
      case 'SNACK':
      case 'MORNING_SNACK':
      case 'EVENING_SNACK':
        return Colors.teal.shade700;
      default:
        return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Meal Details')),
        body: const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    if (_meal == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Meal Details')),
        body: const Center(child: Text('Meal not found')),
      );
    }

    final meal = _meal!;
    final occasionColor = _getOccasionColor(meal.occasion);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          meal.occasion.replaceAll('_', ' '),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: AppColors.slate900,
        actions: [
          IconButton(
            icon: const Icon(Icons.feedback_outlined, size: 20),
            tooltip: 'Give Feedback',
            onPressed: _showFeedbackModal,
          ),
        ],
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          // 1. Meal Title & Hero Header
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.slate200),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
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
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade100,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.amber.shade400),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.stars_rounded, size: 14, color: Colors.amber.shade900),
                            const SizedBox(width: 4),
                            Text(
                              'CHEAT MEAL',
                              style: TextStyle(
                                color: Colors.amber.shade900,
                                fontSize: 11,
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
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.slate900,
                    letterSpacing: -0.2,
                  ),
                ),
                if (meal.description != null && meal.description!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    meal.description!,
                    style: const TextStyle(
                      fontSize: 13.5,
                      color: AppColors.slate600,
                      height: 1.4,
                    ),
                  ),
                ],
                if (meal.isCheatMeal && meal.guidance != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.amber.shade200),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline_rounded, size: 18, color: Colors.amber.shade900),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Dietitian Guidance: ${meal.guidance!}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.amber.shade900,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),

          // 2. Adherence Tracking Card (Section 84/43)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.slate200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Today\'s Adherence',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
                    ),
                    Text(
                      _adherenceStatus == 'CONFIRMED_CONSUMED'
                          ? 'Logged as Eaten'
                          : (_adherenceStatus == 'SKIPPED' ? 'Marked as Skipped' : 'Pending'),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: _adherenceStatus == 'CONFIRMED_CONSUMED'
                            ? AppColors.successDark
                            : (_adherenceStatus == 'SKIPPED' ? AppColors.danger : AppColors.slate500),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          backgroundColor: _adherenceStatus == 'CONFIRMED_CONSUMED'
                              ? const Color(0xFFF0FDF4)
                              : Colors.white,
                          side: BorderSide(
                            color: _adherenceStatus == 'CONFIRMED_CONSUMED'
                                ? const Color(0xFF16A34A)
                                : AppColors.slate300,
                            width: _adherenceStatus == 'CONFIRMED_CONSUMED' ? 1.5 : 1,
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        icon: Icon(
                          Icons.check_circle_rounded,
                          color: _adherenceStatus == 'CONFIRMED_CONSUMED'
                              ? const Color(0xFF16A34A)
                              : AppColors.slate400,
                          size: 18,
                        ),
                        label: Text(
                          _adherenceStatus == 'CONFIRMED_CONSUMED'
                              ? 'Consumed'
                              : 'I Ate This',
                          style: TextStyle(
                            color: _adherenceStatus == 'CONFIRMED_CONSUMED'
                                ? const Color(0xFF166534)
                                : AppColors.slate800,
                            fontWeight: FontWeight.bold,
                            fontSize: 12.5,
                          ),
                        ),
                        onPressed: () => _updateAdherence('CONFIRMED_CONSUMED'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          backgroundColor: _adherenceStatus == 'SKIPPED'
                              ? const Color(0xFFFEF2F2)
                              : Colors.white,
                          side: BorderSide(
                            color: _adherenceStatus == 'SKIPPED'
                                ? const Color(0xFFDC2626)
                                : AppColors.slate300,
                            width: _adherenceStatus == 'SKIPPED' ? 1.5 : 1,
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        icon: Icon(
                          Icons.cancel_outlined,
                          color: _adherenceStatus == 'SKIPPED'
                              ? const Color(0xFFDC2626)
                              : AppColors.slate400,
                          size: 18,
                        ),
                        label: Text(
                          _adherenceStatus == 'SKIPPED' ? 'Skipped' : 'Skip Meal',
                          style: TextStyle(
                            color: _adherenceStatus == 'SKIPPED'
                                ? const Color(0xFF991B1B)
                                : AppColors.slate800,
                            fontWeight: FontWeight.bold,
                            fontSize: 12.5,
                          ),
                        ),
                        onPressed: () => _updateAdherence('SKIPPED'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // 3. Nutrition Snapshot
          if (meal.plannedNutrition != null)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.slate200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Meal Nutrition Target',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primarySubtle,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${meal.plannedNutrition!.calories} kcal',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryDark,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _buildMacroCard('Calories', '${meal.plannedNutrition!.calories}', 'kcal', const Color(0xFFF97316), Icons.local_fire_department_rounded),
                      const SizedBox(width: 8),
                      _buildMacroCard('Protein', '${meal.plannedNutrition!.proteinG}', 'g', const Color(0xFF3B82F6), Icons.fitness_center_rounded),
                      const SizedBox(width: 8),
                      _buildMacroCard('Carbs', '${meal.plannedNutrition!.carbsG}', 'g', const Color(0xFF10B981), Icons.bolt_rounded),
                      const SizedBox(width: 8),
                      _buildMacroCard('Fat', '${meal.plannedNutrition!.fatG}', 'g', const Color(0xFFEC4899), Icons.water_drop_rounded),
                      const SizedBox(width: 8),
                      _buildMacroCard('Fibre', '${meal.plannedNutrition!.fibreG}', 'g', const Color(0xFF8B5CF6), Icons.grain_rounded),
                    ],
                  ),
                ],
              ),
            ),
          const SizedBox(height: 16),

          // 4. Detailed Dishes & Ingredients List
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Assigned Dishes (${meal.dishes.length})',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.slate900,
                ),
              ),
              const Text(
                'Tap dish for full recipe',
                style: TextStyle(
                  fontSize: 11.5,
                  color: AppColors.slate500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          ...meal.dishes.map((dishItem) => _buildDishItemCard(dishItem)),

          const SizedBox(height: 14),

          const SizedBox(height: 16),

          // 6. Book Certified Chef CTA (Section 20 & 31)
          if (meal.bookChefEligible)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF042F2E), Color(0xFF0F766E)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0F766E).withOpacity(0.2),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.soup_kitchen_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Cook this Meal with an EBIC Chef',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Verified chef cooks in your kitchen with clean hygiene standards',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF042F2E),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.calendar_today_rounded, size: 16),
                      label: const Text(
                        'Book Chef for this Meal',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                      ),
                      onPressed: () {
                        Navigator.pushNamed(
                          context,
                          AppRoutes.bookChefAssigned,
                          arguments: {
                            'dietPlanMealId': meal.id,
                            'occasion': meal.occasion,
                            'mealTitle': meal.title,
                            'dishes': meal.dishes
                                .map((d) => {
                                      'dishId': d.dishId.isNotEmpty ? d.dishId : d.id,
                                      'name': d.name,
                                      'quantity': d.servingQuantity,
                                    })
                                .toList(),
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // Dish Card with Image, Video, Portions, and Ingredients
  Widget _buildDishItemCard(DietPlanDishItemModel dishItem) {
    final isVeg = dishItem.dietaryTags.any(
      (t) => t.toLowerCase() == 'vegetarian' || t.toLowerCase() == 'vegan',
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.slate200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row: Image, Name, Servings, Video Button
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => DishDetailScreen(dish: dishItem.toDishModel()),
                      ),
                    );
                  },
                  child: EBICDishImage(
                    imageUrl: dishItem.imageUrl,
                    width: 64,
                    height: 64,
                    borderRadius: 12,
                    isVegetarian: isVeg,
                    showVegIndicator: true,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        dishItem.name,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppColors.slate900,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primarySubtle,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '${dishItem.servingQuantity} ${dishItem.servingUnit}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primaryDark,
                              ),
                            ),
                          ),
                          if (dishItem.cookingTimeMin != null) ...[
                            const SizedBox(width: 6),
                            Text(
                              '• ~${dishItem.cookingTimeMin} mins',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.slate500,
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (dishItem.dietaryTags.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 5,
                          runSpacing: 4,
                          children: dishItem.dietaryTags.take(4).map((tag) {
                            final t = tag.toUpperCase();
                            Color bg = const Color(0xFFF8FAFC);
                            Color border = const Color(0xFFE2E8F0);
                            Color text = const Color(0xFF475569);

                            if (t.contains('PROTEIN')) {
                              bg = const Color(0xFFEFF6FF);
                              border = const Color(0xFFBFDBFE);
                              text = const Color(0xFF1D4ED8);
                            } else if (t.contains('CARB') || t.contains('KETO')) {
                              bg = const Color(0xFFF5F3FF);
                              border = const Color(0xFFDDD6FE);
                              text = const Color(0xFF6D28D9);
                            } else if (t.contains('VEG')) {
                              bg = const Color(0xFFECFDF5);
                              border = const Color(0xFFA7F3D0);
                              text = const Color(0xFF047857);
                            }

                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: bg,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: border, width: 1),
                              ),
                              child: Text(
                                tag,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: text,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Action Chips: Watch Video & View Full Recipe
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () {
                      final videoUrl = dishItem.videoUrl ??
                          'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4';
                      DishVideoModal.show(context, videoUrl: videoUrl, title: dishItem.name);
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 14),
                          SizedBox(width: 4),
                          Text(
                            'Watch Video',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => DishDetailScreen(dish: dishItem.toDishModel()),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                      decoration: BoxDecoration(
                        color: AppColors.primarySubtle,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.restaurant_menu_rounded, color: AppColors.primaryDark, size: 14),
                          SizedBox(width: 4),
                          Text(
                            'Full Recipe',
                            style: TextStyle(
                              color: AppColors.primaryDark,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Ingredients Breakdown Box
          if (dishItem.ingredients.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 12),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.slate50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.slate200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Ingredients (${dishItem.ingredients.length})',
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          color: AppColors.slate700,
                        ),
                      ),
                      Text(
                        'Scaled for ${dishItem.servingQuantity} ${dishItem.servingUnit}',
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.slate500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: dishItem.ingredients.map((ing) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppColors.slate200),
                        ),
                        child: Text(
                          '${ing.name} • ${ing.quantity} ${ing.unit}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: AppColors.slate800,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildMacroCard(String label, String value, String unit, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 13,
                color: color,
              ),
            ),
            Text(
              unit,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              label,
              style: const TextStyle(
                fontSize: 9.5,
                color: AppColors.slate600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
