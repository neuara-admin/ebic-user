import 'package:flutter/material.dart';

enum AddressServiceabilityStatus {
  unknown,
  checking,
  serviceable,
  notServiceable,
  temporarilyUnavailable,
  requiresReview,
}

/// Module 3 — Section 29 & 42: Delivery Kitchen Address Data Model
class AddressModel {
  final String id;
  final String label; // HOME, VILLA, PARENTS, FARMHOUSE, OTHER
  final String? recipientName;
  final String? phone;
  final String line1;
  final String? line2;
  final String? landmark;
  final String? locality;
  final String? city;
  final String? state;
  final String? postalCode;
  final String country;
  final double lat;
  final double lng;
  final String? hubId;
  final String? hubName;
  final String geocodingStatus;
  final bool isDefault;
  final AddressServiceabilityStatus serviceabilityStatus;

  AddressModel({
    required this.id,
    this.label = 'HOME',
    this.recipientName,
    this.phone,
    required this.line1,
    this.line2,
    this.landmark,
    this.locality,
    this.city,
    this.state,
    this.postalCode,
    this.country = 'India',
    required this.lat,
    required this.lng,
    this.hubId,
    this.hubName,
    this.geocodingStatus = 'VERIFIED',
    this.isDefault = false,
    this.serviceabilityStatus = AddressServiceabilityStatus.unknown,
  });

  String get type => label.toUpperCase();

  String get kitchenLabelDisplayName {
    final t = label.trim();
    if (t.toUpperCase() == 'HOME') {
      return 'Home';
    }
    if (t.toUpperCase() == 'OTHER') {
      return 'Other';
    }
    return t;
  }

  IconData get kitchenIcon {
    final l = label.toLowerCase();
    if (l == 'home' || l.contains('home')) {
      return Icons.home_rounded;
    }
    if (l.contains('villa')) {
      return Icons.villa_rounded;
    }
    if (l.contains('parent') || l.contains('family')) {
      return Icons.family_restroom_rounded;
    }
    if (l.contains('farm')) {
      return Icons.cottage_rounded;
    }
    return Icons.location_on_rounded;
  }

  String get formattedAddress {
    final parts = <String>[];
    if (line1.isNotEmpty) parts.add(line1);
    if (line2 != null && line2!.isNotEmpty) parts.add(line2!);
    if (landmark != null && landmark!.isNotEmpty) parts.add('Near $landmark');
    if (city != null && city!.isNotEmpty) parts.add(city!);
    if (postalCode != null && postalCode!.isNotEmpty) parts.add(postalCode!);
    return parts.join(', ');
  }

  bool get isServiceable =>
      hubId != null &&
      hubId!.isNotEmpty &&
      serviceabilityStatus != AddressServiceabilityStatus.notServiceable &&
      serviceabilityStatus != AddressServiceabilityStatus.temporarilyUnavailable;

  String get serviceabilityBadgeText {
    switch (serviceabilityStatus) {
      case AddressServiceabilityStatus.serviceable:
        return 'SERVICEABLE';
      case AddressServiceabilityStatus.notServiceable:
        return 'UNSERVICEABLE';
      case AddressServiceabilityStatus.temporarilyUnavailable:
        return 'PAUSED';
      case AddressServiceabilityStatus.requiresReview:
        return 'REVIEW';
      case AddressServiceabilityStatus.checking:
        return 'CHECKING';
      case AddressServiceabilityStatus.unknown:
        return isServiceable ? 'SERVICEABLE' : 'UNCHECKED';
    }
  }

  factory AddressModel.fromJson(Map<String, dynamic> json) {
    final hub = json['hub'] as Map<String, dynamic>?;
    final statusStr = json['status']?.toString().toUpperCase();

    AddressServiceabilityStatus status = AddressServiceabilityStatus.unknown;
    if (statusStr == 'SERVICEABLE') {
      status = AddressServiceabilityStatus.serviceable;
    } else if (statusStr == 'NOT_SERVICEABLE' || statusStr == 'OUTSIDE_SERVICE_AREA') {
      status = AddressServiceabilityStatus.notServiceable;
    } else if (statusStr == 'TEMPORARILY_UNAVAILABLE') {
      status = AddressServiceabilityStatus.temporarilyUnavailable;
    } else if (statusStr == 'REQUIRES_REVIEW') {
      status = AddressServiceabilityStatus.requiresReview;
    } else if (json['hubId'] != null || hub?['id'] != null) {
      status = AddressServiceabilityStatus.serviceable;
    }

    // Normalize legacy labels like 'WORK' or 'Office' to 'VILLA'
    String rawLabel = (json['label'] ?? 'HOME').toString().toUpperCase();
    if (rawLabel == 'WORK' || rawLabel == 'OFFICE') {
      rawLabel = 'VILLA';
    }

    return AddressModel(
      id: json['id'] ?? '',
      label: rawLabel,
      recipientName: json['recipientName'],
      phone: json['phone'],
      line1: json['line1'] ?? '',
      line2: json['line2'],
      landmark: json['landmark'],
      locality: json['locality'],
      city: json['city'] ?? 'Hyderabad',
      state: json['state'] ?? 'Telangana',
      postalCode: json['postalCode'],
      country: json['country'] ?? 'India',
      lat: double.tryParse(json['lat']?.toString() ?? '0') ?? 17.4319,
      lng: double.tryParse(json['lng']?.toString() ?? '0') ?? 78.4073,
      hubId: json['hubId'] ?? hub?['id'],
      hubName: hub?['name'] ?? json['hubName'],
      geocodingStatus: json['geocodingStatus'] ?? 'VERIFIED',
      isDefault: json['isDefault'] == true,
      serviceabilityStatus: status,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'label': label,
      'recipientName': recipientName,
      'phone': phone,
      'line1': line1,
      'line2': line2,
      'landmark': landmark,
      'locality': locality,
      'city': city,
      'state': state,
      'postalCode': postalCode,
      'country': country,
      'lat': lat,
      'lng': lng,
      'hubId': hubId,
      'hubName': hubName,
      'geocodingStatus': geocodingStatus,
      'isDefault': isDefault,
    };
  }

  AddressModel copyWith({
    String? id,
    String? label,
    String? recipientName,
    String? phone,
    String? line1,
    String? line2,
    String? landmark,
    String? locality,
    String? city,
    String? state,
    String? postalCode,
    String? country,
    double? lat,
    double? lng,
    String? hubId,
    String? hubName,
    String? geocodingStatus,
    bool? isDefault,
    AddressServiceabilityStatus? serviceabilityStatus,
  }) {
    return AddressModel(
      id: id ?? this.id,
      label: label ?? this.label,
      recipientName: recipientName ?? this.recipientName,
      phone: phone ?? this.phone,
      line1: line1 ?? this.line1,
      line2: line2 ?? this.line2,
      landmark: landmark ?? this.landmark,
      locality: locality ?? this.locality,
      city: city ?? this.city,
      state: state ?? this.state,
      postalCode: postalCode ?? this.postalCode,
      country: country ?? this.country,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      hubId: hubId ?? this.hubId,
      hubName: hubName ?? this.hubName,
      geocodingStatus: geocodingStatus ?? this.geocodingStatus,
      isDefault: isDefault ?? this.isDefault,
      serviceabilityStatus: serviceabilityStatus ?? this.serviceabilityStatus,
    );
  }
}

class ServiceabilityResult {
  final bool isServiceable;
  final String? hubId;
  final String? hubName;
  final String message;
  final AddressServiceabilityStatus status;

  ServiceabilityResult({
    required this.isServiceable,
    this.hubId,
    this.hubName,
    required this.message,
    this.status = AddressServiceabilityStatus.unknown,
  });

  factory ServiceabilityResult.fromJson(Map<String, dynamic> json) {
    final statusStr = json['status']?.toString().toUpperCase();
    AddressServiceabilityStatus status = AddressServiceabilityStatus.unknown;
    final isServ = json['serviceable'] == true || json['isServiceable'] == true;

    if (statusStr == 'SERVICEABLE' || (isServ && statusStr == null)) {
      status = AddressServiceabilityStatus.serviceable;
    } else if (statusStr == 'NOT_SERVICEABLE' || json['reasonCode'] == 'OUTSIDE_SERVICE_AREA') {
      status = AddressServiceabilityStatus.notServiceable;
    } else if (statusStr == 'TEMPORARILY_UNAVAILABLE') {
      status = AddressServiceabilityStatus.temporarilyUnavailable;
    } else if (statusStr == 'REQUIRES_REVIEW') {
      status = AddressServiceabilityStatus.requiresReview;
    }

    final hub = json['hub'] as Map<String, dynamic>?;
    final hubName = json['hubName'] ?? hub?['name'];

    return ServiceabilityResult(
      isServiceable: isServ,
      hubId: json['hubId'] ?? hub?['id'],
      hubName: hubName,
      message: json['message'] ??
          (isServ
              ? (hubName != null
                  ? 'Chef service is available at this address ($hubName).'
                  : 'Chef service is available at this address.')
              : "Chef service isn't currently available at this address."),
      status: status,
    );
  }
}
