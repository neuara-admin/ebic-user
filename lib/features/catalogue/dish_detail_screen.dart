import 'package:flutter/material.dart';
import '../../core/auth/session_manager.dart';
import '../../core/routing/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/models/dish_model.dart';
import '../../shared/widgets/ebic_button.dart';
import '../../shared/widgets/ebic_dish_image.dart';
import '../../shared/widgets/dish_video_modal.dart';
import 'cart_service.dart';

class DishDetailScreen extends StatefulWidget {
  final DishModel dish;

  const DishDetailScreen({super.key, required this.dish});

  @override
  State<DishDetailScreen> createState() => _DishDetailScreenState();
}

class _DishDetailScreenState extends State<DishDetailScreen> {
  int _servings = 1;
  int _currentImageIndex = 0;
  final PageController _pageController = PageController();
  final Set<String> _checkedIngredients = {};

  @override
  void initState() {
    super.initState();
    _servings = widget.dish.defaultServings > 0 ? widget.dish.defaultServings : 1;
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _openVideo() {
    final videoUrl = widget.dish.videoUrl ??
        'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4';
    DishVideoModal.show(context, videoUrl: videoUrl, title: widget.dish.name);
  }

  void _toggleIngredientChecked(String ingredientId) {
    setState(() {
      if (_checkedIngredients.contains(ingredientId)) {
        _checkedIngredients.remove(ingredientId);
      } else {
        _checkedIngredients.add(ingredientId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final dish = widget.dish;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final totalCookTime =
        dish.baseCookTimeMin + (_servings - 1) * dish.perServingIncMin;

    final allImages = dish.allImages;

    return Scaffold(
      backgroundColor: isDark ? AppColors.slate950 : const Color(0xFFF8FAFC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: isDark ? AppColors.slate900 : Colors.white,
        foregroundColor: isDark ? Colors.white : AppColors.slate900,
        title: Text(
          dish.name,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined, size: 20),
            tooltip: 'Share Dish',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Sharing ${dish.name} recipe link...'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Gallery Carousel Showcase & Video Button
                    _buildImageGallery(allImages, totalCookTime, isDark),
                    const SizedBox(height: 14),

                    // 2. Video Preview Banner CTA
                    _buildVideoCtaBanner(isDark),
                    const SizedBox(height: 14),

                    // 3. Category, Cuisine, Diet & Health Badges
                    _buildDietaryPills(isDark),
                    const SizedBox(height: 12),

                    // 4. Dish Title & Description
                    Text(
                      dish.name,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : AppColors.slate900,
                        letterSpacing: -0.3,
                      ),
                    ),
                    if (dish.description != null &&
                        dish.description!.trim().isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        dish.description!,
                        style: TextStyle(
                          fontSize: 13.5,
                          color: isDark
                              ? AppColors.slate400
                              : AppColors.slate600,
                          height: 1.45,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),

                    // 5. Portions Calculator & Live Scaler Control
                    _buildPortionCalculatorCard(isDark, totalCookTime),
                    const SizedBox(height: 16),

                    // 6. Nutritional Profile Card (with Portion Scaling)
                    if (dish.nutrition != null) ...[
                      _buildNutritionalProfile(isDark),
                      const SizedBox(height: 16),
                    ],

                    // 7. Allergens Advisory (if any)
                    if (dish.allergens.isNotEmpty) ...[
                      _buildAllergenBanner(),
                      const SizedBox(height: 16),
                    ],

                    // 8. Pantry Ingredients Required (Interactive Checklist)
                    if (dish.ingredients.isNotEmpty) ...[
                      _buildIngredientsChecklist(isDark),
                      const SizedBox(height: 16),
                    ],

                    // 9. Live Cooking In-Kitchen Hygiene Assurance
                    _buildHygieneAssuranceBanner(isDark),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),

            // 11. Bottom Servings & Add Action Bar
            _buildBottomActionBar(dish, isDark),
          ],
        ),
      ),
    );
  }

  // 1. Gallery Carousel
  Widget _buildImageGallery(List<String> images, int totalCookTime, bool isDark) {
    if (images.isEmpty) {
      return EBICDishImage(
        imageUrl: widget.dish.imageUrl,
        width: double.infinity,
        height: 240,
        borderRadius: 20,
        isVegetarian: widget.dish.isVegetarian,
        showVegIndicator: true,
        fit: BoxFit.cover,
      );
    }

    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              SizedBox(
                height: 240,
                width: double.infinity,
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: images.length,
                  onPageChanged: (i) => setState(() => _currentImageIndex = i),
                  itemBuilder: (context, idx) {
                    return EBICDishImage(
                      imageUrl: images[idx],
                      width: double.infinity,
                      height: 240,
                      borderRadius: 0,
                      isVegetarian: widget.dish.isVegetarian,
                      showVegIndicator: idx == 0,
                      fit: BoxFit.cover,
                    );
                  },
                ),
              ),

              // Gradient Overlay at bottom
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 60,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withOpacity(0.6),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),

              // Floating Cook Time Badge
              Positioned(
                bottom: 12,
                left: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.75),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white24, width: 0.5),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.timer_outlined, size: 14, color: Colors.white),
                      const SizedBox(width: 4),
                      Text(
                        '~$totalCookTime mins cook time',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Gallery Counter (e.g. 1/3)
              if (images.length > 1)
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.65),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${_currentImageIndex + 1}/${images.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

              // Veg/Non-Veg Icon Top Left
              Positioned(
                top: 12,
                left: 12,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.circle,
                    size: 14,
                    color: widget.dish.isVegetarian
                        ? const Color(0xFF16A34A)
                        : const Color(0xFFDC2626),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Thumbnail Row if more than 1 image
        if (images.length > 1) ...[
          const SizedBox(height: 8),
          SizedBox(
            height: 52,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: images.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, idx) {
                final isSelected = _currentImageIndex == idx;
                return GestureDetector(
                  onTap: () {
                    _pageController.animateToPage(
                      idx,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  },
                  child: Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected ? AppColors.primary : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        images[idx],
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: AppColors.slate200,
                          child: const Icon(Icons.restaurant, size: 18),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }

  // 2. Video Preview Banner
  Widget _buildVideoCtaBanner(bool isDark) {
    return InkWell(
      onTap: _openVideo,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Watch Chef Preparation Video',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'See how our certified chef prepares and presents this dish',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white70, size: 14),
          ],
        ),
      ),
    );
  }

  // 3. Dietary Pills (Modern Pill Tag Design)
  Widget _buildDietaryPills(bool isDark) {
    final dish = widget.dish;
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: [
        _buildSleekTag(
          label: dish.isVegetarian ? 'Vegetarian' : 'Non-Veg',
          icon: dish.isVegetarian ? Icons.eco_rounded : Icons.restaurant_rounded,
          bgColor: dish.isVegetarian ? const Color(0xFFECFDF5) : const Color(0xFFFFF1F2),
          borderColor: dish.isVegetarian ? const Color(0xFFA7F3D0) : const Color(0xFFFECDD3),
          textColor: dish.isVegetarian ? const Color(0xFF047857) : const Color(0xFF9F1239),
          iconColor: dish.isVegetarian ? const Color(0xFF10B981) : const Color(0xFFE11D48),
        ),
        if (dish.cuisine != null)
          _buildSleekTag(
            label: dish.cuisine!,
            icon: Icons.public_rounded,
            bgColor: isDark ? AppColors.slate800 : const Color(0xFFF1F5F9),
            borderColor: isDark ? AppColors.slate700 : const Color(0xFFE2E8F0),
            textColor: isDark ? AppColors.slate200 : AppColors.slate700,
            iconColor: isDark ? AppColors.slate400 : AppColors.slate500,
          ),
        _buildSleekTag(
          label: dish.category.replaceAll('_', ' '),
          icon: Icons.local_fire_department_rounded,
          bgColor: const Color(0xFFFFFBEB),
          borderColor: const Color(0xFFFDE68A),
          textColor: const Color(0xFF92400E),
          iconColor: const Color(0xFFF59E0B),
        ),
        ...dish.dietaryTags.map((tag) {
          final t = tag.toUpperCase();
          if (t.contains('PROTEIN')) {
            return _buildSleekTag(
              label: tag,
              icon: Icons.fitness_center_rounded,
              bgColor: const Color(0xFFEFF6FF),
              borderColor: const Color(0xFFBFDBFE),
              textColor: const Color(0xFF1D4ED8),
              iconColor: const Color(0xFF3B82F6),
            );
          } else if (t.contains('CARB') || t.contains('KETO')) {
            return _buildSleekTag(
              label: tag,
              icon: Icons.bolt_rounded,
              bgColor: const Color(0xFFF5F3FF),
              borderColor: const Color(0xFFDDD6FE),
              textColor: const Color(0xFF6D28D9),
              iconColor: const Color(0xFF8B5CF6),
            );
          } else if (t.contains('GLUTEN') || t.contains('DAIRY') || t.contains('VEGAN')) {
            return _buildSleekTag(
              label: tag,
              icon: Icons.health_and_safety_rounded,
              bgColor: const Color(0xFFF0FDFA),
              borderColor: const Color(0xFF99F6E4),
              textColor: const Color(0xFF0F766E),
              iconColor: const Color(0xFF14B8A6),
            );
          }
          return _buildSleekTag(
            label: tag,
            icon: Icons.check_circle_outline_rounded,
            bgColor: isDark ? AppColors.slate800 : const Color(0xFFF8FAFC),
            borderColor: isDark ? AppColors.slate700 : const Color(0xFFE2E8F0),
            textColor: isDark ? AppColors.slate300 : AppColors.slate600,
            iconColor: isDark ? AppColors.slate400 : AppColors.slate500,
          );
        }),
      ],
    );
  }

  Widget _buildSleekTag({
    required String label,
    required IconData icon,
    required Color bgColor,
    required Color borderColor,
    required Color textColor,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: iconColor),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: textColor,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  // 5. Portions Calculator Card
  Widget _buildPortionCalculatorCard(bool isDark, int totalCookTime) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.slate900 : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppColors.slate800 : AppColors.slate200),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Portion Scaling',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : AppColors.slate900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Ingredients scale dynamically with portions',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? AppColors.slate400 : AppColors.slate500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Interactive Stepper
              Container(
                decoration: BoxDecoration(
                  color: AppColors.primarySubtle,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InkWell(
                      onTap: () {
                        if (_servings > 1) setState(() => _servings--);
                      },
                      borderRadius: const BorderRadius.horizontal(left: Radius.circular(9)),
                      child: Container(
                        width: 32,
                        height: 32,
                        alignment: Alignment.center,
                        child: const Icon(Icons.remove, size: 16, color: AppColors.primaryDark),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        '$_servings ${_servings == 1 ? "Portion" : "Portions"}',
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryDark,
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: () {
                        if (_servings < 12) setState(() => _servings++);
                      },
                      borderRadius: const BorderRadius.horizontal(right: Radius.circular(9)),
                      child: Container(
                        width: 32,
                        height: 32,
                        alignment: Alignment.center,
                        child: const Icon(Icons.add, size: 16, color: AppColors.primaryDark),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isDark ? AppColors.slate800.withOpacity(0.5) : AppColors.slate50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded, size: 14, color: AppColors.slate500),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'For $_servings ${_servings == 1 ? "person" : "people"}: ~$totalCookTime mins live cooking required.',
                    style: const TextStyle(fontSize: 11, color: AppColors.slate600),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 6. Nutritional Profile Card
  Widget _buildNutritionalProfile(bool isDark) {
    final n = widget.dish.nutrition!;
    final totalCalories = (n.calories * _servings).toInt();
    final totalProtein = (n.proteinG * _servings).toInt();
    final totalCarbs = (n.carbsG * _servings).toInt();
    final totalFat = (n.fatG * _servings).toInt();
    final totalFiber = (n.fiberG * _servings).toInt();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Nutritional Profile',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : AppColors.slate900,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.primarySubtle,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                _servings > 1 ? 'Total for $_servings Portions' : 'Per 1 Portion',
                style: const TextStyle(
                  fontSize: 10.5,
                  color: AppColors.primaryDark,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _buildMacroTile(
              'Calories',
              '$totalCalories',
              'kcal',
              const Color(0xFFF97316),
              Icons.local_fire_department_rounded,
              isDark,
            ),
            const SizedBox(width: 8),
            _buildMacroTile(
              'Protein',
              '$totalProtein',
              'g',
              const Color(0xFF3B82F6),
              Icons.fitness_center_rounded,
              isDark,
            ),
            const SizedBox(width: 8),
            _buildMacroTile(
              'Carbs',
              '$totalCarbs',
              'g',
              const Color(0xFF10B981),
              Icons.bolt_rounded,
              isDark,
            ),
            const SizedBox(width: 8),
            _buildMacroTile(
              'Fat',
              '$totalFat',
              'g',
              const Color(0xFFEC4899),
              Icons.water_drop_rounded,
              isDark,
            ),
          ],
        ),
        if (totalFiber > 0) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isDark ? AppColors.slate900 : Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: isDark ? AppColors.slate800 : AppColors.slate200),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Dietary Fiber',
                  style: TextStyle(fontSize: 11.5, color: AppColors.slate600),
                ),
                Text(
                  '$totalFiber g',
                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildMacroTile(
    String label,
    String value,
    String unit,
    Color color,
    IconData icon,
    bool isDark,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(isDark ? 0.15 : 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 16,
                color: isDark ? Colors.white : color,
              ),
            ),
            Text(
              unit,
              style: TextStyle(
                fontSize: 10,
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10.5,
                color: isDark ? AppColors.slate400 : AppColors.slate600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 7. Allergen Warning Banner
  Widget _buildAllergenBanner() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded, color: Color(0xFFD97706), size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Allergen Advisory',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF92400E),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Contains: ${widget.dish.allergens.join(", ")}',
                  style: const TextStyle(fontSize: 11.5, color: Color(0xFFB45309)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 8. Pantry Ingredients Checklist
  Widget _buildIngredientsChecklist(bool isDark) {
    final ingredients = widget.dish.ingredients;
    final readyCount = _checkedIngredients.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Pantry Checklist (${ingredients.length} items)',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : AppColors.slate900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Tick off ingredients you have in your kitchen',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: isDark ? AppColors.slate400 : AppColors.slate500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: readyCount == ingredients.length
                    ? AppColors.successLight
                    : AppColors.primarySubtle,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '$readyCount/${ingredients.length} Ready',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: readyCount == ingredients.length
                      ? AppColors.successDark
                      : AppColors.primaryDark,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.slate900 : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: isDark ? AppColors.slate800 : AppColors.slate200),
          ),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: ingredients.length,
            separatorBuilder: (_, __) => Divider(
              height: 1,
              color: isDark ? AppColors.slate800 : AppColors.slate100,
            ),
            itemBuilder: (context, index) {
              final ing = ingredients[index];
              final isLinear = ing.scalingType == 'LINEAR';
              final scaledQty = isLinear ? (ing.quantity * _servings) : ing.quantity;
              final displayQty = scaledQty % 1 == 0
                  ? scaledQty.toInt().toString()
                  : scaledQty.toStringAsFixed(1);
              final isChecked = _checkedIngredients.contains(ing.ingredientId);

              return InkWell(
                onTap: () => _toggleIngredientChecked(ing.ingredientId),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(
                    children: [
                      Icon(
                        isChecked
                            ? Icons.check_circle_rounded
                            : Icons.radio_button_unchecked_rounded,
                        size: 20,
                        color: isChecked ? AppColors.primary : AppColors.slate400,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              ing.name,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                decoration: isChecked ? TextDecoration.lineThrough : null,
                                color: isChecked
                                    ? AppColors.slate400
                                    : (isDark ? Colors.white : AppColors.slate800),
                              ),
                            ),
                            const SizedBox(height: 1),
                            Text(
                              isLinear
                                  ? 'Scales with portions'
                                  : 'Fixed spice / condiment',
                              style: const TextStyle(
                                fontSize: 10,
                                color: AppColors.slate400,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '$displayQty ${ing.unit}',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppColors.slate300 : AppColors.slate700,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }



  // 10. Live Cooking In-Kitchen Hygiene Assurance
  Widget _buildHygieneAssuranceBanner(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF06281E) : const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark
              ? const Color(0xFF047857).withOpacity(0.4)
              : const Color(0xFFBBF7D0),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.14),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.soup_kitchen_rounded,
              color: AppColors.primary,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Live In-Kitchen Preparation',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF166534),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Prepared fresh in your utensils by a certified chef. Utensils and kitchen sanitized after cooking.',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? AppColors.slate400 : const Color(0xFF15803D),
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 11. Bottom Servings & Add Action Bar
  Widget _buildBottomActionBar(DishModel dish, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.slate900 : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
        border: Border(
          top: BorderSide(
            color: isDark ? AppColors.slate800 : AppColors.slate200,
          ),
        ),
      ),
      child: Row(
        children: [
          // Portions display
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? AppColors.slate800 : AppColors.slate50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isDark ? AppColors.slate700 : AppColors.slate300,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$_servings',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: isDark ? Colors.white : AppColors.slate900,
                  ),
                ),
                Text(
                  _servings == 1 ? 'Portion' : 'Portions',
                  style: TextStyle(
                    fontSize: 10,
                    color: isDark ? AppColors.slate400 : AppColors.slate600,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // Add to Booking Button
          Expanded(
            child: EbicButton(
              label: SessionManager().isAuthenticated
                  ? 'Add to Chef Booking'
                  : 'Sign in to Add',
              icon: SessionManager().isAuthenticated
                  ? Icons.add_rounded
                  : Icons.login_rounded,
              onPressed: () {
                if (!SessionManager().isAuthenticated) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Please sign in to add dishes to your chef booking.',
                      ),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                  Navigator.pushNamed(context, AppRoutes.login);
                  return;
                }
                CartService().addDish(dish, servings: _servings);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Added ${dish.name} ($_servings ${_servings == 1 ? "portion" : "portions"}) to booking.',
                    ),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
