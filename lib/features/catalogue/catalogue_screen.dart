import 'package:flutter/material.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/routing/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/models/dish_model.dart';
import '../../shared/widgets/ebic_card.dart';
import '../../shared/widgets/ebic_button.dart';
import '../../shared/widgets/loading_view.dart';
import 'cart_service.dart';
import 'dish_detail_screen.dart';

class CatalogueScreen extends StatefulWidget {
  const CatalogueScreen({super.key});

  @override
  State<CatalogueScreen> createState() => _CatalogueScreenState();
}

class _CatalogueScreenState extends State<CatalogueScreen> {
  final ApiClient _api = ApiClient();
  final CartService _cart = CartService();

  bool _isLoading = true;
  List<DishModel> _dishes = [];
  String _selectedCategory = 'ALL'; // ALL, HIGH_PROTEIN, HIGH_FIBRE, BALANCED
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _cart.addListener(_onCartChanged);
    _loadDishes();
  }

  @override
  void dispose() {
    _cart.removeListener(_onCartChanged);
    super.dispose();
  }

  void _onCartChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadDishes() async {
    setState(() => _isLoading = true);

    try {
      final res = await _api.get<Map<String, dynamic>>(
        ApiEndpoints.dishes,
        queryParameters: {'limit': 50},
      );
      if (res.success && res.data != null) {
        final items = res.data!['items'] as List<dynamic>? ?? [];
        _dishes = items.map((d) => DishModel.fromJson(d as Map<String, dynamic>)).toList();
      }
    } catch (_) {}

    // Fallback healthy catalogue if server has limited seed
    if (_dishes.isEmpty) {
      _dishes = _getCuratedFallbackDishes();
    }

    if (mounted) setState(() => _isLoading = false);
  }

  List<DishModel> _getCuratedFallbackDishes() {
    return [
      DishModel(
        id: 'dish-1',
        name: 'Herb Grilled Chicken Breast',
        category: 'HIGH_PROTEIN',
        cuisine: 'Continental',
        description: 'Tender marinated chicken breast with rosemary, thyme, and roasted garlic.',
        baseCookTimeMin: 22,
        perServingIncMin: 4,
        nutrition: DishNutritionModel(calories: 380, proteinG: 44, carbsG: 4, fatG: 8),
      ),
      DishModel(
        id: 'dish-2',
        name: 'Paneer Tikka Protein Bowl',
        category: 'HIGH_PROTEIN',
        cuisine: 'North Indian',
        description: 'Cottage cheese cubes charred with bell peppers and roasted cumin.',
        baseCookTimeMin: 20,
        perServingIncMin: 3,
        nutrition: DishNutritionModel(calories: 420, proteinG: 28, carbsG: 14, fatG: 22),
      ),
      DishModel(
        id: 'dish-3',
        name: 'High-Fibre Quinoa & Lentil Khichdi',
        category: 'HIGH_FIBRE',
        cuisine: 'Healthy Indian',
        description: 'Nutritious slow-cooked organic quinoa with yellow moong lentils and spinach.',
        baseCookTimeMin: 25,
        perServingIncMin: 5,
        nutrition: DishNutritionModel(calories: 340, proteinG: 18, carbsG: 48, fatG: 6),
      ),
      DishModel(
        id: 'dish-4',
        name: 'Steamed Lemon Garlic Broccoli & Greens',
        category: 'HIGH_FIBRE',
        cuisine: 'Continental',
        description: 'Fresh crisp broccoli and zucchini tossed in virgin olive oil and lemon zest.',
        baseCookTimeMin: 12,
        perServingIncMin: 2,
        nutrition: DishNutritionModel(calories: 140, proteinG: 6, carbsG: 12, fatG: 4),
      ),
      DishModel(
        id: 'dish-5',
        name: 'Balanced Brown Basmati Pulao',
        category: 'BALANCED',
        cuisine: 'Indian',
        description: 'Aromatic whole grain brown rice with garden peas, carrots and whole spices.',
        baseCookTimeMin: 18,
        perServingIncMin: 3,
        nutrition: DishNutritionModel(calories: 280, proteinG: 8, carbsG: 52, fatG: 3),
      ),
    ];
  }

  List<DishModel> get _filteredDishes {
    return _dishes.where((d) {
      final matchesCategory = _selectedCategory == 'ALL' || d.category == _selectedCategory;
      final matchesSearch = _searchQuery.isEmpty ||
          d.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (d.cuisine?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false);
      return matchesCategory && matchesSearch;
    }).toList();
  }

  void _proceedToReview() {
    if (_cart.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one dish to your order.')),
      );
      return;
    }

    final dishInputs = _cart.items.map((item) {
      return {
        'dishId': item.dish.id,
        'name': item.dish.name,
        'servings': item.servings,
        'baseCookTimeMin': item.dish.baseCookTimeMin,
        'perServingIncMin': item.dish.perServingIncMin,
      };
    }).toList();

    Navigator.pushNamed(
      context,
      AppRoutes.bookChefQuote,
      arguments: {
        'mode': 'CATALOGUE',
        'occasion': _cart.selectedOccasion,
        'bookingOption': _cart.selectedOccasion == 'BREAKFAST'
            ? 'B'
            : _cart.selectedOccasion == 'LUNCH'
                ? 'L'
                : 'D',
        'dishes': dishInputs,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Catalogue Chef Booking'),
        actions: [
          if (!_cart.isEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Badge(
                  label: Text('${_cart.itemCount}'),
                  backgroundColor: AppColors.primary,
                  child: const Icon(Icons.soup_kitchen_rounded),
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Search and Category filter
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: TextField(
                onChanged: (val) => setState(() => _searchQuery = val),
                decoration: InputDecoration(
                  hintText: 'Search dishes, cuisines...',
                  prefixIcon: const Icon(Icons.search),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  fillColor: Colors.white,
                  filled: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.slate200),
                  ),
                ),
              ),
            ),

            // Category Chips
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  _buildCategoryChip('ALL', 'All Recipes'),
                  _buildCategoryChip('HIGH_PROTEIN', 'High Protein'),
                  _buildCategoryChip('HIGH_FIBRE', 'High Fibre'),
                  _buildCategoryChip('BALANCED', 'Balanced Meals'),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Dish list
            Expanded(
              child: _isLoading
                  ? const LoadingView(message: 'Loading recipe catalogue...')
                  : _filteredDishes.isEmpty
                      ? const Center(child: Text('No dishes found.'))
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _filteredDishes.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final dish = _filteredDishes[index];
                            return _buildDishCard(dish);
                          },
                        ),
            ),

            // Bottom cart action bar
            if (!_cart.isEmpty) _buildCartBottomBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryChip(String categoryKey, String label) {
    final isSelected = _selectedCategory == categoryKey;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        selectedColor: AppColors.primarySubtle,
        backgroundColor: Colors.white,
        side: BorderSide(
          color: isSelected ? AppColors.primary : AppColors.slate200,
        ),
        labelStyle: TextStyle(
          color: isSelected ? AppColors.primary : AppColors.slate700,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          fontSize: 12,
        ),
        onSelected: (selected) {
          if (selected) setState(() => _selectedCategory = categoryKey);
        },
      ),
    );
  }

  Widget _buildDishCard(DishModel dish) {
    final cartItem = _cart.items.firstWhere(
      (i) => i.dish.id == dish.id,
      orElse: () => CartItem(dish: dish, servings: 0),
    );
    final count = cartItem.servings;

    return EbicCard(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => DishDetailScreen(dish: dish)),
        );
      },
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Dish icon / image thumbnail
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              color: AppColors.primarySubtle,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.restaurant, color: AppColors.primary, size: 36),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dish.name,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                if (dish.description != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    dish.description!,
                    style: const TextStyle(color: AppColors.slate500, fontSize: 12),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      '~${dish.baseCookTimeMin} mins',
                      style: const TextStyle(fontSize: 12, color: AppColors.slate600, fontWeight: FontWeight.w500),
                    ),
                    if (dish.nutrition != null) ...[
                      const Text(' • ', style: TextStyle(color: AppColors.slate400)),
                      Text(
                        '${dish.nutrition!.calories.toInt()} kcal',
                        style: const TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.bold),
                      ),
                      const Text(' • ', style: TextStyle(color: AppColors.slate400)),
                      Text(
                        '${dish.nutrition!.proteinG.toInt()}g P',
                        style: const TextStyle(fontSize: 12, color: AppColors.slate600),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Servings stepper
          count == 0
              ? OutlinedButton(
                  onPressed: () => _cart.addDish(dish, servings: 1),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.primary),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  ),
                  child: const Text('ADD', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
                )
              : Container(
                  decoration: BoxDecoration(
                    color: AppColors.primarySubtle,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.primary),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove, size: 16, color: AppColors.primary),
                        constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                        padding: EdgeInsets.zero,
                        onPressed: () => _cart.updateServings(dish.id, count - 1),
                      ),
                      Text(
                        '$count',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add, size: 16, color: AppColors.primary),
                        constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                        padding: EdgeInsets.zero,
                        onPressed: () => _cart.updateServings(dish.id, count + 1),
                      ),
                    ],
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildCartBottomBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 16, offset: const Offset(0, -4)),
        ],
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${_cart.itemCount} items selected',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              const Text(
                'Cooking time & price calculated on backend',
                style: TextStyle(fontSize: 11, color: AppColors.slate500),
              ),
            ],
          ),
          const Spacer(),
          SizedBox(
            width: 140,
            child: EbicButton(
              label: 'Review Quote',
              onPressed: _proceedToReview,
              isFullWidth: false,
            ),
          ),
        ],
      ),
    );
  }
}
