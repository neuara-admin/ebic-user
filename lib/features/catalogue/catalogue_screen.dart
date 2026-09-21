import 'dart:async';
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
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;

  bool _isLoading = true;
  List<DishModel> _dishes = [];
  List<HouseholdMemberModel> _members = [];
  HouseholdMemberModel? _selectedMember;
  List<Map<String, dynamic>> _categories = [];
  String _selectedCategory = 'ALL';
  String _searchQuery = '';
  String? _validationError;
  bool _isValidating = false;

  bool _isSearchExpanded = false;

  // Filter State
  String _quickFilter = 'ALL'; // ALL, VEG, NON_VEG, HIGH_PROTEIN, QUICK, LOW_CAL
  String _dietaryFilter = 'ALL'; // ALL, VEG, NON_VEG, VEGAN
  Set<String> _selectedCuisines = {};
  String _sortBy = 'RECOMMENDED'; // RECOMMENDED, COOK_TIME_ASC, PROTEIN_DESC, CALORIES_ASC
  int? _maxCookTime; // null = any, 20, 30, 45
  int? _maxCalories; // null = any, 350, 500

  @override
  void initState() {
    super.initState();
    _cart.addListener(_onCartChanged);
    _loadInitialData();
  }

  @override
  void dispose() {
    _cart.removeListener(_onCartChanged);
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onCartChanged() {
    if (mounted) {
      setState(() {});
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
      }

      if (_members.isEmpty) {
        _members = [
          HouseholdMemberModel(
            id: 'member_self',
            name: 'Self',
            relationship: 'SELF',
            isCoveredByHealthPass: true,
            dietaryPreferences: ['Vegetarian'],
          ),
        ];
      }

      if (_members.isNotEmpty) {
        _selectedMember = _members.first;
        _cart.setMember(_selectedMember!.id, _selectedMember!.name);
      }

      // 2. Fetch Dynamic Catalogue Categories (Section 11)
      final catRes = await _api.get<List<dynamic>>(ApiEndpoints.categories);
      if (catRes.success && catRes.data != null) {
        _categories = catRes.data!.map((c) => c as Map<String, dynamic>).toList();
      }

      // 3. Fetch Dishes from Backend (Section 51)
      await _loadDishes();
    } catch (_) {}

    if (mounted) setState(() => _isLoading = false);
  }

  /// Authoritative backend-driven dish query
  Future<void> _loadDishes({bool showSpinner = false}) async {
    if (showSpinner && mounted) {
      setState(() => _isLoading = true);
    }

    try {
      final query = <String, dynamic>{'limit': 60};

      // Backend Meal Occasion Filtering
      if (_cart.selectedOccasion.isNotEmpty) {
        query['meal_type'] = _cart.occasionCode;
      }

      // Backend Category Filtering
      if (_selectedCategory != 'ALL') {
        query['category'] = _selectedCategory;
      }

      // Backend Search Filtering
      if (_searchQuery.isNotEmpty) {
        query['search'] = _searchQuery;
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

    // Curated high-yield fallbacks if backend returns empty
    if (_dishes.isEmpty) {
      _dishes = _getCuratedFallbackDishes();
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  void _onSearchChanged(String val) {
    _searchQuery = val.trim();
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      _loadDishes();
    });
    setState(() {});
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
        dietaryTags: ['High Protein', 'Gluten Free'],
      ),
      DishModel(
        id: 'dish-2',
        name: 'Paneer Tikka Protein Bowl',
        category: 'HIGH_PROTEIN',
        cuisine: 'North Indian',
        description: 'Cottage cheese cubes charred with bell peppers, onions, and roasted cumin.',
        baseCookTimeMin: 20,
        perServingIncMin: 3,
        nutrition: DishNutritionModel(calories: 420, proteinG: 28, carbsG: 14, fatG: 22),
        dietaryTags: ['Vegetarian', 'High Protein'],
      ),
      DishModel(
        id: 'dish-3',
        name: 'High-Fibre Quinoa & Lentil Khichdi',
        category: 'HIGH_FIBRE',
        cuisine: 'Healthy Indian',
        description: 'Nutritious slow-cooked organic quinoa with yellow moong lentils and fresh spinach.',
        baseCookTimeMin: 25,
        perServingIncMin: 5,
        nutrition: DishNutritionModel(calories: 340, proteinG: 18, carbsG: 48, fatG: 6),
        dietaryTags: ['Vegetarian', 'Vegan', 'High Fibre'],
      ),
      DishModel(
        id: 'dish-4',
        name: 'Steamed Lemon Garlic Broccoli & Greens',
        category: 'HIGH_FIBRE',
        cuisine: 'Continental',
        description: 'Fresh crisp broccoli, zucchini, and asparagus tossed in extra virgin olive oil and lemon zest.',
        baseCookTimeMin: 14,
        perServingIncMin: 2,
        nutrition: DishNutritionModel(calories: 140, proteinG: 6, carbsG: 12, fatG: 4),
        dietaryTags: ['Vegetarian', 'Vegan', 'Low Calorie'],
      ),
      DishModel(
        id: 'dish-5',
        name: 'Balanced Brown Basmati Pulao',
        category: 'BALANCED',
        cuisine: 'North Indian',
        description: 'Aromatic whole grain brown rice with garden peas, carrots and whole spices.',
        baseCookTimeMin: 18,
        perServingIncMin: 3,
        nutrition: DishNutritionModel(calories: 280, proteinG: 8, carbsG: 52, fatG: 3),
        dietaryTags: ['Vegetarian', 'Balanced'],
      ),
      DishModel(
        id: 'dish-6',
        name: 'Atlantic Salmon Pan-Seared Fillet',
        category: 'HIGH_PROTEIN',
        cuisine: 'Continental',
        description: 'Omega-3 rich wild salmon seared with dill butter and served with sautéed green beans.',
        baseCookTimeMin: 18,
        perServingIncMin: 4,
        nutrition: DishNutritionModel(calories: 410, proteinG: 38, carbsG: 2, fatG: 24),
        dietaryTags: ['High Protein', 'Keto Friendly'],
      ),
      DishModel(
        id: 'dish-7',
        name: 'Tofu & Vegetable Stir-Fry',
        category: 'BALANCED',
        cuisine: 'Asian',
        description: 'Crispy tofu batons with bell peppers, mushrooms and snow peas in ginger soy glaze.',
        baseCookTimeMin: 16,
        perServingIncMin: 3,
        nutrition: DishNutritionModel(calories: 260, proteinG: 20, carbsG: 18, fatG: 11),
        dietaryTags: ['Vegetarian', 'Vegan', 'High Protein'],
      ),
    ];
  }

  Future<void> _validateSelection() async {
    if (_cart.isEmpty || _selectedMember == null) {
      setState(() => _validationError = null);
      return;
    }

    setState(() => _isValidating = true);
    final mealCode = _cart.occasionCode;

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

  int get _activeFilterCount {
    int count = 0;
    if (_dietaryFilter != 'ALL') count++;
    if (_selectedCuisines.isNotEmpty) count += _selectedCuisines.length;
    if (_maxCookTime != null) count++;
    if (_maxCalories != null) count++;
    if (_sortBy != 'RECOMMENDED') count++;
    return count;
  }

  List<DishModel> get _filteredDishes {
    var list = _dishes.where((d) {
      // 1. Quick Filter Pills
      bool matchesQuick = true;
      if (_quickFilter == 'VEG') {
        matchesQuick = d.isVegetarian;
      } else if (_quickFilter == 'NON_VEG') {
        matchesQuick = !d.isVegetarian;
      } else if (_quickFilter == 'HIGH_PROTEIN') {
        matchesQuick = d.isHighProtein;
      } else if (_quickFilter == 'QUICK') {
        matchesQuick = d.isQuickPrep;
      } else if (_quickFilter == 'LOW_CAL') {
        matchesQuick = d.isLowCalorie;
      }

      // 2. Modal Dietary Filter
      bool matchesDietary = true;
      if (_dietaryFilter == 'VEG') {
        matchesDietary = d.isVegetarian;
      } else if (_dietaryFilter == 'NON_VEG') {
        matchesDietary = !d.isVegetarian;
      } else if (_dietaryFilter == 'VEGAN') {
        matchesDietary = d.isVegan;
      }

      // 3. Cuisines Multi-select
      bool matchesCuisine = _selectedCuisines.isEmpty ||
          (_selectedCuisines.contains(d.cuisine ?? 'Other'));

      // 4. Max Cook Time
      bool matchesCookTime = _maxCookTime == null || d.baseCookTimeMin <= _maxCookTime!;

      // 5. Max Calories
      bool matchesCalories = _maxCalories == null ||
          ((d.nutrition?.calories ?? 0) <= _maxCalories!);

      return matchesQuick &&
          matchesDietary &&
          matchesCuisine &&
          matchesCookTime &&
          matchesCalories;
    }).toList();

    // Sorting
    if (_sortBy == 'COOK_TIME_ASC') {
      list.sort((a, b) => a.baseCookTimeMin.compareTo(b.baseCookTimeMin));
    } else if (_sortBy == 'PROTEIN_DESC') {
      list.sort((a, b) =>
          (b.nutrition?.proteinG ?? 0).compareTo(a.nutrition?.proteinG ?? 0));
    } else if (_sortBy == 'CALORIES_ASC') {
      list.sort((a, b) =>
          (a.nutrition?.calories ?? 999).compareTo(b.nutrition?.calories ?? 999));
    }

    return list;
  }

  Set<String> get _availableCuisines {
    final set = <String>{};
    for (final d in _dishes) {
      if (d.cuisine != null && d.cuisine!.isNotEmpty) {
        set.add(d.cuisine!);
      }
    }
    return set;
  }

  void _proceedToReview() {
    if (_cart.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one dish to your order.')),
      );
      return;
    }

    if (_validationError != null && _validationError!.toLowerCase().contains('allerg')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Allergen conflict: $_validationError'),
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
        'unitPrice': 120.0,
        'quantity': 1,
        'baseCookTimeMin': item.dish.baseCookTimeMin,
        'perServingIncMin': item.dish.perServingIncMin,
        'memberId': item.memberId,
        'memberName': item.memberName,
      };
    }).toList();

    Navigator.pushNamed(
      context,
      AppRoutes.bookChefQuote,
      arguments: {
        'mode': 'CATALOGUE',
        'memberId': _selectedMember?.id,
        'memberName': _selectedMember?.name ?? 'Self',
        'memberRelation': _selectedMember?.relationship ?? 'SELF',
        'memberDietary': _selectedMember?.dietaryPreferences ?? [],
        'memberAllergies': _selectedMember?.allergies ?? [],
        'isHealthPassCovered': _selectedMember?.isCoveredByHealthPass ?? false,
        'allMembers': _members.map((m) => {
          'id': m.id,
          'name': m.name,
          'relationship': m.relationship,
          'allergies': m.allergies,
          'dietaryPreferences': m.dietaryPreferences,
          'isCoveredByHealthPass': m.isCoveredByHealthPass,
        }).toList(),
        'occasion': _cart.selectedOccasion,
        'bookingOption': _cart.occasionCode,
        'dishes': dishInputs,
      },
    );
  }

  void _showFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.78,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  // Modal Handle
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(top: 12, bottom: 8),
                      decoration: BoxDecoration(
                        color: AppColors.slate300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  // Header
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Filters & Dietary Preferences',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.slate900),
                        ),
                        TextButton(
                          onPressed: () {
                            setModalState(() {
                              _dietaryFilter = 'ALL';
                              _selectedCuisines.clear();
                              _sortBy = 'RECOMMENDED';
                              _maxCookTime = null;
                              _maxCalories = null;
                            });
                            setState(() {});
                          },
                          child: const Text('Reset All', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),

                  // Scrollable Filter Sections
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.all(20),
                      children: [
                        // Section 1: Dietary Preference
                        const Text('Dietary Preference', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.slate900)),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _buildModalFilterChip('All', _dietaryFilter == 'ALL', () {
                              setModalState(() => _dietaryFilter = 'ALL');
                              setState(() {});
                            }),
                            _buildModalFilterChip('🥦 Vegetarian', _dietaryFilter == 'VEG', () {
                              setModalState(() => _dietaryFilter = 'VEG');
                              setState(() {});
                            }),
                            _buildModalFilterChip('🍗 Non-Vegetarian', _dietaryFilter == 'NON_VEG', () {
                              setModalState(() => _dietaryFilter = 'NON_VEG');
                              setState(() {});
                            }),
                            _buildModalFilterChip('🌱 Vegan', _dietaryFilter == 'VEGAN', () {
                              setModalState(() => _dietaryFilter = 'VEGAN');
                              setState(() {});
                            }),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // Section 2: Sort By
                        const Text('Sort By', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.slate900)),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _buildModalFilterChip('Recommended', _sortBy == 'RECOMMENDED', () {
                              setModalState(() => _sortBy = 'RECOMMENDED');
                              setState(() {});
                            }),
                            _buildModalFilterChip('⚡ Fastest Cook Time', _sortBy == 'COOK_TIME_ASC', () {
                              setModalState(() => _sortBy = 'COOK_TIME_ASC');
                              setState(() {});
                            }),
                            _buildModalFilterChip('💪 High Protein First', _sortBy == 'PROTEIN_DESC', () {
                              setModalState(() => _sortBy = 'PROTEIN_DESC');
                              setState(() {});
                            }),
                            _buildModalFilterChip('🥗 Lowest Calories', _sortBy == 'CALORIES_ASC', () {
                              setModalState(() => _sortBy = 'CALORIES_ASC');
                              setState(() {});
                            }),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // Section 3: Cooking Time
                        const Text('Maximum Cooking Time', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.slate900)),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          children: [
                            _buildModalFilterChip('Any Time', _maxCookTime == null, () {
                              setModalState(() => _maxCookTime = null);
                              setState(() {});
                            }),
                            _buildModalFilterChip('≤ 20 mins', _maxCookTime == 20, () {
                              setModalState(() => _maxCookTime = 20);
                              setState(() {});
                            }),
                            _buildModalFilterChip('≤ 30 mins', _maxCookTime == 30, () {
                              setModalState(() => _maxCookTime = 30);
                              setState(() {});
                            }),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // Section 4: Calories
                        const Text('Calorie Intake', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.slate900)),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          children: [
                            _buildModalFilterChip('Any Calories', _maxCalories == null, () {
                              setModalState(() => _maxCalories = null);
                              setState(() {});
                            }),
                            _buildModalFilterChip('Light (≤ 350 kcal)', _maxCalories == 350, () {
                              setModalState(() => _maxCalories = 350);
                              setState(() {});
                            }),
                            _buildModalFilterChip('Moderate (≤ 500 kcal)', _maxCalories == 500, () {
                              setModalState(() => _maxCalories = 500);
                              setState(() {});
                            }),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // Section 5: Cuisines
                        if (_availableCuisines.isNotEmpty) ...[
                          const Text('Cuisines', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.slate900)),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _availableCuisines.map((cuisine) {
                              final isSelected = _selectedCuisines.contains(cuisine);
                              return _buildModalFilterChip(cuisine, isSelected, () {
                                setModalState(() {
                                  if (isSelected) {
                                    _selectedCuisines.remove(cuisine);
                                  } else {
                                    _selectedCuisines.add(cuisine);
                                  }
                                });
                                setState(() {});
                              });
                            }).toList(),
                          ),
                          const SizedBox(height: 20),
                        ],
                      ],
                    ),
                  ),

                  // Apply Button
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      border: Border(top: BorderSide(color: AppColors.slate200)),
                    ),
                    child: EbicButton(
                      label: 'Show ${_filteredDishes.length} Recipes',
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildModalFilterChip(String label, bool isSelected, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        highlightColor: Colors.transparent,
        focusColor: Colors.transparent,
        splashColor: AppColors.primary.withOpacity(0.12),
        child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primarySubtle : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.slate300,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? AppColors.primaryDark : AppColors.slate800,
          ),
        ),
      ),
    ),
  );
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.slate50,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: AppColors.slate900,
        iconTheme: const IconThemeData(color: AppColors.slate900),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              "Chef's Menu",
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.slate900),
            ),
            Text(
              'Certified Live Home Cooking in Your Kitchen',
              style: TextStyle(fontSize: 11, color: AppColors.slate500, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              _isSearchExpanded ? Icons.search_off_rounded : Icons.search_rounded,
              color: (_isSearchExpanded || _searchQuery.isNotEmpty) ? AppColors.primary : AppColors.slate700,
            ),
            tooltip: 'Search Dishes',
            onPressed: () {
              setState(() {
                _isSearchExpanded = !_isSearchExpanded;
                if (!_isSearchExpanded && _searchQuery.isNotEmpty) {
                  _searchController.clear();
                  _onSearchChanged('');
                }
              });
            },
          ),
          IconButton(
            icon: Badge(
              isLabelVisible: _activeFilterCount > 0,
              label: Text('$_activeFilterCount'),
              backgroundColor: AppColors.primary,
              child: Icon(
                Icons.tune_rounded,
                color: _activeFilterCount > 0 ? AppColors.primary : AppColors.slate700,
              ),
            ),
            tooltip: 'Filters',
            onPressed: _showFilterBottomSheet,
          ),
          if (!_cart.isEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(
                child: Badge(
                  label: Text('${_cart.itemCount}'),
                  backgroundColor: AppColors.primary,
                  child: InkWell(
                    onTap: _proceedToReview,
                    borderRadius: BorderRadius.circular(20),
                    highlightColor: Colors.transparent,
                    focusColor: Colors.transparent,
                    splashColor: AppColors.primary.withOpacity(0.12),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: AppColors.primarySubtle,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.restaurant_rounded, color: AppColors.primary, size: 20),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                // Top Filter & Control Panel Container
                Container(
                  color: Colors.white,
                  child: Column(
                    children: [
                      // Step 1: Member Selector (Section 8)
                      if (_members.isNotEmpty) _buildMemberSelector(),

                      // Step 2: Meal Occasion Segmented Switcher (Breakfast, Lunch, Dinner, B+L, L+D)
                      _buildOccasionSwitcher(),

                      // Step 3: Expandable Search Bar (displayed when search icon clicked)
                      if (_isSearchExpanded || _searchQuery.isNotEmpty) ...[
                        _buildSearchBarWithFilter(),
                        const SizedBox(height: 4),
                      ],

                      // Step 4: Unified Categories & Quick Filters (Single row)
                      _buildUnifiedFilterBar(),

                      const SizedBox(height: 6),
                    ],
                  ),
                ),



                // Dish list header with count & backend indicator
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 6),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${_filteredDishes.length} Recipes Available',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppColors.slate800,
                        ),
                      ),
                      if (_sortBy != 'RECOMMENDED')
                        Text(
                          _sortBy == 'COOK_TIME_ASC'
                              ? '⚡ Fastest First'
                              : _sortBy == 'PROTEIN_DESC'
                                  ? '💪 High Protein'
                                  : '🥗 Lowest Cal',
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                    ],
                  ),
                ),

                // Dish list
                Expanded(
                  child: _isLoading
                      ? const LoadingView(message: "Loading Chef's Menu...")
                      : _filteredDishes.isEmpty
                          ? _buildEmptyState()
                          : ListView.separated(
                              padding: EdgeInsets.fromLTRB(16, 4, 16, _cart.isEmpty ? 24 : 110),
                              itemCount: _filteredDishes.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                final dish = _filteredDishes[index];
                                return _buildDishCard(dish);
                              },
                            ),
                ),
              ],
            ),

            // Floating Bottom Cart Action Bar
            if (!_cart.isEmpty)
              Positioned(
                left: 16,
                right: 16,
                bottom: 14,
                child: _buildFloatingCartBar(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMemberSelector() {
    return Container(
      height: 46,
      margin: const EdgeInsets.only(top: 6),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _members.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          if (index == _members.length) {
            return Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(24),
                onTap: _showAddMemberModalSheet,
                highlightColor: Colors.transparent,
                focusColor: Colors.transparent,
                splashColor: AppColors.primary.withOpacity(0.12),
                child: Ink(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.slate100,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppColors.slate300),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.person_add_alt_1_rounded, size: 15, color: AppColors.primary),
                      SizedBox(width: 5),
                      Text(
                        'Add Member',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          final member = _members[index];
          final isSelected = _selectedMember?.id == member.id;
          final memberDishes = (_cart.itemsGroupedByMember[member.id] ?? [])
              .fold<int>(0, (sum, i) => sum + i.servings);

          return Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(24),
              onTap: () {
                setState(() => _selectedMember = member);
                _cart.setMember(member.id, member.name);
                _validateSelection();
              },
              highlightColor: Colors.transparent,
              focusColor: Colors.transparent,
              splashColor: AppColors.primary.withOpacity(0.12),
              child: Ink(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primarySubtle : Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: isSelected ? AppColors.primary : AppColors.slate300,
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: 12,
                      backgroundColor: isSelected ? AppColors.primary : AppColors.slate400,
                      child: Text(
                        member.name.isNotEmpty ? member.name[0].toUpperCase() : 'M',
                        style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      memberDishes > 0 ? '${member.name} ($memberDishes)' : member.name,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                        color: isSelected ? AppColors.primaryDark : AppColors.slate800,
                      ),
                    ),
                    if (member.isCoveredByHealthPass) ...[
                      const SizedBox(width: 4),
                      const Icon(Icons.verified_rounded, size: 13, color: AppColors.primary),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showAddMemberModalSheet() {
    final nameCtrl = TextEditingController();
    String selectedRelation = 'SPOUSE';
    String selectedDiet = 'Vegetarian';

    final relations = [
      {'key': 'SPOUSE', 'label': 'Spouse'},
      {'key': 'CHILD', 'label': 'Child'},
      {'key': 'MOTHER', 'label': 'Mother'},
      {'key': 'FATHER', 'label': 'Father'},
      {'key': 'SIBLING', 'label': 'Sibling'},
      {'key': 'OTHER', 'label': 'Other'},
    ];

    final diets = ['Vegetarian', 'Non-Vegetarian', 'Vegan'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                top: 16,
                left: 20,
                right: 20,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: AppColors.slate300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Add Family Member',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: AppColors.slate900),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: AppColors.slate600),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: nameCtrl,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: 'Member Name',
                      hintText: 'e.g. Priya, Aarav, Mom',
                      filled: true,
                      fillColor: AppColors.slate50,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppColors.slate300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppColors.slate300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppColors.primary, width: 1.8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text('Relationship', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppColors.slate800)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    children: relations.map((r) {
                      final isSel = selectedRelation == r['key'];
                      return ChoiceChip(
                        label: Text(r['label']!),
                        selected: isSel,
                        selectedColor: AppColors.primarySubtle,
                        side: BorderSide(color: isSel ? AppColors.primary : AppColors.slate300),
                        labelStyle: TextStyle(
                          color: isSel ? AppColors.primaryDark : AppColors.slate800,
                          fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                          fontSize: 12,
                        ),
                        onSelected: (sel) {
                          if (sel) setSheetState(() => selectedRelation = r['key']!);
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),
                  const Text('Dietary Preference', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppColors.slate800)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    children: diets.map((d) {
                      final isSel = selectedDiet == d;
                      return ChoiceChip(
                        label: Text(d),
                        selected: isSel,
                        selectedColor: AppColors.primarySubtle,
                        side: BorderSide(color: isSel ? AppColors.primary : AppColors.slate300),
                        labelStyle: TextStyle(
                          color: isSel ? AppColors.primaryDark : AppColors.slate800,
                          fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                          fontSize: 12,
                        ),
                        onSelected: (sel) {
                          if (sel) setSheetState(() => selectedDiet = d);
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton(
                      onPressed: () {
                        final name = nameCtrl.text.trim();
                        if (name.isEmpty) return;

                        final newMember = HouseholdMemberModel(
                          id: 'member_${DateTime.now().millisecondsSinceEpoch}',
                          name: name,
                          relationship: selectedRelation,
                          dietaryPreferences: [selectedDiet],
                          isCoveredByHealthPass: true,
                        );

                        setState(() {
                          _members.add(newMember);
                          _selectedMember = newMember;
                          _cart.setMember(newMember.id, newMember.name);
                        });

                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('$name added! You can now select dishes for $name.'),
                            backgroundColor: AppColors.primary,
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Save & Select Dishes for Member', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildOccasionSwitcher() {
    const occasions = [
      {'key': 'BREAKFAST', 'label': 'Breakfast', 'icon': Icons.wb_twilight_rounded},
      {'key': 'LUNCH', 'label': 'Lunch', 'icon': Icons.wb_sunny_rounded},
      {'key': 'DINNER', 'label': 'Dinner', 'icon': Icons.nightlight_round},
      {'key': 'BREAKFAST_LUNCH', 'label': 'B + L', 'icon': Icons.set_meal_rounded},
      {'key': 'LUNCH_DINNER', 'label': 'L + D', 'icon': Icons.soup_kitchen_rounded},
    ];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.slate100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: occasions.map((occ) {
            final isSelected = _cart.selectedOccasion == occ['key'];
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: InkWell(
                borderRadius: BorderRadius.circular(9),
                highlightColor: Colors.transparent,
                focusColor: Colors.transparent,
                splashColor: AppColors.primary.withOpacity(0.12),
                onTap: () {
                  _cart.setOccasion(occ['key'] as String);
                  _loadDishes(showSpinner: true);
                  _validateSelection();
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.white : Colors.transparent,
                    borderRadius: BorderRadius.circular(9),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            )
                          ]
                        : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        occ['icon'] as IconData,
                        size: 14,
                        color: isSelected ? AppColors.primary : AppColors.slate600,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        occ['label'] as String,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                          color: isSelected ? AppColors.primaryDark : AppColors.slate700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildSearchBarWithFilter() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.slate100,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primary.withOpacity(0.35)),
              ),
              child: TextField(
                controller: _searchController,
                autofocus: _isSearchExpanded && _searchQuery.isEmpty,
                style: const TextStyle(fontSize: 13, color: AppColors.slate900, fontWeight: FontWeight.w500),
                onChanged: _onSearchChanged,
                decoration: InputDecoration(
                  hintText: 'Search dishes, cuisines, ingredients...',
                  hintStyle: const TextStyle(fontSize: 12.5, color: AppColors.slate500),
                  prefixIcon: const Icon(Icons.search_rounded, size: 20, color: AppColors.primary),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18, color: AppColors.slate600),
                          onPressed: () {
                            _searchController.clear();
                            _onSearchChanged('');
                          },
                        )
                      : null,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  border: InputBorder.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 20, color: AppColors.slate600),
            tooltip: 'Close search',
            onPressed: () {
              setState(() {
                _isSearchExpanded = false;
                _searchController.clear();
                _onSearchChanged('');
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildUnifiedFilterBar() {
    final filters = [
      {'key': 'ALL', 'label': 'All Dishes', 'isCat': true},
      {'key': 'VEG', 'label': '🥦 Pure Veg', 'isCat': false},
      {'key': 'NON_VEG', 'label': '🍗 Non-Veg', 'isCat': false},
      {'key': 'HIGH_PROTEIN', 'label': '💪 High Protein', 'isCat': false},
      {'key': 'HIGH_FIBRE', 'label': '🌾 High Fibre', 'isCat': true},
      {'key': 'BALANCED', 'label': '🥗 Balanced Meals', 'isCat': true},
      {'key': 'QUICK', 'label': '⚡ Quick (<20m)', 'isCat': false},
      {'key': 'LOW_CAL', 'label': '🥗 Low Calorie', 'isCat': false},
      ..._categories.map((c) => {
            'key': c['code']?.toString() ?? '',
            'label': c['name']?.toString() ?? '',
            'isCat': true,
          }),
    ];

    return Container(
      height: 38,
      margin: const EdgeInsets.only(top: 6, bottom: 4),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (context, index) {
          final item = filters[index];
          final key = item['key'] as String;
          final label = item['label'] as String;
          final isCat = item['isCat'] == true;

          final isSelected = isCat ? (_selectedCategory == key) : (_quickFilter == key);

          return InkWell(
            borderRadius: BorderRadius.circular(20),
            highlightColor: Colors.transparent,
            focusColor: Colors.transparent,
            splashColor: AppColors.primary.withOpacity(0.12),
            onTap: () {
              setState(() {
                if (key == 'ALL') {
                  _quickFilter = 'ALL';
                  _selectedCategory = 'ALL';
                  _loadDishes(showSpinner: true);
                } else if (isCat) {
                  _quickFilter = 'ALL';
                  _selectedCategory = key;
                  _loadDishes(showSpinner: true);
                } else {
                  _selectedCategory = 'ALL';
                  _quickFilter = (_quickFilter == key) ? 'ALL' : key;
                }
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? AppColors.primary : AppColors.slate300,
                  width: isSelected ? 1.4 : 1,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.2),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        )
                      ]
                    : null,
              ),
              child: Center(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected ? Colors.white : AppColors.slate800,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDishCard(DishModel dish) {
    final activeMemberId = _selectedMember?.id ?? 'self';
    final activeMemberName = _selectedMember?.name ?? 'Self';
    final count = _cart.getServingsForMember(activeMemberId, dish.id);

    return EbicCard(
      padding: const EdgeInsets.all(14),
      onTap: null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => DishDetailScreen(dish: dish)),
              );
            },
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              // Dish Culinary Icon Box
              Stack(
                children: [
                  Container(
                    width: 86,
                    height: 86,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: dish.isVegetarian
                            ? [const Color(0xFFE8F5E9), const Color(0xFFC8E6C9)]
                            : [const Color(0xFFFFF3E0), const Color(0xFFFFE0B2)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Center(
                      child: Icon(
                        dish.isVegetarian ? Icons.eco_rounded : Icons.restaurant_rounded,
                        color: dish.isVegetarian ? AppColors.primary : AppColors.accent,
                        size: 38,
                      ),
                    ),
                  ),
                  // Veg / Non-Veg Indicator
                  Positioned(
                    top: 6,
                    left: 6,
                    child: _buildVegIndicator(dish.isVegetarian),
                  ),
                ],
              ),
              const SizedBox(width: 14),

              // Title, Description & Tags
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (dish.cuisine != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.slate100,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              dish.cuisine!,
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.slate700),
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primarySubtle,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            dish.category.replaceAll('_', ' '),
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primaryDark),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),

                    Text(
                      dish.name,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.slate900),
                    ),
                    if (dish.description != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        dish.description!,
                        style: const TextStyle(color: AppColors.slate600, fontSize: 12, height: 1.3),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),

          const SizedBox(height: 12),
          const Divider(height: 1, color: AppColors.slate200),
          const SizedBox(height: 10),

          // Bottom metrics & Add/Quantity Stepper
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Macros Pill
              Expanded(
                child: Wrap(
                  spacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.timer_outlined, size: 14, color: AppColors.slate600),
                        const SizedBox(width: 3),
                        Text(
                          '~${dish.baseCookTimeMin}m',
                          style: const TextStyle(fontSize: 12, color: AppColors.slate800, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    if (dish.nutrition != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF7ED),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: const Color(0xFFFFEDD5)),
                        ),
                        child: Text(
                          '${dish.nutrition!.calories.toInt()} kcal',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFC2410C)),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: const Color(0xFFDBEAFE)),
                        ),
                        child: Text(
                          '${dish.nutrition!.proteinG.toInt()}g protein',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1D4ED8)),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Quantity Stepper or Clean Modern Add Button (Borderless)
              count == 0
                  ? Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => _cart.addDishForMember(dish, activeMemberId, activeMemberName, servings: 1),
                        borderRadius: BorderRadius.circular(8),
                        highlightColor: Colors.transparent,
                        focusColor: Colors.transparent,
                        splashColor: Colors.white24,
                        child: Ink(
                          height: 32,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'ADD',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12,
                                  color: Colors.white,
                                  letterSpacing: 0.6,
                                ),
                              ),
                              SizedBox(width: 4),
                              Icon(Icons.add_rounded, size: 16, color: Colors.white),
                            ],
                          ),
                        ),
                      ),
                    )
                  : Container(
                      height: 32,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => _cart.decrementDishForMember(dish, activeMemberId),
                              borderRadius: const BorderRadius.horizontal(left: Radius.circular(8)),
                              highlightColor: Colors.transparent,
                              focusColor: Colors.transparent,
                              splashColor: Colors.white24,
                              child: const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 7, vertical: 6),
                                child: Icon(Icons.remove, size: 15, color: Colors.white),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Text(
                              '$count',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 12.5),
                            ),
                          ),
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => _cart.incrementDishForMember(dish, activeMemberId, activeMemberName),
                              borderRadius: const BorderRadius.horizontal(right: Radius.circular(8)),
                              highlightColor: Colors.transparent,
                              focusColor: Colors.transparent,
                              splashColor: Colors.white24,
                              child: const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 7, vertical: 6),
                                child: Icon(Icons.add, size: 15, color: Colors.white),
                              ),
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

  Widget _buildVegIndicator(bool isVeg) {
    return Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(
          color: isVeg ? const Color(0xFF388E3C) : const Color(0xFFD32F2F),
          width: 1.5,
        ),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Center(
        child: Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: isVeg ? const Color(0xFF388E3C) : const Color(0xFFD32F2F),
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingCartBar() {
    final distinctCount = _cart.distinctDishCount;
    final totalServings = _cart.itemCount;
    final estCookTime = 25 + (distinctCount - 1) * 8;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.slate900,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.28),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.restaurant_rounded, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$distinctCount dishes ($totalServings servings)',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Colors.white),
                ),
                Text(
                  '~$estCookTime mins est. live cooking',
                  style: const TextStyle(fontSize: 11, color: Colors.white70),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            height: 38,
            child: ElevatedButton.icon(
              onPressed: _proceedToReview,
              icon: const Text('Review Order', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
              label: const Icon(Icons.arrow_forward_rounded, size: 16),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.slate100,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.search_off_rounded, size: 48, color: AppColors.slate500),
            ),
            const SizedBox(height: 16),
            const Text(
              'No matching recipes found',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.slate800),
            ),
            const SizedBox(height: 6),
            const Text(
              'Try adjusting your dietary filters or search keywords.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.slate600, fontSize: 12),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () {
                _searchController.clear();
                setState(() {
                  _searchQuery = '';
                  _quickFilter = 'ALL';
                  _selectedCategory = 'ALL';
                  _dietaryFilter = 'ALL';
                  _selectedCuisines.clear();
                  _maxCookTime = null;
                  _maxCalories = null;
                });
                _loadDishes(showSpinner: true);
              },
              child: const Text('Clear All Filters'),
            ),
          ],
        ),
      ),
    );
  }
}
