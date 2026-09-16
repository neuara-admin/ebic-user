import 'package:flutter/material.dart';
import '../../core/routing/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/ebic_button.dart';
import '../../shared/widgets/ebic_card.dart';
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
  State<DietPlanMealDetailScreen> createState() => _DietPlanMealDetailScreenState();
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
          backgroundColor: status == 'CONFIRMED_CONSUMED' ? Colors.green : Colors.grey.shade800,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _showFeedbackModal() {
    String selectedFeedback = 'LIKED';
    final notesController = TextEditingController();

    final options = [
      {'key': 'LIKED', 'label': 'Meal liked', 'icon': Icons.thumb_up_alt_outlined},
      {'key': 'DISLIKED', 'label': 'Meal disliked', 'icon': Icons.thumb_down_alt_outlined},
      {'key': 'UNABLE_TO_FOLLOW', 'label': 'Unable to follow', 'icon': Icons.schedule},
      {'key': 'INGREDIENT_UNAVAILABLE', 'label': 'Ingredient unavailable', 'icon': Icons.shopping_basket_outlined},
      {'key': 'PREFERENCE_CHANGED', 'label': 'Meal preference changed', 'icon': Icons.tune},
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
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
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
                      leading: Icon(opt['icon'] as IconData, color: isSel ? AppColors.primary : Colors.grey),
                      title: Text(
                        opt['label'] as String,
                        style: TextStyle(
                          fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                          color: isSel ? AppColors.primary : AppColors.textPrimary,
                        ),
                      ),
                      trailing: isSel
                          ? const Icon(Icons.check_circle, color: AppColors.primary)
                          : const Icon(Icons.circle_outlined, color: Colors.grey),
                      onTap: () {
                        setModalState(() => selectedFeedback = opt['key'] as String);
                      },
                    );
                  }),
                  const SizedBox(height: 12),
                  TextField(
                    controller: notesController,
                    decoration: InputDecoration(
                      hintText: 'Additional notes for your dietitian (optional)',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 18),
                  EbicButton(
                    text: 'Submit Feedback',
                    onPressed: () async {
                      Navigator.pop(ctx);
                      final ok = await _service.recordMealFeedback(
                        widget.planId,
                        widget.mealId,
                        feedbackType: selectedFeedback,
                        notes: notesController.text.trim(),
                      );
                      if (mounted && ok) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Feedback submitted to your dietitian.'),
                            backgroundColor: Colors.green,
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    if (_meal == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Meal Details')),
        body: const Center(child: Text('Meal not found')),
      );
    }

    final meal = _meal!;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(meal.occasion.replaceAll('_', ' ')),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.feedback_outlined),
            tooltip: 'Give Feedback',
            onPressed: _showFeedbackModal,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Meal Title Hero
          EbicCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      meal.occasion.replaceAll('_', ' '),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade700,
                        letterSpacing: 0.5,
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
                            Icon(Icons.stars, size: 14, color: Colors.amber.shade900),
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
                const SizedBox(height: 8),
                Text(
                  meal.title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (meal.description != null && meal.description!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    meal.description!,
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
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
                        Icon(Icons.info_outline, size: 18, color: Colors.amber.shade900),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Guidance: ${meal.guidance!}',
                            style: TextStyle(fontSize: 12, color: Colors.amber.shade900),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Adherence tracking card (Section 84/43)
          EbicCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Today\'s Adherence',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          backgroundColor: _adherenceStatus == 'CONFIRMED_CONSUMED'
                              ? Colors.green.shade50
                              : Colors.white,
                          side: BorderSide(
                            color: _adherenceStatus == 'CONFIRMED_CONSUMED'
                                ? Colors.green
                                : Colors.grey.shade300,
                            width: _adherenceStatus == 'CONFIRMED_CONSUMED' ? 2 : 1,
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: Icon(
                          Icons.check_circle,
                          color: _adherenceStatus == 'CONFIRMED_CONSUMED'
                              ? Colors.green
                              : Colors.grey.shade400,
                          size: 18,
                        ),
                        label: Text(
                          _adherenceStatus == 'CONFIRMED_CONSUMED' ? 'Consumed' : 'I Ate This',
                          style: TextStyle(
                            color: _adherenceStatus == 'CONFIRMED_CONSUMED'
                                ? Colors.green.shade900
                                : AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        onPressed: () => _updateAdherence('CONFIRMED_CONSUMED'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          backgroundColor: _adherenceStatus == 'SKIPPED'
                              ? Colors.red.shade50
                              : Colors.white,
                          side: BorderSide(
                            color: _adherenceStatus == 'SKIPPED'
                                ? Colors.red
                                : Colors.grey.shade300,
                            width: _adherenceStatus == 'SKIPPED' ? 2 : 1,
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: Icon(
                          Icons.cancel_outlined,
                          color: _adherenceStatus == 'SKIPPED'
                              ? Colors.red
                              : Colors.grey.shade400,
                          size: 18,
                        ),
                        label: Text(
                          _adherenceStatus == 'SKIPPED' ? 'Skipped' : 'Skip Meal',
                          style: TextStyle(
                            color: _adherenceStatus == 'SKIPPED'
                                ? Colors.red.shade900
                                : AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
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

          const SizedBox(height: 16),

          // Nutrition Targets / Macros breakdown
          if (meal.plannedNutrition != null)
            EbicCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Nutrition Snapshot',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildMacroBadge('Calories', '${meal.plannedNutrition!.calories}', 'kcal', Colors.orange),
                      _buildMacroBadge('Protein', '${meal.plannedNutrition!.proteinG}', 'g', Colors.red),
                      _buildMacroBadge('Carbs', '${meal.plannedNutrition!.carbsG}', 'g', Colors.blue),
                      _buildMacroBadge('Fat', '${meal.plannedNutrition!.fatG}', 'g', Colors.green),
                      _buildMacroBadge('Fibre', '${meal.plannedNutrition!.fibreG}', 'g', Colors.teal),
                    ],
                  ),
                ],
              ),
            ),

          const SizedBox(height: 16),

          // Dishes in Meal
          EbicCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Included Dishes & Ingredients',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const SizedBox(height: 12),
                ...meal.dishes.map((d) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                d.name,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                            ),
                            Text(
                              '${d.servingQuantity} ${d.servingUnit}',
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                            ),
                          ],
                        ),
                        if (d.dietaryTags.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            children: d.dietaryTags.map((tag) {
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade50,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: Colors.green.shade200),
                                ),
                                child: Text(
                                  tag,
                                  style: TextStyle(fontSize: 10, color: Colors.green.shade800),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                        if (d.ingredients.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Text(
                            'Ingredients: ${d.ingredients.map((i) => '${i.name} (${i.quantity}${i.unit})').join(', ')}',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                          ),
                        ],
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Instructions card
          if (meal.instructions != null && meal.instructions!.isNotEmpty)
            EbicCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Preparation Instructions',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    meal.instructions!,
                    style: TextStyle(fontSize: 13, height: 1.4, color: AppColors.textPrimary),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 20),

          // Chef Booking Flow (Section 20, 31 & Rule 2: Diet Plan ≠ Chef Booking)
          if (meal.bookChefEligible)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.teal.shade50,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.teal.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.soup_kitchen, color: Colors.teal.shade800, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Want an EBIC Chef to cook this?',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Colors.teal.shade900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'You can book a verified chef to prepare this dietitian-assigned meal at your home.',
                    style: TextStyle(fontSize: 12, color: Colors.teal.shade800),
                  ),
                  const SizedBox(height: 12),
                  EbicButton(
                    label: 'Book Chef for this Meal',
                    icon: Icons.calendar_today,
                    onPressed: () {
                      // Routes to Chef Booking passing assigned meal details
                      Navigator.pushNamed(
                        context,
                        AppRoutes.bookChefAssigned,
                        arguments: {
                          'dietPlanMealId': meal.id,
                          'mealTitle': meal.title,
                          'dishes': meal.dishes.map((d) => {'dishId': d.dishId, 'name': d.name}).toList(),
                        },
                      );
                    },
                  ),
                ],
              ),
            ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildMacroBadge(String label, String value, String unit, MaterialColor color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color.shade50,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            '$value $unit',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color: color.shade800,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
        ),
      ],
    );
  }
}
