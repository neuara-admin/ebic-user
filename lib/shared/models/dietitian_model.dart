class DietitianModel {
  final String id;
  final String name;
  final String? qualification;
  final String? specialization;
  final int? experienceYears;
  final String? bio;
  final String? languages;
  /// Null until the dietitian has been rated.
  final double? rating;
  final String? photoUrl;
  final List<DietitianSlotModel> availableSlots;

  DietitianModel({
    required this.id,
    required this.name,
    this.qualification,
    this.specialization,
    this.experienceYears,
    this.bio,
    this.languages,
    this.rating,
    this.photoUrl,
    this.availableSlots = const [],
  });

  factory DietitianModel.fromJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>?;
    final specs = json['specializations'];
    final specStr = json['specialization'] ??
        (specs is List && specs.isNotEmpty ? specs.join(', ') : null);

    final langs = json['languages'];
    final langStr = langs is List
        ? (langs.isEmpty ? null : langs.join(', '))
        : langs?.toString();

    return DietitianModel(
      id: json['id'] ?? '',
      name: user?['name'] ?? json['name'] ?? '',
      qualification: json['qualification'],
      specialization: specStr,
      experienceYears: int.tryParse(json['experienceYears']?.toString() ?? ''),
      bio: json['bio'],
      languages: langStr,
      rating: double.tryParse(json['rating']?.toString() ?? ''),
      photoUrl: json['photoUrl'],
      availableSlots: (json['availability'] as List<dynamic>?)
              ?.map((e) => DietitianSlotModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class DietitianSlotModel {
  final String id;
  final String dietitianId;
  final DateTime startsAt;
  final DateTime endsAt;
  final bool isBooked;

  DietitianSlotModel({
    required this.id,
    required this.dietitianId,
    required this.startsAt,
    required this.endsAt,
    this.isBooked = false,
  });

  factory DietitianSlotModel.fromJson(Map<String, dynamic> json) {
    return DietitianSlotModel(
      id: json['id'] ?? '',
      dietitianId: json['dietitianId'] ?? '',
      startsAt: json['startsAt'] != null
          ? DateTime.tryParse(json['startsAt']) ?? DateTime.now()
          : DateTime.now(),
      endsAt: json['endsAt'] != null
          ? DateTime.tryParse(json['endsAt']) ?? DateTime.now().add(const Duration(minutes: 45))
          : DateTime.now().add(const Duration(minutes: 45)),
      isBooked: json['isBooked'] ?? false,
    );
  }
}
