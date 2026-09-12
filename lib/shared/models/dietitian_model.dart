class DietitianModel {
  final String id;
  final String name;
  final String? qualification;
  final String? specialization;
  final int experienceYears;
  final String? bio;
  final String? languages;
  final double rating;
  final String? photoUrl;
  final List<DietitianSlotModel> availableSlots;
  final String? hubId;
  final String? hubName;
  final String? hubCode;

  DietitianModel({
    required this.id,
    required this.name,
    this.qualification,
    this.specialization,
    this.experienceYears = 5,
    this.bio,
    this.languages,
    this.rating = 4.9,
    this.photoUrl,
    this.availableSlots = const [],
    this.hubId,
    this.hubName,
    this.hubCode,
  });

  factory DietitianModel.fromJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>?;
    final specs = json['specializations'];
    final specStr = json['specialization'] ??
        (specs is List ? specs.join(', ') : specs?.toString()) ??
        'Metabolic Health & Weight Management';

    final langs = json['languages'];
    final langStr = (langs is List ? langs.join(', ') : langs?.toString()) ?? 'English, Hindi';
    final hub = json['hub'] as Map<String, dynamic>?;

    return DietitianModel(
      id: json['id'] ?? '',
      name: user?['name'] ?? json['name'] ?? 'Clinical Dietitian',
      qualification: json['qualification'] ?? 'M.Sc Clinical Nutrition, RD',
      specialization: specStr,
      experienceYears: int.tryParse(json['experienceYears']?.toString() ?? '6') ?? 6,
      bio: json['bio'] ?? 'Specializing in personalized preventive nutrition and clinical diet plans.',
      languages: langStr,
      rating: double.tryParse(json['rating']?.toString() ?? '4.9') ?? 4.9,
      photoUrl: json['photoUrl'],
      availableSlots: (json['availability'] as List<dynamic>?)
              ?.map((e) => DietitianSlotModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      hubId: json['hubId'] ?? hub?['id'],
      hubName: json['hubName'] ?? hub?['name'] ?? 'Hyderabad Central Hub',
      hubCode: json['hubCode'] ?? hub?['code'] ?? 'HYD-CENTRAL',
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
