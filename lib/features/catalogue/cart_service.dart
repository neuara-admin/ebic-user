import 'package:flutter/foundation.dart';
import '../../shared/models/dish_model.dart';

class CartItem {
  final DishModel dish;
  int servings;

  CartItem({required this.dish, this.servings = 1});
}

class CartService extends ChangeNotifier {
  static final CartService _instance = CartService._internal();
  factory CartService() => _instance;
  CartService._internal();

  final Map<String, CartItem> _items = {};
  String _selectedOccasion = 'LUNCH'; // BREAKFAST, LUNCH, DINNER

  List<CartItem> get items => _items.values.toList();
  int get itemCount => _items.values.fold(0, (sum, i) => sum + i.servings);
  bool get isEmpty => _items.isEmpty;
  String get selectedOccasion => _selectedOccasion;

  void setOccasion(String occasion) {
    _selectedOccasion = occasion;
    notifyListeners();
  }

  void addDish(DishModel dish, {int servings = 1}) {
    if (_items.containsKey(dish.id)) {
      _items[dish.id]!.servings += servings;
    } else {
      _items[dish.id] = CartItem(dish: dish, servings: servings);
    }
    notifyListeners();
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
}
