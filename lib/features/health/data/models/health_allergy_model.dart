class HealthAllergyModel {
  final String allergenId;
  final String name;
  final String severity; // UNKNOWN, MILD, MODERATE, SEVERE
  final String status; // ACTIVE, RESOLVED, INACTIVE
  final String source; // CUSTOMER_REPORTED, DIETITIAN_CONFIRMED, SYSTEM_IMPORTED
  final String? notes;
  final String? verifiedByUserId;
  final String? verifiedAt;

  HealthAllergyModel({
    required this.allergenId,
    required this.name,
    this.severity = 'UNKNOWN',
    this.status = 'ACTIVE',
    this.source = 'CUSTOMER_REPORTED',
    this.notes,
    this.verifiedByUserId,
    this.verifiedAt,
  });

  factory HealthAllergyModel.fromJson(Map<String, dynamic> json) {
    final allergenObj = json['allergen'];
    final allergenName = allergenObj is Map ? (allergenObj['name']?.toString() ?? '') : '';

    return HealthAllergyModel(
      allergenId: json['allergenId']?.toString() ?? '',
      name: allergenName.isNotEmpty ? allergenName : (json['name']?.toString() ?? 'Allergy'),
      severity: json['severity']?.toString() ?? 'UNKNOWN',
      status: json['status']?.toString() ?? 'ACTIVE',
      source: json['source']?.toString() ?? 'CUSTOMER_REPORTED',
      notes: json['notes']?.toString(),
      verifiedByUserId: json['verifiedByUserId']?.toString(),
      verifiedAt: json['verifiedAt']?.toString(),
    );
  }

  bool get isDietitianConfirmed => source == 'DIETITIAN_CONFIRMED';

  Map<String, dynamic> toJson() {
    return {
      'allergenId': allergenId,
      'severity': severity,
      'status': status,
      'source': source,
      'notes': notes,
    };
  }
}
