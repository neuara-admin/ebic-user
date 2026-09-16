import 'package:flutter_test/flutter_test.dart';
import 'package:ebic_user/features/diet_plan/models/diet_plan_models.dart';

void main() {
  group('Module 7: Diet Plan Models Verification', () {
    test('DietPlanDetailModel parses full specification payload correctly', () {
      final json = {
        'hasActivePlan': true,
        'id': 'dp-123',
        'planName': 'Metabolic Balance V1',
        'goal': 'Improve nutritional consistency',
        'versionNumber': 1,
        'status': 'ACTIVE',
        'customerFacingStatus': 'Active plan',
        'startDate': '2026-09-01T00:00:00.000Z',
        'reviewDate': '2026-09-30T00:00:00.000Z',
        'specialInstructions': 'Maintain regular meal timing and hydration.',
        'dietitian': {
          'id': 'd-1',
          'name': 'Dr. Ananya Sharma',
          'qualification': 'Senior Clinical Nutritionist',
        },
        'member': {
          'id': 'm-1',
          'name': 'John Doe',
          'relationship': 'SELF',
          'isSelf': true,
        },
        'todayDayOfWeek': 'MONDAY',
        'todayMeals': [
          {
            'id': 'meal-1',
            'occasion': 'LUNCH',
            'dayOfWeek': 'MONDAY',
            'mealType': 'NORMAL',
            'title': 'Grilled Chicken & Quinoa Protein Bowl',
            'adherenceStatus': 'CONFIRMED_CONSUMED',
            'bookChefEligible': true,
            'plannedNutrition': {
              'calories': 550,
              'proteinG': 42,
              'carbsG': 58,
              'fatG': 14,
              'fibreG': 8,
            },
            'dishes': [
              {
                'id': 'dish-1',
                'dishId': 'catalogue-dish-1',
                'name': 'Grilled Chicken Breast',
                'servings': 1,
                'servingQuantity': 1,
                'servingUnit': 'serving',
                'isActive': true,
                'dietaryTags': ['High Protein', 'Gluten Free'],
                'allergens': [],
                'allergenConflicts': [],
              }
            ],
          },
          {
            'id': 'meal-2',
            'occasion': 'DINNER',
            'dayOfWeek': 'SATURDAY',
            'mealType': 'CHEAT',
            'title': 'Controlled Flexible Meal',
            'guidance': 'One flexible meal. Avoid known allergens.',
            'adherenceStatus': 'PLANNED',
            'bookChefEligible': false,
            'dishes': [],
          },
        ],
        'goals': [
          {
            'id': 'g-1',
            'goalType': 'PRIMARY',
            'title': 'Improve nutritional consistency',
            'priority': 1,
          },
          {
            'id': 'g-2',
            'goalType': 'SECONDARY',
            'title': 'Maintain regular meal timing',
            'priority': 2,
          }
        ],
        'nutritionTargets': [
          {
            'nutrient': 'CALORIES',
            'targetValue': 2000,
            'unit': 'kcal',
            'period': 'DAILY',
          },
          {
            'nutrient': 'PROTEIN',
            'targetValue': 120,
            'unit': 'g',
            'period': 'DAILY',
          },
          {
            'nutrient': 'WATER',
            'targetValue': 2.5,
            'unit': 'L',
            'period': 'DAILY',
          }
        ],
        'dailyPlannedNutrition': {
          'calories': 1950,
          'proteinG': 118,
          'carbsG': 210,
          'fatG': 52,
          'fibreG': 31,
        },
      };

      final model = DietPlanDetailModel.fromJson(json);

      expect(model.hasActivePlan, isTrue);
      expect(model.id, equals('dp-123'));
      expect(model.planName, equals('Metabolic Balance V1'));
      expect(model.versionNumber, equals(1));
      expect(model.status, equals('ACTIVE'));
      expect(model.customerFacingStatus, equals('Active plan'));
      expect(model.dietitian?.name, equals('Dr. Ananya Sharma'));
      expect(model.member?.name, equals('John Doe'));
      expect(model.todayMeals.length, equals(2));

      // Verify normal meal
      final normalMeal = model.todayMeals[0];
      expect(normalMeal.isCheatMeal, isFalse);
      expect(normalMeal.adherenceStatus, equals('CONFIRMED_CONSUMED'));
      expect(normalMeal.bookChefEligible, isTrue);
      expect(normalMeal.dishes.length, equals(1));
      expect(normalMeal.dishes[0].name, equals('Grilled Chicken Breast'));

      // Verify cheat meal
      final cheatMeal = model.todayMeals[1];
      expect(cheatMeal.isCheatMeal, isTrue);
      expect(cheatMeal.guidance, contains('Avoid known allergens'));

      // Verify goals and nutrition targets
      expect(model.goals.length, equals(2));
      expect(model.nutritionTargets.length, equals(3));
      expect(model.nutritionTargets[0].nutrient, equals('CALORIES'));
      expect(model.nutritionTargets[0].targetValue, equals(2000));
      expect(model.nutritionTargets[2].nutrient, equals('WATER'));
      expect(model.nutritionTargets[2].targetValue, equals(2.5));
    });
  });
}
