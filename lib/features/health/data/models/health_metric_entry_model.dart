class HealthMetricEntryModel {
  final String id;
  final String householdMemberId;
  final String metricType; // WEIGHT, HEIGHT, BMI, CALORIES, PROTEIN, WATER, STEPS, SLEEP_HOURS, ACTIVITY_MINUTES
  final double value;
  final String unit;
  final String source; // MANUAL, DERIVED, WEARABLE, APPLE_HEALTH, etc.
  final String? sourceReference;
  final String? notes;
  final String recordedAt;

  HealthMetricEntryModel({
    required this.id,
    required this.householdMemberId,
    required this.metricType,
    required this.value,
    required this.unit,
    this.source = 'MANUAL',
    this.sourceReference,
    this.notes,
    required this.recordedAt,
  });

  factory HealthMetricEntryModel.fromJson(Map<String, dynamic> json) {
    return HealthMetricEntryModel(
      id: json['id']?.toString() ?? '',
      householdMemberId: json['householdMemberId']?.toString() ?? '',
      metricType: json['metricType']?.toString() ?? '',
      value: double.tryParse(json['value']?.toString() ?? '0') ?? 0.0,
      unit: json['unit']?.toString() ?? '',
      source: json['source']?.toString() ?? 'MANUAL',
      sourceReference: json['sourceReference']?.toString(),
      notes: json['notes']?.toString(),
      recordedAt: json['recordedAt']?.toString() ?? DateTime.now().toIso8601String(),
    );
  }

  bool get isDerived => source == 'DERIVED';

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'memberId': householdMemberId,
      'metricType': metricType,
      'value': value,
      'unit': unit,
      'source': source,
      'notes': notes,
      'recordedAt': recordedAt,
    };
  }
}
