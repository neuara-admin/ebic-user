class HealthCompletionModel {
  final String profileId;
  final int completionPercentage;
  final Map<String, bool> sections;
  final List<String> missingFields;
  final String updatedAt;

  HealthCompletionModel({
    required this.profileId,
    required this.completionPercentage,
    required this.sections,
    required this.missingFields,
    required this.updatedAt,
  });

  factory HealthCompletionModel.fromJson(Map<String, dynamic> json) {
    final rawSections = json['sections'] is Map ? json['sections'] as Map : {};
    final sectionsMap = <String, bool>{};
    rawSections.forEach((k, v) {
      sectionsMap[k.toString()] = v == true;
    });

    final rawMissing = json['missingFields'] as List<dynamic>? ?? [];
    final missingList = rawMissing.map((e) => e.toString()).toList();

    return HealthCompletionModel(
      profileId: json['profileId']?.toString() ?? '',
      completionPercentage: int.tryParse(json['completionPercentage']?.toString() ?? '0') ?? 0,
      sections: sectionsMap,
      missingFields: missingList,
      updatedAt: json['updatedAt']?.toString() ?? DateTime.now().toIso8601String(),
    );
  }

  bool isSectionComplete(String sectionName) {
    return sections[sectionName.toLowerCase()] ?? false;
  }
}
