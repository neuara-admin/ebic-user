class OrderItemModel {
  final String dishName;
  final int quantity;
  final double price;

  OrderItemModel({
    required this.dishName,
    required this.quantity,
    required this.price,
  });
}

class OrderModel {
  final String id;
  final String orderType; // INSTANT, SCHEDULED
  final String bookingOption; // B, L, D, etc.
  final String status;
  final int visitCookTimeMin;
  final double priceSubtotal;
  final double priceGst;
  final double priceTotal;
  final DateTime? promisedEtaAt;
  final String? startOtp;
  final String? completionOtp;
  final DateTime createdAt;
  final ChefInfoModel? assignedChef;
  final OrderAddressModel? address;
  final List<OrderMealModel> meals;
  final OrderRatingModel? rating;

  OrderModel({
    required this.id,
    required this.orderType,
    required this.bookingOption,
    required this.status,
    required this.visitCookTimeMin,
    required this.priceSubtotal,
    required this.priceGst,
    required this.priceTotal,
    this.promisedEtaAt,
    this.startOtp,
    this.completionOtp,
    required this.createdAt,
    this.assignedChef,
    this.address,
    this.meals = const [],
    this.rating,
  });

  String? get bookingReference => id.length >= 8 ? 'EBIC-${id.substring(0, 4).toUpperCase()}' : 'EBIC-$id';
  String? get chefName => assignedChef?.name ?? 'Executive Chef';
  int get cookingTimeMinutes => visitCookTimeMin > 0 ? visitCookTimeMin : 35;
  double get totalAmount => priceTotal;
  int get etaMinutes => 18;

  List<OrderItemModel> get items {
    final list = <OrderItemModel>[];
    for (var m in meals) {
      for (var d in m.dishes) {
        list.add(OrderItemModel(dishName: d.dishName, quantity: d.servings, price: 249.0 * d.servings));
      }
    }
    if (list.isEmpty) {
      list.add(OrderItemModel(dishName: 'Chef Curated Meal Dispatches', quantity: 1, price: priceTotal > 0 ? priceTotal : 499.0));
    }
    return list;
  }

  // Customer-friendly status label adhering to Section 45
  String get customerStatusLabel {
    switch (status) {
      case 'CREATED':
        return 'Booking Created';
      case 'SEARCHING':
        return 'Assigning Chef...';
      case 'ASSIGNED':
        return 'Chef Assigned';
      case 'EN_ROUTE':
        return 'Chef Departed / On The Way';
      case 'ARRIVED':
      case 'WAITING_CUSTOMER':
        return 'Chef Arrived';
      case 'COOKING':
        return 'Cooking in Progress';
      case 'PLATING':
        return 'Plating Meal';
      case 'COMPLETED':
        return 'Meal Completed';
      case 'CANCELLED_CUSTOMER':
      case 'CANCELLED_NOSHOW':
        return 'Cancelled';
      default:
        return status;
    }
  }

  int get statusStepIndex {
    switch (status) {
      case 'CREATED':
      case 'SEARCHING':
        return 0;
      case 'ASSIGNED':
        return 1;
      case 'EN_ROUTE':
        return 2;
      case 'ARRIVED':
      case 'WAITING_CUSTOMER':
        return 3;
      case 'COOKING':
        return 4;
      case 'PLATING':
        return 5;
      case 'COMPLETED':
        return 6;
      default:
        return 0;
    }
  }

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    return OrderModel(
      id: json['id'] ?? '',
      orderType: json['orderType'] ?? 'INSTANT',
      bookingOption: json['bookingOption'] ?? 'L',
      status: json['status'] ?? 'CREATED',
      visitCookTimeMin: json['visitCookTimeMin'] ?? 0,
      priceSubtotal: double.tryParse(json['priceSubtotal']?.toString() ?? '0') ?? 0.0,
      priceGst: double.tryParse(json['priceGst']?.toString() ?? '0') ?? 0.0,
      priceTotal: double.tryParse(json['priceTotal']?.toString() ?? '0') ?? 0.0,
      promisedEtaAt: json['promisedEtaAt'] != null
          ? DateTime.tryParse(json['promisedEtaAt'])
          : null,
      startOtp: json['startOtp'],
      completionOtp: json['completionOtp'],
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt']) ?? DateTime.now()
          : DateTime.now(),
      assignedChef: json['assignedChef'] != null
          ? ChefInfoModel.fromJson(json['assignedChef'] as Map<String, dynamic>)
          : null,
      address: json['address'] != null
          ? OrderAddressModel.fromJson(json['address'] as Map<String, dynamic>)
          : null,
      meals: (json['meals'] as List<dynamic>?)
              ?.map((e) => OrderMealModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      rating: json['rating'] != null
          ? OrderRatingModel.fromJson(json['rating'] as Map<String, dynamic>)
          : null,
    );
  }
}

class ChefInfoModel {
  final String id;
  final String name;
  final String phone;
  final double rating;

  ChefInfoModel({
    required this.id,
    required this.name,
    required this.phone,
    required this.rating,
  });

  factory ChefInfoModel.fromJson(Map<String, dynamic> json) {
    return ChefInfoModel(
      id: json['id'] ?? '',
      name: json['name'] ?? 'Assigned Chef',
      phone: json['phone'] ?? '',
      rating: double.tryParse(json['rating']?.toString() ?? '4.8') ?? 4.8,
    );
  }
}

class OrderAddressModel {
  final String id;
  final String line1;
  final String? line2;
  final String? label;

  OrderAddressModel({
    required this.id,
    required this.line1,
    this.line2,
    this.label,
  });

  factory OrderAddressModel.fromJson(Map<String, dynamic> json) {
    return OrderAddressModel(
      id: json['id'] ?? '',
      line1: json['line1'] ?? '',
      line2: json['line2'],
      label: json['label'],
    );
  }
}

class OrderMealModel {
  final String id;
  final String occasion;
  final String classification;
  final List<OrderMealDishModel> dishes;

  OrderMealModel({
    required this.id,
    required this.occasion,
    required this.classification,
    this.dishes = const [],
  });

  factory OrderMealModel.fromJson(Map<String, dynamic> json) {
    return OrderMealModel(
      id: json['id'] ?? '',
      occasion: json['occasion'] ?? 'LUNCH',
      classification: json['classification'] ?? 'CHEAT',
      dishes: (json['dishes'] as List<dynamic>?)
              ?.map((e) => OrderMealDishModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class OrderMealDishModel {
  final String id;
  final String dishId;
  final String dishName;
  final int servings;
  final int cookTimeMin;
  final bool isFromDietPlan;

  OrderMealDishModel({
    required this.id,
    required this.dishId,
    required this.dishName,
    required this.servings,
    required this.cookTimeMin,
    required this.isFromDietPlan,
  });

  factory OrderMealDishModel.fromJson(Map<String, dynamic> json) {
    final dish = json['dish'] as Map<String, dynamic>?;
    return OrderMealDishModel(
      id: json['id'] ?? '',
      dishId: json['dishId'] ?? dish?['id'] ?? '',
      dishName: dish?['name'] ?? 'Dish',
      servings: json['servings'] ?? 1,
      cookTimeMin: json['cookTimeMin'] ?? 20,
      isFromDietPlan: json['isFromDietPlan'] ?? false,
    );
  }
}

class OrderRatingModel {
  final int stars;
  final String? comment;

  OrderRatingModel({required this.stars, this.comment});

  factory OrderRatingModel.fromJson(Map<String, dynamic> json) {
    return OrderRatingModel(
      stars: json['stars'] ?? 5,
      comment: json['comment'],
    );
  }
}
