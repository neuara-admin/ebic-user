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
  final double baseVisitCharge;
  final double cookingCharge;
  final double surgeAmount;
  final double platformFee;
  final double timePackBenefit;
  final double freeBookingBenefit;
  final double creditsApplied;
  final double gstRate;
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
    this.baseVisitCharge = 199.0,
    this.cookingCharge = 0.0,
    this.surgeAmount = 0.0,
    this.platformFee = 0.0,
    this.timePackBenefit = 0.0,
    this.freeBookingBenefit = 0.0,
    this.creditsApplied = 0.0,
    this.gstRate = 0.05,
    this.currency = 'INR',
    this.expiresAt,
    this.items = const [],
  });

  factory QuoteModel.fromJson(Map<String, dynamic> json) {
    return QuoteModel(
      quoteId: json['id'] ?? json['quoteId'] ?? json['quote_id'] ?? json['quoteNumber'] ?? '',
      cookingTimeMinutes: json['cookingTimeMinutes'] ?? json['cooking_time_minutes'] ?? 35,
      chefServiceCharge: double.tryParse(
              (json['chefServiceCharge'] ?? json['chef_service_charge'] ?? 0).toString()) ??
          0.0,
      itemCharges: double.tryParse(
              (json['itemCharges'] ?? json['item_charges'] ?? 0).toString()) ??
          0.0,
      healthPassBenefit: double.tryParse(
              (json['healthPassBenefit'] ?? json['health_pass_benefit'] ?? 0).toString()) ??
          0.0,
      discount: double.tryParse(
              (json['discount'] ?? json['discountTotal'] ?? json['discountAmount'] ?? 0).toString()) ??
          0.0,
      promotion: double.tryParse((json['promotion'] ?? json['free_booking_benefit'] ?? json['time_pack_benefit'] ?? 0).toString()) ?? 0.0,
      tax: double.tryParse(
              (json['tax'] ?? json['taxTotal'] ?? json['taxAmount'] ?? json['gst'] ?? 0).toString()) ??
          0.0,
      subtotal: double.tryParse(
              (json['subtotal'] ?? json['subTotalRupees'] ?? 0).toString()) ??
          0.0,
      total: double.tryParse(
              (json['total'] ?? json['grandTotal'] ?? json['grand_total'] ?? json['customer_payable'] ?? json['customerPayable'] ?? json['totalRupees'] ?? json['finalAmount'] ?? 0).toString()) ??
          0.0,
      baseVisitCharge: double.tryParse(
              (json['baseVisitCharge'] ?? json['base_visit_charge'] ?? 0).toString()) ??
          0.0,
      cookingCharge: double.tryParse(
              (json['cooking_charge'] ?? json['cookTimeCharge'] ?? json['cookingCharge'] ?? 0).toString()) ??
          0.0,
      surgeAmount: double.tryParse(
              (json['surge_amount'] ?? json['surgeAmount'] ?? 0).toString()) ??
          0.0,
      platformFee: double.tryParse(
              (json['platform_fee'] ?? json['platformFee'] ?? 0).toString()) ??
          0.0,
      timePackBenefit: double.tryParse(
              (json['time_pack_benefit'] ?? json['timePackBenefit'] ?? 0).toString()) ??
          0.0,
      freeBookingBenefit: double.tryParse(
              (json['free_booking_benefit'] ?? json['freeBookingBenefit'] ?? 0).toString()) ??
          0.0,
      creditsApplied: double.tryParse(
              (json['credits_applied'] ?? json['creditsApplied'] ?? 0).toString()) ??
          0.0,
      gstRate: double.tryParse(
              (json['gst_rate'] ?? json['gstRate'] ?? 0.05).toString()) ??
          0.05,
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
  final String? referenceId;
  final String? description;
  final int quantity;
  final double unitPrice;
  final double total;

  QuoteItemModel({
    required this.itemType,
    this.referenceId,
    this.description,
    required this.quantity,
    required this.unitPrice,
    required this.total,
  });

  factory QuoteItemModel.fromJson(Map<String, dynamic> json) {
    return QuoteItemModel(
      itemType: json['itemType'] ?? json['item_type'] ?? 'CHEF_VISIT',
      referenceId: (json['referenceId'] ?? json['reference_id'])?.toString(),
      description: json['description'] ?? 'Home Chef Service',
      quantity: json['quantity'] ?? 1,
      unitPrice: double.tryParse((json['unitPrice'] ?? json['unit_price'] ?? 0).toString()) ?? 0.0,
      total: double.tryParse((json['total'] ?? json['lineTotal'] ?? 0).toString()) ?? 0.0,
    );
  }
}
