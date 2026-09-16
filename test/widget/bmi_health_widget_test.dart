import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ebic_user/shared/widgets/bmi_health_widget.dart';
import 'package:ebic_user/shared/widgets/dietary_health_selection_widget.dart';
import 'package:ebic_user/shared/models/household_member_model.dart';

void main() {
  group('BmiHealthWidget & BMI Calculation Tests', () {
    test('Calculates BMI accurately and categorizes appropriately', () {
      // Underweight: 45kg at 170cm -> 15.6
      final under = BmiHealthWidget.calculateBmi(170, 45);
      expect(under, 15.6);
      expect(BmiHealthWidget.getCategory(under), BmiCategory.underweight);

      // Normal: 65kg at 170cm -> 22.5
      final normal = BmiHealthWidget.calculateBmi(170, 65);
      expect(normal, 22.5);
      expect(BmiHealthWidget.getCategory(normal), BmiCategory.normal);

      // Overweight: 78kg at 170cm -> 27.0
      final over = BmiHealthWidget.calculateBmi(170, 78);
      expect(over, 27.0);
      expect(BmiHealthWidget.getCategory(over), BmiCategory.overweight);

      // Obese: 95kg at 170cm -> 32.9
      final obese = BmiHealthWidget.calculateBmi(170, 95);
      expect(obese, 32.9);
      expect(BmiHealthWidget.getCategory(obese), BmiCategory.obese);

      // Invalid or zero inputs return null
      expect(BmiHealthWidget.calculateBmi(null, 65), isNull);
      expect(BmiHealthWidget.calculateBmi(170, null), isNull);
      expect(BmiHealthWidget.calculateBmi(0, 0), isNull);
    });

    testWidgets('BmiHealthWidget full card renders score, category badge and guidance', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: BmiHealthWidget(
              heightCm: 175,
              weightKg: 70,
            ),
          ),
        ),
      );

      // BMI for 175cm, 70kg is 22.9
      expect(find.text('BODY MASS INDEX'), findsOneWidget);
      expect(find.text('22.9'), findsOneWidget);
      expect(find.text('kg/m²'), findsOneWidget);
      expect(find.text('Normal weight'), findsOneWidget);
      expect(find.textContaining('Healthy weight range'), findsOneWidget);
    });

    testWidgets('BmiHealthWidget compact badge renders concise pill format', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: BmiHealthWidget.badge(
              bmi: 24.2,
            ),
          ),
        ),
      );

      expect(find.text('BMI 24.2 • Normal weight'), findsOneWidget);
    });

    test('HouseholdMemberModel handles DOB, BMI, dietary preferences and conditions', () {
      final json = {
        'id': 'mem-1',
        'name': 'Aarav Patel',
        'relationship': 'CHILD',
        'dateOfBirth': '2010-05-15',
        'sex': 'Male',
        'healthProfile': {
          'heightCm': '155',
          'currentWeightKg': '48',
          'healthGoals': 'Conditions: Hypothyroid, Fatty Liver | Goals: Better immunity',
          'dietaryRestrictions': [
            {'dietaryTag': {'name': 'Vegetarian'}},
            {'dietaryTag': {'name': 'High-Protein'}},
          ],
          'allergens': [
            {'allergen': {'name': 'Lactose / Dairy'}},
          ],
        },
      };

      final member = HouseholdMemberModel.fromJson(json);

      expect(member.name, 'Aarav Patel');
      expect(member.relationship, 'CHILD');
      expect(member.displayRelationship, 'Child');
      expect(member.formattedDob, '15/05/2010');
      expect(member.heightCm, 155.0);
      expect(member.weightCmOrNull, isNotNull);
      expect(member.heightDisplay, '5\'1" (155 cm)');
      expect(member.weightDisplay, '48.0 kg (106 lbs)');
      expect(member.bmi, 20.0); // 48 / (1.55 * 1.55) = 19.979 -> 20.0
      expect(member.bmiCategory, 'Normal weight');
      expect(member.dietaryPreferences, containsAll(['Vegetarian', 'High-Protein']));
      expect(member.allergies, contains('Lactose / Dairy'));
      expect(member.medicalConditions, containsAll(['Hypothyroid', 'Fatty Liver']));
    });

    testWidgets('DietaryHealthSelectionWidget renders categories and badges', (tester) async {
      List<String> dietary = ['Vegetarian'];
      List<String> allergies = ['None'];
      List<String> goals = ['Weight Management'];
      List<String> conditions = ['None'];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: DietaryHealthSelectionWidget(
                selectedDietary: dietary,
                onDietaryChanged: (val) => dietary = val,
                selectedAllergies: allergies,
                onAllergiesChanged: (val) => allergies = val,
                selectedGoals: goals,
                onGoalsChanged: (val) => goals = val,
                selectedConditions: conditions,
                onConditionsChanged: (val) => conditions = val,
              ),
            ),
          ),
        ),
      );

      expect(find.text('Dietary Preferences'), findsOneWidget);
      expect(find.text('Food Allergies & Intolerances'), findsOneWidget);
      expect(find.text('Primary Health Goals'), findsOneWidget);
      expect(find.text('Known Medical Conditions'), findsOneWidget);

      expect(find.text('1 selected'), findsOneWidget);
      expect(find.text('Allergen-Free'), findsOneWidget);
      expect(find.text('1 goal'), findsOneWidget);
      expect(find.text('Healthy / None'), findsOneWidget);
    });
  });
}

extension on HouseholdMemberModel {
  double? get weightCmOrNull => weightKg;
}
