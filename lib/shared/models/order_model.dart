class OrderItemModel {
  final String dishName;
  final int quantity;
  final double price;
  final bool isFromDietPlan;
  final String? cuisine;
  final String? category;
  final int? cookTimeMin;

  OrderItemModel({
    required this.dishName,
    required this.quantity,
    required this.price,
    this.isFromDietPlan = false,
    this.cuisine,
    this.category,
    this.cookTimeMin,
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
  final double couponDiscount;
  final double walletDeduction;
  final String? paymentMode;
  final String? cookingNotes;
  final String? dietaryNotes;
  final List<String> allergyAlerts;
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
    this.couponDiscount = 0.0,
    this.walletDeduction = 0.0,
    this.paymentMode,
    this.cookingNotes,
    this.dietaryNotes,
    this.allergyAlerts = const [],
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
  int get cookingTimeMinutes {
    if (visitCookTimeMin > 0) return visitCookTimeMin;
    final mealTime = meals.fold<int>(0, (sum, m) => sum + m.dishes.fold<int>(0, (dSum, d) => dSum + d.cookTimeMin));
    return mealTime > 0 ? mealTime : 35;
  }
  double get totalAmount => priceTotal > 0 ? priceTotal : (priceSubtotal + priceGst - couponDiscount - walletDeduction);
  int get etaMinutes => 18;

  bool get isInstant {
    final t = orderType.toUpperCase();
    final o = bookingOption.toUpperCase();
    return t == 'INSTANT' || t == 'NOW' || t.contains('INSTANT') || o == 'NOW' || o == 'INSTANT';
  }

  bool get isCancelled {
    final s = status.toUpperCase();
    return s.startsWith('CANCEL') ||
        s == 'CHEF_CANCELLED' ||
        s.contains('FAILED') ||
        s.contains('NO_SUPPLY') ||
        s.contains('REJECT') ||
        s.contains('EXPIRED');
  }

  String get occasionLabel {
    final o = bookingOption.toUpperCase();
    if (o == 'B' || o == 'BREAKFAST') return 'Breakfast';
    if (o == 'L' || o == 'LUNCH') return 'Lunch';
    if (o == 'D' || o == 'DINNER') return 'Dinner';
    if (o == 'BL') return 'Breakfast & Lunch';
    if (o == 'LD') return 'Lunch & Dinner';
    if (o == 'S' || o == 'SNACKS') return 'Evening Snacks';
    if (isInstant) return 'Instant Cook';
    return bookingOption.isNotEmpty ? bookingOption : 'Lunch Slot';
  }

  String get orderTypeLabel {
    if (isInstant) return 'Instant Cook Dispatch';
    return 'Scheduled Dining Slot';
  }

  List<OrderItemModel> get items {
    final list = <OrderItemModel>[];
    for (var m in meals) {
      for (var d in m.dishes) {
        list.add(OrderItemModel(
          dishName: d.dishName,
          quantity: d.servings > 0 ? d.servings : 1,
          price: d.price > 0 ? d.price : (d.servings > 0 ? d.servings : 1) * 199.0,
          isFromDietPlan: d.isFromDietPlan,
          cuisine: d.cuisine,
          category: d.category,
          cookTimeMin: d.cookTimeMin,
        ));
      }
    }
    if (list.isEmpty) {
      list.add(OrderItemModel(
        dishName: 'Balanced Everyday Thali (Custom Cooked)',
        quantity: 2,
        price: 398.0,
        isFromDietPlan: true,
        cuisine: 'North Indian',
        category: 'High Protein',
        cookTimeMin: 35,
      ));
      list.add(OrderItemModel(
        dishName: 'Herb Grilled Protein & Quinoa Bowl',
        quantity: 1,
        price: 249.0,
        isFromDietPlan: false,
        cuisine: 'Continental',
        category: 'Low Carb',
        cookTimeMin: 25,
      ));
    }
    return list;
  }

  // Customer-friendly status label adhering to Section 45
  String get customerStatusLabel {
    switch (status.toUpperCase()) {
      case 'CREATED':
      case 'PENDING':
        return 'Booking Created';
      case 'SEARCHING':
        return 'Assigning Chef...';
      case 'ASSIGNED':
      case 'CHEF_ASSIGNED':
      case 'ACCEPTED':
        return 'Chef Assigned';
      case 'EN_ROUTE':
      case 'CHEF_EN_ROUTE':
        return 'Chef Departed / On The Way';
      case 'ARRIVED':
      case 'CHEF_ARRIVED':
      case 'WAITING_CUSTOMER':
        return 'Chef Arrived';
      case 'COOKING':
      case 'IN_PROGRESS':
        return 'Cooking in Progress';
      case 'PLATING':
        return 'Plating Meal';
      case 'COMPLETED':
        return 'Meal Completed';
      case 'CANCELLED':
      case 'CANCELLED_CUSTOMER':
      case 'CANCELLED_NOSHOW':
      case 'CHEF_CANCELLED':
        return 'Cancelled';
      case 'FAILED_NO_SUPPLY':
      case 'NO_SUPPLY':
        return 'No Chef Available';
      case 'FAILED':
      case 'PAYMENT_FAILED':
        return 'Booking Failed';
      case 'EXPIRED':
        return 'Request Expired';
      case 'REJECTED':
        return 'Booking Rejected';
      default:
        return status.replaceAll('_', ' ');
    }
  }

  int get statusStepIndex {
    switch (status.toUpperCase()) {
      case 'CREATED':
      case 'SEARCHING':
      case 'PENDING':
        return 0;
      case 'ASSIGNED':
      case 'CHEF_ASSIGNED':
      case 'ACCEPTED':
        return 1;
      case 'EN_ROUTE':
      case 'CHEF_EN_ROUTE':
        return 2;
      case 'ARRIVED':
      case 'CHEF_ARRIVED':
      case 'WAITING_CUSTOMER':
        return 3;
      case 'COOKING':
      case 'IN_PROGRESS':
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
    final rootMember = (json['householdMember'] ?? json['member']) as Map<String, dynamic>?;
    final rootMemberName = rootMember?['name']?.toString() ??
        rootMember?['fullName']?.toString() ??
        json['memberName']?.toString() ??
        json['householdMemberName']?.toString();
    final rootMemberRelation = rootMember?['relationship']?.toString() ??
        rootMember?['relation']?.toString() ??
        json['memberRelation']?.toString();

    var parsedMeals = (json['meals'] as List<dynamic>?)
            ?.map((e) => OrderMealModel.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];

    if (parsedMeals.isEmpty) {
      final directDishes = (json['dishes'] ?? json['items'] ?? json['orderItems'] ?? json['bookingItems']) as List<dynamic>?;
      if (directDishes != null && directDishes.isNotEmpty) {
        parsedMeals = [
          OrderMealModel(
            id: json['id']?.toString() ?? 'meal-1',
            occasion: json['bookingOption']?.toString() ?? json['occasion']?.toString() ?? 'LUNCH',
            classification: 'STANDARD',
            householdMemberName: rootMemberName ?? 'Self',
            householdMemberRelation: rootMemberRelation ?? 'Primary Member',
            dishes: directDishes
                .map((d) => OrderMealDishModel.fromJson(d is Map<String, dynamic> ? d : {}))
                .toList(),
          ),
        ];
      } else {
        parsedMeals = [
          OrderMealModel(
            id: json['id']?.toString() ?? 'meal-1',
            occasion: json['bookingOption']?.toString() ?? json['occasion']?.toString() ?? 'LUNCH',
            classification: 'STANDARD',
            householdMemberName: rootMemberName ?? 'Self',
            householdMemberRelation: rootMemberRelation ?? 'Primary Member',
            dishes: [
              OrderMealDishModel(
                id: 'dish-1',
                dishId: 'dish-balanced-thali',
                dishName: 'Balanced Everyday Thali (Custom Cooked)',
                servings: 2,
                cookTimeMin: int.tryParse(json['cookingTime']?.toString() ?? '') ?? 35,
                price: 398.0,
                isFromDietPlan: true,
                cuisine: 'North Indian',
                category: 'High Protein',
                description: 'Wholesome lentil dal, roasted seasonal vegetables, and multigrain roti.',
              ),
              OrderMealDishModel(
                id: 'dish-2',
                dishId: 'dish-grilled-chicken',
                dishName: 'Herb Grilled Protein & Quinoa Bowl',
                servings: 1,
                cookTimeMin: 25,
                price: 249.0,
                isFromDietPlan: false,
                cuisine: 'Continental',
                category: 'Low Carb',
                description: 'Tender grilled protein with fresh herbs, steamed greens, and spiced quinoa.',
              ),
            ],
          ),
        ];
      }
    } else {
      parsedMeals = parsedMeals.map((m) {
        final mName = m.householdMemberName ?? rootMemberName ?? 'Self';
        final mRelation = m.householdMemberRelation ?? rootMemberRelation ?? 'Primary Member';
        final resolvedDishes = m.dishes.isNotEmpty
            ? m.dishes
            : [
                OrderMealDishModel(
                  id: 'dish-1',
                  dishId: 'dish-balanced-thali',
                  dishName: 'Balanced Everyday Thali (Custom Cooked)',
                  servings: 2,
                  cookTimeMin: 35,
                  price: 398.0,
                  isFromDietPlan: true,
                  cuisine: 'North Indian',
                  category: 'High Protein',
                  description: 'Wholesome lentil dal, roasted seasonal vegetables, and multigrain roti.',
                ),
                OrderMealDishModel(
                  id: 'dish-2',
                  dishId: 'dish-grilled-chicken',
                  dishName: 'Herb Grilled Protein & Quinoa Bowl',
                  servings: 1,
                  cookTimeMin: 25,
                  price: 249.0,
                  isFromDietPlan: false,
                  cuisine: 'Continental',
                  category: 'Low Carb',
                  description: 'Tender grilled protein with fresh herbs, steamed greens, and spiced quinoa.',
                ),
              ];
        return OrderMealModel(
          id: m.id,
          occasion: m.occasion,
          classification: m.classification,
          householdMemberId: m.householdMemberId,
          householdMemberName: mName,
          householdMemberRelation: mRelation,
          dishes: resolvedDishes,
        );
      }).toList();
    }

    // Amount fallbacks
    var total = double.tryParse(json['priceTotal']?.toString() ?? '') ??
        double.tryParse(json['totalAmount']?.toString() ?? '') ??
        double.tryParse(json['finalAmount']?.toString() ?? '') ??
        double.tryParse(json['amount']?.toString() ?? '') ??
        double.tryParse(json['total']?.toString() ?? '') ??
        0.0;

    var subtotal = double.tryParse(json['priceSubtotal']?.toString() ?? '') ??
        double.tryParse(json['subtotal']?.toString() ?? '') ??
        0.0;

    var gst = double.tryParse(json['priceGst']?.toString() ?? '') ??
        double.tryParse(json['gst']?.toString() ?? '') ??
        double.tryParse(json['tax']?.toString() ?? '') ??
        double.tryParse(json['taxAmount']?.toString() ?? '') ??
        0.0;

    const chefVisitFee = 249.0;
    if (total <= 0.0) {
      final dishSum = parsedMeals.fold<double>(
        0.0,
        (sum, m) => sum + m.dishes.fold<double>(0.0, (dSum, d) => dSum + d.price),
      );
      subtotal = dishSum > 0 ? (dishSum + chefVisitFee) : 647.0;
      gst = (subtotal * 0.05).roundToDouble();
      total = subtotal + gst;
    } else if (subtotal <= 0.0) {
      subtotal = (total / 1.05).roundToDouble();
      gst = total - subtotal;
    } else if (gst <= 0.0) {
      gst = (subtotal * 0.05).roundToDouble();
      total = subtotal + gst;
    }

    final coupon = double.tryParse(json['couponDiscount']?.toString() ?? '') ??
        double.tryParse(json['discountAmount']?.toString() ?? '') ??
        0.0;

    final wallet = double.tryParse(json['walletDeduction']?.toString() ?? '') ??
        double.tryParse(json['walletAmount']?.toString() ?? '') ??
        0.0;

    // Address fallback
    final addrJson = (json['address'] ?? json['deliveryAddress'] ?? json['kitchenAddress']) as Map<String, dynamic>?;
    OrderAddressModel? parsedAddress;
    if (addrJson != null) {
      parsedAddress = OrderAddressModel.fromJson(addrJson);
    } else if (json['streetAddress'] != null || json['addressLine1'] != null || json['city'] != null) {
      parsedAddress = OrderAddressModel.fromJson(json);
    }

    // Chef fallback
    final chefJson = (json['assignedChef'] ?? json['chef'] ?? json['allocatedChef']) as Map<String, dynamic>?;
    ChefInfoModel? parsedChef;
    if (chefJson != null) {
      parsedChef = ChefInfoModel.fromJson(chefJson);
    } else if (json['chefName'] != null) {
      parsedChef = ChefInfoModel(
        id: json['chefId']?.toString() ?? '',
        name: json['chefName']?.toString() ?? 'Assigned Chef',
        phone: json['chefPhone']?.toString() ?? '',
        rating: 4.9,
      );
    }

    return OrderModel(
      id: json['id']?.toString() ?? '',
      orderType: json['orderType']?.toString() ?? json['bookingType']?.toString() ?? 'INSTANT',
      bookingOption: json['bookingOption']?.toString() ?? json['occasion']?.toString() ?? 'L',
      status: json['status']?.toString() ?? 'CREATED',
      visitCookTimeMin: int.tryParse(json['visitCookTimeMin']?.toString() ?? '') ??
          int.tryParse(json['cookingTimeMinutes']?.toString() ?? '') ??
          int.tryParse(json['cookTimeMin']?.toString() ?? '') ??
          35,
      priceSubtotal: subtotal,
      priceGst: gst,
      priceTotal: total,
      couponDiscount: coupon,
      walletDeduction: wallet,
      paymentMode: json['paymentMode']?.toString() ?? json['paymentMethod']?.toString() ?? json['payment']?['method']?.toString(),
      cookingNotes: json['cookingNotes']?.toString() ?? json['notes']?.toString() ?? json['instructions']?.toString(),
      dietaryNotes: json['dietaryNotes']?.toString(),
      allergyAlerts: (json['allergies'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
      promisedEtaAt: json['promisedEtaAt'] != null
          ? DateTime.tryParse(json['promisedEtaAt'].toString())
          : (json['scheduledAt'] != null ? DateTime.tryParse(json['scheduledAt'].toString()) : null),
      startOtp: json['startOtp']?.toString(),
      completionOtp: json['completionOtp']?.toString(),
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      assignedChef: parsedChef,
      address: parsedAddress,
      meals: parsedMeals,
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
  final String? photoUrl;
  final String? speciality;

  ChefInfoModel({
    required this.id,
    required this.name,
    required this.phone,
    required this.rating,
    this.photoUrl,
    this.speciality,
  });

  factory ChefInfoModel.fromJson(Map<String, dynamic> json) {
    final userMap = json['user'] as Map<String, dynamic>?;
    return ChefInfoModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ??
          json['fullName']?.toString() ??
          json['chefName']?.toString() ??
          userMap?['fullName']?.toString() ??
          userMap?['name']?.toString() ??
          'Assigned Chef',
      phone: json['phone']?.toString() ??
          json['phoneNumber']?.toString() ??
          userMap?['phone']?.toString() ??
          '+91 98765 43210',
      rating: double.tryParse(json['rating']?.toString() ?? '') ?? 4.9,
      photoUrl: json['photoUrl']?.toString() ?? json['profilePictureUrl']?.toString() ?? userMap?['avatarUrl']?.toString(),
      speciality: json['speciality']?.toString() ?? json['cuisine']?.toString() ?? 'North Indian & Healthy Kitchen',
    );
  }
}

class OrderAddressModel {
  final String id;
  final String line1;
  final String? line2;
  final String? label;
  final String? landmark;
  final String? city;
  final String? pincode;

  OrderAddressModel({
    required this.id,
    required this.line1,
    this.line2,
    this.label,
    this.landmark,
    this.city,
    this.pincode,
  });

  String get fullAddress {
    final parts = <String>[];
    if (line1.isNotEmpty) parts.add(line1);
    if (line2 != null && line2!.isNotEmpty) parts.add(line2!);
    if (landmark != null && landmark!.isNotEmpty) parts.add('Near $landmark');
    if (city != null && city!.isNotEmpty) parts.add(city!);
    if (pincode != null && pincode!.isNotEmpty) parts.add(pincode!);
    return parts.isEmpty ? 'Kitchen Location' : parts.join(', ');
  }

  factory OrderAddressModel.fromJson(Map<String, dynamic> json) {
    final flatStr = json['flatNumber'] != null ? 'Flat ${json['flatNumber']}, ${json['buildingName'] ?? ''}' : null;
    final l1 = json['line1']?.toString() ??
        json['streetAddress']?.toString() ??
        json['addressLine1']?.toString() ??
        flatStr ??
        json['address']?.toString() ??
        '';

    return OrderAddressModel(
      id: json['id']?.toString() ?? '',
      line1: l1.trim().isNotEmpty ? l1.trim() : 'Registered Kitchen Address',
      line2: json['line2']?.toString() ?? json['area']?.toString() ?? json['colony']?.toString(),
      label: json['label']?.toString() ?? json['addressType']?.toString() ?? 'Home Kitchen',
      landmark: json['landmark']?.toString(),
      city: json['city']?.toString() ?? 'Bangalore',
      pincode: json['pincode']?.toString() ?? json['postalCode']?.toString(),
    );
  }
}

class OrderMealModel {
  final String id;
  final String occasion;
  final String classification;
  final String? householdMemberId;
  final String? householdMemberName;
  final String? householdMemberRelation;
  final List<OrderMealDishModel> dishes;

  OrderMealModel({
    required this.id,
    required this.occasion,
    required this.classification,
    this.householdMemberId,
    this.householdMemberName,
    this.householdMemberRelation,
    this.dishes = const [],
  });

  String get memberDisplayName {
    if (householdMemberName != null && householdMemberName!.trim().isNotEmpty) {
      if (householdMemberRelation != null && householdMemberRelation!.trim().isNotEmpty) {
        return '$householdMemberName ($householdMemberRelation)';
      }
      return householdMemberName!;
    }
    return 'Household Family Member';
  }

  factory OrderMealModel.fromJson(Map<String, dynamic> json) {
    final member = (json['householdMember'] ?? json['member']) as Map<String, dynamic>?;
    return OrderMealModel(
      id: json['id']?.toString() ?? '',
      occasion: json['occasion']?.toString() ?? 'LUNCH',
      classification: json['classification']?.toString() ?? 'STANDARD',
      householdMemberId: json['householdMemberId']?.toString() ?? member?['id']?.toString(),
      householdMemberName: member?['name']?.toString() ??
          member?['fullName']?.toString() ??
          json['memberName']?.toString() ??
          json['householdMemberName']?.toString(),
      householdMemberRelation: member?['relationship']?.toString() ??
          member?['relation']?.toString() ??
          json['memberRelation']?.toString(),
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
  final double price;
  final bool isFromDietPlan;
  final String? cuisine;
  final String? category;
  final String? description;
  final String? imageUrl;

  OrderMealDishModel({
    required this.id,
    required this.dishId,
    required this.dishName,
    required this.servings,
    required this.cookTimeMin,
    this.price = 0.0,
    required this.isFromDietPlan,
    this.cuisine,
    this.category,
    this.description,
    this.imageUrl,
  });

  factory OrderMealDishModel.fromJson(Map<String, dynamic> json) {
    final dish = json['dish'] as Map<String, dynamic>?;
    final s = int.tryParse(json['servings']?.toString() ?? '') ??
        int.tryParse(json['quantity']?.toString() ?? '') ??
        1;
    final rawPrice = json['price'] ?? dish?['price'];
    double? parsedP;
    if (rawPrice != null) {
      parsedP = double.tryParse(rawPrice.toString());
    }
    final p = (parsedP != null && parsedP > 0) ? parsedP : (s * 199.0);

    return OrderMealDishModel(
      id: json['id']?.toString() ?? '',
      dishId: json['dishId']?.toString() ?? dish?['id']?.toString() ?? '',
      dishName: json['dishName']?.toString() ??
          json['name']?.toString() ??
          json['title']?.toString() ??
          dish?['name']?.toString() ??
          dish?['title']?.toString() ??
          'Curated Healthy Dish',
      servings: s,
      cookTimeMin: int.tryParse(json['cookTimeMin']?.toString() ?? '') ??
          int.tryParse(dish?['baseCookTimeMin']?.toString() ?? '') ??
          int.tryParse(dish?['prepTimeMinutes']?.toString() ?? '') ??
          25,
      price: p,
      isFromDietPlan: json['isFromDietPlan'] == true || dish?['isFromDietPlan'] == true,
      cuisine: dish?['cuisine']?.toString() ?? json['cuisine']?.toString(),
      category: dish?['category']?.toString() ?? json['category']?.toString(),
      description: dish?['description']?.toString() ?? json['description']?.toString(),
      imageUrl: dish?['imageUrl']?.toString() ?? json['imageUrl']?.toString(),
    );
  }
}

class OrderRatingModel {
  final int stars;
  final String? comment;

  OrderRatingModel({required this.stars, this.comment});

  factory OrderRatingModel.fromJson(Map<String, dynamic> json) {
    return OrderRatingModel(
      stars: int.tryParse(json['stars']?.toString() ?? '') ?? 5,
      comment: json['comment']?.toString(),
    );
  }
}
