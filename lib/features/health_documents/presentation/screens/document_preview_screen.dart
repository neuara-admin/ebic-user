import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdfx/pdfx.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/api/api_endpoints.dart';

/// Views a health document. The file is stored encrypted on the server; the
/// authenticated `/health/documents/:id/access` endpoint checks access and
/// returns the decrypted bytes, which are kept in memory only. Nothing is
/// written to disk unless the user explicitly shares the file.
class DocumentPreviewScreen extends StatefulWidget {
  final String documentId;
  final String title;
  final String fileExtension;
  final String? mimeType;

  const DocumentPreviewScreen({
    super.key,
    required this.documentId,
    required this.title,
    required this.fileExtension,
    this.mimeType,
  });

  @override
  State<DocumentPreviewScreen> createState() => _DocumentPreviewScreenState();
}

class _DocumentPreviewScreenState extends State<DocumentPreviewScreen> {
  static const _bg = Color(0xFF0F172A);
  static const _accent = Color(0xFF0D9488);

  Uint8List? _bytes;
  PdfControllerPinch? _pdfController;
  int _page = 1;
  int _pageCount = 0;
  bool _isLoading = true;
  bool _sharing = false;
  String? _errorMessage;

  bool _detectIsPdf(Uint8List bytes) {
    if (bytes.length >= 4 &&
        bytes[0] == 0x25 && // %
        bytes[1] == 0x50 && // P
        bytes[2] == 0x44 && // D
        bytes[3] == 0x46) { // F
      return true;
    }
    return widget.fileExtension.toUpperCase() == 'PDF' ||
        (widget.mimeType ?? '').toLowerCase().contains('pdf');
  }

  bool _isPdf = false;

  @override
  void initState() {
    super.initState();
    _isPdf = widget.fileExtension.toUpperCase() == 'PDF' ||
        (widget.mimeType ?? '').toLowerCase().contains('pdf');
    _load();
  }

  @override
  void dispose() {
    _pdfController?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    final result = await ApiClient()
        .downloadBinary(ApiEndpoints.healthDocumentAccess(widget.documentId));
    if (!mounted) return;
    if (!result.success || result.bytes == null || result.bytes!.isEmpty) {
      setState(() {
        _errorMessage =
            result.error ?? 'Could not open this document. Please try again.';
        _isLoading = false;
      });
      return;
    }
    final bytes = Uint8List.fromList(result.bytes!);
    _pdfController?.dispose();
    final isPdf = _detectIsPdf(bytes);
    setState(() {
      _bytes = bytes;
      _isPdf = isPdf;
      _pdfController =
          isPdf ? PdfControllerPinch(document: PdfDocument.openData(bytes)) : null;
      _page = 1;
      _isLoading = false;
    });
  }

  String get _fileName {
    final ext = _isPdf ? 'pdf' : (widget.fileExtension.toLowerCase() == 'png' ? 'png' : 'jpg');
    final base = widget.title.replaceAll(RegExp(r'[^\w\- ]'), '').trim();
    return '${base.isEmpty ? 'health-document' : base}.$ext';
  }

  Future<void> _share() async {
    final bytes = _bytes;
    if (bytes == null || _sharing) return;
    setState(() => _sharing = true);
    File? tmp;
    try {
      final mime = widget.mimeType ?? (_isPdf ? 'application/pdf' : 'image/jpeg');
      if (kIsWeb) {
        await Share.shareXFiles([XFile.fromData(bytes, mimeType: mime, name: _fileName)]);
      } else {
        final dir = await getTemporaryDirectory();
        tmp = File('${dir.path}/$_fileName');
        await tmp.writeAsBytes(bytes, flush: true);
        await Share.shareXFiles([XFile(tmp.path, mimeType: mime, name: _fileName)]);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not share this document.')),
        );
      }
    } finally {
      // Don't leave a decrypted copy lying around in the cache.
      try {
        await tmp?.delete();
      } catch (_) {}
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: Text(
          widget.title,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
        ),
        backgroundColor: _bg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: Colors.white),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        actions: [
          if (_bytes != null)
            IconButton(
              icon: _sharing
                  ? const SizedBox(
                      width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.ios_share_rounded, color: Colors.white),
              onPressed: _share,
              tooltip: 'Share or save',
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: const Color(0xFF1E293B),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.lock_rounded, size: 13, color: Color(0xFF10B981)),
                  SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'Stored encrypted · visible only to you and dietitians you share with',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF94A3B8)),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return const Center(child: CircularProgressIndicator(color: _accent));
    if (_errorMessage != null) return _buildError(_errorMessage!);
    if (_isPdf && _pdfController != null) return _buildPdf();
    return _buildImage();
  }

  Widget _buildError(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 48, color: Colors.amber),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 13)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _load,
              style: ElevatedButton.styleFrom(backgroundColor: _accent, foregroundColor: Colors.white),
              child: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPdf() {
    return Stack(
      children: [
        PdfViewPinch(
          controller: _pdfController!,
          onDocumentLoaded: (doc) => setState(() => _pageCount = doc.pagesCount),
          onPageChanged: (page) => setState(() => _page = page),
          builders: PdfViewPinchBuilders<DefaultBuilderOptions>(
            options: const DefaultBuilderOptions(),
            documentLoaderBuilder: (_) => const Center(child: CircularProgressIndicator(color: _accent)),
            pageLoaderBuilder: (_) => const Center(child: CircularProgressIndicator(color: _accent)),
            errorBuilder: (_, __) => _buildError(
              "This PDF can't be shown here. Use Share to open it in another app.",
            ),
          ),
        ),
        if (_pageCount > 1)
          Positioned(
            bottom: 16,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$_page / $_pageCount',
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildImage() {
    return InteractiveViewer(
      minScale: 0.8,
      maxScale: 5.0,
      child: Center(
        child: Image.memory(
          _bytes!,
          fit: BoxFit.contain,
          gaplessPlayback: true,
          errorBuilder: (_, __, ___) => _buildError("This image can't be shown. Use Share to open it in another app."),
        ),
      ),
    );
  }
}
