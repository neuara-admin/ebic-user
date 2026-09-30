import 'package:flutter/material.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/api/api_endpoints.dart';
import '../../../../core/context/member_context.dart';
import '../../../../shared/models/household_member_model.dart';
import '../../data/datasources/health_documents_remote_datasource.dart';
import '../../data/repositories/health_documents_repository_impl.dart';
import '../../domain/entities/health_document_entity.dart';
import 'document_details_screen.dart';
import 'document_preview_screen.dart';
import 'upload_health_document_screen.dart';

class HealthDocumentsScreen extends StatefulWidget {
  final String? initialMemberId;

  const HealthDocumentsScreen({super.key, this.initialMemberId});

  @override
  State<HealthDocumentsScreen> createState() => _HealthDocumentsScreenState();
}

class _HealthDocumentsScreenState extends State<HealthDocumentsScreen> {
  final HealthDocumentsRepositoryImpl _repository =
      HealthDocumentsRepositoryImpl();
  final ApiClient _api = ApiClient();
  final TextEditingController _searchController = TextEditingController();

  List<HouseholdMemberModel> _members = [];
  String? _selectedMemberId;
  String? _selectedMemberName;

  List<DocumentCategoryItem> _categories =
      HealthDocumentsRemoteDataSource.defaultCategories;
  String _selectedCategory = 'ALL';

  List<HealthDocumentEntity> _documents = [];
  bool _isLoadingMembers = true;
  bool _isLoadingDocs = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _initData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _initData() async {
    await Future.wait([
      _loadMembers(),
      _loadCategories(),
    ]);
  }

  Future<void> _loadMembers() async {
    setState(() => _isLoadingMembers = true);
    try {
      final res = await _api.get<List<dynamic>>(ApiEndpoints.householdMembers);
      if (res.success && res.data != null && res.data!.isNotEmpty) {
        final list = res.data!
            .whereType<Map<String, dynamic>>()
            .map((json) => HouseholdMemberModel.fromJson(json))
            .toList();

        if (mounted && list.isNotEmpty) {
          _setMembers(list);
          return;
        }
      }
    } catch (_) {}

    // Fallback 1: check MemberContext singleton
    final contextMembers = MemberContext().members;
    if (contextMembers.isNotEmpty && mounted) {
      _setMembers(contextMembers);
      return;
    }

    // Fallback 2: create default self member so UI is always responsive
    if (mounted) {
      final defaultSelf = HouseholdMemberModel(
        id: 'self',
        name: 'My Health Records',
        relationship: 'SELF',
        isSelf: true,
      );
      _setMembers([defaultSelf]);
    }
  }

  void _setMembers(List<HouseholdMemberModel> list) {
    setState(() {
      _members = list;
      _isLoadingMembers = false;
      final initial = widget.initialMemberId != null
          ? list.firstWhere(
              (m) => m.id == widget.initialMemberId,
              orElse: () => list.first,
            )
          : list.first;
      _selectedMemberId = initial.id;
      _selectedMemberName = initial.name;
    });
    _fetchDocuments();
  }

  Future<void> _loadCategories() async {
    try {
      final cats = await _repository.getCategories();
      if (mounted && cats.isNotEmpty) {
        setState(() {
          _categories = cats;
        });
      }
    } catch (_) {}
  }

  Future<void> _fetchDocuments() async {
    if (_selectedMemberId == null) return;
    setState(() => _isLoadingDocs = true);
    try {
      final docs = await _repository.getMemberDocuments(
        _selectedMemberId == 'self' ? '' : _selectedMemberId!,
        category: _selectedCategory == 'ALL' ? null : _selectedCategory,
      );
      if (mounted) {
        setState(() {
          _documents = docs;
          _isLoadingDocs = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingDocs = false);
    }
  }

  List<HealthDocumentEntity> get _filteredDocuments {
    if (_searchQuery.trim().isEmpty) return _documents;
    final q = _searchQuery.toLowerCase().trim();
    return _documents.where((d) {
      return d.title.toLowerCase().contains(q) ||
          d.categoryDisplay.toLowerCase().contains(q) ||
          (d.reference?.toLowerCase().contains(q) ?? false);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Health Documents Vault',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A),
              ),
            ),
            if (_selectedMemberName != null)
              Text(
                'Member: $_selectedMemberName',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF0D9488),
                ),
              ),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            size: 20,
            color: Color(0xFF0F172A),
          ),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF475569)),
            onPressed: _fetchDocuments,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoadingMembers
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF0D9488)),
            )
          : RefreshIndicator(
              color: const Color(0xFF0D9488),
              onRefresh: _fetchDocuments,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  // 1. Household Member Switcher
                  SliverToBoxAdapter(
                    child: _buildMemberSelectionSection(),
                  ),

                  // 2. Encrypted Vault Banner & CTA
                  SliverToBoxAdapter(
                    child: _buildUploadCtaSection(),
                  ),

                  // 3. Search Bar & Category Filter Chips
                  SliverToBoxAdapter(
                    child: _buildFilterSection(),
                  ),

                  // 4. Documents List Sliver
                  _buildDocumentsListSliver(),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF0D9488),
        elevation: 4,
        icon: const Icon(Icons.cloud_upload_rounded, color: Colors.white),
        label: const Text(
          'Upload Document',
          style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
        ),
        onPressed: _openUploadScreen,
      ),
    );
  }

  // ─── Member Selection Section ──────────────────────────────────────────────

  Widget _buildMemberSelectionSection() {
    if (_members.isEmpty) return const SizedBox.shrink();

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.people_alt_outlined,
                size: 15,
                color: Color(0xFF64748B),
              ),
              const SizedBox(width: 6),
              Text(
                'SELECT HOUSEHOLD MEMBER',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _members.map((member) {
                final isSelected = member.id == _selectedMemberId;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          member.isSelf
                              ? Icons.person_rounded
                              : Icons.family_restroom_rounded,
                          size: 15,
                          color: isSelected
                              ? Colors.white
                              : const Color(0xFF475569),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          member.name + (member.isSelf ? ' (Me)' : ''),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.w500,
                            color: isSelected
                                ? Colors.white
                                : const Color(0xFF1E293B),
                          ),
                        ),
                      ],
                    ),
                    selected: isSelected,
                    selectedColor: const Color(0xFF0D9488),
                    backgroundColor: const Color(0xFFF1F5F9),
                    side: BorderSide(
                      color: isSelected
                          ? const Color(0xFF0D9488)
                          : const Color(0xFFE2E8F0),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    onSelected: (selected) {
                      if (selected && _selectedMemberId != member.id) {
                        setState(() {
                          _selectedMemberId = member.id;
                          _selectedMemberName = member.name;
                        });
                        _fetchDocuments();
                      }
                    },
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Vault Banner ──────────────────────────────────────────────────────────

  Widget _buildUploadCtaSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF065F46), Color(0xFF0D9488)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0D9488).withValues(alpha: 0.25),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.security_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Encrypted Health Records Vault',
                    style: TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Upload lab tests, diagnostic scans, and medical prescriptions for ${_selectedMemberName ?? 'this member'}. Seamlessly share with your clinical dietitian for nutrition planning.',
              style: TextStyle(
                fontSize: 12.5,
                color: Colors.white.withValues(alpha: 0.9),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(
                  Icons.lock_outline_rounded,
                  size: 13,
                  color: Colors.white70,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'End-to-End Encrypted · Visible only to you & assigned dietitian',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─── Search & Category Filters ─────────────────────────────────────────────

  Widget _buildFilterSection() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search box with clear button
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (val) => setState(() => _searchQuery = val),
              decoration: InputDecoration(
                hintText: 'Search documents by title, category, or ID...',
                hintStyle:
                    const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  size: 20,
                  color: Color(0xFF94A3B8),
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(
                          Icons.clear_rounded,
                          size: 18,
                          color: Color(0xFF64748B),
                        ),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Category Chips Row
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildCategoryChip('ALL', 'All Documents'),
                ..._categories.map((c) => _buildCategoryChip(c.key, c.name)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChip(String key, String label) {
    final isSelected = _selectedCategory == key;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        selected: isSelected,
        label: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected
                ? const Color(0xFF0D9488)
                : const Color(0xFF475569),
          ),
        ),
        backgroundColor: Colors.white,
        selectedColor: const Color(0xFFCCFBF1),
        checkmarkColor: const Color(0xFF0D9488),
        side: BorderSide(
          color: isSelected
              ? const Color(0xFF0D9488)
              : const Color(0xFFE2E8F0),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        onSelected: (selected) {
          setState(() {
            _selectedCategory = selected ? key : 'ALL';
          });
          _fetchDocuments();
        },
      ),
    );
  }

  // ─── Documents List Sliver ─────────────────────────────────────────────────

  Widget _buildDocumentsListSliver() {
    if (_isLoadingDocs) {
      return const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.all(48),
          child: Center(
            child: CircularProgressIndicator(color: Color(0xFF0D9488)),
          ),
        ),
      );
    }

    final docs = _filteredDocuments;

    if (docs.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
          child: Center(
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF1F5F9),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _searchQuery.isNotEmpty
                        ? Icons.search_off_rounded
                        : Icons.folder_open_outlined,
                    size: 46,
                    color: const Color(0xFF94A3B8),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  _searchQuery.isNotEmpty
                      ? 'No Matching Documents'
                      : (_selectedCategory != 'ALL'
                          ? 'No Documents in this Category'
                          : 'No Health Documents Yet'),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _searchQuery.isNotEmpty
                      ? 'Try searching with another keyword or clear your filter.'
                      : 'Upload recent blood reports, prescriptions, or doctor summaries to help your dietitian formulate precise meal recommendations.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 18),
                if (_searchQuery.isNotEmpty)
                  OutlinedButton(
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF0D9488)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      'Clear Search',
                      style: TextStyle(color: Color(0xFF0D9488)),
                    ),
                  )
                else
                  OutlinedButton.icon(
                    onPressed: _openUploadScreen,
                    icon: const Icon(
                      Icons.add_rounded,
                      size: 18,
                      color: Color(0xFF0D9488),
                    ),
                    label: const Text(
                      'Upload Document',
                      style: TextStyle(
                        color: Color(0xFF0D9488),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF0D9488)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final doc = docs[index];
            return _buildDocumentCard(doc);
          },
          childCount: docs.length,
        ),
      ),
    );
  }

  // ─── Document Card ─────────────────────────────────────────────────────────

  Widget _buildDocumentCard(HealthDocumentEntity doc) {
    final isPdf = doc.fileExtension == 'PDF';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _openDocumentPreview(doc),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Format icon badge with tap to preview
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: isPdf
                          ? const Color(0xFFFEE2E2)
                          : const Color(0xFFCCFBF1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            isPdf
                                ? Icons.picture_as_pdf_rounded
                                : Icons.image_rounded,
                            size: 24,
                            color: isPdf
                                ? const Color(0xFFDC2626)
                                : const Color(0xFF0D9488),
                          ),
                          Text(
                            doc.fileExtension,
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: isPdf
                                  ? const Color(0xFFDC2626)
                                  : const Color(0xFF0D9488),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Title and details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                doc.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            _buildStatusBadge(doc.statusDisplay),
                          ],
                        ),
                        const SizedBox(height: 4),

                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                doc.categoryDisplay,
                                style: const TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF475569),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              doc.formattedFileSize,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF94A3B8),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),

                        // Date & Dietitian Sharing Indicator
                        Row(
                          children: [
                            Icon(
                              Icons.calendar_today_outlined,
                              size: 12,
                              color: Colors.grey.shade500,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              doc.reportDate != null
                                  ? '${doc.reportDate!.day.toString().padLeft(2, '0')} ${_monthName(doc.reportDate!.month)} ${doc.reportDate!.year}'
                                  : 'Recent',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const Spacer(),

                            // Dietitian sharing badge
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: doc.isSharedWithDietitian
                                    ? const Color(0xFFECFDF5)
                                    : const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: doc.isSharedWithDietitian
                                      ? const Color(0xFFA7F3D0)
                                      : const Color(0xFFE2E8F0),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    doc.isSharedWithDietitian
                                        ? Icons.check_circle_outline_rounded
                                        : Icons.lock_outline_rounded,
                                    size: 11,
                                    color: doc.isSharedWithDietitian
                                        ? const Color(0xFF059669)
                                        : const Color(0xFF64748B),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    doc.isSharedWithDietitian
                                        ? 'Dietitian Access'
                                        : 'Private',
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w600,
                                      color: doc.isSharedWithDietitian
                                          ? const Color(0xFF059669)
                                          : const Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Divider(height: 1, color: Color(0xFFF1F5F9)),
              const SizedBox(height: 8),
              // Action Row: View Document and Details
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _openDocumentPreview(doc),
                      icon: const Icon(
                        Icons.visibility_outlined,
                        size: 16,
                        color: Colors.white,
                      ),
                      label: Text(
                        isPdf ? 'View PDF Document' : 'View Image Scan',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0D9488),
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () => _openDocumentDetail(doc),
                    icon: const Icon(
                      Icons.settings_outlined,
                      size: 15,
                      color: Color(0xFF475569),
                    ),
                    label: const Text(
                      'Manage',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF475569),
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
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
  }

  Widget _buildStatusBadge(String status) {
    Color bg = const Color(0xFFECFDF5);
    Color fg = const Color(0xFF059669);

    if (status.toLowerCase().contains('uploading') ||
        status.toLowerCase().contains('process')) {
      bg = const Color(0xFFFEF3C7);
      fg = const Color(0xFFD97706);
    } else if (status.toLowerCase().contains('failed') ||
        status.toLowerCase().contains('unavail')) {
      bg = const Color(0xFFFEE2E2);
      fg = const Color(0xFFDC2626);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        status,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: fg,
        ),
      ),
    );
  }

  String _monthName(int month) {
    const months = [
      '',
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return (month >= 1 && month <= 12) ? months[month] : '';
  }

  Future<void> _openUploadScreen() async {
    if (_selectedMemberId == null && _members.isNotEmpty) {
      _selectedMemberId = _members.first.id;
      _selectedMemberName = _members.first.name;
    }
    if (_selectedMemberId == null) return;

    final uploaded = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => UploadHealthDocumentScreen(
          memberId: _selectedMemberId!,
          memberName: _selectedMemberName ?? 'Member',
          availableCategories: _categories,
          householdMembers: _members,
        ),
      ),
    );
    if (uploaded == true) {
      _fetchDocuments();
    }
  }

  Future<void> _openDocumentDetail(HealthDocumentEntity doc) async {
    final updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => DocumentDetailsScreen(
          documentId: doc.id,
          memberId: _selectedMemberId ?? doc.householdMemberId,
        ),
      ),
    );
    if (updated == true) {
      _fetchDocuments();
    }
  }

  void _openDocumentPreview(HealthDocumentEntity doc) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DocumentPreviewScreen(
          documentId: doc.id,
          title: doc.title,
          fileExtension: doc.fileExtension,
          mimeType: doc.mimeType,
        ),
      ),
    );
  }
}
