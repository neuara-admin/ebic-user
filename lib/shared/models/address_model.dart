class AddressModel {
  final String id;
  final String? label; // Home, Work, Other
  final String line1;
  final String? line2;
  final double lat;
  final double lng;
  final String? hubId;
  final String? hubName;
  final bool isDefault;

  AddressModel({
    required this.id,
    this.label,
    required this.line1,
    this.line2,
    required this.lat,
    required this.lng,
    this.hubId,
    this.hubName,
    this.isDefault = false,
  });

  String get type => label ?? 'HOME';
  String get formattedAddress => line2 != null && line2!.isNotEmpty ? '$line1, $line2' : line1;
  bool get isServiceable => hubId != null && hubId!.isNotEmpty;

  factory AddressModel.fromJson(Map<String, dynamic> json) {
    final hub = json['hub'] as Map<String, dynamic>?;
    return AddressModel(
      id: json['id'] ?? '',
      label: json['label'] ?? 'Home',
      line1: json['line1'] ?? '',
      line2: json['line2'],
      lat: double.tryParse(json['lat']?.toString() ?? '0') ?? 0.0,
      lng: double.tryParse(json['lng']?.toString() ?? '0') ?? 0.0,
      hubId: json['hubId'] ?? hub?['id'],
      hubName: hub?['name'],
      isDefault: json['isDefault'] ?? false,
    );
  }
}

class ServiceabilityResult {
  final bool isServiceable;
  final String? hubId;
  final String? hubName;
  final String message;

  ServiceabilityResult({
    required this.isServiceable,
    this.hubId,
    this.hubName,
    required this.message,
  });

  factory ServiceabilityResult.fromJson(Map<String, dynamic> json) {
    return ServiceabilityResult(
      isServiceable: json['serviceable'] == true || json['isServiceable'] == true,
      hubId: json['hubId'] ?? json['hub']?['id'],
      hubName: json['hubName'] ?? json['hub']?['name'],
      message: json['message'] ?? (json['serviceable'] == true ? 'Serviceable' : 'Not serviceable'),
    );
  }
}
