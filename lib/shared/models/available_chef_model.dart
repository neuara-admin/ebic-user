/// One chef in the "Choose your chef" list (GET /chef-bookings/available-chefs).
/// Availability is decided by the backend with the same rules it dispatches
/// with — the app never infers it.
class AvailableChefModel {
  final String id;
  final String name;
  final String? photoUrl;
  final String hubName;
  final bool fromYourHub;
  final double? rating;
  final int ratingCount;
  final int? experienceYears;
  final List<String> specialities;
  final int completedVisits;
  final int cookedForYouCount;
  final double? distanceKm;
  final int? etaMinutes;
  final bool available;
  final String status;
  final String statusLabel;
  final DateTime? availableAt;
  final bool recommended;
  final List<ChefReviewModel> recentReviews;

  const AvailableChefModel({
    required this.id,
    required this.name,
    this.photoUrl,
    required this.hubName,
    required this.fromYourHub,
    this.rating,
    required this.ratingCount,
    this.experienceYears,
    required this.specialities,
    required this.completedVisits,
    required this.cookedForYouCount,
    this.distanceKm,
    this.etaMinutes,
    required this.available,
    required this.status,
    required this.statusLabel,
    this.availableAt,
    required this.recommended,
    required this.recentReviews,
  });

  factory AvailableChefModel.fromJson(Map<String, dynamic> json) {
    return AvailableChefModel(
      id: json['id'].toString(),
      name: json['name']?.toString() ?? 'Chef',
      photoUrl: json['photoUrl']?.toString(),
      hubName: json['hubName']?.toString() ?? '',
      fromYourHub: json['fromYourHub'] == true,
      rating: (json['rating'] as num?)?.toDouble(),
      ratingCount: (json['ratingCount'] as num?)?.toInt() ?? 0,
      experienceYears: (json['experienceYears'] as num?)?.toInt(),
      specialities: (json['specialities'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      completedVisits: (json['completedVisits'] as num?)?.toInt() ?? 0,
      cookedForYouCount: (json['cookedForYouCount'] as num?)?.toInt() ?? 0,
      distanceKm: (json['distanceKm'] as num?)?.toDouble(),
      etaMinutes: (json['etaMinutes'] as num?)?.toInt(),
      available: json['available'] == true,
      status: json['status']?.toString() ?? 'UNAVAILABLE',
      statusLabel: json['statusLabel']?.toString() ?? 'Unavailable',
      availableAt: DateTime.tryParse(json['availableAt']?.toString() ?? '')?.toLocal(),
      recommended: json['recommended'] == true,
      recentReviews: (json['recentReviews'] as List<dynamic>? ?? [])
          .whereType<Map>()
          .map((r) => ChefReviewModel.fromJson(Map<String, dynamic>.from(r)))
          .toList(),
    );
  }
}

class ChefReviewModel {
  final int stars;
  final String comment;
  final DateTime? createdAt;

  const ChefReviewModel({required this.stars, required this.comment, this.createdAt});

  factory ChefReviewModel.fromJson(Map<String, dynamic> json) => ChefReviewModel(
        stars: (json['stars'] as num?)?.toInt() ?? 0,
        comment: json['comment']?.toString() ?? '',
        createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '')?.toLocal(),
      );
}

class AvailableChefsResult {
  final String? hubName;
  final bool hubOpen;
  final int maxTravelTimeMin;
  final int availableCount;
  final String? recommendedChefId;
  final List<AvailableChefModel> chefs;

  const AvailableChefsResult({
    this.hubName,
    required this.hubOpen,
    required this.maxTravelTimeMin,
    required this.availableCount,
    this.recommendedChefId,
    required this.chefs,
  });

  factory AvailableChefsResult.fromJson(Map<String, dynamic> json) {
    final hub = json['hub'] is Map ? Map<String, dynamic>.from(json['hub'] as Map) : null;
    return AvailableChefsResult(
      hubName: hub?['name']?.toString(),
      hubOpen: hub?['open'] == true,
      maxTravelTimeMin: (hub?['maxTravelTimeMin'] as num?)?.toInt() ?? 25,
      availableCount: (json['availableCount'] as num?)?.toInt() ?? 0,
      recommendedChefId: json['recommendedChefId']?.toString(),
      chefs: (json['chefs'] as List<dynamic>? ?? [])
          .whereType<Map>()
          .map((c) => AvailableChefModel.fromJson(Map<String, dynamic>.from(c)))
          .toList(),
    );
  }

  List<AvailableChefModel> get availableChefs => chefs.where((c) => c.available).toList();
  List<AvailableChefModel> get unavailableChefs => chefs.where((c) => !c.available).toList();
}
