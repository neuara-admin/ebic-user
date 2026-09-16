import 'package:flutter/material.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/routing/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/models/dish_model.dart';
import '../../shared/models/household_member_model.dart';
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
  List<HouseholdMemberModel> _members = [];
  HouseholdMemberModel? _selectedMember;
  List<Map<String, dynamic>> _categories = [];
  String _selectedCategory = 'ALL';
  String _searchQuery = '';
  String? _validationError;
  bool _isValidating = false;

  @override
  void initState() {
    super.initState();
    _cart.addListener(_onCartChanged);
    _loadInitialData();
  }

  @override
  void dispose() {
    _cart.removeListener(_onCartChanged);
    super.dispose();
  }

  void _onCartChanged() {
    if (mounted) {
      setState(() {});
      _validateSelection();
    }
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);

    try {
      // 1. Fetch Household Members (Section 8)
      final membersRes = await _api.get<List<dynamic>>(ApiEndpoints.householdMembers);
      if (membersRes.success && membersRes.data != null) {
        _members = membersRes.data!
            .map((m) => HouseholdMemberModel.fromJson(m as Map<String, dynamic>))
            .toList();
        if (_members.isNotEmpty) {
          _selectedMember = _members.first;
          _cart.setMember(_selectedMember!.id, _selectedMember!.name);
        }
      }

      // 2. Fetch Dynamic Catalogue Categories (Section 11)
      final catRes = await _api.get<List<dynamic>>(ApiEndpoints.categories);
      if (catRes.success && catRes.data != null) {
        _categories = catRes.data!.map((c) => c as Map<String, dynamic>).toList();
      }

      // 3. Fetch Dishes (Section 51)
      await _loadDishes();
    } catch (_) {}

    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _loadDishes() async {
    try {
      final query = <String, dynamic>{'limit': 50};
      if (_cart.selectedOccasion.isNotEmpty) {
        query['meal_type'] = _cart.selectedOccasion == 'BREAKFAST'
            ? 'B'
            : _cart.selectedOccasion == 'LUNCH'
                ? 'L'
                : 'D';
      }
      final res = await _api.get<Map<String, dynamic>>(
        ApiEndpoints.dishes,
        queryParameters: query,
      );
      if (res.success && res.data != null) {
        final items = res.data!['items'] as List<dynamic>? ?? [];
        _dishes = items.map((d) => DishModel.fromJson(d as Map<String, dynamic>)).toList();
      }
    } catch (_) {}

    if (_dishes.isEmpty) {
      _dishes = _getCuratedFallbackDishes();
    }
  }

  Future<void> _validateSelection() async {
    if (_cart.isEmpty || _selectedMember == null) {
      setState(() => _validationError = null);
      return;
    }

    setState(() => _isValidating = true);
    final mealCode = _cart.selectedOccasion == 'BREAKFAST'
        ? 'B'
        : _cart.selectedOccasion == 'LUNCH'
            ? 'L'
            : 'D';

    try {
      final res = await _api.post<Map<String, dynamic>>(
        ApiEndpoints.catalogueBookingValidate,
        body: {
          'member_id': _selectedMember!.id,
          'meal_type': mealCode,
          'items': _cart.toApiItems(),
        },
      );

      if (res.success && res.data != null) {
        final data = res.data!;
        if (data['valid'] == false) {
          final errors = data['errors'] as List<dynamic>? ?? [];
          if (errors.isNotEmpty) {
            final firstErr = errors.first as Map<String, dynamic>;
            _validationError = firstErr['message']?.toString() ?? 'Selection conflict';
          }
        } else {
          _validationError = null;
        }
      }
    } catch (_) {
      _validationError = null;
    }

    if (mounted) setState(() => _isValidating = false);
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

    if (_validationError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please resolve validation conflict: $_validationError'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    final dishInputs = _cart.items.map((item) {
      return {
        'dishId': item.dish.id,
        'name': item.dish.name,
        'servings': item.servings,
        'quantity': 1,
        'baseCookTimeMin': item.dish.baseCookTimeMin,
        'perServingIncMin': item.dish.perServingIncMin,
      };
    }).toList();

    Navigator.pushNamed(
      context,
      AppRoutes.bookChefQuote,
      arguments: {
        'mode': 'CATALOGUE',
        'memberId': _selectedMember?.id,
        'memberName': _selectedMember?.name ?? 'Self',
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
            // Step 1: Member Selector (Section 8)
            if (_members.isNotEmpty)
              Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _members.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final member = _members[index];
                    final isSelected = _selectedMember?.id == member.id;
                    return ChoiceChip(
                      avatar: CircleAvatar(
                        backgroundColor: isSelected ? AppColors.primary : AppColors.slate300,
                        child: Text(
                          member.name.isNotEmpty ? member.name[0] : 'M',
                          style: const TextStyle(fontSize: 10, color: Colors.white),
                        ),
                      ),
                      label: Text(member.name),
                      selected: isSelected,
                      selectedColor: AppColors.primarySubtle,
                      backgroundColor: Colors.white,
                      side: BorderSide(color: isSelected ? AppColors.primary : AppColors.slate200),
                      labelStyle: TextStyle(
                        color: isSelected ? AppColors.primary : AppColors.slate700,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        fontSize: 12,
                      ),
                      onSelected: (selected) {
                        if (selected) {
                          setState(() => _selectedMember = member);
                          _cart.setMember(member.id, member.name);
                          _validateSelection();
                        }
                      },
                    );
                  },
                ),
              ),

            // Step 2: Meal Occasion Selector (Section 9)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: ['BREAKFAST', 'LUNCH', 'DINNER'].map((occ) {
                  final isSelected = _cart.selectedOccasion == occ;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () {
                          _cart.setOccasion(occ);
                          _loadDishes();
                          _validateSelection();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected ? AppColors.primarySubtle : Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isSelected ? AppColors.primary : AppColors.slate200,
                              width: isSelected ? 1.5 : 1,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              occ,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isSelected ? AppColors.primary : AppColors.slate600,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

            if (_isValidating)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                child: LinearProgressIndicator(minHeight: 2, color: AppColors.primary),
              ),

            // Section 31 Allergy / Selection Warning UI
            if (_validationError != null)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: AppColors.danger, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _validationError!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.danger,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Search and Category filter
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: TextField(
                onChanged: (val) => setState(() => _searchQuery = val),
                decoration: InputDecoration(
                  hintText: 'Search dishes, cuisines...',
                  prefixIcon: const Icon(Icons.search),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  fillColor: Colors.white,
                  filled: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.slate200),
                  ),
                ),
              ),
            ),

            // Dynamic Category Chips (Section 11)
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  _buildCategoryChip('ALL', 'All Recipes'),
                  _buildCategoryChip('HIGH_PROTEIN', 'High Protein'),
                  _buildCategoryChip('HIGH_FIBRE', 'High Fibre'),
                  _buildCategoryChip('BALANCED', 'Balanced Meals'),
                  ..._categories.map((c) => _buildCategoryChip(c['code']?.toString() ?? '', c['name']?.toString() ?? '')),
                ],
              ),
            ),
            const SizedBox(height: 6),

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
