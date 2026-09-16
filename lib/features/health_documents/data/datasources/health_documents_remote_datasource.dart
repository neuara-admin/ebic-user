import '../../../../core/api/api_client.dart';
import '../../../../core/api/api_endpoints.dart';
import '../models/health_document_model.dart';
import '../../domain/entities/health_document_entity.dart';

class HealthDocumentsRemoteDataSource {
  final ApiClient _api = ApiClient();

  Future<List<DocumentCategoryItem>> fetchCategories() async {
    try {
      final res = await _api.get(ApiEndpoints.healthDocumentCategories);
      if (res.success && res.data != null) {
        final data = res.data;
        List<dynamic>? rawList;
        if (data is Map && data['categories'] is List) {
          rawList = data['categories'] as List<dynamic>;
        } else if (data is List) {
          rawList = data;
        }

        if (rawList != null) {
          return rawList
              .whereType<Map<String, dynamic>>()
              .map((item) => DocumentCategoryItem.fromJson(item))
              .toList();
        }
      }
    } catch (_) {}

    // Fallback initial categories per Section 5 of specification
    return const [
      DocumentCategoryItem(
        key: 'LAB_REPORT',
        name: 'Lab Report',
        description: 'Blood work, urinalysis, pathology panels, and lipid profiles',
      ),
      DocumentCategoryItem(
        key: 'DIAGNOSTIC_REPORT',
        name: 'Diagnostic Report',
        description: 'Radiology, scans, ultrasounds, ECG, and diagnostic testing',
      ),
      DocumentCategoryItem(
        key: 'DOCTOR_REPORT',
        name: 'Doctor Report',
        description: 'Physician notes, clinical summaries, and hospital discharge papers',
      ),
      DocumentCategoryItem(
        key: 'PRESCRIPTION',
        name: 'Prescription',
        description: 'Medical prescriptions, pharmaceutical regimens, and supplements',
      ),
      DocumentCategoryItem(
        key: 'DIETITIAN_REPORT',
        name: 'Dietitian Report',
        description: 'Nutrition assessments, clinical goals, and consultation notes',
      ),
      DocumentCategoryItem(
        key: 'MEDICAL_DOCUMENT',
        name: 'Medical Document',
        description: 'Health history summaries, insurance records, and vaccination certificates',
      ),
      DocumentCategoryItem(
        key: 'OTHER',
        name: 'Other Health Document',
        description: 'Miscellaneous health, recovery, or fitness reports',
      ),
    ];
  }

  Future<List<HealthDocumentModel>> fetchMemberDocuments(
    String memberId, {
    String? category,
    String? status,
  }) async {
    final query = <String, dynamic>{'memberId': memberId};
    if (category != null && category.isNotEmpty) query['category'] = category;
    if (status != null && status.isNotEmpty) query['status'] = status;

    final res = await _api.get(ApiEndpoints.healthDocuments, queryParameters: query);
    if (res.success && res.data != null) {
      final data = res.data;
      List<dynamic> list = [];
      if (data is List) {
        list = data;
      } else if (data is Map && data['data'] is List) {
        list = data['data'] as List<dynamic>;
      }
      return list
          .whereType<Map<String, dynamic>>()
          .map((item) => HealthDocumentModel.fromJson(item))
          .toList();
    }
    return [];
  }

  Future<HealthDocumentModel> fetchDocumentDetail(String documentId) async {
    final res = await _api.get(ApiEndpoints.healthDocumentDetail(documentId));
    if (res.success && res.data != null) {
      final map = res.data is Map<String, dynamic>
          ? res.data as Map<String, dynamic>
          : (res.data is Map && (res.data as Map)['data'] is Map
              ? (res.data as Map)['data'] as Map<String, dynamic>
              : <String, dynamic>{});
      return HealthDocumentModel.fromJson(map);
    }
    throw Exception(res.error?.message ?? 'Failed to load document');
  }

  Future<String> fetchAccessUrl(String documentId) async {
    final res = await _api.post(ApiEndpoints.healthDocumentAccess(documentId));
    if (res.success && res.data != null) {
      if (res.data is Map) {
        final map = res.data as Map;
        final accessUrl = map['accessUrl']?.toString() ??
            (map['data'] is Map ? map['data']['accessUrl']?.toString() : null);
        if (accessUrl != null) return accessUrl;
      }
    }
    return ApiEndpoints.healthDocumentAccess(documentId);
  }

  Future<HealthDocumentModel> uploadDirect({
    required String memberId,
    required String category,
    required String title,
    required List<int> fileBytes,
    required String fileName,
    String? mimeType,
    DateTime? documentDate,
    String? notes,
  }) async {
    final fields = <String, String>{
      'memberId': memberId,
      'category': category,
      'title': title,
    };
    if (documentDate != null) {
      fields['documentDate'] = documentDate.toIso8601String();
    }
    if (notes != null && notes.isNotEmpty) {
      fields['notes'] = notes;
    }

    final res = await _api.uploadMultipart(
      ApiEndpoints.healthDocumentUploadDirect,
      fileBytes: fileBytes,
      filename: fileName,
      fieldName: 'file',
      fields: fields,
    );

    if (res.success && res.data != null) {
      final map = res.data is Map<String, dynamic>
          ? res.data as Map<String, dynamic>
          : (res.data is Map && (res.data as Map)['data'] is Map
              ? (res.data as Map)['data'] as Map<String, dynamic>
              : <String, dynamic>{});
      return HealthDocumentModel.fromJson(map);
    }

    throw Exception(res.error?.message ?? 'Failed to upload health document');
  }

  Future<bool> deleteDocument(String documentId) async {
    final res = await _api.delete(ApiEndpoints.healthDocumentDetail(documentId));
    return res.success;
  }

  Future<bool> setDietitianAccess(String documentId, String memberId, bool allowAccess) async {
    if (allowAccess) {
      final res = await _api.post(
        ApiEndpoints.healthDocumentPermissions(documentId),
        body: {
          'memberId': memberId,
          'subjectType': 'DIETITIAN',
          'purpose': 'CONSULTATION',
          'status': 'GRANTED',
        },
      );
      return res.success;
    } else {
      // Grant revocation or delete permission
      final res = await _api.post(
        ApiEndpoints.healthDocumentPermissions(documentId),
        body: {
          'memberId': memberId,
          'subjectType': 'DIETITIAN',
          'purpose': 'CONSULTATION',
          'status': 'REVOKED',
        },
      );
      return res.success;
    }
  }
}
