import 'health_allergy_model.dart';
import 'health_goal_model.dart';

class HealthProfileModel {
  final String id;
  final String householdMemberId;
  final String profileStatus;
  final String? currentVersionId;
  final String? dateOfBirth;
  final String? biologicalSex;
  final String activityLevel; // SEDENTARY, LIGHT, MODERATE, HIGH, VERY_HIGH, UNKNOWN
  final Map<String, dynamic> lifestyle;
  final double? heightCm;
  final double? currentWeightKg;
  final String? healthGoalsText;
  final List<HealthAllergyModel> allergies;
  final List<DietaryRestrictionModel> dietaryRestrictions;
  final List<HealthGoalModel> goals;
  final Map<String, dynamic> latestMetrics;
  final String? updatedAt;

  HealthProfileModel({
    required this.id,
    required this.householdMemberId,
    this.profileStatus = 'ACTIVE',
    this.currentVersionId,
    this.dateOfBirth,
    this.biologicalSex,
    this.activityLevel = 'UNKNOWN',
    this.lifestyle = const {},
    this.heightCm,
    this.currentWeightKg,
    this.healthGoalsText,
    this.allergies = const [],
    this.dietaryRestrictions = const [],
    this.goals = const [],
    this.latestMetrics = const {},
    this.updatedAt,
  });

  factory HealthProfileModel.fromJson(Map<String, dynamic> json) {
    return HealthProfileModel(
      id: json['id']?.toString() ?? '',
      householdMemberId: json['householdMemberId']?.toString() ?? '',
      profileStatus: json['profileStatus']?.toString() ?? 'ACTIVE',
      currentVersionId: json['currentVersionId']?.toString(),
      dateOfBirth: json['dateOfBirth']?.toString(),
      biologicalSex: json['biologicalSex']?.toString(),
      activityLevel: json['activityLevel']?.toString() ?? 'UNKNOWN',
      lifestyle: json['lifestyle'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(json['lifestyle'])
          : {},
      heightCm: json['heightCm'] != null ? double.tryParse(json['heightCm'].toString()) : null,
      currentWeightKg: json['currentWeightKg'] != null
          ? double.tryParse(json['currentWeightKg'].toString())
          : null,
      healthGoalsText: json['healthGoals']?.toString(),
      allergies: (json['allergens'] as List<dynamic>?)
              ?.map((item) => HealthAllergyModel.fromJson(item as Map<String, dynamic>))
              .toList() ??
          [],
      dietaryRestrictions: (json['dietaryRestrictions'] as List<dynamic>?)
              ?.map((item) => DietaryRestrictionModel.fromJson(item as Map<String, dynamic>))
              .toList() ??
          [],
      goals: (json['goals'] as List<dynamic>?)
              ?.map((item) => HealthGoalModel.fromJson(item as Map<String, dynamic>))
              .toList() ??
          [],
      latestMetrics: json['latestMetrics'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(json['latestMetrics'])
          : {},
      updatedAt: json['updatedAt']?.toString(),
    );
  }

  /// Derived BMI from backend metrics or canonical calculation
  double? get bmi {
    if (latestMetrics.containsKey('BMI')) {
      final bmiObj = latestMetrics['BMI'];
      if (bmiObj is Map && bmiObj['value'] != null) {
        return double.tryParse(bmiObj['value'].toString());
      }
    }
    if (heightCm != null && currentWeightKg != null && heightCm! > 0) {
      final heightM = heightCm! / 100.0;
      return double.parse((currentWeightKg! / (heightM * heightM)).toStringAsFixed(1));
    }
    return null;
  }

  String get bmiCategory {
    final val = bmi;
    if (val == null) return 'Not Calculated';
    if (val < 18.5) return 'Underweight';
    if (val < 25.0) return 'Normal weight';
    if (val < 30.0) return 'Overweight';
    return 'Obese';
  }

  String get formattedActivityLevel {
    switch (activityLevel) {
      case 'SEDENTARY':
        return 'Sedentary';
      case 'LIGHT':
        return 'Lightly Active';
      case 'MODERATE':
        return 'Moderately Active';
      case 'HIGH':
        return 'Very Active';
      case 'VERY_HIGH':
        return 'Extremely Active';
      default:
        return 'Not Specified';
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'memberId': householdMemberId,
      'dateOfBirth': dateOfBirth,
      'biologicalSex': biologicalSex,
      'heightCm': heightCm,
      'currentWeightKg': currentWeightKg,
      'activityLevel': activityLevel,
      'lifestyle': lifestyle,
      'healthGoals': healthGoalsText,
    };
  }
}

class DietaryRestrictionModel {
  final String dietaryTagId;
  final String name;
  final String source;
  final String status;

  DietaryRestrictionModel({
    required this.dietaryTagId,
    required this.name,
    this.source = 'CUSTOMER_REPORTED',
    this.status = 'ACTIVE',
  });

  factory DietaryRestrictionModel.fromJson(Map<String, dynamic> json) {
    final tagObj = json['dietaryTag'];
    final tagName = tagObj is Map ? (tagObj['name']?.toString() ?? '') : '';
    return DietaryRestrictionModel(
      dietaryTagId: json['dietaryTagId']?.toString() ?? '',
      name: tagName.isNotEmpty ? tagName : (json['name']?.toString() ?? 'Dietary Restriction'),
      source: json['source']?.toString() ?? 'CUSTOMER_REPORTED',
      status: json['status']?.toString() ?? 'ACTIVE',
    );
  }
}
