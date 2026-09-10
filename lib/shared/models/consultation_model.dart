class ConsultationModel {
  final String id;
  final String dietitianId;
  final String dietitianName;
  final String? dietitianSpecialization;
  final String memberName;
  final DateTime scheduledAt;
  final String status; // SCHEDULED, COMPLETED, CANCELLED, NO_SHOW
  final String consultationType;
  final String? roomUrl;
  final String? notes;
  final String? summary;

  ConsultationModel({
    required this.id,
    required this.dietitianId,
    required this.dietitianName,
    this.dietitianSpecialization,
    required this.memberName,
    required this.scheduledAt,
    required this.status,
    this.consultationType = 'Video Consultation',
    this.roomUrl,
    this.notes,
    this.summary,
  });

  bool get isScheduled => status == 'SCHEDULED';
  bool get isCompleted => status == 'COMPLETED';

  factory ConsultationModel.fromJson(Map<String, dynamic> json) {
    final dietitian = json['dietitian'] as Map<String, dynamic>?;
    final dietitianUser = dietitian?['user'] as Map<String, dynamic>?;
    final hpMember = json['healthPassMember'] as Map<String, dynamic>?;
    final hhMember = hpMember?['householdMember'] as Map<String, dynamic>?;

    return ConsultationModel(
      id: json['id'] ?? '',
      dietitianId: json['dietitianId'] ?? dietitian?['id'] ?? '',
      dietitianName: dietitianUser?['name'] ?? dietitian?['name'] ?? 'Clinical Dietitian',
      dietitianSpecialization: dietitian?['specialization'],
      memberName: hhMember?['name'] ?? 'Self',
      scheduledAt: json['scheduledAt'] != null
          ? DateTime.tryParse(json['scheduledAt']) ?? DateTime.now()
          : DateTime.now(),
      status: json['status'] ?? 'SCHEDULED',
      consultationType: json['consultationType'] ?? 'Video Consultation',
      roomUrl: json['roomUrl'],
      notes: json['notes'],
      summary: json['summary'],
    );
  }
}
