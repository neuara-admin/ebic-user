import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../../../shared/models/household_member_model.dart';
import '../../data/datasources/health_documents_remote_datasource.dart';
import '../../data/repositories/health_documents_repository_impl.dart';
import '../../domain/entities/health_document_entity.dart';

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
  final List<HouseholdMemberModel>? householdMembers;

  const UploadHealthDocumentScreen({
    super.key,
    required this.memberId,
    required this.memberName,
    required this.availableCategories,
    this.householdMembers,
  });

  @override
  State<UploadHealthDocumentScreen> createState() =>
      _UploadHealthDocumentScreenState();
}

class _UploadHealthDocumentScreenState
    extends State<UploadHealthDocumentScreen> {
  final HealthDocumentsRepositoryImpl _repository =
      HealthDocumentsRepositoryImpl();
  final ImagePicker _imagePicker = ImagePicker();

  late String _activeMemberId;
  late String _activeMemberName;

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  late String _selectedCategory;
  DateTime _documentDate = DateTime.now();
  bool _shareWithDietitian = true;

  Uint8List? _fileBytes;
  String? _fileName;
  String? _mimeType;
  int? _fileSizeBytes;

  UploadFlowState _state = UploadFlowState.idle;
  double _uploadProgress = 0.0;
  String? _errorMessage;

  static const double _maxFileSizeMb = 15.0;

  List<DocumentCategoryItem> get _effectiveCategories {
    if (widget.availableCategories.isNotEmpty) {
      return widget.availableCategories;
    }
    return HealthDocumentsRemoteDataSource.defaultCategories;
  }

  @override
  void initState() {
    super.initState();
    _activeMemberId = widget.memberId;
    _activeMemberName = widget.memberName;

    final cats = _effectiveCategories;
    _selectedCategory = cats.isNotEmpty ? cats.first.key : 'LAB_REPORT';
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  // ─── File Selection ──────────────────────────────────────────────────────────

  void _showPickerBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const Text(
                'Upload Health Document',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Select a PDF or image scan of your medical report.',
                style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 20),
              _buildPickerOption(
                icon: Icons.picture_as_pdf_rounded,
                iconColor: const Color(0xFFDC2626),
                iconBg: const Color(0xFFFEE2E2),
                title: 'PDF or Document File',
                subtitle: 'Browse phone storage for PDF, JPG, or PNG',
                onTap: () {
                  Navigator.of(ctx).pop();
                  _pickFromFiles();
                },
              ),
              const SizedBox(height: 10),
              _buildPickerOption(
                icon: Icons.photo_library_rounded,
                iconColor: const Color(0xFF2563EB),
                iconBg: const Color(0xFFEFF6FF),
                title: 'Photo Gallery',
                subtitle: 'Pick a captured scan from your photo library',
                onTap: () {
                  Navigator.of(ctx).pop();
                  _pickFromGallery();
                },
              ),
              const SizedBox(height: 10),
              _buildPickerOption(
                icon: Icons.camera_alt_rounded,
                iconColor: const Color(0xFF0D9488),
                iconBg: const Color(0xFFCCFBF1),
                title: 'Scan with Camera',
                subtitle: 'Take a clear photo of physical prescription or report',
                onTap: () {
                  Navigator.of(ctx).pop();
                  _pickFromCamera();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPickerOption({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: Color(0xFFCBD5E1),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickFromFiles() async {
    setState(() => _state = UploadFlowState.selecting);
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      );

      if (files.isNotEmpty) {
        final file = files.first;
        try {
          final bytes = await file.readAsBytes();
          _applyFile(bytes: bytes, name: file.name, size: bytes.length);
        } catch (_) {
          setState(() {
            _state = UploadFlowState.idle;
            _errorMessage = 'Could not read file data. Please try again.';
          });
        }
      } else {
        setState(() => _state = UploadFlowState.idle);
      }
    } catch (e) {
      setState(() {
        _state = UploadFlowState.idle;
        _errorMessage = 'Could not open file picker: $e';
      });
    }
  }

  Future<void> _pickFromGallery() async {
    setState(() => _state = UploadFlowState.selecting);
    try {
      final picked = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 92,
      );
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        _applyFile(bytes: bytes, name: picked.name, size: bytes.length);
      } else {
        setState(() => _state = UploadFlowState.idle);
      }
    } catch (e) {
      setState(() {
        _state = UploadFlowState.idle;
        _errorMessage = 'Could not pick from gallery: $e';
      });
    }
  }

  Future<void> _pickFromCamera() async {
    setState(() => _state = UploadFlowState.selecting);
    try {
      final picked = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 92,
      );
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        _applyFile(bytes: bytes, name: picked.name, size: bytes.length);
      } else {
        setState(() => _state = UploadFlowState.idle);
      }
    } catch (e) {
      setState(() {
        _state = UploadFlowState.idle;
        _errorMessage = 'Could not capture photo: $e';
      });
    }
  }

  void _applyFile({
    required Uint8List bytes,
    required String name,
    required int size,
  }) {
    if (size == 0) {
      setState(() {
        _state = UploadFlowState.idle;
        _errorMessage = 'Selected file is empty.';
      });
      return;
    }

    if (size > _maxFileSizeMb * 1024 * 1024) {
      setState(() {
        _state = UploadFlowState.idle;
        _errorMessage =
            'File is too large. Maximum allowed size is ${_maxFileSizeMb.toInt()} MB.';
      });
      return;
    }

    final lower = name.toLowerCase();
    String mime;
    if (lower.endsWith('.pdf')) {
      mime = 'application/pdf';
    } else if (lower.endsWith('.png')) {
      mime = 'image/png';
    } else {
      mime = 'image/jpeg';
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
  }

  String _getCategoryDisplayName(String key) {
    for (final cat in _effectiveCategories) {
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
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: Color(0xFF0D9488),
            onPrimary: Colors.white,
            onSurface: Color(0xFF0F172A),
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _documentDate = picked);
  }

  void _showImagePreviewDialog() {
    if (_fileBytes == null) return;
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(12),
        child: Stack(
          alignment: Alignment.center,
          children: [
            InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.memory(
                  _fileBytes!,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            Positioned(
              top: 10,
              right: 10,
              child: CircleAvatar(
                backgroundColor: Colors.black.withValues(alpha: 0.6),
                child: IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Upload Execution ──────────────────────────────────────────────────────

  Future<void> _startUpload() async {
    if (_fileBytes == null || _fileName == null) {
      setState(() => _errorMessage = 'Please select a document file to upload.');
      return;
    }

    final title = _titleController.text.trim();
    if (title.isEmpty) {
      setState(() => _errorMessage = 'Please provide a document title.');
      return;
    }

    setState(() {
      _state = UploadFlowState.validating;
      _uploadProgress = 0.15;
      _errorMessage = null;
    });

    await Future.delayed(const Duration(milliseconds: 250));

    setState(() {
      _state = UploadFlowState.uploading;
      _uploadProgress = 0.50;
    });

    try {
      await _repository.uploadDocumentDirect(
        memberId: _activeMemberId,
        category: _selectedCategory,
        title: title,
        fileBytes: _fileBytes!,
        fileName: _fileName!,
        mimeType: _mimeType,
        documentDate: _documentDate,
        notes: _notesController.text.trim().isNotEmpty
            ? _notesController.text.trim()
            : null,
        shareWithDietitian: _shareWithDietitian,
      );

      setState(() {
        _state = UploadFlowState.processing;
        _uploadProgress = 0.90;
      });

      await Future.delayed(const Duration(milliseconds: 350));

      setState(() {
        _state = UploadFlowState.success;
        _uploadProgress = 1.0;
      });

      await Future.delayed(const Duration(milliseconds: 700));
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      setState(() {
        _state = UploadFlowState.failed;
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  // ─── Build Method ──────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isBusy = _state == UploadFlowState.uploading ||
        _state == UploadFlowState.validating ||
        _state == UploadFlowState.processing;

    final cats = _effectiveCategories;
    final validCategory = cats.any((c) => c.key == _selectedCategory)
        ? _selectedCategory
        : (cats.isNotEmpty ? cats.first.key : 'LAB_REPORT');

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
          icon: const Icon(
            Icons.arrow_back_ios_new,
            size: 20,
            color: Color(0xFF0F172A),
          ),
          onPressed: isBusy ? null : () => Navigator.of(context).maybePop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Household Member Card / Switcher ──────────────────────────────
            _buildMemberCard(isBusy),
            const SizedBox(height: 18),

            // ── Document Category Dropdown ───────────────────────────────────
            _fieldLabel('Document Category'),
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
                  value: validCategory,
                  icon: const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: Color(0xFF64748B),
                  ),
                  items: cats.map((cat) {
                    return DropdownMenuItem<String>(
                      value: cat.key,
                      child: Row(
                        children: [
                          Icon(
                            _getCategoryIcon(cat.key),
                            size: 18,
                            color: const Color(0xFF0D9488),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              cat.name,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: isBusy
                      ? null
                      : (val) {
                          if (val != null) {
                            setState(() {
                              _selectedCategory = val;
                              if (_fileBytes != null &&
                                  _titleController.text.contains('-')) {
                                final catName = _getCategoryDisplayName(val);
                                final dateStr =
                                    DateFormat('MMM yyyy').format(_documentDate);
                                _titleController.text = '$catName - $dateStr';
                              }
                            });
                          }
                        },
                ),
              ),
            ),
            const SizedBox(height: 18),

            // ── File Selection & Visual Preview Card ──────────────────────────
            _fieldLabel(
              'Document File  (PDF, JPG, PNG · Max ${_maxFileSizeMb.toInt()} MB)',
            ),
            const SizedBox(height: 6),
            _buildFileSelectorCard(isBusy),
            const SizedBox(height: 18),

            // ── Document Title with Explanatory Subtext ──────────────────────
            _fieldLabel('Document Title'),
            const SizedBox(height: 2),
            const Text(
              'Give this record a clear name (e.g. Lipid Profile, Fasting Blood Sugar, Prescription) to help your dietitian identify it.',
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _titleController,
              enabled: !isBusy,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF0F172A),
              ),
              decoration: _inputStyle(
                hint: 'e.g. Complete Blood Count (CBC) - Sep 2026',
              ),
            ),
            const SizedBox(height: 18),

            // ── Report / Document Date with Explanatory Subtext ───────────────
            _fieldLabel('Report / Test Date'),
            const SizedBox(height: 2),
            const Text(
              'The date printed on your physical report or when this medical test was actually performed.',
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 8),
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: isBusy ? null : _selectDate,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.calendar_month_rounded,
                      size: 18,
                      color: Color(0xFF0D9488),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      DateFormat('dd MMMM yyyy').format(_documentDate),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const Spacer(),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: Color(0xFF94A3B8),
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),

            // ── Clinical Notes (Optional) ────────────────────────────────────
            _fieldLabel('Clinical Notes (Optional)'),
            const SizedBox(height: 6),
            TextField(
              controller: _notesController,
              enabled: !isBusy,
              maxLines: 2,
              style: const TextStyle(fontSize: 13.5, color: Color(0xFF0F172A)),
              decoration: _inputStyle(
                hint: 'Notes for your clinical dietitian (e.g. fasting blood sugar, doctor remarks)...',
              ),
            ),
            const SizedBox(height: 18),

            // ── Dietitian Sharing Toggle Card ────────────────────────────────
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _shareWithDietitian
                      ? const Color(0xFF0D9488).withValues(alpha: 0.3)
                      : const Color(0xFFE2E8F0),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.medical_services_outlined,
                      color: Color(0xFF0D9488),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Share with Clinical Dietitian',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Allows dietitian to tailor meal plans based on this report',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch.adaptive(
                    value: _shareWithDietitian,
                    activeColor: const Color(0xFF0D9488),
                    onChanged: isBusy
                        ? null
                        : (v) => setState(() => _shareWithDietitian = v),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── Error Banner ─────────────────────────────────────────────────
            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFCA5A5)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      color: Color(0xFFDC2626),
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: Color(0xFF991B1B),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // ── Progress Section ─────────────────────────────────────────────
            if (isBusy || _state == UploadFlowState.success) ...[
              _buildProgressSection(),
              const SizedBox(height: 16),
            ],

            // ── Action Button ────────────────────────────────────────────────
            if (_state == UploadFlowState.failed) ...[
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () =>
                          setState(() => _state = UploadFlowState.idle),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
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
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ] else ...[
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: isBusy ? null : _startUpload,
                  icon: isBusy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.cloud_upload_rounded, color: Colors.white),
                  label: Text(
                    isBusy ? 'Uploading Document...' : 'Upload Document',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0D9488),
                    disabledBackgroundColor:
                        const Color(0xFF0D9488).withValues(alpha: 0.6),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 36),
          ],
        ),
      ),
    );
  }

  // ─── Sub-widgets ───────────────────────────────────────────────────────────

  /// Updated, polished "Document For Member" UI
  Widget _buildMemberCard(bool isBusy) {
    final members = widget.householdMembers ?? [];

    if (members.length > 1) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.people_alt_rounded,
                    color: Color(0xFF0D9488),
                    size: 16,
                  ),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'DOCUMENT FOR MEMBER',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        'Select which household member this medical document belongs to',
                        style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: members.map((m) {
                  final isSelected = m.id == _activeMemberId;
                  final relTag = m.isSelf
                      ? 'Self'
                      : (m.relationship.isNotEmpty
                          ? m.relationship.toLowerCase().replaceFirst(
                                m.relationship[0].toLowerCase(),
                                m.relationship[0].toUpperCase(),
                              )
                          : 'Family');

                  return Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: isBusy
                          ? null
                          : () {
                              setState(() {
                                _activeMemberId = m.id;
                                _activeMemberName = m.name;
                              });
                            },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFFF0FDFA)
                              : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFF0D9488)
                                : const Color(0xFFE2E8F0),
                            width: isSelected ? 1.6 : 1.0,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Stack(
                              clipBehavior: Clip.none,
                              children: [
                                CircleAvatar(
                                  radius: 16,
                                  backgroundColor: isSelected
                                      ? const Color(0xFF0D9488)
                                      : const Color(0xFFE2E8F0),
                                  child: Text(
                                    m.name.isNotEmpty
                                        ? m.name[0].toUpperCase()
                                        : 'M',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: isSelected
                                          ? Colors.white
                                          : const Color(0xFF475569),
                                    ),
                                  ),
                                ),
                                if (isSelected)
                                  Positioned(
                                    right: -2,
                                    bottom: -2,
                                    child: Container(
                                      padding: const EdgeInsets.all(2),
                                      decoration: const BoxDecoration(
                                        color: Color(0xFF10B981),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.check,
                                        size: 10,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  m.name,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: isSelected
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: isSelected
                                        ? const Color(0xFF0D9488)
                                        : const Color(0xFF0F172A),
                                  ),
                                ),
                                Container(
                                  margin: const EdgeInsets.only(top: 2),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 1,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? const Color(0xFFCCFBF1)
                                        : const Color(0xFFE2E8F0),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    relTag,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: isSelected
                                          ? const Color(0xFF0D9488)
                                          : const Color(0xFF475569),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDFA),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFCCFBF1)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.verified_outlined,
                    size: 14,
                    color: Color(0xFF0D9488),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Filing to $_activeMemberName\'s health profile & shared with their dietitian',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF065F46),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // Single member layout
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: const Color(0xFFCCFBF1),
            child: Text(
              _activeMemberName.isNotEmpty
                  ? _activeMemberName[0].toUpperCase()
                  : 'M',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0D9488),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
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
                  _activeMemberName,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const Text(
                  'Saved to private health profile and encrypted at rest',
                  style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFFECFDF5),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFA7F3D0)),
            ),
            child: const Text(
              'Selected',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFF059669),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Large, visual file preview card so the user can easily see their document/image
  Widget _buildFileSelectorCard(bool isBusy) {
    if (_fileBytes != null && _fileName != null) {
      final isPdf = _mimeType?.contains('pdf') ?? false;

      // ── Image Preview Box (Prominent & Clear) ──────────────────────────────
      if (!isPdf) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF0D9488), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0D9488).withValues(alpha: 0.08),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // High-visibility image display with interactive zoom tap
              GestureDetector(
                onTap: _showImagePreviewDialog,
                child: Stack(
                  children: [
                    Container(
                      width: double.infinity,
                      height: 200,
                      decoration: const BoxDecoration(
                        color: Color(0xFF0F172A),
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(12),
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(12),
                        ),
                        child: Image.memory(
                          _fileBytes!,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const Center(
                            child: Icon(
                              Icons.broken_image_rounded,
                              color: Colors.white54,
                              size: 40,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 10,
                      left: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.zoom_in_rounded,
                              size: 13,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Tap to preview full screen',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.9),
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: CircleAvatar(
                        radius: 16,
                        backgroundColor: Colors.black.withValues(alpha: 0.65),
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          icon: const Icon(
                            Icons.close_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                          tooltip: 'Remove',
                          onPressed: isBusy
                              ? null
                              : () => setState(() {
                                    _fileBytes = null;
                                    _fileName = null;
                                    _mimeType = null;
                                    _fileSizeBytes = null;
                                  }),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // File metadata and change button
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _fileName!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 2),
                          if (_fileSizeBytes != null)
                            Text(
                              '${(_fileSizeBytes! / (1024 * 1024)).toStringAsFixed(2)} MB · Image Scan Attached',
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: Color(0xFF0D9488),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                        ],
                      ),
                    ),
                    TextButton.icon(
                      onPressed: isBusy ? null : _showPickerBottomSheet,
                      icon: const Icon(Icons.sync_rounded, size: 16),
                      label: const Text(
                        'Change',
                        style: TextStyle(fontSize: 12.5),
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF0D9488),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }

      // ── PDF Document Preview Card ──────────────────────────────────────────
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF0D9488), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0D9488).withValues(alpha: 0.08),
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
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.picture_as_pdf_rounded,
                      color: Color(0xFFDC2626),
                      size: 32,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _fileName!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 3),
                      if (_fileSizeBytes != null)
                        Text(
                          '${(_fileSizeBytes! / (1024 * 1024)).toStringAsFixed(2)} MB · PDF Document Ready',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFDC2626),
                          ),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                  tooltip: 'Remove',
                  onPressed: isBusy
                      ? null
                      : () => setState(() {
                            _fileBytes = null;
                            _fileName = null;
                            _mimeType = null;
                            _fileSizeBytes = null;
                          }),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: isBusy ? null : _showPickerBottomSheet,
                  icon: const Icon(Icons.swap_horiz_rounded, size: 16),
                  label: const Text('Change File'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF0D9488),
                    side: const BorderSide(color: Color(0xFF0D9488)),
                    visualDensity: VisualDensity.compact,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    // Empty selector box
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: isBusy ? null : _showPickerBottomSheet,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: const Color(0xFFCBD5E1),
            style: BorderStyle.solid,
          ),
        ),
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: const BoxDecoration(
                color: Color(0xFFCCFBF1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.cloud_upload_outlined,
                size: 28,
                color: Color(0xFF0D9488),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Select Document to Upload',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'PDF, JPG, or PNG · Up to 15 MB',
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _smallBadge(
                  Icons.picture_as_pdf_rounded,
                  'PDF',
                  const Color(0xFFDC2626),
                ),
                const SizedBox(width: 8),
                _smallBadge(
                  Icons.image_rounded,
                  'Images',
                  const Color(0xFF2563EB),
                ),
                const SizedBox(width: 8),
                _smallBadge(
                  Icons.camera_alt_rounded,
                  'Camera',
                  const Color(0xFF0D9488),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _smallBadge(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressSection() {
    String statusText = 'Uploading document...';
    Color barColor = const Color(0xFF0D9488);
    if (_state == UploadFlowState.validating) {
      statusText = 'Validating file format and size...';
    } else if (_state == UploadFlowState.processing) {
      statusText = 'Storing securely in encrypted health vault...';
    } else if (_state == UploadFlowState.success) {
      statusText = '✓  Uploaded successfully!';
      barColor = const Color(0xFF10B981);
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
              Expanded(
                child: Text(
                  statusText,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
              Text(
                '${(_uploadProgress * 100).toInt()}%',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: barColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: _uploadProgress,
              backgroundColor: const Color(0xFFE2E8F0),
              valueColor: AlwaysStoppedAnimation<Color>(barColor),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Keep the app open while we encrypt and securely transmit your record.',
            style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
          ),
        ],
      ),
    );
  }

  Widget _fieldLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: Color(0xFF334155),
      ),
    );
  }

  InputDecoration _inputStyle({required String hint}) {
    return InputDecoration(
      hintText: hint,
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
