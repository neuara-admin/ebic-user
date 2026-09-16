import '../../domain/entities/health_document_entity.dart';
import '../../domain/repositories/health_documents_repository.dart';
import '../datasources/health_documents_remote_datasource.dart';

class HealthDocumentsRepositoryImpl implements HealthDocumentsRepository {
  final HealthDocumentsRemoteDataSource _dataSource;

  HealthDocumentsRepositoryImpl([HealthDocumentsRemoteDataSource? dataSource])
      : _dataSource = dataSource ?? HealthDocumentsRemoteDataSource();

  @override
  Future<List<DocumentCategoryItem>> getCategories() {
    return _dataSource.fetchCategories();
  }

  @override
  Future<List<HealthDocumentEntity>> getMemberDocuments(
    String memberId, {
    String? category,
    String? status,
  }) {
    return _dataSource.fetchMemberDocuments(memberId, category: category, status: status);
  }

  @override
  Future<HealthDocumentEntity> getDocumentDetail(String documentId) {
    return _dataSource.fetchDocumentDetail(documentId);
  }

  @override
  Future<String> getDocumentAccessUrl(String documentId) {
    return _dataSource.fetchAccessUrl(documentId);
  }

  @override
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
  }) async {
    final doc = await _dataSource.uploadDirect(
      memberId: memberId,
      category: category,
      title: title,
      fileBytes: fileBytes,
      fileName: fileName,
      mimeType: mimeType,
      documentDate: documentDate,
      notes: notes,
    );

    if (shareWithDietitian) {
      await _dataSource.setDietitianAccess(doc.id, memberId, true);
    }

    return doc;
  }

  @override
  Future<bool> deleteDocument(String documentId) {
    return _dataSource.deleteDocument(documentId);
  }

  @override
  Future<bool> setDietitianAccess(String documentId, String memberId, bool allowAccess) {
    return _dataSource.setDietitianAccess(documentId, memberId, allowAccess);
  }
}
