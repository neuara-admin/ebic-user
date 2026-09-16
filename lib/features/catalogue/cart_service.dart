import 'package:flutter/foundation.dart';
import '../../shared/models/dish_model.dart';

class CartItem {
  final DishModel dish;
  int servings;
  int quantity;

  CartItem({required this.dish, this.servings = 1, this.quantity = 1});
}

class CartService extends ChangeNotifier {
  static final CartService _instance = CartService._internal();
  factory CartService() => _instance;
  CartService._internal();

  final Map<String, CartItem> _items = {};
  String _selectedOccasion = 'LUNCH'; // BREAKFAST, LUNCH, DINNER
  String? _selectedMemberId;
  String? _selectedMemberName;

  List<CartItem> get items => _items.values.toList();
  int get itemCount => _items.values.fold(0, (sum, i) => sum + i.servings);
  int get distinctDishCount => _items.length;
  bool get isEmpty => _items.isEmpty;
  String get selectedOccasion => _selectedOccasion;
  String? get selectedMemberId => _selectedMemberId;
  String? get selectedMemberName => _selectedMemberName;

  void setMember(String id, String name) {
    _selectedMemberId = id;
    _selectedMemberName = name;
    notifyListeners();
  }

  void setOccasion(String occasion) {
    _selectedOccasion = occasion;
    notifyListeners();
  }

  int getServings(String dishId) {
    return _items[dishId]?.servings ?? 0;
  }

  void addDish(DishModel dish, {int servings = 1}) {
    if (_items.containsKey(dish.id)) {
      _items[dish.id]!.servings += servings;
    } else {
      _items[dish.id] = CartItem(dish: dish, servings: servings);
    }
    notifyListeners();
  }

  void incrementDish(DishModel dish) {
    if (_items.containsKey(dish.id)) {
      _items[dish.id]!.servings += 1;
    } else {
      _items[dish.id] = CartItem(dish: dish, servings: 1);
    }
    notifyListeners();
  }

  void decrementDish(DishModel dish) {
    if (_items.containsKey(dish.id)) {
      final current = _items[dish.id]!.servings;
      if (current <= 1) {
        _items.remove(dish.id);
      } else {
        _items[dish.id]!.servings -= 1;
      }
      notifyListeners();
    }
  }

  void updateServings(String dishId, int servings) {
    if (servings <= 0) {
      _items.remove(dishId);
    } else if (_items.containsKey(dishId)) {
      _items[dishId]!.servings = servings;
    }
    notifyListeners();
  }

  void removeDish(String dishId) {
    _items.remove(dishId);
    notifyListeners();
  }

  void clear() {
    _items.clear();
    notifyListeners();
  }

  List<Map<String, dynamic>> toApiItems() {
    return _items.values.map((item) {
      return {
        'dish_id': item.dish.id,
        'quantity': 1,
        'servings': item.servings,
      };
    }).toList();
  }
}

