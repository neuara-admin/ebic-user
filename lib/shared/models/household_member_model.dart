class HouseholdMemberModel {
  final String id;
  final String name;
  final String relationship; // SELF, SPOUSE, MOTHER, FATHER, CHILD, SIBLING, OTHER
  final String? dateOfBirth;
  final String? sex;
  final String? avatarUrl;
  final bool isSelf;
  final bool isCoveredByHealthPass;

  // Health related data
  final double? heightCm;
  final double? weightKg;
  final String? healthGoals;
  final String? clinicalNotes;
  final List<String> dietaryPreferences;
  final List<String> allergies;
  final List<String> medicalConditions;

  HouseholdMemberModel({
    required this.id,
    required this.name,
    required this.relationship,
    this.dateOfBirth,
    this.sex,
    this.avatarUrl,
    this.isSelf = false,
    this.isCoveredByHealthPass = false,
    this.heightCm,
    this.weightKg,
    this.healthGoals,
    this.clinicalNotes,
    this.dietaryPreferences = const [],
    this.allergies = const [],
    this.medicalConditions = const [],
  });

  int get age {
    if (dateOfBirth != null) {
      try {
        final dob = DateTime.parse(dateOfBirth!);
        final now = DateTime.now();
        int years = now.year - dob.year;
        if (now.month < dob.month || (now.month == dob.month && now.day < dob.day)) {
          years--;
        }
        return years > 0 ? years : 0;
      } catch (_) {
        return 28;
      }
    }
    return 28;
  }

  String get gender => sex ?? 'Not specified';
  bool get isHealthPassCovered => isCoveredByHealthPass;

  double? get bmi {
    if (heightCm != null && weightKg != null && heightCm! > 0) {
      final heightM = heightCm! / 100.0;
      final val = weightKg! / (heightM * heightM);
      return double.parse(val.toStringAsFixed(1));
    }
    return null;
  }

  String? get bmiCategory {
    final b = bmi;
    if (b == null) return null;
    if (b < 18.5) return 'Underweight';
    if (b < 25.0) return 'Normal weight';
    if (b < 30.0) return 'Overweight';
    return 'Obese';
  }

  String get formattedDob {
    if (dateOfBirth == null) return 'Not provided';
    try {
      final dob = DateTime.parse(dateOfBirth!);
      final d = dob.day.toString().padLeft(2, '0');
      final m = dob.month.toString().padLeft(2, '0');
      return '$d/$m/${dob.year}';
    } catch (_) {
      return dateOfBirth!;
    }
  }

  String get heightDisplay {
    if (heightCm == null) return 'Not set';
    final totalInches = (heightCm! / 2.54).round();
    final ft = totalInches ~/ 12;
    final inch = totalInches % 12;
    return "$ft'$inch\" (${heightCm!.round()} cm)";
  }

  String get weightDisplay {
    if (weightKg == null) return 'Not set';
    final lbs = (weightKg! * 2.20462).round();
    return '${weightKg!.toStringAsFixed(1)} kg ($lbs lbs)';
  }

  String get bmiFormatted => bmi != null ? bmi!.toStringAsFixed(1) : '--';

  String get displayRelationship {
    switch (relationship.toUpperCase()) {
      case 'SELF':
        return 'Self (Account Owner)';
      case 'SPOUSE':
      case 'PARTNER':
        return 'Spouse / Partner';
      case 'CHILD':
        return 'Child';
      case 'PARENT':
      case 'FATHER':
      case 'MOTHER':
        return 'Parent';
      case 'SIBLING':
        return 'Sibling';
      default:
        return relationship;
    }
  }

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts[0].isEmpty) return 'M';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  factory HouseholdMemberModel.fromJson(Map<String, dynamic> json) {
    // Extract health profile if present
    double? height;
    double? weight;
    String? goals;
    List<String> diets = [];
    List<String> allergs = [];
    List<String> conditions = [];

    String? clinicalNotes;

    if (json['healthProfile'] is Map<String, dynamic>) {
      final hp = json['healthProfile'] as Map<String, dynamic>;
      if (hp['heightCm'] != null) {
        height = double.tryParse(hp['heightCm'].toString());
      }
      if (hp['currentWeightKg'] != null) {
        weight = double.tryParse(hp['currentWeightKg'].toString());
      }
      goals = hp['healthGoals']?.toString();
      clinicalNotes = hp['clinicalNotes']?.toString();

      if (hp['allergens'] is List) {
        allergs = (hp['allergens'] as List)
            .map((a) {
              if (a is Map && a['allergen'] is Map) {
                return (a['allergen']['name'] ?? a['allergen']['code'] ?? '').toString();
              }
              return (a['name'] ?? a['code'] ?? a.toString()).toString();
            })
            .where((s) => s.isNotEmpty)
            .toList();
      }

      if (hp['dietaryRestrictions'] is List) {
        diets = (hp['dietaryRestrictions'] as List)
            .map((d) {
              if (d is Map && d['dietaryTag'] is Map) {
                return (d['dietaryTag']['name'] ?? d['dietaryTag']['code'] ?? '').toString();
              }
              return (d['name'] ?? d['code'] ?? d.toString()).toString();
            })
            .where((s) => s.isNotEmpty)
            .toList();
      }

      if (hp['medicalConditions'] is List) {
        conditions = (hp['medicalConditions'] as List).map((e) => e.toString()).toList();
      }
    }

    // Direct fallback fields
    if (height == null && json['heightCm'] != null) {
      height = double.tryParse(json['heightCm'].toString());
    }
    if (weight == null && json['currentWeightKg'] != null) {
      weight = double.tryParse(json['currentWeightKg'].toString());
    }
    if (weight == null && json['weightKg'] != null) {
      weight = double.tryParse(json['weightKg'].toString());
    }
    if (goals == null && json['healthGoals'] != null) {
      goals = json['healthGoals']?.toString();
    }
    if (clinicalNotes == null && json['clinicalNotes'] != null) {
      clinicalNotes = json['clinicalNotes']?.toString();
    }
    if (diets.isEmpty && json['dietaryPreferences'] is List) {
      diets = (json['dietaryPreferences'] as List).map((e) => e.toString()).toList();
    }
    if (allergs.isEmpty && json['allergies'] is List) {
      allergs = (json['allergies'] as List).map((e) => e.toString()).toList();
    }
    if (conditions.isEmpty && json['medicalConditions'] is List) {
      conditions = (json['medicalConditions'] as List).map((e) => e.toString()).toList();
    }

    // Parse 'Notes: ...' embedded inside healthGoals if clinicalNotes is still empty
    if ((clinicalNotes == null || clinicalNotes.isEmpty) && goals != null && goals.contains('Notes:')) {
      final match = RegExp(r'Notes:\s*([^|]+)', caseSensitive: false).firstMatch(goals);
      if (match != null) {
        clinicalNotes = match.group(1)!.trim();
        goals = goals.replaceAll(RegExp(r'Notes:\s*[^|]+(\|?\s*)?', caseSensitive: false), '').trim();
        if (goals.isEmpty) goals = null;
      }
    }

    // Parse 'Conditions: ...' embedded inside healthGoals if conditions list is still empty
    if (conditions.isEmpty && goals != null && goals.contains('Conditions:')) {
      final match = RegExp(r'Conditions:\s*([^|]+)', caseSensitive: false).firstMatch(goals);
      if (match != null) {
        final parsed = match.group(1)!.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty && s != 'None');
        conditions.addAll(parsed);
        goals = goals.replaceAll(RegExp(r'Conditions:\s*[^|]+(\|?\s*)?', caseSensitive: false), '').trim();
        if (goals.isEmpty) goals = null;
      }
    }

    return HouseholdMemberModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      relationship: json['relationship'] ?? 'SELF',
      dateOfBirth: json['dateOfBirth']?.toString(),
      sex: json['sex'],
      avatarUrl: json['avatarUrl']?.toString(),
      isSelf: json['isSelf'] == true || (json['relationship']?.toString().toUpperCase() == 'SELF'),
      isCoveredByHealthPass: json['isCoveredByHealthPass'] == true,
      heightCm: height,
      weightKg: weight,
      healthGoals: goals,
      clinicalNotes: clinicalNotes,
      dietaryPreferences: diets,
      allergies: allergs,
      medicalConditions: conditions,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'relationship': relationship,
      'dateOfBirth': dateOfBirth,
      'sex': sex,
      'avatarUrl': avatarUrl,
      'isSelf': isSelf,
      'isCoveredByHealthPass': isCoveredByHealthPass,
      'heightCm': heightCm,
      'weightKg': weightKg,
      'healthGoals': healthGoals,
      'clinicalNotes': clinicalNotes,
      'dietaryPreferences': dietaryPreferences,
      'allergies': allergies,
      'medicalConditions': medicalConditions,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HouseholdMemberModel && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
