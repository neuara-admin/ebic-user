class HealthPassPlanModel {
  final String id;
  final String code;
  final String name;
  final String? description;
  final List<String> benefits;
  final List<HealthPassDurationOption> durationOptions;

  HealthPassPlanModel({
    required this.id,
    required this.code,
    required this.name,
    this.description,
    this.benefits = const [],
    this.durationOptions = const [],
  });

  factory HealthPassPlanModel.fromJson(Map<String, dynamic> json) {
    return HealthPassPlanModel(
      id: json['id'] ?? '',
      code: json['code'] ?? 'EBIC_CARE',
      name: json['name'] ?? 'EBIC Care',
      description: json['description'],
      benefits: (json['benefits'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [
        'Dedicated Clinical Dietitian consultation',
        'Personalized daily meal plan design',
        'Chef booking benefits & allowances',
        'Bi-weekly progress reviews & health metrics tracking',
        'Priority home chef scheduling window',
      ],
      durationOptions: (json['durationOptions'] as List<dynamic>?)
              ?.map((e) => HealthPassDurationOption.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [
            HealthPassDurationOption(months: 1, label: '1 Month', priceRupees: 2999),
            HealthPassDurationOption(months: 3, label: '3 Months (Save 15%)', priceRupees: 7649),
            HealthPassDurationOption(months: 6, label: '6 Months (Save 25%)', priceRupees: 13499),
            HealthPassDurationOption(months: 12, label: '12 Months (Save 35%)', priceRupees: 23399),
          ],
    );
  }
}

class HealthPassDurationOption {
  final int months;
  final String label;
  final double priceRupees;

  HealthPassDurationOption({
    required this.months,
    required this.label,
    required this.priceRupees,
  });

  factory HealthPassDurationOption.fromJson(Map<String, dynamic> json) {
    return HealthPassDurationOption(
      months: json['months'] ?? 1,
      label: json['label'] ?? '${json['months'] ?? 1} Month',
      priceRupees: double.tryParse(json['priceRupees']?.toString() ?? '2999') ?? 2999.0,
    );
  }
}

class MyHealthPassModel {
  final String id;
  final String planName;
  final String status; // ACTIVE, PENDING_PAYMENT, EXPIRED, CANCELLED
  final DateTime startDate;
  final DateTime endDate;
  final int coveredMembersCount;
  final List<String> coveredMemberNames;
  final List<String> benefits;

  MyHealthPassModel({
    required this.id,
    required this.planName,
    required this.status,
    required this.startDate,
    required this.endDate,
    required this.coveredMembersCount,
    this.coveredMemberNames = const [],
    this.benefits = const [],
  });

  bool get isActive => status == 'ACTIVE';

  factory MyHealthPassModel.fromJson(Map<String, dynamic> json) {
    final plan = json['plan'] as Map<String, dynamic>?;
    final members = (json['members'] as List<dynamic>?) ?? [];

    return MyHealthPassModel(
      id: json['id'] ?? '',
      planName: plan?['name'] ?? json['planName'] ?? 'EBIC Care',
      status: json['status'] ?? 'ACTIVE',
      startDate: json['startDate'] != null
          ? DateTime.tryParse(json['startDate']) ?? DateTime.now()
          : DateTime.now(),
      endDate: json['endDate'] != null
          ? DateTime.tryParse(json['endDate']) ?? DateTime.now().add(const Duration(days: 30))
          : DateTime.now().add(const Duration(days: 30)),
      coveredMembersCount: members.length,
      coveredMemberNames: members.map((m) {
        final hm = m['householdMember'] as Map<String, dynamic>?;
        return hm?['name']?.toString() ?? 'Member';
      }).toList(),
      benefits: (json['benefits'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [
        'Dietitian consultation',
        'Personalized diet plan',
        'Chef-related benefits where eligible',
        'Progress tracking',
        'Health insights',
        'Chat/support',
      ],
    );
  }
}
