import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../domain/entities/health_document_entity.dart';
import '../../data/repositories/health_documents_repository_impl.dart';
import 'document_preview_screen.dart';

class DocumentDetailsScreen extends StatefulWidget {
  final String documentId;
  final String memberId;

  const DocumentDetailsScreen({
    super.key,
    required this.documentId,
    required this.memberId,
  });

  @override
  State<DocumentDetailsScreen> createState() => _DocumentDetailsScreenState();
}

class _DocumentDetailsScreenState extends State<DocumentDetailsScreen> {
  final HealthDocumentsRepositoryImpl _repository = HealthDocumentsRepositoryImpl();

  HealthDocumentEntity? _document;
  bool _isLoading = true;
  bool _isTogglingAccess = false;
  bool _isDeleting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadDocument();
  }

  Future<void> _loadDocument() async {
    setState(() => _isLoading = true);
    try {
      final doc = await _repository.getDocumentDetail(widget.documentId);
      if (mounted) {
        setState(() {
          _document = doc;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _toggleDietitianAccess(bool allow) async {
    if (_document == null) return;
    setState(() => _isTogglingAccess = true);
    try {
      await _repository.setDietitianAccess(widget.documentId, widget.memberId, allow);
      // Reload document details to reflect state
      final updated = await _repository.getDocumentDetail(widget.documentId);
      if (mounted) {
        setState(() {
          _document = updated;
          _isTogglingAccess = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              allow
                ? 'Dietitian granted access for consultation.'
                : 'Dietitian access revoked successfully.',
            ),
            backgroundColor: allow ? const Color(0xFF0D9488) : const Color(0xFF475569),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isTogglingAccess = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update access: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Delete this document?',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
        ),
        content: const Text(
          'This will remove it from your Health Documents. The record will be securely archived.',
          style: TextStyle(fontSize: 13.5, color: Color(0xFF475569)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isDeleting = true);
      try {
        final success = await _repository.deleteDocument(widget.documentId);
        if (success && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Document removed.'), backgroundColor: Color(0xFF475569)),
          );
          Navigator.of(context).pop(true);
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isDeleting = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not delete: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  void _openPreview() {
    if (_document == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DocumentPreviewScreen(
          documentId: _document!.id,
          title: _document!.title,
          fileExtension: _document!.fileExtension,
          mimeType: _document!.mimeType,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF8FAFC),
        body: Center(child: CircularProgressIndicator(color: Color(0xFF0D9488))),
      );
    }

    if (_document == null) {
      return Scaffold(
        appBar: AppBar(backgroundColor: Colors.white, elevation: 0),
        body: Center(
          child: Text(_errorMessage ?? 'Document not found.'),
        ),
      );
    }

    final doc = _document!;
    final isPdf = doc.fileExtension == 'PDF';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Document Details',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: Color(0xFF0F172A),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: Color(0xFF0F172A)),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFDC2626)),
            onPressed: _isDeleting ? null : _confirmDelete,
            tooltip: 'Delete Document',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Preview Card Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: isPdf ? const Color(0xFFFEE2E2) : const Color(0xFFE0F2FE),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Center(
                          child: Icon(
                            isPdf ? Icons.picture_as_pdf_rounded : Icons.image_rounded,
                            size: 28,
                            color: isPdf ? const Color(0xFFDC2626) : const Color(0xFF0284C7),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              doc.title,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${doc.categoryDisplay} • ${doc.formattedFileSize}',
                              style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Open / Preview Button (Section 23 & 24)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _openPreview,
                      icon: const Icon(Icons.visibility_outlined, size: 18, color: Colors.white),
                      label: const Text(
                        'Open Document',
                        style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0D9488),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Metadata Section (Section 14 & 23)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'DOCUMENT METADATA',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildMetaRow('Category', doc.categoryDisplay),
                  const Divider(height: 16, color: Color(0xFFF1F5F9)),
                  _buildMetaRow(
                    'Report Date',
                    doc.reportDate != null
                        ? DateFormat('dd MMMM yyyy').format(doc.reportDate!)
                        : 'Not specified',
                  ),
                  const Divider(height: 16, color: Color(0xFFF1F5F9)),
                  _buildMetaRow(
                    'Uploaded',
                    doc.uploadedAt != null
                        ? DateFormat('dd MMM yyyy, hh:mm a').format(doc.uploadedAt!)
                        : 'Recently',
                  ),
                  const Divider(height: 16, color: Color(0xFFF1F5F9)),
                  _buildMetaRow('File Name', doc.originalFileName ?? 'Attached document'),
                  const Divider(height: 16, color: Color(0xFFF1F5F9)),
                  _buildMetaRow('Status', doc.statusDisplay),
                  if (doc.reference != null) ...[
                    const Divider(height: 16, color: Color(0xFFF1F5F9)),
                    _buildMetaRow('Reference Code', doc.reference!),
                  ],
                  if (doc.notes != null && doc.notes!.isNotEmpty) ...[
                    const Divider(height: 16, color: Color(0xFFF1F5F9)),
                    _buildMetaRow('Notes', doc.notes!),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Dietitian Access Control Section (Section 27, 28, 29)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.security_rounded, size: 18, color: Color(0xFF0D9488)),
                      const SizedBox(width: 8),
                      const Text(
                        'ACCESS & PRIVACY CONTROL',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Dietitian Consultation Access',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              doc.isSharedWithDietitian
                                  ? 'Authorized. Assigned dietitian can reference this record during consultation & diet planning.'
                                  : 'Private. Dietitian cannot see or download this file.',
                              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.3),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      _isTogglingAccess
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0D9488)),
                            )
                          : Switch.adaptive(
                              value: doc.isSharedWithDietitian,
                              activeColor: const Color(0xFF0D9488),
                              onChanged: _toggleDietitianAccess,
                            ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Document History / Audit Trail (Section 35)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.history_rounded, size: 18, color: Color(0xFF64748B)),
                      const SizedBox(width: 8),
                      const Text(
                        'DOCUMENT HISTORY & AUDIT',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildHistoryItem(
                    icon: Icons.cloud_done_rounded,
                    title: 'Document Uploaded',
                    subtitle: doc.uploadedAt != null
                        ? DateFormat('dd MMM yyyy, hh:mm a').format(doc.uploadedAt!)
                        : 'Initial record saved',
                  ),
                  if (doc.isSharedWithDietitian)
                    _buildHistoryItem(
                      icon: Icons.verified_user_rounded,
                      title: 'Dietitian Consultation Permission Granted',
                      subtitle: 'Active consent for nutrition assessment',
                    ),
                  _buildHistoryItem(
                    icon: Icons.lock_outline_rounded,
                    title: 'Encrypted at Rest & In Transit',
                    subtitle: 'Private object storage with signed short-lived tokens',
                    isLast: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildMetaRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
          child: Text(
            label,
            style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF0F172A),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHistoryItem({
    required IconData icon,
    required String title,
    required String subtitle,
    bool isLast = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 14, color: const Color(0xFF0D9488)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
