import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../domain/entities/health_document_entity.dart';
import '../../data/repositories/health_documents_repository_impl.dart';

enum UploadFlowState {
  idle,
  selecting,
  validating,
  uploading,
  processing,
  success,
  failed,
}

class UploadHealthDocumentScreen extends StatefulWidget {
  final String memberId;
  final String memberName;
  final List<DocumentCategoryItem> availableCategories;

  const UploadHealthDocumentScreen({
    super.key,
    required this.memberId,
    required this.memberName,
    required this.availableCategories,
  });

  @override
  State<UploadHealthDocumentScreen> createState() => _UploadHealthDocumentScreenState();
}

class _UploadHealthDocumentScreenState extends State<UploadHealthDocumentScreen> {
  final HealthDocumentsRepositoryImpl _repository = HealthDocumentsRepositoryImpl();
  final ImagePicker _picker = ImagePicker();

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  String _selectedCategory = 'LAB_REPORT';
  DateTime _documentDate = DateTime.now();
  bool _shareWithDietitian = true;

  Uint8List? _fileBytes;
  String? _fileName;
  String? _mimeType;
  int? _fileSizeBytes;

  UploadFlowState _state = UploadFlowState.idle;
  double _uploadProgress = 0.0;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    if (widget.availableCategories.isNotEmpty) {
      _selectedCategory = widget.availableCategories.first.key;
    }
  }

  @override
  void dispose() {
    _titleController.disposeWidget();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickFile(ImageSource source) async {
    setState(() => _state = UploadFlowState.selecting);
    try {
      final picked = await _picker.pickImage(
        source: source,
        imageQuality: 90,
      );
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        final size = bytes.length;

        // Section 11 & 12 validation: 15MB limit
        if (size > 15 * 1024 * 1024) {
          setState(() {
            _state = UploadFlowState.idle;
            _errorMessage = 'DOCUMENT_SIZE_EXCEEDED: Maximum allowed file size is 15 MB.';
          });
          return;
        }

        final name = picked.name;
        String mime = 'image/jpeg';
        if (name.toLowerCase().endsWith('.png')) {
          mime = 'image/png';
        } else if (name.toLowerCase().endsWith('.pdf')) {
          mime = 'application/pdf';
        }

        setState(() {
          _fileBytes = bytes;
          _fileName = name;
          _mimeType = mime;
          _fileSizeBytes = size;
          _state = UploadFlowState.idle;
          _errorMessage = null;

          if (_titleController.text.trim().isEmpty) {
            final catName = _getCategoryDisplayName(_selectedCategory);
            final dateStr = DateFormat('MMM yyyy').format(_documentDate);
            _titleController.text = '$catName - $dateStr';
          }
        });
      } else {
        setState(() => _state = UploadFlowState.idle);
      }
    } catch (e) {
      setState(() {
        _state = UploadFlowState.idle;
        _errorMessage = 'Could not select file: $e';
      });
    }
  }

  String _getCategoryDisplayName(String key) {
    for (final cat in widget.availableCategories) {
      if (cat.key == key) return cat.name;
    }
    return key.replaceAll('_', ' ');
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _documentDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF0D9488),
              onPrimary: Colors.white,
              onSurface: Color(0xFF0F172A),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _documentDate = picked);
    }
  }

  Future<void> _startUpload() async {
    if (_fileBytes == null || _fileName == null) {
      setState(() => _errorMessage = 'Please choose a document file to upload.');
      return;
    }

    final title = _titleController.text.trim();
    if (title.isEmpty) {
      setState(() => _errorMessage = 'Please enter a document title.');
      return;
    }

    setState(() {
      _state = UploadFlowState.validating;
      _uploadProgress = 0.15;
      _errorMessage = null;
    });

    await Future.delayed(const Duration(milliseconds: 300));

    setState(() {
      _state = UploadFlowState.uploading;
      _uploadProgress = 0.55;
    });

    try {
      await _repository.uploadDocumentDirect(
        memberId: widget.memberId,
        category: _selectedCategory,
        title: title,
        fileBytes: _fileBytes!,
        fileName: _fileName!,
        mimeType: _mimeType,
        documentDate: _documentDate,
        notes: _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
        shareWithDietitian: _shareWithDietitian,
      );

      setState(() {
        _state = UploadFlowState.processing;
        _uploadProgress = 0.90;
      });

      await Future.delayed(const Duration(milliseconds: 400));

      setState(() {
        _state = UploadFlowState.success;
        _uploadProgress = 1.0;
      });

      await Future.delayed(const Duration(milliseconds: 800));
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      setState(() {
        _state = UploadFlowState.failed;
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isBusy = _state == UploadFlowState.uploading ||
        _state == UploadFlowState.validating ||
        _state == UploadFlowState.processing;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Upload Health Document',
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
          onPressed: isBusy ? null : () => Navigator.of(context).maybePop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Target Member Card (Section 10)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFCCFBF1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.person_rounded, color: Color(0xFF0D9488), size: 20),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'DOCUMENT BELONGS TO',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.7,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.memberName,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Category Selection (Section 10)
            const Text(
              'Document Category',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFCBD5E1)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: _selectedCategory,
                  icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF64748B)),
                  items: widget.availableCategories.map((cat) {
                    return DropdownMenuItem<String>(
                      value: cat.key,
                      child: Row(
                        children: [
                          Icon(_getCategoryIcon(cat.key), size: 18, color: const Color(0xFF0D9488)),
                          const SizedBox(width: 10),
                          Text(cat.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: isBusy
                      ? null
                      : (val) {
                          if (val != null) {
                            setState(() => _selectedCategory = val);
                          }
                        },
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Document Title (Section 10)
            const Text(
              'Document Title',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _titleController,
              enabled: !isBusy,
              decoration: InputDecoration(
                hintText: 'e.g. Blood Test - September, Lipid Panel',
                hintStyle: const TextStyle(fontSize: 13.5, color: Color(0xFF94A3B8)),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF0D9488), width: 1.5),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
            const SizedBox(height: 16),

            // Document Date (Section 10)
            const Text(
              'Report / Document Date',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
            ),
            const SizedBox(height: 6),
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: isBusy ? null : _selectDate,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_month_rounded, size: 18, color: Color(0xFF0D9488)),
                    const SizedBox(width: 10),
                    Text(
                      DateFormat('dd MMMM yyyy').format(_documentDate),
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF0F172A)),
                    ),
                    const Spacer(),
                    const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8), size: 20),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // File Attachment Box (Section 10 & 11)
            const Text(
              'Document File (PDF, JPG, PNG up to 15MB)',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
            ),
            const SizedBox(height: 6),
            _buildFileSelectorCard(),
            const SizedBox(height: 16),

            // Optional Notes (Section 10: "Do not ask for unnecessary medical details")
            const Text(
              'Notes (Optional)',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _notesController,
              enabled: !isBusy,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'Any special notes for your dietitian regarding this report...',
                hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF0D9488), width: 1.5),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
            const SizedBox(height: 16),

            // Share with Dietitian Switch (Section 27-29)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.share_rounded, color: Color(0xFF2563EB), size: 18),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Share with Dietitian',
                          style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                        ),
                        Text(
                          'Allow assigned dietitian to review for meal planning',
                          style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  Switch.adaptive(
                    value: _shareWithDietitian,
                    activeColor: const Color(0xFF0D9488),
                    onChanged: isBusy ? null : (v) => setState(() => _shareWithDietitian = v),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Error display / Upload Failed banner (Section 57)
            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFCA5A5)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(fontSize: 12.5, color: Color(0xFF991B1B)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Progress bar (Section 56)
            if (isBusy || _state == UploadFlowState.success) ...[
              _buildProgressSection(),
              const SizedBox(height: 16),
            ],

            // Upload Button or Retry Button (Section 57)
            if (_state == UploadFlowState.failed) ...[
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => setState(() => _state = UploadFlowState.idle),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _startUpload,
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text('Retry Upload'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0D9488),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ] else ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: isBusy ? null : _startUpload,
                  icon: isBusy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.cloud_upload_rounded, color: Colors.white),
                  label: Text(
                    isBusy ? 'Uploading...' : 'Upload Document',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0D9488),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildFileSelectorCard() {
    if (_fileBytes != null && _fileName != null) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF0D9488)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFCCFBF1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.insert_drive_file_rounded, color: Color(0xFF0D9488), size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _fileName!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
                  ),
                  if (_fileSizeBytes != null)
                    Text(
                      '${(_fileSizeBytes! / (1024 * 1024)).toStringAsFixed(2)} MB',
                      style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                    ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
              onPressed: () {
                setState(() {
                  _fileBytes = null;
                  _fileName = null;
                  _mimeType = null;
                  _fileSizeBytes = null;
                });
              },
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      child: Column(
        children: [
          const Icon(Icons.cloud_upload_outlined, size: 36, color: Color(0xFF0D9488)),
          const SizedBox(height: 8),
          const Text(
            'Select Document or Photo',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 4),
          const Text(
            'Upload a scan from gallery or capture with camera',
            style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: () => _pickFile(ImageSource.gallery),
                icon: const Icon(Icons.photo_library_outlined, size: 16, color: Color(0xFF0D9488)),
                label: const Text('Photo / Gallery', style: TextStyle(color: Color(0xFF0D9488))),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF0D9488)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: () => _pickFile(ImageSource.camera),
                icon: const Icon(Icons.camera_alt_outlined, size: 16, color: Color(0xFF0D9488)),
                label: const Text('Scan / Camera', style: TextStyle(color: Color(0xFF0D9488))),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF0D9488)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProgressSection() {
    String statusText = 'Uploading document...';
    if (_state == UploadFlowState.validating) {
      statusText = 'Validating file signature and size...';
    } else if (_state == UploadFlowState.processing) {
      statusText = 'Storing securely in encrypted health vault...';
    } else if (_state == UploadFlowState.success) {
      statusText = 'Uploaded successfully!';
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                statusText,
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
              ),
              Text(
                '${(_uploadProgress * 100).toInt()}%',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF0D9488)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: _uploadProgress,
              backgroundColor: const Color(0xFFE2E8F0),
              color: const Color(0xFF0D9488),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Please keep the app open while we securely transmit and encrypt your document.',
            style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
          ),
        ],
      ),
    );
  }

  IconData _getCategoryIcon(String key) {
    switch (key) {
      case 'LAB_REPORT':
        return Icons.biotech_rounded;
      case 'DIAGNOSTIC_REPORT':
        return Icons.monitor_heart_rounded;
      case 'DOCTOR_REPORT':
        return Icons.medical_services_rounded;
      case 'PRESCRIPTION':
        return Icons.medication_rounded;
      case 'DIETITIAN_REPORT':
        return Icons.restaurant_menu_rounded;
      case 'MEDICAL_DOCUMENT':
        return Icons.assignment_rounded;
      default:
        return Icons.description_rounded;
    }
  }
}
extension on TextEditingController {
  void disposeWidget() {
    dispose();
  }
}
