class OrderPreparationChecklistModel {
  final String orderId;
  final List<PreparationItemModel> items;
  final int readyCount;
  final int totalCount;
  final bool allReady;
  final String? updatedAt;

  OrderPreparationChecklistModel({
    required this.orderId,
    required this.items,
    required this.readyCount,
    required this.totalCount,
    required this.allReady,
    this.updatedAt,
  });

  factory OrderPreparationChecklistModel.fromJson(Map<String, dynamic> json) {
    final list = (json['items'] as List<dynamic>?)
            ?.map((e) => PreparationItemModel.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];
    return OrderPreparationChecklistModel(
      orderId: json['orderId'] ?? '',
      items: list,
      readyCount: json['readyCount'] ?? list.filterReadyCount(),
      totalCount: json['totalCount'] ?? list.length,
      allReady: json['allReady'] ?? (list.isNotEmpty && list.every((i) => i.isReady)),
      updatedAt: json['updatedAt'],
    );
  }
}

extension PrepListExt on List<PreparationItemModel> {
  int filterReadyCount() => where((i) => i.isReady).length;
}

class PreparationItemModel {
  final String id;
  final String ingredientId;
  final String name;
  final double quantity;
  final String unit;
  final bool customerProvides;
  final bool ebicProvides;
  final bool optional;
  final bool preparationRequired;
  final String? preparationInstructions;
  final String? preparationForm;
  final List<String> allergens;
  String status; // PENDING, READY, NOT_AVAILABLE, SUBSTITUTION_REQUESTED, REMOVED, SUBSTITUTED
  String? note;

  PreparationItemModel({
    required this.id,
    required this.ingredientId,
    required this.name,
    required this.quantity,
    required this.unit,
    this.customerProvides = true,
    this.ebicProvides = false,
    this.optional = false,
    this.preparationRequired = false,
    this.preparationInstructions,
    this.preparationForm,
    this.allergens = const [],
    this.status = 'PENDING',
    this.note,
  });

  bool get isReady => status == 'READY';
  bool get isPending => status == 'PENDING';
  bool get isUnavailable => status == 'NOT_AVAILABLE';
  bool get isSubstitutionRequested => status == 'SUBSTITUTION_REQUESTED';
  bool get isSubstituted => status == 'SUBSTITUTED';
  bool get isRemoved => status == 'REMOVED';

  factory PreparationItemModel.fromJson(Map<String, dynamic> json) {
    return PreparationItemModel(
      id: json['id'] ?? '',
      ingredientId: json['ingredientId'] ?? '',
      name: json['name'] ?? '',
      quantity: double.tryParse(json['quantity']?.toString() ?? '0') ?? 0.0,
      unit: json['unit'] ?? 'g',
      customerProvides: json['customerProvides'] ?? true,
      ebicProvides: json['ebicProvides'] ?? false,
      optional: json['optional'] ?? false,
      preparationRequired: json['preparationRequired'] ?? false,
      preparationInstructions: json['preparationInstructions'],
      preparationForm: json['preparationForm'],
      allergens: (json['allergens'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      status: json['status'] ?? 'PENDING',
      note: json['note'],
    );
  }
}
