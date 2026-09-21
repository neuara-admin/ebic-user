import 'package:flutter_test/flutter_test.dart';
import 'package:ebic_user/shared/models/preparation_model.dart';

void main() {
  group('Module 14: Preparation Checklist Models', () {
    test('PreparationItemModel parses preparationForm and allergens correctly', () {
      final json = {
        'id': 'item-1',
        'ingredientId': 'ing-chicken',
        'name': 'Chicken Breast',
        'quantity': 300,
        'unit': 'g',
        'customerProvides': true,
        'preparationForm': 'diced',
        'allergens': ['Dairy', 'Gluten'],
        'status': 'PENDING',
      };

      final item = PreparationItemModel.fromJson(json);

      expect(item.id, 'item-1');
      expect(item.name, 'Chicken Breast');
      expect(item.quantity, 300.0);
      expect(item.unit, 'g');
      expect(item.preparationForm, 'diced');
      expect(item.allergens, ['Dairy', 'Gluten']);
      expect(item.isPending, true);
      expect(item.isReady, false);
      expect(item.isSubstituted, false);
    });

    test('PreparationItemModel handles SUBSTITUTED status correctly', () {
      final json = {
        'id': 'item-2',
        'ingredientId': 'ing-rice',
        'name': 'Brown Rice',
        'quantity': 200,
        'unit': 'g',
        'status': 'SUBSTITUTED',
      };

      final item = PreparationItemModel.fromJson(json);

      expect(item.status, 'SUBSTITUTED');
      expect(item.isSubstituted, true);
      expect(item.isReady, false);
    });

    test('OrderPreparationChecklistModel calculates allReady and counts correctly', () {
      final json = {
        'orderId': 'order-123',
        'items': [
          {
            'id': '1',
            'name': 'Chicken',
            'quantity': 300,
            'unit': 'g',
            'status': 'READY',
          },
          {
            'id': '2',
            'name': 'Rice',
            'quantity': 200,
            'unit': 'g',
            'status': 'READY',
          },
        ],
      };

      final checklist = OrderPreparationChecklistModel.fromJson(json);

      expect(checklist.orderId, 'order-123');
      expect(checklist.totalCount, 2);
      expect(checklist.readyCount, 2);
      expect(checklist.allReady, true);
    });
  });
}
