class DishModel {
  final String id;
  final String name;
  final String category; // HIGH_PROTEIN, HIGH_FIBRE, BALANCED
  final String? cuisine;
  final String? description;
  final String? imageUrl;
  final int baseCookTimeMin;
  final int perServingIncMin;
  final int defaultServings;
  final String? preparationInstructions;
  final List<DishIngredientModel> ingredients;
  final DishNutritionModel? nutrition;

  DishModel({
    required this.id,
    required this.name,
    required this.category,
    this.cuisine,
    this.description,
    this.imageUrl,
    required this.baseCookTimeMin,
    this.perServingIncMin = 0,
    this.defaultServings = 1,
    this.preparationInstructions,
    this.ingredients = const [],
    this.nutrition,
  });

  int get prepTimeMinutes => 12;
  int get cookTimeMinutes => baseCookTimeMin;
  double get basePrice => 249.0;

  factory DishModel.fromJson(Map<String, dynamic> json) {
    return DishModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      category: json['category'] ?? 'BALANCED',
      cuisine: json['cuisine'],
      description: json['description'],
      imageUrl: json['imageUrl'],
      baseCookTimeMin: json['baseCookTimeMin'] ?? 25,
      perServingIncMin: json['perServingIncMin'] ?? 0,
      defaultServings: json['defaultServings'] ?? 1,
      preparationInstructions: json['preparationInstructions'],
      ingredients: (json['ingredients'] as List<dynamic>?)
              ?.map((e) => DishIngredientModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
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

  DishIngredientModel({
    required this.ingredientId,
    required this.name,
    required this.quantity,
    required this.unit,
    required this.scalingType,
  });

  factory DishIngredientModel.fromJson(Map<String, dynamic> json) {
    final ing = json['ingredient'] as Map<String, dynamic>?;
    return DishIngredientModel(
      ingredientId: json['ingredientId'] ?? ing?['id'] ?? '',
      name: ing?['name'] ?? 'Ingredient',
      quantity: double.tryParse(json['quantityPerServing']?.toString() ?? '1') ?? 1.0,
      unit: ing?['unit'] ?? 'g',
      scalingType: json['scalingType'] ?? 'LINEAR',
    );
  }
}

class DishNutritionModel {
  final double calories;
  final double proteinG;
  final double carbsG;
  final double fatG;

  DishNutritionModel({
    required this.calories,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
  });

  factory DishNutritionModel.fromJson(Map<String, dynamic> json) {
    return DishNutritionModel(
      calories: double.tryParse(json['caloriesPerServing']?.toString() ?? '0') ?? 0.0,
      proteinG: double.tryParse(json['proteinGPerServing']?.toString() ?? '0') ?? 0.0,
      carbsG: double.tryParse(json['carbsGPerServing']?.toString() ?? '0') ?? 0.0,
      fatG: double.tryParse(json['fatGPerServing']?.toString() ?? '0') ?? 0.0,
    );
  }
}
