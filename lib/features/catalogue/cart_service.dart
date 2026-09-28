import 'package:flutter/foundation.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/auth/session_manager.dart';
import '../../shared/models/dish_model.dart';

class CartItem {
  final DishModel dish;
  int servings;
  int quantity;
  final String? _memberId;
  final String? _memberName;
  String? backendItemId;

  CartItem({
    required this.dish,
    this.servings = 1,
    this.quantity = 1,
    String? memberId,
    String? memberName,
    this.backendItemId,
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
  bool _isLoading = false;

  List<CartItem> get items => _items.values.toList();
  int get itemCount => _items.values.fold(0, (sum, i) => sum + i.servings);
  int get distinctDishCount => _items.length;
  bool get isEmpty => _items.isEmpty;
  bool get isNotEmpty => _items.isNotEmpty;
  bool get isLoading => _isLoading;
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

    if (SessionManager().isAuthenticated) {
      _syncOccasionRemote(occasionCode);
    }
  }

  Future<void> _syncOccasionRemote(String code) async {
    try {
      await ApiClient().patch(
        ApiEndpoints.cartOccasion,
        requiresAuth: true,
        body: {'occasion': code},
      );
    } catch (err) {
      debugPrint('[CartService] Remote setOccasion error: $err');
    }
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

    _syncAddItemRemote(dish.id, servings, memberId, memberName);
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
      final newServings = _items[key]!.servings;
      final backendId = _items[key]!.backendItemId;
      notifyListeners();
      _syncUpdateRemote(dish.id, memberId, newServings, backendId);
    } else {
      _items[key] = CartItem(
        dish: dish,
        servings: 1,
        memberId: memberId,
        memberName: memberName,
      );
      notifyListeners();
      _syncAddItemRemote(dish.id, 1, memberId, memberName);
    }
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
      final backendId = _items[key]!.backendItemId;
      if (current <= 1) {
        _items.remove(key);
        notifyListeners();
        _syncRemoveRemote(dish.id, memberId, backendId);
      } else {
        _items[key]!.servings -= 1;
        notifyListeners();
        _syncUpdateRemote(dish.id, memberId, current - 1, backendId);
      }
    }
  }

  void decrementDish(DishModel dish) {
    final mId = _selectedMemberId ?? 'self';
    decrementDishForMember(dish, mId);
  }

  void updateServings(String dishId, int servings, {String? memberId}) {
    final mId = memberId ?? _selectedMemberId ?? 'self';
    final key = _itemKey(mId, dishId);
    if (servings <= 0) {
      final backendId = _items[key]?.backendItemId;
      _items.remove(key);
      notifyListeners();
      _syncRemoveRemote(dishId, mId, backendId);
    } else if (_items.containsKey(key)) {
      _items[key]!.servings = servings;
      final backendId = _items[key]!.backendItemId;
      notifyListeners();
      _syncUpdateRemote(dishId, mId, servings, backendId);
    }
  }

  void removeDish(String dishId, {String? memberId}) {
    final mId = memberId ?? _selectedMemberId ?? 'self';
    final key = _itemKey(mId, dishId);
    final backendId = _items[key]?.backendItemId;
    _items.remove(key);
    notifyListeners();
    _syncRemoveRemote(dishId, mId, backendId);
  }

  void clear() {
    _items.clear();
    notifyListeners();

    if (SessionManager().isAuthenticated) {
      _syncClearRemote();
    }
  }

  Future<void> _syncClearRemote() async {
    try {
      await ApiClient().delete(
        ApiEndpoints.cart,
        requiresAuth: true,
      );
    } catch (err) {
      debugPrint('[CartService] Remote clear error: $err');
    }
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

  // ===========================================================================
  // Cloud Cart Synchronization (Option A - PostgreSQL Persistent Cart)
  // ===========================================================================

  /// Load persistent cart from backend upon app startup or user login
  Future<void> loadFromBackend() async {
    if (!SessionManager().isAuthenticated) return;
    try {
      _isLoading = true;
      final res = await ApiClient().get<Map<String, dynamic>>(
        ApiEndpoints.cart,
        requiresAuth: true,
      );

      if (res.success && res.data != null) {
        final data = res.data!;
        _items.clear();

        if (data['occasion'] != null && data['occasion'].toString().isNotEmpty) {
          final occ = data['occasion'].toString().toUpperCase();
          if (occ == 'B') {
            _selectedOccasion = 'BREAKFAST';
          } else if (occ == 'L') {
            _selectedOccasion = 'LUNCH';
          } else if (occ == 'D') {
            _selectedOccasion = 'DINNER';
          } else if (occ == 'BL') {
            _selectedOccasion = 'BREAKFAST_LUNCH';
          } else if (occ == 'LD') {
            _selectedOccasion = 'LUNCH_DINNER';
          } else {
            _selectedOccasion = occ;
          }
        }

        final rawItems = data['items'] as List<dynamic>? ?? [];
        for (final item in rawItems) {
          if (item is Map<String, dynamic> && item['dish'] != null) {
            final dish = DishModel.fromJson(item['dish'] as Map<String, dynamic>);
            final memberId = item['memberId']?.toString() ?? 'self';
            final memberName = item['memberName']?.toString() ?? 'Self';
            final servings = (item['servings'] as num?)?.toInt() ?? 1;
            final backendId = item['id']?.toString();

            final cartItem = CartItem(
              dish: dish,
              servings: servings,
              quantity: servings,
              memberId: memberId,
              memberName: memberName,
              backendItemId: backendId,
            );
            _items[_itemKey(memberId, dish.id)] = cartItem;
          }
        }
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[CartService] loadFromBackend error: $e');
    } finally {
      _isLoading = false;
    }
  }

  /// Sync local/guest cart items to cloud cart after user signs in
  Future<void> syncToBackend() async {
    if (!SessionManager().isAuthenticated) return;
    try {
      if (_items.isEmpty) {
        await loadFromBackend();
        return;
      }

      final itemsPayload = _items.values.map((i) => {
        'dishId': i.dish.id,
        'servings': i.servings,
        'memberId': i.memberId == 'self' ? null : i.memberId,
        'memberName': i.memberName,
      }).toList();

      final res = await ApiClient().post<Map<String, dynamic>>(
        ApiEndpoints.cartSync,
        requiresAuth: true,
        body: {
          'items': itemsPayload,
          'occasion': occasionCode,
        },
      );

      if (res.success) {
        await loadFromBackend();
      }
    } catch (e) {
      debugPrint('[CartService] syncToBackend error: $e');
    }
  }

  Future<void> _syncAddItemRemote(String dishId, int servings, String memberId, String memberName) async {
    if (!SessionManager().isAuthenticated) return;
    try {
      final res = await ApiClient().post<Map<String, dynamic>>(
        ApiEndpoints.cartItems,
        requiresAuth: true,
        body: {
          'dishId': dishId,
          'servings': servings,
          'memberId': memberId == 'self' ? null : memberId,
          'memberName': memberName,
          'occasion': occasionCode,
        },
      );

      if (res.success && res.data != null) {
        final rawItems = res.data!['items'] as List<dynamic>? ?? [];
        for (final item in rawItems) {
          if (item is Map<String, dynamic> &&
              item['dishId'] == dishId &&
              (item['memberId'] ?? 'self') == memberId) {
            final key = _itemKey(memberId, dishId);
            if (_items.containsKey(key)) {
              _items[key]!.backendItemId = item['id']?.toString();
            }
          }
        }
      }
    } catch (err) {
      debugPrint('[CartService] _syncAddItemRemote error: $err');
    }
  }

  Future<void> _syncUpdateRemote(String dishId, String memberId, int servings, String? backendItemId) async {
    if (!SessionManager().isAuthenticated) return;
    try {
      if (backendItemId != null && backendItemId.isNotEmpty) {
        await ApiClient().patch(
          ApiEndpoints.cartItem(backendItemId),
          requiresAuth: true,
          body: {'servings': servings},
        );
      } else {
        await ApiClient().post(
          ApiEndpoints.cartItems,
          requiresAuth: true,
          body: {
            'dishId': dishId,
            'servings': servings,
            'memberId': memberId == 'self' ? null : memberId,
            'occasion': occasionCode,
          },
        );
      }
    } catch (err) {
      debugPrint('[CartService] _syncUpdateRemote error: $err');
    }
  }

  Future<void> _syncRemoveRemote(String dishId, String memberId, String? backendItemId) async {
    if (!SessionManager().isAuthenticated) return;
    try {
      if (backendItemId != null && backendItemId.isNotEmpty) {
        await ApiClient().delete(
          ApiEndpoints.cartItem(backendItemId),
          requiresAuth: true,
        );
      } else {
        final query = memberId != 'self' ? '?memberId=$memberId' : '?memberId=self';
        await ApiClient().delete(
          '${ApiEndpoints.cartDish(dishId)}$query',
          requiresAuth: true,
        );
      }
    } catch (err) {
      debugPrint('[CartService] _syncRemoveRemote error: $err');
    }
  }
}
