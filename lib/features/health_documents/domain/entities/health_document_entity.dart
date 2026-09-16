class HealthDocumentEntity {
  final String id;
  final String? reference;
  final String householdMemberId;
  final String documentType;
  final String title;
  final String? originalFileName;
  final String? mimeType;
  final int? fileSize;
  final String status;
  final DateTime? reportDate;
  final DateTime? uploadedAt;
  final String? notes;
  final bool isSharedWithDietitian;
  final String? storageKey;

  const HealthDocumentEntity({
    required this.id,
    this.reference,
    required this.householdMemberId,
    required this.documentType,
    required this.title,
    this.originalFileName,
    this.mimeType,
    this.fileSize,
    required this.status,
    this.reportDate,
    this.uploadedAt,
    this.notes,
    this.isSharedWithDietitian = false,
    this.storageKey,
  });

  String get formattedFileSize {
    if (fileSize == null || fileSize! <= 0) return 'Unknown size';
    if (fileSize! < 1024) return '$fileSize B';
    if (fileSize! < 1024 * 1024) return '${(fileSize! / 1024).toStringAsFixed(1)} KB';
    return '${(fileSize! / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String get fileExtension {
    if (originalFileName != null && originalFileName!.contains('.')) {
      return originalFileName!.split('.').last.toUpperCase();
    }
    if (mimeType != null && mimeType!.contains('pdf')) return 'PDF';
    if (mimeType != null && (mimeType!.contains('png') || mimeType!.contains('jpeg') || mimeType!.contains('jpg'))) {
      return 'IMG';
    }
    return 'DOC';
  }

  String get statusDisplay {
    switch (status.toUpperCase()) {
      case 'UPLOADING':
        return 'Uploading...';
      case 'UPLOADED':
      case 'PROCESSING':
        return 'Processing';
      case 'AVAILABLE':
        return 'Available';
      case 'FAILED':
        return 'Upload failed';
      case 'DELETED':
        return 'Deleted';
      case 'QUARANTINED':
        return 'Unavailable';
      default:
        return status;
    }
  }

  String get categoryDisplay {
    switch (documentType) {
      case 'LAB_REPORT':
        return 'Lab Report';
      case 'DIAGNOSTIC_REPORT':
        return 'Diagnostic Report';
      case 'DOCTOR_REPORT':
        return 'Doctor Report';
      case 'PRESCRIPTION':
        return 'Prescription';
      case 'DIETITIAN_REPORT':
        return 'Dietitian Report';
      case 'MEDICAL_DOCUMENT':
        return 'Medical Document';
      case 'OTHER':
        return 'Other Health Document';
      default:
        return documentType.replaceAll('_', ' ');
    }
  }
}

class DocumentCategoryItem {
  final String key;
  final String name;
  final String description;

  const DocumentCategoryItem({
    required this.key,
    required this.name,
    required this.description,
  });

  factory DocumentCategoryItem.fromJson(Map<String, dynamic> json) {
    return DocumentCategoryItem(
      key: json['key']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
    );
  }
}
