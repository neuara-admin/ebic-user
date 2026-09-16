import '../../domain/entities/health_document_entity.dart';

class HealthDocumentModel extends HealthDocumentEntity {
  const HealthDocumentModel({
    required super.id,
    super.reference,
    required super.householdMemberId,
    required super.documentType,
    required super.title,
    super.originalFileName,
    super.mimeType,
    super.fileSize,
    required super.status,
    super.reportDate,
    super.uploadedAt,
    super.notes,
    super.isSharedWithDietitian,
    super.storageKey,
  });

  factory HealthDocumentModel.fromJson(Map<String, dynamic> json) {
    bool isShared = false;
    final accessList = json['accessList'];
    if (accessList is List) {
      isShared = accessList.any((item) =>
          item is Map &&
          item['subjectType'] == 'DIETITIAN' &&
          item['status'] == 'GRANTED');
    }

    return HealthDocumentModel(
      id: json['id']?.toString() ?? '',
      reference: json['reference']?.toString(),
      householdMemberId: json['householdMemberId']?.toString() ??
          json['memberId']?.toString() ??
          '',
      documentType: json['documentType']?.toString() ??
          json['category']?.toString() ??
          'OTHER',
      title: json['title']?.toString() ??
          json['originalFileName']?.toString() ??
          'Health Document',
      originalFileName: json['originalFileName']?.toString() ??
          json['fileName']?.toString(),
      mimeType: json['mimeType']?.toString(),
      fileSize: json['fileSize'] is int
          ? json['fileSize'] as int
          : (json['fileSize'] != null ? int.tryParse(json['fileSize'].toString()) : null),
      status: json['status']?.toString() ?? 'AVAILABLE',
      reportDate: json['reportDate'] != null
          ? DateTime.tryParse(json['reportDate'].toString())
          : null,
      uploadedAt: json['uploadedAt'] != null
          ? DateTime.tryParse(json['uploadedAt'].toString())
          : null,
      notes: json['notes']?.toString(),
      isSharedWithDietitian: isShared,
      storageKey: json['storageKey']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'reference': reference,
      'householdMemberId': householdMemberId,
      'documentType': documentType,
      'title': title,
      'originalFileName': originalFileName,
      'mimeType': mimeType,
      'fileSize': fileSize,
      'status': status,
      'reportDate': reportDate?.toIso8601String(),
      'uploadedAt': uploadedAt?.toIso8601String(),
      'notes': notes,
      'storageKey': storageKey,
    };
  }
}
