class HealthPermissionModel {
  final String id;
  final String householdMemberId;
  final String dataType; // WEIGHT, STEPS, SLEEP, ACTIVITY, HEART_RATE, ALLERGIES, DIETARY_RESTRICTIONS, ALL
  final String provider; // DIETITIAN, CHEF, EBIC_SYSTEM
  final String purpose;
  final String status; // GRANTED, REVOKED, EXPIRED, PENDING
  final String? grantedAt;
  final String? revokedAt;

  HealthPermissionModel({
    required this.id,
    required this.householdMemberId,
    required this.dataType,
    required this.provider,
    required this.purpose,
    required this.status,
    this.grantedAt,
    this.revokedAt,
  });

  factory HealthPermissionModel.fromJson(Map<String, dynamic> json) {
    return HealthPermissionModel(
      id: json['id']?.toString() ?? '',
      householdMemberId: json['householdMemberId']?.toString() ?? '',
      dataType: json['dataType']?.toString() ?? '',
      provider: json['provider']?.toString() ?? 'EBIC_SYSTEM',
      purpose: json['purpose']?.toString() ?? '',
      status: json['status']?.toString() ?? 'GRANTED',
      grantedAt: json['grantedAt']?.toString(),
      revokedAt: json['revokedAt']?.toString(),
    );
  }

  bool get isGranted => status == 'GRANTED';

  Map<String, dynamic> toJson() {
    return {
      'dataType': dataType,
      'provider': provider,
      'purpose': purpose,
      'status': status,
    };
  }
}
