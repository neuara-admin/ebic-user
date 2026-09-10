import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/models/dish_model.dart';
import '../../shared/widgets/ebic_card.dart';
import '../../shared/widgets/ebic_button.dart';
import '../../shared/widgets/status_badge.dart';
import 'cart_service.dart';

class DishDetailScreen extends StatefulWidget {
  final DishModel dish;

  const DishDetailScreen({super.key, required this.dish});

  @override
  State<DishDetailScreen> createState() => _DishDetailScreenState();
}

class _DishDetailScreenState extends State<DishDetailScreen> {
  int _servings = 1;

  @override
  Widget build(BuildContext context) {
    final dish = widget.dish;
    final totalCookTime = dish.baseCookTimeMin + (_servings - 1) * dish.perServingIncMin;

    return Scaffold(
      appBar: AppBar(
        title: Text(dish.name),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Dish Header Container
                    Container(
                      width: double.infinity,
                      height: 180,
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Center(
                        child: Icon(Icons.restaurant_menu_rounded, color: Colors.white.withOpacity(0.9), size: 72),
                      ),
                    ),
                    const SizedBox(height: 18),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        StatusBadge.success(dish.category.replaceAll('_', ' ')),
                        Row(
                          children: [
                            const Icon(Icons.timer_outlined, size: 16, color: AppColors.slate500),
                            const SizedBox(width: 4),
                            Text(
                              '~$totalCookTime mins cooking',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    Text(
                      dish.name,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    if (dish.description != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        dish.description!,
                        style: const TextStyle(color: AppColors.slate600, fontSize: 14, height: 1.4),
                      ),
                    ],
                    const SizedBox(height: 20),

                    // Nutrition Grid
                    if (dish.nutrition != null) ...[
                      const Text('Nutritional Profile (Per Serving)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          _buildMacroTile('Calories', '${dish.nutrition!.calories.toInt()}', 'kcal', Colors.orange),
                          const SizedBox(width: 8),
                          _buildMacroTile('Protein', '${dish.nutrition!.proteinG.toInt()}', 'g', Colors.blue),
                          const SizedBox(width: 8),
                          _buildMacroTile('Carbs', '${dish.nutrition!.carbsG.toInt()}', 'g', Colors.green),
                          const SizedBox(width: 8),
                          _buildMacroTile('Fat', '${dish.nutrition!.fatG.toInt()}', 'g', Colors.red),
                        ],
                      ),
                      const SizedBox(height: 24),
                    ],

                    // Preparation notes
                    const Text('Preparation & Chef Notes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 8),
                    EbicCard(
                      child: Text(
                        dish.preparationInstructions ??
                            'Fresh pantry ingredients required. Handled and prepared live in customer kitchen by certified EBIC chef.',
                        style: const TextStyle(fontSize: 13, color: AppColors.slate600),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Bottom Add to Cart action bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 16, offset: const Offset(0, -4)),
                ],
              ),
              child: Row(
                children: [
                  // Servings counter
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.slate200),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove, size: 18),
                          onPressed: () {
                            if (_servings > 1) setState(() => _servings--);
                          },
                        ),
                        Text(
                          '$_servings ${_servings == 1 ? "Serving" : "Servings"}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add, size: 18),
                          onPressed: () => setState(() => _servings++),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: EbicButton(
                      label: 'Add to Booking',
                      onPressed: () {
                        CartService().addDish(dish, servings: _servings);
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Added ${dish.name} ($_servings servings)')),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMacroTile(String label, String value, String unit, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color)),
            Text(unit, style: TextStyle(fontSize: 10, color: color.withOpacity(0.8), fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(fontSize: 11, color: AppColors.slate600)),
          ],
        ),
      ),
    );
  }
}
