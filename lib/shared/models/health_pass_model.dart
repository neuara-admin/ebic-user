import 'consultation_model.dart';

class HealthPassBenefitModel {
  final String code;
  final String name;
  final String description;
  final String benefitType;
  final int? quantity;
  final String frequency;
  final String allowanceScope;

  HealthPassBenefitModel({
    required this.code,
    required this.name,
    required this.description,
    required this.benefitType,
    this.quantity,
    this.frequency = 'MONTHLY',
    this.allowanceScope = 'PER_MEMBER',
  });

  factory HealthPassBenefitModel.fromJson(Map<String, dynamic> json) {
    return HealthPassBenefitModel(
      code: json['code']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      benefitType: json['benefitType']?.toString() ?? '',
      quantity: json['quantity'] != null ? int.tryParse(json['quantity'].toString()) : null,
      frequency: json['frequency']?.toString() ?? 'MONTHLY',
      allowanceScope: json['allowanceScope']?.toString() ?? 'PER_MEMBER',
    );
  }
}

class HealthPassDurationModel {
  final int durationMonths;
  final String label;
  final double discountPercent;

  HealthPassDurationModel({
    required this.durationMonths,
    required this.label,
    this.discountPercent = 0.0,
  });

  factory HealthPassDurationModel.fromJson(Map<String, dynamic> json) {
    return HealthPassDurationModel(
      durationMonths: int.tryParse(json['durationMonths']?.toString() ?? '1') ?? 1,
      label: json['label']?.toString() ?? '${json['durationMonths'] ?? 1} Month',
      discountPercent: double.tryParse(json['discountValue']?.toString() ?? '0') ?? 0.0,
    );
  }
}

class HealthPassMediaModel {
  final String id;
  final String url;
  final String? title;
  final int sortOrder;

  HealthPassMediaModel({
    required this.id,
    required this.url,
    this.title,
    this.sortOrder = 0,
  });

  factory HealthPassMediaModel.fromJson(Map<String, dynamic> json) {
    return HealthPassMediaModel(
      id: json['id']?.toString() ?? '',
      url: json['url']?.toString() ?? '',
      title: json['title']?.toString(),
      sortOrder: int.tryParse(json['sortOrder']?.toString() ?? '0') ?? 0,
    );
  }
}

class HealthPassPlanModel {
  final String id;
  final String code;
  final String name;
  final String displayName;
  final String shortDescription;
  final String fullDescription;
  final String? imageUrl;
  final List<HealthPassMediaModel> images;
  final List<HealthPassMediaModel> videos;
  final double basePrice;
  final double additionalMemberPrice;
  final double memberDiscountPercent;
  final int minMembers;
  final int maxMembers;
  final List<HealthPassDurationModel> durations;
  final List<HealthPassBenefitModel> benefits;

  HealthPassPlanModel({
    required this.id,
    required this.code,
    required this.name,
    required this.displayName,
    this.shortDescription = '',
    this.fullDescription = '',
    this.imageUrl,
    this.images = const [],
    this.videos = const [],
    required this.basePrice,
    required this.additionalMemberPrice,
    this.memberDiscountPercent = 0.0,
    this.minMembers = 1,
    this.maxMembers = 5,
    this.durations = const [],
    this.benefits = const [],
  });

  factory HealthPassPlanModel.fromJson(Map<String, dynamic> json) {
    final versions = (json['versions'] as List<dynamic>?) ?? [];
    final activeVersion = versions.isNotEmpty ? versions.first as Map<String, dynamic> : null;

    final durationsList = (activeVersion?['durations'] as List<dynamic>?)
            ?.map((d) => HealthPassDurationModel.fromJson(d as Map<String, dynamic>))
            .toList() ??
        [];

    final benefitsList = (activeVersion?['benefits'] as List<dynamic>?)
            ?.map((b) => HealthPassBenefitModel.fromJson(b as Map<String, dynamic>))
            .toList() ??
        [];

    final imagesList = (json['images'] as List<dynamic>?)
            ?.map((img) => HealthPassMediaModel.fromJson(img as Map<String, dynamic>))
            .toList() ??
        [];

    final videosList = (json['videos'] as List<dynamic>?)
            ?.map((vid) => HealthPassMediaModel.fromJson(vid as Map<String, dynamic>))
            .toList() ??
        [];

    final primaryImageUrl = json['imageUrl']?.toString() ??
        (imagesList.isNotEmpty ? imagesList.first.url : null);

    return HealthPassPlanModel(
      id: json['id']?.toString() ?? '',
      code: json['code']?.toString() ?? 'ESSENTIAL_V1',
      name: json['name']?.toString() ?? 'EBIC Essential',
      displayName: json['displayName']?.toString() ?? json['name']?.toString() ?? 'EBIC Essential',
      shortDescription: json['shortDescription']?.toString() ?? '',
      fullDescription: json['fullDescription']?.toString() ?? '',
      imageUrl: primaryImageUrl,
      images: imagesList,
      videos: videosList,
      basePrice: double.tryParse(activeVersion?['basePrice']?.toString() ?? '999') ?? 999.0,
      additionalMemberPrice: double.tryParse(activeVersion?['additionalMemberPrice']?.toString() ?? '999') ?? 999.0,
      memberDiscountPercent: double.tryParse(activeVersion?['memberDiscountValue']?.toString() ?? '20') ?? 20.0,
      minMembers: int.tryParse(activeVersion?['minCoveredMembers']?.toString() ?? '1') ?? 1,
      maxMembers: int.tryParse(activeVersion?['maxCoveredMembers']?.toString() ?? '5') ?? 5,
      durations: durationsList,
      benefits: benefitsList,
    );
  }
}

class HealthPassComparisonModel {
  final List<HealthPassPlanSummary> plans;
  final List<BenefitComparisonRow> matrix;

  HealthPassComparisonModel({
    required this.plans,
    required this.matrix,
  });

  factory HealthPassComparisonModel.fromJson(Map<String, dynamic> json) {
    final plans = ((json['plans'] as List<dynamic>?) ?? [])
        .map((p) => HealthPassPlanSummary.fromJson(p as Map<String, dynamic>))
        .toList();
    final matrix = ((json['matrix'] as List<dynamic>?) ?? [])
        .map((m) => BenefitComparisonRow.fromJson(m as Map<String, dynamic>))
        .toList();
    return HealthPassComparisonModel(plans: plans, matrix: matrix);
  }
}

class HealthPassPlanSummary {
  final String id;
  final String code;
  final String name;
  final String displayName;
  final String shortDescription;
  final double basePrice;

  HealthPassPlanSummary({
    required this.id,
    required this.code,
    required this.name,
    required this.displayName,
    required this.shortDescription,
    required this.basePrice,
  });

  factory HealthPassPlanSummary.fromJson(Map<String, dynamic> json) {
    return HealthPassPlanSummary(
      id: json['id']?.toString() ?? '',
      code: json['code']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      displayName: json['displayName']?.toString() ?? '',
      shortDescription: json['shortDescription']?.toString() ?? '',
      basePrice: double.tryParse(json['basePrice']?.toString() ?? '0') ?? 0.0,
    );
  }
}

class BenefitComparisonRow {
  final String code;
  final String name;
  final String description;
  final Map<String, BenefitAvailability> availability;

  BenefitComparisonRow({
    required this.code,
    required this.name,
    required this.description,
    required this.availability,
  });

  factory BenefitComparisonRow.fromJson(Map<String, dynamic> json) {
    final rawAvail = (json['availability'] as Map<String, dynamic>?) ?? {};
    final mapped = <String, BenefitAvailability>{};
    rawAvail.forEach((key, val) {
      if (val is Map<String, dynamic>) {
        mapped[key] = BenefitAvailability.fromJson(val);
      }
    });
    return BenefitComparisonRow(
      code: json['code']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      availability: mapped,
    );
  }
}

class BenefitAvailability {
  final bool included;
  final String label;
  final int? quantity;

  BenefitAvailability({
    required this.included,
    required this.label,
    this.quantity,
  });

  factory BenefitAvailability.fromJson(Map<String, dynamic> json) {
    return BenefitAvailability(
      included: json['included'] == true,
      label: json['label']?.toString() ?? '—',
      quantity: json['quantity'] != null ? int.tryParse(json['quantity'].toString()) : null,
    );
  }
}

class HealthPassQuoteModel {
  final String planCode;
  final int memberCount;
  final int durationMonths;
  final double subtotal;
  final double memberCharges;
  final double memberDiscount;
  final double durationDiscount;
  final double promotionDiscount;
  final double platformFee;
  final double otherCharges;
  final double gstPercent;
  final double tax;
  final double finalAmount;

  HealthPassQuoteModel({
    required this.planCode,
    required this.memberCount,
    required this.durationMonths,
    required this.subtotal,
    required this.memberCharges,
    required this.memberDiscount,
    required this.durationDiscount,
    required this.promotionDiscount,
    this.platformFee = 0.0,
    this.otherCharges = 0.0,
    this.gstPercent = 18.0,
    required this.tax,
    required this.finalAmount,
  });

  double get totalDiscounts => memberDiscount + durationDiscount + promotionDiscount;

  factory HealthPassQuoteModel.fromJson(Map<String, dynamic> json) {
    return HealthPassQuoteModel(
      planCode: json['planCode']?.toString() ?? '',
      memberCount: int.tryParse(json['memberCount']?.toString() ?? '1') ?? 1,
      durationMonths: int.tryParse(json['durationMonths']?.toString() ?? '1') ?? 1,
      subtotal: double.tryParse(json['subtotal']?.toString() ?? '0') ?? 0.0,
      memberCharges: double.tryParse(json['memberCharges']?.toString() ?? '0') ?? 0.0,
      memberDiscount: double.tryParse(json['memberDiscount']?.toString() ?? '0') ?? 0.0,
      durationDiscount: double.tryParse(json['durationDiscount']?.toString() ?? '0') ?? 0.0,
      promotionDiscount: double.tryParse(json['promotionDiscount']?.toString() ?? '0') ?? 0.0,
      platformFee: double.tryParse(json['platformFee']?.toString() ?? '0') ?? 0.0,
      otherCharges: double.tryParse(json['otherCharges']?.toString() ?? '0') ?? 0.0,
      gstPercent: double.tryParse(json['gstPercent']?.toString() ?? '18') ?? 18.0,
      tax: double.tryParse(json['tax']?.toString() ?? '0') ?? 0.0,
      finalAmount: double.tryParse(json['finalAmount']?.toString() ?? '0') ?? 0.0,
    );
  }
}

class ActiveHealthPassModel {
  final String id;
  final String status;
  final String planCode;
  final String planName;
  final String displayName;
  final String shortDescription;
  final int durationMonths;
  final DateTime? bookedDate;
  final DateTime? startDate;
  final DateTime? endDate;
  final int daysRemaining;
  final bool isExpiringSoon;
  final bool isExpired;
  final bool isConsultationPending;
  final String? validityNote;

  // Anniversary-based reset
  final int anniversaryMonthIndex;
  final DateTime anniversaryStartDate;
  final DateTime anniversaryEndDate;

  // Entitlement Counters
  final int chefVisitsAllocated;
  final int chefVisitsUsed;
  final int chefVisitsRemaining;

  final int consultationsAllocated;
  final int consultationsUsed;
  final int consultationsRemaining;

  final List<CoveredMemberModel> coveredMembers;
  final AssignedDietitianModel? assignedDietitian;
  final ConsultationModel? activeConsultation;
  final ConsultationModel? latestCompletedConsultation;
  final double finalAmount;

  ActiveHealthPassModel({
    required this.id,
    required this.status,
    required this.planCode,
    required this.planName,
    required this.displayName,
    this.shortDescription = '',
    required this.durationMonths,
    this.bookedDate,
    this.startDate,
    this.endDate,
    required this.daysRemaining,
    this.isExpiringSoon = false,
    this.isExpired = false,
    this.isConsultationPending = false,
    this.validityNote,
    required this.anniversaryMonthIndex,
    required this.anniversaryStartDate,
    required this.anniversaryEndDate,
    required this.chefVisitsAllocated,
    required this.chefVisitsUsed,
    required this.chefVisitsRemaining,
    required this.consultationsAllocated,
    required this.consultationsUsed,
    required this.consultationsRemaining,
    this.coveredMembers = const [],
    this.assignedDietitian,
    this.activeConsultation,
    this.latestCompletedConsultation,
    this.finalAmount = 0.0,
  });

  bool get isActive => status == 'ACTIVE' || status == 'EXPIRING_SOON';
  int get coveredMembersCount => coveredMembers.length;
  List<String> get coveredMemberNames => coveredMembers.map((m) => m.name).toList();
  List<String> get benefits => const [
        'In-Home Chef Visits',
        'Clinical Dietitian Consultations',
        'Personalized Diet Plan',
        'Health Progress Tracking',
      ];

  factory ActiveHealthPassModel.fromJson(Map<String, dynamic> json) {
    final plan = (json['plan'] as Map<String, dynamic>?) ?? {};
    final duration = (json['duration'] as Map<String, dynamic>?) ?? {};
    final anniv = (json['anniversaryPeriod'] as Map<String, dynamic>?) ?? {};
    final ent = (json['entitlements'] as Map<String, dynamic>?) ?? {};
    final chef = (ent['chefVisits'] as Map<String, dynamic>?) ?? {};
    final consult = (ent['consultations'] as Map<String, dynamic>?) ?? {};
    final rawMembers = (json['coveredMembers'] as List<dynamic>?) ?? (json['members'] as List<dynamic>?) ?? [];
    final members = rawMembers
        .map((m) => CoveredMemberModel.fromJson(m as Map<String, dynamic>))
        .toList();
    final dietitian = json['assignedDietitian'] != null
        ? AssignedDietitianModel.fromJson(json['assignedDietitian'] as Map<String, dynamic>)
        : null;
    final activeConsult = json['activeConsultation'] != null
        ? ConsultationModel.fromJson(json['activeConsultation'] as Map<String, dynamic>)
        : null;
    final completedConsult = json['latestCompletedConsultation'] != null
        ? ConsultationModel.fromJson(json['latestCompletedConsultation'] as Map<String, dynamic>)
        : null;
    final fin = (json['financialSnapshot'] as Map<String, dynamic>?) ?? {};

    final rawCreated = json['createdAt']?.toString() ?? json['purchasedAt']?.toString() ?? json['bookingDate']?.toString();
    final bookedDate = rawCreated != null && rawCreated.isNotEmpty ? DateTime.tryParse(rawCreated) : null;
    final rawStart = json['startDate']?.toString();
    final rawEnd = json['endDate']?.toString();
    final isPending = json['isConsultationPending'] == true || (rawStart == null || rawStart.isEmpty);

    return ActiveHealthPassModel(
      id: json['id']?.toString() ?? '',
      status: json['status']?.toString() ?? 'ACTIVE',
      planCode: plan['code']?.toString() ?? '',
      planName: plan['name']?.toString() ?? json['planName']?.toString() ?? 'EBIC Care',
      displayName: plan['displayName']?.toString() ?? plan['name']?.toString() ?? json['planName']?.toString() ?? 'EBIC Care',
      shortDescription: plan['shortDescription']?.toString() ?? '',
      durationMonths: int.tryParse(json['durationMonths']?.toString() ?? duration['durationMonths']?.toString() ?? '1') ?? 1,
      bookedDate: bookedDate,
      startDate: rawStart != null && rawStart.isNotEmpty ? DateTime.tryParse(rawStart) : null,
      endDate: rawEnd != null && rawEnd.isNotEmpty ? DateTime.tryParse(rawEnd) : null,
      daysRemaining: int.tryParse(json['daysRemaining']?.toString() ?? '0') ?? 0,
      isExpiringSoon: json['isExpiringSoon'] == true,
      isExpired: json['isExpired'] == true,
      isConsultationPending: isPending,
      validityNote: json['validityNote']?.toString(),
      anniversaryMonthIndex: int.tryParse(anniv['monthIndex']?.toString() ?? '1') ?? 1,
      anniversaryStartDate: DateTime.tryParse(anniv['startDate']?.toString() ?? '') ?? DateTime.now(),
      anniversaryEndDate: DateTime.tryParse(anniv['endDate']?.toString() ?? '') ?? DateTime.now().add(const Duration(days: 30)),
      chefVisitsAllocated: int.tryParse(chef['allocated']?.toString() ?? '0') ?? 0,
      chefVisitsUsed: int.tryParse(chef['used']?.toString() ?? '0') ?? 0,
      chefVisitsRemaining: int.tryParse(chef['remaining']?.toString() ?? '0') ?? 0,
      consultationsAllocated: int.tryParse(consult['allocated']?.toString() ?? '0') ?? 0,
      consultationsUsed: int.tryParse(consult['used']?.toString() ?? '0') ?? 0,
      consultationsRemaining: int.tryParse(consult['remaining']?.toString() ?? '0') ?? 0,
      coveredMembers: members,
      assignedDietitian: dietitian,
      activeConsultation: activeConsult,
      latestCompletedConsultation: completedConsult,
      finalAmount: double.tryParse(fin['finalAmount']?.toString() ?? json['finalAmount']?.toString() ?? '0') ?? 0.0,
    );
  }
}

class CoveredMemberModel {
  final String id;
  final String householdMemberId;
  final String name;
  final String relationship;
  final bool isPrimary;
  final String? dietitianName;

  CoveredMemberModel({
    required this.id,
    required this.householdMemberId,
    required this.name,
    required this.relationship,
    this.isPrimary = false,
    this.dietitianName,
  });

  factory CoveredMemberModel.fromJson(Map<String, dynamic> json) {
    final hm = json['householdMember'] as Map<String, dynamic>?;
    final diet = json['dietitian'] as Map<String, dynamic>?;
    return CoveredMemberModel(
      id: json['id']?.toString() ?? '',
      householdMemberId: json['householdMemberId']?.toString() ?? hm?['id']?.toString() ?? '',
      name: json['name']?.toString() ?? hm?['name']?.toString() ?? 'Member',
      relationship: json['relationship']?.toString() ?? hm?['relationship']?.toString() ?? 'Self',
      isPrimary: json['isPrimary'] == true,
      dietitianName: diet?['name']?.toString(),
    );
  }
}

class AssignedDietitianModel {
  final String id;
  final String name;
  final String? photoUrl;
  final List<String> specializations;

  AssignedDietitianModel({
    required this.id,
    required this.name,
    this.photoUrl,
    this.specializations = const [],
  });

  factory AssignedDietitianModel.fromJson(Map<String, dynamic> json) {
    return AssignedDietitianModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Assigned Dietitian',
      photoUrl: json['photoUrl']?.toString(),
      specializations: (json['specializations'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
    );
  }
}

class HealthPassUsageLedgerModel {
  final String healthPassId;
  final String planName;
  final List<EntitlementSummaryModel> entitlements;
  final List<UsageLedgerEntryModel> usageLedger;

  HealthPassUsageLedgerModel({
    required this.healthPassId,
    required this.planName,
    required this.entitlements,
    required this.usageLedger,
  });

  factory HealthPassUsageLedgerModel.fromJson(Map<String, dynamic> json) {
    final entList = ((json['entitlements'] as List<dynamic>?) ?? [])
        .map((e) => EntitlementSummaryModel.fromJson(e as Map<String, dynamic>))
        .toList();
    final ledgerList = ((json['usageLedger'] as List<dynamic>?) ?? [])
        .map((l) => UsageLedgerEntryModel.fromJson(l as Map<String, dynamic>))
        .toList();

    return HealthPassUsageLedgerModel(
      healthPassId: json['healthPassId']?.toString() ?? '',
      planName: json['planName']?.toString() ?? '',
      entitlements: entList,
      usageLedger: ledgerList,
    );
  }
}

class EntitlementSummaryModel {
  final String id;
  final String benefitCode;
  final String benefitName;
  final String allowanceScope;
  final int quantityTotal;
  final int quantityUsed;
  final int quantityRemaining;
  final int periodIndex;
  final String memberName;

  EntitlementSummaryModel({
    required this.id,
    required this.benefitCode,
    required this.benefitName,
    required this.allowanceScope,
    required this.quantityTotal,
    required this.quantityUsed,
    required this.quantityRemaining,
    required this.periodIndex,
    required this.memberName,
  });

  factory EntitlementSummaryModel.fromJson(Map<String, dynamic> json) {
    return EntitlementSummaryModel(
      id: json['id']?.toString() ?? '',
      benefitCode: json['benefitCode']?.toString() ?? '',
      benefitName: json['benefitName']?.toString() ?? '',
      allowanceScope: json['allowanceScope']?.toString() ?? 'PER_MEMBER',
      quantityTotal: int.tryParse(json['quantityTotal']?.toString() ?? '0') ?? 0,
      quantityUsed: int.tryParse(json['quantityUsed']?.toString() ?? '0') ?? 0,
      quantityRemaining: int.tryParse(json['quantityRemaining']?.toString() ?? '0') ?? 0,
      periodIndex: int.tryParse(json['periodIndex']?.toString() ?? '0') ?? 0,
      memberName: json['memberName']?.toString() ?? '',
    );
  }
}

class UsageLedgerEntryModel {
  final String id;
  final DateTime date;
  final String service;
  final String benefitCode;
  final int quantity;
  final String memberName;
  final String reason;
  final String? orderNumber;
  final String? orderId;

  UsageLedgerEntryModel({
    required this.id,
    required this.date,
    required this.service,
    required this.benefitCode,
    required this.quantity,
    required this.memberName,
    required this.reason,
    this.orderNumber,
    this.orderId,
  });

  factory UsageLedgerEntryModel.fromJson(Map<String, dynamic> json) {
    return UsageLedgerEntryModel(
      id: json['id']?.toString() ?? '',
      date: DateTime.tryParse(json['date']?.toString() ?? '') ?? DateTime.now(),
      service: json['service']?.toString() ?? 'Health Service',
      benefitCode: json['benefitCode']?.toString() ?? '',
      quantity: int.tryParse(json['quantity']?.toString() ?? '1') ?? 1,
      memberName: json['memberName']?.toString() ?? 'Household',
      reason: json['reason']?.toString() ?? 'Usage Recorded',
      orderNumber: json['orderNumber']?.toString(),
      orderId: json['orderId']?.toString(),
    );
  }
}

class HealthPassHistoryItemModel {
  final String id;
  final String status;
  final String planCode;
  final String planName;
  final String displayName;
  final int durationMonths;
  final String durationLabel;
  final DateTime? startDate;
  final DateTime? endDate;
  final double finalAmount;
  final int memberCount;
  final List<CoveredMemberModel> members;
  final DateTime createdAt;

  HealthPassHistoryItemModel({
    required this.id,
    required this.status,
    required this.planCode,
    required this.planName,
    required this.displayName,
    required this.durationMonths,
    required this.durationLabel,
    this.startDate,
    this.endDate,
    required this.finalAmount,
    required this.memberCount,
    this.members = const [],
    required this.createdAt,
  });

  factory HealthPassHistoryItemModel.fromJson(Map<String, dynamic> json) {
    return HealthPassHistoryItemModel(
      id: json['id']?.toString() ?? '',
      status: json['status']?.toString() ?? 'COMPLETED',
      planCode: json['planCode']?.toString() ?? '',
      planName: json['planName']?.toString() ?? 'Health Pass',
      displayName: json['displayName']?.toString() ?? json['planName']?.toString() ?? 'Health Pass',
      durationMonths: int.tryParse(json['durationMonths']?.toString() ?? '1') ?? 1,
      durationLabel: json['durationLabel']?.toString() ?? '1 Month',
      startDate: json['startDate'] != null ? DateTime.tryParse(json['startDate']) : null,
      endDate: json['endDate'] != null ? DateTime.tryParse(json['endDate']) : null,
      finalAmount: double.tryParse(json['finalAmount']?.toString() ?? '0') ?? 0.0,
      memberCount: int.tryParse(json['memberCount']?.toString() ?? '1') ?? 1,
      members: (json['members'] as List<dynamic>?)
              ?.map((m) => CoveredMemberModel.fromJson(m as Map<String, dynamic>))
              .toList() ??
          [],
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}

// Backward-compatible alias
typedef MyHealthPassModel = ActiveHealthPassModel;
typedef HealthPassDurationOption = HealthPassDurationModel;
