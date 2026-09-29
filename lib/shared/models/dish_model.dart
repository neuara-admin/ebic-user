class DishModel {
  final String id;
  final String name;
  final String category; // HIGH_PROTEIN, HIGH_FIBRE, BALANCED
  final String? cuisine;
  final String? description;
  final String? imageUrl;
  final List<String> images;
  final String? videoUrl;
  final int baseCookTimeMin;
  final int perServingIncMin;
  final int defaultServings;
  final String? preparationInstructions;
  final List<String> preparationSteps;
  final List<DishIngredientModel> ingredients;
  final List<String> dietaryTags;
  final List<String> allergens;
  final DishNutritionModel? nutrition;

  DishModel({
    required this.id,
    required this.name,
    required this.category,
    this.cuisine,
    this.description,
    this.imageUrl,
    this.images = const [],
    this.videoUrl,
    required this.baseCookTimeMin,
    this.perServingIncMin = 0,
    this.defaultServings = 1,
    this.preparationInstructions,
    this.preparationSteps = const [],
    this.ingredients = const [],
    this.dietaryTags = const [],
    this.allergens = const [],
    this.nutrition,
  });

  int get cookTimeMinutes => baseCookTimeMin;

  /// Returns full list of all available images (gallery + primary)
  List<String> get allImages {
    final list = <String>[];
    for (final img in images) {
      if (img.trim().isNotEmpty && !list.contains(img.trim())) {
        list.add(img.trim());
      }
    }
    if (imageUrl != null && imageUrl!.trim().isNotEmpty && !list.contains(imageUrl!.trim())) {
      list.insert(0, imageUrl!.trim());
    }
    return list;
  }

  /// Curator-set Vegetarian/Vegan dietary tags are the only source — the
  /// same rule the backend `diet` filter applies, so the badge and the
  /// Veg/Non-Veg filter always agree.
  bool get isVegetarian => dietaryTags.any((t) {
        final tag = t.trim().toLowerCase();
        return tag == 'vegetarian' || tag == 'vegan';
      });

  bool get isVegan => dietaryTags.any((t) => t.trim().toLowerCase() == 'vegan');
  bool get isHighProtein => (nutrition?.proteinG ?? 0) >= 20 || category == 'HIGH_PROTEIN';
  bool get isLowCalorie => (nutrition?.calories ?? 999) <= 350;
  bool get isQuickPrep => baseCookTimeMin <= 20;

  factory DishModel.fromJson(Map<String, dynamic> json) {
    // Parse dietary tags from tag relation objects or plain strings
    final rawTags = json['dietaryTags'] as List<dynamic>? ?? [];
    final parsedTags = rawTags.map((t) {
      if (t is Map<String, dynamic>) {
        return (t['dietaryTag']?['name'] ?? t['name'] ?? t['code'] ?? '').toString();
      }
      return t.toString();
    }).where((t) => t.isNotEmpty).toList();

    // Parse allergens
    final rawAllergens = json['allergens'] as List<dynamic>? ?? [];
    final parsedAllergens = rawAllergens.map((a) {
      if (a is Map<String, dynamic>) {
        return (a['allergen']?['name'] ?? a['name'] ?? '').toString();
      }
      return a.toString();
    }).where((a) => a.isNotEmpty).toList();

    // Parse gallery images
    final rawImages = json['images'] as List<dynamic>? ?? [];
    final parsedImages = rawImages.map((img) {
      if (img is Map<String, dynamic>) {
        return (img['url'] ?? img['imageUrl'] ?? '').toString();
      }
      return img.toString();
    }).where((url) => url.isNotEmpty).toList();

    // Parse video URL
    final dynamic videoObj = json['video'];
    String? parsedVideoUrl;
    if (videoObj is Map<String, dynamic>) {
      parsedVideoUrl = videoObj['url']?.toString();
    } else if (videoObj is String && videoObj.isNotEmpty) {
      parsedVideoUrl = videoObj;
    }
    parsedVideoUrl ??= json['videoUrl']?.toString() ?? json['preparationVideoUrl']?.toString();

    // Parse preparation steps
    final List<String> parsedSteps = [];
    if (json['preparationSteps'] is List) {
      for (final step in (json['preparationSteps'] as List<dynamic>)) {
        final s = step.toString().trim();
        if (s.isNotEmpty) parsedSteps.add(s);
      }
    } else if (json['preparationInstructions'] != null) {
      final rawInstructions = json['preparationInstructions'].toString();
      final lines = rawInstructions.split(RegExp(r'\r?\n+'));
      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.isNotEmpty) {
          // Remove leading numbers like "1. ", "Step 1: "
          final cleaned = trimmed.replaceFirst(RegExp(r'^(Step\s*\d+[:.]*|\d+[\.\)\-:])\s*'), '').trim();
          if (cleaned.isNotEmpty) parsedSteps.add(cleaned);
        }
      }
    }

    return DishModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      category: json['category'] ?? 'BALANCED',
      cuisine: json['cuisine'],
      description: json['description'],
      imageUrl: json['imageUrl'],
      images: parsedImages,
      videoUrl: parsedVideoUrl,
      baseCookTimeMin: json['baseCookTimeMin'] ?? 25,
      perServingIncMin: json['perServingIncMin'] ?? 0,
      defaultServings: json['defaultServings'] ?? 1,
      preparationInstructions: json['preparationInstructions'],
      preparationSteps: parsedSteps,
      ingredients: (json['ingredients'] as List<dynamic>?)
              ?.map((e) => DishIngredientModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      dietaryTags: parsedTags,
      allergens: parsedAllergens,
      nutrition: json['nutrition'] != null
          ? DishNutritionModel.fromJson(json['nutrition'] as Map<String, dynamic>)
          : null,
    );
  }
}

class DishIngredientModel {
  final String ingredientId;
  final String name;
  final double quantity;
  final String unit;
  final String scalingType; // FIXED or LINEAR
  final String? imageUrl;

  DishIngredientModel({
    required this.ingredientId,
    required this.name,
    required this.quantity,
    required this.unit,
    required this.scalingType,
    this.imageUrl,
  });

  factory DishIngredientModel.fromJson(Map<String, dynamic> json) {
    final ing = json['ingredient'] as Map<String, dynamic>?;
    return DishIngredientModel(
      ingredientId: json['ingredientId'] ?? ing?['id'] ?? '',
      name: ing?['name'] ?? json['name'] ?? 'Ingredient',
      quantity: double.tryParse(json['quantityPerServing']?.toString() ?? json['quantity']?.toString() ?? '1') ?? 1.0,
      unit: ing?['unit'] ?? json['unit'] ?? 'g',
      scalingType: json['scalingType'] ?? 'LINEAR',
      imageUrl: ing?['imageUrl'] ?? json['imageUrl'],
    );
  }
}

class DishNutritionModel {
  final double calories;
  final double proteinG;
  final double carbsG;
  final double fatG;
  final double fiberG;
  final double sodiumMg;

  DishNutritionModel({
    required this.calories,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    this.fiberG = 0.0,
    this.sodiumMg = 0.0,
  });

  factory DishNutritionModel.fromJson(Map<String, dynamic> json) {
    return DishNutritionModel(
      calories: double.tryParse(json['caloriesPerServing']?.toString() ?? json['calories']?.toString() ?? '0') ?? 0.0,
      proteinG: double.tryParse(json['proteinGPerServing']?.toString() ?? json['proteinG']?.toString() ?? '0') ?? 0.0,
      carbsG: double.tryParse(json['carbsGPerServing']?.toString() ?? json['carbsG']?.toString() ?? '0') ?? 0.0,
      fatG: double.tryParse(json['fatGPerServing']?.toString() ?? json['fatG']?.toString() ?? '0') ?? 0.0,
      fiberG: double.tryParse(json['fiberGPerServing']?.toString() ?? json['fiberG']?.toString() ?? json['fibreG']?.toString() ?? '0') ?? 0.0,
      sodiumMg: double.tryParse(json['sodiumMgPerServing']?.toString() ?? json['sodiumMg']?.toString() ?? '0') ?? 0.0,
    );
  }
}
