import '../../domain/entities/health_document_entity.dart';

abstract class HealthDocumentsRepository {
  Future<List<DocumentCategoryItem>> getCategories();

  Future<List<HealthDocumentEntity>> getMemberDocuments(String memberId, {String? category, String? status});

  Future<HealthDocumentEntity> getDocumentDetail(String documentId);

  Future<String> getDocumentAccessUrl(String documentId);

  Future<HealthDocumentEntity> uploadDocumentDirect({
    required String memberId,
    required String category,
    required String title,
    required List<int> fileBytes,
    required String fileName,
    String? mimeType,
    DateTime? documentDate,
    String? notes,
    bool shareWithDietitian = true,
  });

  Future<bool> deleteDocument(String documentId);

  Future<bool> setDietitianAccess(String documentId, String memberId, bool allowAccess);
}
