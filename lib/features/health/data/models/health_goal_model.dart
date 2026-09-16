class HealthGoalModel {
  final String id;
  final String householdMemberId;
  final String goalType;
  final String title;
  final String? description;
  final int priority;
  final double? targetValue;
  final String? targetUnit;
  final String status; // ACTIVE, ACHIEVED, PAUSED, CANCELLED
  final String source;
  final String? createdAt;

  HealthGoalModel({
    required this.id,
    required this.householdMemberId,
    required this.goalType,
    required this.title,
    this.description,
    this.priority = 1,
    this.targetValue,
    this.targetUnit,
    this.status = 'ACTIVE',
    this.source = 'CUSTOMER',
    this.createdAt,
  });

  factory HealthGoalModel.fromJson(Map<String, dynamic> json) {
    return HealthGoalModel(
      id: json['id']?.toString() ?? '',
      householdMemberId: json['householdMemberId']?.toString() ?? '',
      goalType: json['goalType']?.toString() ?? 'OTHER',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString(),
      priority: int.tryParse(json['priority']?.toString() ?? '1') ?? 1,
      targetValue: json['targetValue'] != null
          ? double.tryParse(json['targetValue'].toString())
          : null,
      targetUnit: json['targetUnit']?.toString(),
      status: json['status']?.toString() ?? 'ACTIVE',
      source: json['source']?.toString() ?? 'CUSTOMER',
      createdAt: json['createdAt']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'memberId': householdMemberId,
      'goalType': goalType,
      'title': title,
      'description': description,
      'priority': priority,
      'targetValue': targetValue,
      'targetUnit': targetUnit,
      'status': status,
    };
  }
}
