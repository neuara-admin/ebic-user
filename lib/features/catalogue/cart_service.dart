import 'package:flutter/foundation.dart';
import '../../shared/models/dish_model.dart';

class CartItem {
  final DishModel dish;
  int servings;
  int quantity;
  final String? _memberId;
  final String? _memberName;

  CartItem({
    required this.dish,
    this.servings = 1,
    this.quantity = 1,
    String? memberId,
    String? memberName,
  })  : _memberId = memberId,
        _memberName = memberName;

  String get memberId {
    final id = _memberId;
    if (id == null || id.isEmpty) return 'self';
    return id;
  }

  String get memberName {
    final name = _memberName;
    if (name == null || name.isEmpty) return 'Self';
    return name;
  }

  String get itemKey => '${memberId}_${dish.id}';
}

class CartService extends ChangeNotifier {
  static final CartService _instance = CartService._internal();
  factory CartService() => _instance;
  CartService._internal();

  final Map<String, CartItem> _items = {};
  String _selectedOccasion = 'LUNCH'; // BREAKFAST, LUNCH, DINNER, BREAKFAST_LUNCH (BL), LUNCH_DINNER (LD)
  String? _selectedMemberId;
  String? _selectedMemberName;

  List<CartItem> get items => _items.values.toList();
  int get itemCount => _items.values.fold(0, (sum, i) => sum + i.servings);
  int get distinctDishCount => _items.length;
  bool get isEmpty => _items.isEmpty;
  String get selectedOccasion => _selectedOccasion;
  String? get selectedMemberId => _selectedMemberId;
  String? get selectedMemberName => _selectedMemberName;

  String get occasionCode {
    switch (_selectedOccasion.toUpperCase()) {
      case 'BREAKFAST':
      case 'B':
        return 'B';
      case 'LUNCH':
      case 'L':
        return 'L';
      case 'DINNER':
      case 'D':
        return 'D';
      case 'BREAKFAST_LUNCH':
      case 'BL':
        return 'BL';
      case 'LUNCH_DINNER':
      case 'LD':
        return 'LD';
      default:
        return 'L';
    }
  }

  String _itemKey(String memberId, String dishId) => '${memberId}_$dishId';

  void setMember(String id, String name) {
    _selectedMemberId = id;
    _selectedMemberName = name;
    notifyListeners();
  }

  void setOccasion(String occasion) {
    _selectedOccasion = occasion;
    notifyListeners();
  }

  int getServingsForMember(String memberId, String dishId) {
    return _items[_itemKey(memberId, dishId)]?.servings ?? 0;
  }

  int getServings(String dishId) {
    final mId = _selectedMemberId ?? 'self';
    return getServingsForMember(mId, dishId);
  }

  void addDishForMember(DishModel dish, String memberId, String memberName, {int servings = 1}) {
    final key = _itemKey(memberId, dish.id);
    if (_items.containsKey(key)) {
      _items[key]!.servings += servings;
    } else {
      _items[key] = CartItem(
        dish: dish,
        servings: servings,
        memberId: memberId,
        memberName: memberName,
      );
    }
    notifyListeners();
  }

  void addDish(DishModel dish, {int servings = 1}) {
    final mId = _selectedMemberId ?? 'self';
    final mName = _selectedMemberName ?? 'Self';
    addDishForMember(dish, mId, mName, servings: servings);
  }

  void incrementDishForMember(DishModel dish, String memberId, String memberName) {
    final key = _itemKey(memberId, dish.id);
    if (_items.containsKey(key)) {
      _items[key]!.servings += 1;
    } else {
      _items[key] = CartItem(
        dish: dish,
        servings: 1,
        memberId: memberId,
        memberName: memberName,
      );
    }
    notifyListeners();
  }

  void incrementDish(DishModel dish) {
    final mId = _selectedMemberId ?? 'self';
    final mName = _selectedMemberName ?? 'Self';
    incrementDishForMember(dish, mId, mName);
  }

  void decrementDishForMember(DishModel dish, String memberId) {
    final key = _itemKey(memberId, dish.id);
    if (_items.containsKey(key)) {
      final current = _items[key]!.servings;
      if (current <= 1) {
        _items.remove(key);
      } else {
        _items[key]!.servings -= 1;
      }
      notifyListeners();
    }
  }

  void decrementDish(DishModel dish) {
    final mId = _selectedMemberId ?? 'self';
    decrementDishForMember(dish, mId);
  }

  void updateServings(String dishId, int servings) {
    final mId = _selectedMemberId ?? 'self';
    final key = _itemKey(mId, dishId);
    if (servings <= 0) {
      _items.remove(key);
    } else if (_items.containsKey(key)) {
      _items[key]!.servings = servings;
    }
    notifyListeners();
  }

  void removeDish(String dishId) {
    final mId = _selectedMemberId ?? 'self';
    _items.remove(_itemKey(mId, dishId));
    notifyListeners();
  }

  void clear() {
    _items.clear();
    notifyListeners();
  }

  Map<String, List<CartItem>> get itemsGroupedByMember {
    final map = <String, List<CartItem>>{};
    for (final item in _items.values) {
      map.putIfAbsent(item.memberId, () => []).add(item);
    }
    return map;
  }

  int get coveredMemberCount {
    return _items.values.map((i) => i.memberId).toSet().length;
  }

  List<String> get coveredMemberNames {
    return _items.values.map((i) => i.memberName).toSet().toList();
  }

  List<Map<String, dynamic>> toApiItems() {
    return _items.values.map((item) {
      return {
        'dish_id': item.dish.id,
        'quantity': 1,
        'servings': item.servings,
        'member_id': item.memberId,
        'member_name': item.memberName,
      };
    }).toList();
  }
}
