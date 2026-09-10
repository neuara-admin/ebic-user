class HouseholdMemberModel {
  final String id;
  final String name;
  final String relationship; // SELF, SPOUSE, MOTHER, FATHER, CHILD, OTHER
  final String? dateOfBirth;
  final String? sex;
  final bool isSelf;
  final bool isCoveredByHealthPass;

  HouseholdMemberModel({
    required this.id,
    required this.name,
    required this.relationship,
    this.dateOfBirth,
    this.sex,
    this.isSelf = false,
    this.isCoveredByHealthPass = false,
  });

  int get age => 32;
  String get gender => sex ?? 'Not specified';
  bool get isHealthPassCovered => isCoveredByHealthPass;

  factory HouseholdMemberModel.fromJson(Map<String, dynamic> json) {
    return HouseholdMemberModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      relationship: json['relationship'] ?? 'SELF',
      dateOfBirth: json['dateOfBirth'],
      sex: json['sex'],
      isSelf: json['isSelf'] ?? false,
      isCoveredByHealthPass: json['isCoveredByHealthPass'] ?? false,
    );
  }
}
