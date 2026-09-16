class NutritionModel {
  final num calories;
  final num proteinG;
  final num carbsG;
  final num fatG;
  final num fibreG;

  NutritionModel({
    required this.calories,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    required this.fibreG,
  });

  factory NutritionModel.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return NutritionModel(calories: 0, proteinG: 0, carbsG: 0, fatG: 0, fibreG: 0);
    }
    return NutritionModel(
      calories: json['calories'] ?? json['energyKcal'] ?? 0,
      proteinG: json['proteinG'] ?? json['protein'] ?? 0,
      carbsG: json['carbsG'] ?? json['carbohydrates'] ?? json['carbs'] ?? 0,
      fatG: json['fatG'] ?? json['fat'] ?? json['fats'] ?? 0,
      fibreG: json['fibreG'] ?? json['fiber'] ?? json['fibre'] ?? 0,
    );
  }
}

class DietitianSummary {
  final String id;
  final String name;
  final String? photoUrl;
  final String? qualification;

  DietitianSummary({
    required this.id,
    required this.name,
    this.photoUrl,
    this.qualification,
  });

  factory DietitianSummary.fromJson(Map<String, dynamic>? json) {
    if (json == null) return DietitianSummary(id: '', name: 'Assigned Dietitian');
    return DietitianSummary(
      id: json['id'] ?? '',
      name: json['name'] ?? 'Assigned Dietitian',
      photoUrl: json['photoUrl'],
      qualification: json['qualification'],
    );
  }
}

class MemberSummary {
  final String id;
  final String name;
  final String relationship;
  final bool isSelf;

  MemberSummary({
    required this.id,
    required this.name,
    required this.relationship,
    this.isSelf = false,
  });

  factory MemberSummary.fromJson(Map<String, dynamic>? json) {
    if (json == null) return MemberSummary(id: '', name: '', relationship: '');
    return MemberSummary(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      relationship: json['relationship'] ?? '',
      isSelf: json['isSelf'] ?? false,
    );
  }
}

class DietPlanGoalModel {
  final String id;
  final String goalType;
  final String title;
  final String? description;
  final int priority;
  final String? targetValue;
  final String? targetUnit;
  final String status;

  DietPlanGoalModel({
    required this.id,
    required this.goalType,
    required this.title,
    this.description,
    this.priority = 1,
    this.targetValue,
    this.targetUnit,
    this.status = 'ACTIVE',
  });

  factory DietPlanGoalModel.fromJson(Map<String, dynamic> json) {
    return DietPlanGoalModel(
      id: json['id'] ?? '',
      goalType: json['goalType'] ?? 'PRIMARY',
      title: json['title'] ?? '',
      description: json['description'],
      priority: json['priority'] ?? 1,
      targetValue: json['targetValue']?.toString(),
      targetUnit: json['targetUnit'],
      status: json['status'] ?? 'ACTIVE',
    );
  }
}

class DietPlanNutritionTargetModel {
  final String nutrient;
  final num? targetValue;
  final num? minimumValue;
  final num? maximumValue;
  final String unit;
  final String period;
  final String? source;

  DietPlanNutritionTargetModel({
    required this.nutrient,
    this.targetValue,
    this.minimumValue,
    this.maximumValue,
    required this.unit,
    this.period = 'DAILY',
    this.source,
  });

  factory DietPlanNutritionTargetModel.fromJson(Map<String, dynamic> json) {
    return DietPlanNutritionTargetModel(
      nutrient: json['nutrient'] ?? '',
      targetValue: json['targetValue'] != null ? num.tryParse(json['targetValue'].toString()) : null,
      minimumValue: json['minimumValue'] != null ? num.tryParse(json['minimumValue'].toString()) : null,
      maximumValue: json['maximumValue'] != null ? num.tryParse(json['maximumValue'].toString()) : null,
      unit: json['unit'] ?? '',
      period: json['period'] ?? 'DAILY',
      source: json['source'],
    );
  }
}

class IngredientItemModel {
  final String name;
  final num quantity;
  final String unit;

  IngredientItemModel({
    required this.name,
    required this.quantity,
    required this.unit,
  });

  factory IngredientItemModel.fromJson(Map<String, dynamic> json) {
    return IngredientItemModel(
      name: json['name'] ?? '',
      quantity: json['quantity'] ?? 0,
      unit: json['unit'] ?? '',
    );
  }
}

class DietPlanDishItemModel {
  final String id;
  final String dishId;
  final String name;
  final String? description;
  final String? imageUrl;
  final num servings;
  final num servingQuantity;
  final String servingUnit;
  final bool isActive;
  final int? preparationTimeMin;
  final int? cookingTimeMin;
  final List<String> dietaryTags;
  final List<String> allergens;
  final List<String> allergenConflicts;
  final List<IngredientItemModel> ingredients;
  final NutritionModel? nutrition;

  DietPlanDishItemModel({
    required this.id,
    required this.dishId,
    required this.name,
    this.description,
    this.imageUrl,
    this.servings = 1,
    this.servingQuantity = 1,
    this.servingUnit = 'serving',
    this.isActive = true,
    this.preparationTimeMin,
    this.cookingTimeMin,
    this.dietaryTags = const [],
    this.allergens = const [],
    this.allergenConflicts = const [],
    this.ingredients = const [],
    this.nutrition,
  });

  factory DietPlanDishItemModel.fromJson(Map<String, dynamic> json) {
    return DietPlanDishItemModel(
      id: json['id'] ?? '',
      dishId: json['dishId'] ?? '',
      name: json['name'] ?? '',
      description: json['description'],
      imageUrl: json['imageUrl'],
      servings: json['servings'] ?? 1,
      servingQuantity: json['servingQuantity'] ?? json['servings'] ?? 1,
      servingUnit: json['servingUnit'] ?? 'serving',
      isActive: json['isActive'] ?? true,
      preparationTimeMin: json['preparationTimeMin'],
      cookingTimeMin: json['cookingTimeMin'],
      dietaryTags: (json['dietaryTags'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      allergens: (json['allergens'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      allergenConflicts: (json['allergenConflicts'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      ingredients: (json['ingredients'] as List<dynamic>?)
              ?.map((e) => IngredientItemModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      nutrition: json['nutrition'] != null ? NutritionModel.fromJson(json['nutrition']) : null,
    );
  }
}

class DietPlanMealModel {
  final String id;
  final String occasion;
  final String? dayOfWeek;
  final String mealType; // NORMAL or CHEAT
  final String title;
  final String? description;
  final String? instructions;
  final String? flexibilityLevel;
  final String? guidance;
  final String? allowedFrequency;
  final String? restrictionNotes;
  final String adherenceStatus; // PLANNED, CONFIRMED_CONSUMED, SKIPPED
  final bool bookChefEligible;
  final NutritionModel? plannedNutrition;
  final List<DietPlanDishItemModel> dishes;
  final String? lastFeedback;

  DietPlanMealModel({
    required this.id,
    required this.occasion,
    this.dayOfWeek,
    this.mealType = 'NORMAL',
    required this.title,
    this.description,
    this.instructions,
    this.flexibilityLevel,
    this.guidance,
    this.allowedFrequency,
    this.restrictionNotes,
    this.adherenceStatus = 'PLANNED',
    this.bookChefEligible = false,
    this.plannedNutrition,
    this.dishes = const [],
    this.lastFeedback,
  });

  bool get isCheatMeal => mealType.toUpperCase() == 'CHEAT';

  factory DietPlanMealModel.fromJson(Map<String, dynamic> json) {
    return DietPlanMealModel(
      id: json['id'] ?? '',
      occasion: json['occasion'] ?? 'LUNCH',
      dayOfWeek: json['dayOfWeek'],
      mealType: json['mealType'] ?? 'NORMAL',
      title: json['title'] ?? json['occasion'] ?? 'Meal',
      description: json['description'],
      instructions: json['instructions'],
      flexibilityLevel: json['flexibilityLevel'],
      guidance: json['guidance'],
      allowedFrequency: json['allowedFrequency'],
      restrictionNotes: json['restrictionNotes'],
      adherenceStatus: json['adherenceStatus'] ?? 'PLANNED',
      bookChefEligible: json['bookChefEligible'] ?? false,
      plannedNutrition: json['plannedNutrition'] != null
          ? NutritionModel.fromJson(json['plannedNutrition'])
          : null,
      dishes: (json['dishes'] as List<dynamic>?)
              ?.map((e) => DietPlanDishItemModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      lastFeedback: json['lastFeedback'],
    );
  }
}

class DietPlanDetailModel {
  final bool hasActivePlan;
  final String? id;
  final String planName;
  final String? goal;
  final int versionNumber;
  final String status;
  final String customerFacingStatus;
  final DateTime? startDate;
  final DateTime? reviewDate;
  final String? specialInstructions;
  final String? notes;
  final DietitianSummary? dietitian;
  final MemberSummary? member;
  final String? todayDayOfWeek;
  final List<DietPlanMealModel> todayMeals;
  final List<DietPlanGoalModel> goals;
  final List<DietPlanNutritionTargetModel> nutritionTargets;
  final NutritionModel? dailyPlannedNutrition;

  DietPlanDetailModel({
    required this.hasActivePlan,
    this.id,
    required this.planName,
    this.goal,
    this.versionNumber = 1,
    required this.status,
    required this.customerFacingStatus,
    this.startDate,
    this.reviewDate,
    this.specialInstructions,
    this.notes,
    this.dietitian,
    this.member,
    this.todayDayOfWeek,
    this.todayMeals = const [],
    this.goals = const [],
    this.nutritionTargets = const [],
    this.dailyPlannedNutrition,
  });

  factory DietPlanDetailModel.fromJson(Map<String, dynamic> json) {
    final hasActive = json['hasActivePlan'] ?? (json['id'] != null);
    return DietPlanDetailModel(
      hasActivePlan: hasActive,
      id: json['id'],
      planName: json['planName'] ?? 'Personalized Diet Plan',
      goal: json['goal'],
      versionNumber: json['versionNumber'] ?? 1,
      status: json['status'] ?? 'ACTIVE',
      customerFacingStatus: json['customerFacingStatus'] ?? 'Active plan',
      startDate: json['startDate'] != null ? DateTime.tryParse(json['startDate']) : null,
      reviewDate: json['reviewDate'] != null ? DateTime.tryParse(json['reviewDate']) : null,
      specialInstructions: json['specialInstructions'],
      notes: json['notes'],
      dietitian: json['dietitian'] != null ? DietitianSummary.fromJson(json['dietitian']) : null,
      member: json['member'] != null ? MemberSummary.fromJson(json['member']) : null,
      todayDayOfWeek: json['todayDayOfWeek'],
      todayMeals: (json['todayMeals'] as List<dynamic>?)
              ?.map((e) => DietPlanMealModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      goals: (json['goals'] as List<dynamic>?)
              ?.map((e) => DietPlanGoalModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      nutritionTargets: (json['nutritionTargets'] as List<dynamic>?)
              ?.map((e) => DietPlanNutritionTargetModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      dailyPlannedNutrition: json['dailyPlannedNutrition'] != null
          ? NutritionModel.fromJson(json['dailyPlannedNutrition'])
          : null,
    );
  }
}
