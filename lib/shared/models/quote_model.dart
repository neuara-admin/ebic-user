class QuoteModel {
  final String quoteId;
  final int cookingTimeMinutes;
  final double chefServiceCharge;
  final double itemCharges;
  final double healthPassBenefit;
  final double discount;
  final double promotion;
  final double tax;
  final double subtotal;
  final double total;
  final String currency;
  final DateTime? expiresAt;
  final List<QuoteItemModel> items;

  QuoteModel({
    required this.quoteId,
    required this.cookingTimeMinutes,
    required this.chefServiceCharge,
    required this.itemCharges,
    required this.healthPassBenefit,
    required this.discount,
    required this.promotion,
    required this.tax,
    required this.subtotal,
    required this.total,
    this.currency = 'INR',
    this.expiresAt,
    this.items = const [],
  });

  factory QuoteModel.fromJson(Map<String, dynamic> json) {
    return QuoteModel(
      quoteId: json['id'] ?? json['quoteId'] ?? json['quote_id'] ?? '',
      cookingTimeMinutes: json['cookingTimeMinutes'] ?? json['cooking_time_minutes'] ?? 35,
      chefServiceCharge: double.tryParse(
              (json['chefServiceCharge'] ?? json['chef_service_charge'] ?? 249).toString()) ??
          249.0,
      itemCharges: double.tryParse(
              (json['itemCharges'] ?? json['item_charges'] ?? 150).toString()) ??
          150.0,
      healthPassBenefit: double.tryParse(
              (json['healthPassBenefit'] ?? json['health_pass_benefit'] ?? 0).toString()) ??
          0.0,
      discount: double.tryParse(
              (json['discount'] ?? json['discountAmount'] ?? 0).toString()) ??
          0.0,
      promotion: double.tryParse((json['promotion'] ?? 0).toString()) ?? 0.0,
      tax: double.tryParse(
              (json['tax'] ?? json['taxAmount'] ?? json['gst'] ?? 20).toString()) ??
          20.0,
      subtotal: double.tryParse(
              (json['subtotal'] ?? json['subTotalRupees'] ?? 399).toString()) ??
          399.0,
      total: double.tryParse(
              (json['total'] ?? json['totalRupees'] ?? json['finalAmount'] ?? 419).toString()) ??
          419.0,
      currency: json['currency'] ?? 'INR',
      expiresAt: json['expiresAt'] != null || json['expires_at'] != null
          ? DateTime.tryParse(json['expiresAt'] ?? json['expires_at'])
          : null,
      items: (json['items'] as List<dynamic>?)
              ?.map((e) => QuoteItemModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class QuoteItemModel {
  final String itemType;
  final String? description;
  final int quantity;
  final double unitPrice;
  final double total;

  QuoteItemModel({
    required this.itemType,
    this.description,
    required this.quantity,
    required this.unitPrice,
    required this.total,
  });

  factory QuoteItemModel.fromJson(Map<String, dynamic> json) {
    return QuoteItemModel(
      itemType: json['itemType'] ?? json['item_type'] ?? 'CHEF_VISIT',
      description: json['description'] ?? 'Home Chef Service',
      quantity: json['quantity'] ?? 1,
      unitPrice: double.tryParse((json['unitPrice'] ?? json['unit_price'] ?? 0).toString()) ?? 0.0,
      total: double.tryParse((json['total'] ?? json['lineTotal'] ?? 0).toString()) ?? 0.0,
    );
  }
}
