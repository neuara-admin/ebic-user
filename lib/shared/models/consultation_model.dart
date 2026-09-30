class ConsultationModel {
  final String id;
  final String dietitianId;
  final String dietitianName;
  final String? dietitianQualification;
  final String? dietitianSpecialization;
  final String? dietitianPhotoUrl;
  final String memberName;
  final List<String> attendingMembers;
  final DateTime scheduledAt;
  final DateTime? endsAt;
  final String status; // SCHEDULED, IN_PROGRESS, VIDEO_COMPLETED, COMPLETED, CANCELLED, NO_SHOW, RESCHEDULED
  final String consultationType;
  /// INITIAL (the kickoff) or FOLLOW_UP — set by the backend at booking.
  final String kind;
  /// 1 for the member's first consultation, 2 for the next, … (cancelled ones don't count).
  final int sequenceNumber;
  /// NOT_STARTED / PENDING / SAVED / OVERDUE — the dietitian's documentation,
  /// tracked separately from the call itself.
  final String notesStatus;
  /// CUSTOMER / ADMIN / DIETITIAN_NO_SHOW when status is CANCELLED.
  final String? cancelReasonCode;
  final DateTime? callEndedAt;
  final String? roomUrl;
  final String? meetingLink;
  final String? reason;
  final String? notes;
  final String? additionalNotes;
  final String? summary;
  final String? assessment;
  final String? recommendations;
  final String? lifestyleNotes;
  final String? goals;
  final bool hasDietPlan;
  final String? dietPlanId;
  final List<ConsultationAttachmentModel> documents;
  final List<String> referencedDocumentIds;

  ConsultationModel({
    required this.id,
    required this.dietitianId,
    required this.dietitianName,
    this.dietitianQualification,
    this.dietitianSpecialization,
    this.dietitianPhotoUrl,
    required this.memberName,
    this.attendingMembers = const [],
    required this.scheduledAt,
    this.endsAt,
    required this.status,
    this.consultationType = 'Video Consultation',
    this.kind = 'INITIAL',
    this.sequenceNumber = 1,
    this.notesStatus = 'NOT_STARTED',
    this.cancelReasonCode,
    this.callEndedAt,
    this.roomUrl,
    this.meetingLink,
    this.reason,
    this.notes,
    this.additionalNotes,
    this.summary,
    this.assessment,
    this.recommendations,
    this.lifestyleNotes,
    this.goals,
    this.hasDietPlan = false,
    this.dietPlanId,
    this.documents = const [],
    this.referencedDocumentIds = const [],
  });

  bool get isScheduled => status == 'SCHEDULED';
  bool get isInProgress => status == 'IN_PROGRESS';
  /// The video call is over, but the dietitian hasn't finalized the notes yet.
  bool get isVideoCompleted => status == 'VIDEO_COMPLETED';
  bool get isCompleted => status == 'COMPLETED';
  bool get isCancelled => status == 'CANCELLED';
  bool get isRescheduled =>
      status == 'RESCHEDULED' ||
      (reason?.toLowerCase().contains('rescheduled') ?? false) ||
      (additionalNotes?.toLowerCase().contains('rescheduled') ?? false);
  bool get isNoShow => status == 'NO_SHOW';
  bool get isInitial => kind == 'INITIAL';
  /// The call happened (the service was delivered), whether or not notes are saved.
  bool get isDelivered => status == 'VIDEO_COMPLETED' || status == 'COMPLETED';
  /// Delivered, but the dietitian hasn't saved notes yet.
  bool get isNotesPending => status == 'VIDEO_COMPLETED';
  /// Auto-cancelled because the dietitian never started the call — not
  /// counted against the member's plan.
  bool get isDietitianNoShow => status == 'CANCELLED' && cancelReasonCode == 'DIETITIAN_NO_SHOW';

  /// Some dietitian names are stored with "Dr." already — never double it.
  String get dietitianDisplayName {
    final name = dietitianName.trim();
    if (name.isEmpty) return 'your dietitian';
    return RegExp(r'^dr\.?\s', caseSensitive: false).hasMatch(name) ? name : 'Dr. $name';
  }

  /// "Initial Consultation" or "Follow-up · Session 3".
  String get kindLabel => isInitial ? 'Initial Consultation' : 'Follow-up · Session $sequenceNumber';

  factory ConsultationModel.fromJson(Map<String, dynamic> json) {
    final dietitian = json['dietitian'] as Map<String, dynamic>?;
    final dietitianUser = dietitian?['user'] as Map<String, dynamic>?;
    final hpMember = json['healthPassMember'] as Map<String, dynamic>?;
    final hhMember = hpMember?['householdMember'] as Map<String, dynamic>?;
    final slot = json['slot'] as Map<String, dynamic>?;

    final startsAt = json['scheduledAt'] != null
        ? DateTime.tryParse(json['scheduledAt']) ?? DateTime.now()
        : DateTime.now();

    final endsAt = slot?['endsAt'] != null
        ? DateTime.tryParse(slot!['endsAt']) ?? startsAt.add(const Duration(minutes: 45))
        : (json['endsAt'] != null ? DateTime.tryParse(json['endsAt']) : startsAt.add(const Duration(minutes: 45)));

    final rawAdditionalNotes = json['additionalNotes'] as String?;
    final rawReason = json['reason'] as String?;

    // Parse attending members list from additionalNotes if formatted as "Attending Members: name1, name2"
    List<String> attendees = [];
    if (rawAdditionalNotes != null && rawAdditionalNotes.contains('Attending Members:')) {
      final parts = rawAdditionalNotes.replaceFirst('Attending Members:', '').split(',');
      attendees = parts.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    }
    if (attendees.isEmpty && hhMember?['name'] != null) {
      attendees = [hhMember!['name'] as String];
    }

    final dietPlansList = json['dietPlans'] as List?;
    final hasPlan = dietPlansList != null && dietPlansList.isNotEmpty;
    String? planId;
    if (hasPlan && dietPlansList.first is Map) {
      planId = (dietPlansList.first as Map)['id']?.toString();
    }

    final rawRefDocIds = (json['referencedDocumentIds'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [];

    final rawDocs = (json['documents'] as List<dynamic>?) ??
        (json['healthDocuments'] as List<dynamic>?) ??
        [];
    List<ConsultationAttachmentModel> docs = rawDocs
        .map((d) => ConsultationAttachmentModel.fromJson(d is Map<String, dynamic> ? d : {}))
        .toList();

    if (docs.isEmpty && rawRefDocIds.isNotEmpty) {
      docs = rawRefDocIds.map((id) => ConsultationAttachmentModel(
        id: id,
        title: 'Referenced Medical Document',
        documentType: 'Lab Report / Health Record',
      )).toList();
    }

    return ConsultationModel(
      id: json['id'] ?? '',
      dietitianId: json['dietitianId'] ?? dietitian?['id'] ?? '',
      dietitianName: dietitianUser?['name'] ?? dietitian?['name'] ?? 'Clinical Dietitian',
      dietitianQualification: dietitian?['qualification'],
      dietitianSpecialization: dietitian?['specialization'] ??
          (dietitian?['specializations'] is List ? (dietitian!['specializations'] as List).join(', ') : null),
      dietitianPhotoUrl: dietitian?['photoUrl'] ?? dietitian?['imageUrl'],
      memberName: hhMember?['name'] ?? 'Family Member',
      attendingMembers: attendees,
      scheduledAt: startsAt,
      endsAt: endsAt,
      status: json['status'] ?? 'SCHEDULED',
      consultationType: json['consultationType'] ?? 'Video Consultation',
      kind: json['kind']?.toString() ?? 'INITIAL',
      sequenceNumber: (json['sequenceNumber'] as num?)?.toInt() ?? 1,
      notesStatus: json['notesStatus']?.toString() ?? 'NOT_STARTED',
      cancelReasonCode: json['cancelReasonCode']?.toString(),
      callEndedAt: json['callEndedAt'] != null ? DateTime.tryParse(json['callEndedAt'].toString()) : null,
      roomUrl: json['roomUrl'] ?? json['meetingLink'],
      meetingLink: json['meetingLink'] ?? json['roomUrl'],
      reason: rawReason,
      notes: json['notes'] ?? rawReason,
      additionalNotes: rawAdditionalNotes,
      summary: json['summary'] ?? json['assessment'],
      assessment: json['assessment'] ?? json['summary'],
      recommendations: json['recommendations'],
      lifestyleNotes: json['lifestyleNotes'],
      goals: json['goals'],
      hasDietPlan: hasPlan,
      dietPlanId: planId,
      documents: docs,
      referencedDocumentIds: rawRefDocIds,
    );
  }
}

class ConsultationAttachmentModel {
  final String id;
  final String title;
  final String? documentType;
  final String? fileUrl;
  final DateTime? uploadedAt;

  ConsultationAttachmentModel({
    required this.id,
    required this.title,
    this.documentType,
    this.fileUrl,
    this.uploadedAt,
  });

  factory ConsultationAttachmentModel.fromJson(Map<String, dynamic> json) {
    return ConsultationAttachmentModel(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? json['fileName']?.toString() ?? json['name']?.toString() ?? 'Medical Document',
      documentType: json['documentType']?.toString() ?? json['type']?.toString() ?? 'Clinical Report',
      fileUrl: json['fileUrl']?.toString() ?? json['url']?.toString(),
      uploadedAt: DateTime.tryParse(json['createdAt']?.toString() ?? json['uploadedAt']?.toString() ?? ''),
    );
  }
}
