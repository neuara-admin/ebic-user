import 'package:flutter/material.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/api/api_endpoints.dart';
import '../../../../shared/models/household_member_model.dart';
import '../../domain/entities/health_document_entity.dart';
import '../../data/repositories/health_documents_repository_impl.dart';
import 'upload_health_document_screen.dart';
import 'document_details_screen.dart';

class HealthDocumentsScreen extends StatefulWidget {
  final String? initialMemberId;

  const HealthDocumentsScreen({super.key, this.initialMemberId});

  @override
  State<HealthDocumentsScreen> createState() => _HealthDocumentsScreenState();
}

class _HealthDocumentsScreenState extends State<HealthDocumentsScreen> {
  final HealthDocumentsRepositoryImpl _repository = HealthDocumentsRepositoryImpl();
  final ApiClient _api = ApiClient();

  List<HouseholdMemberModel> _members = [];
  String? _selectedMemberId;
  String? _selectedMemberName;

  List<DocumentCategoryItem> _categories = [];
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
      if (res.success && res.data != null) {
        final list = res.data!
            .whereType<Map<String, dynamic>>()
            .map((json) => HouseholdMemberModel.fromJson(json))
            .toList();

        if (mounted) {
          setState(() {
            _members = list;
            _isLoadingMembers = false;
            if (list.isNotEmpty) {
              final initial = widget.initialMemberId != null
                  ? list.firstWhere(
                      (m) => m.id == widget.initialMemberId,
                      orElse: () => list.first,
                    )
                  : list.first;
              _selectedMemberId = initial.id;
              _selectedMemberName = initial.name;
              _fetchDocuments();
            }
          });
        }
      } else {
        if (mounted) setState(() => _isLoadingMembers = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingMembers = false);
    }
  }

  Future<void> _loadCategories() async {
    try {
      final cats = await _repository.getCategories();
      if (mounted) {
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
        _selectedMemberId!,
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
              'Health Documents',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A),
              ),
            ),
            if (_selectedMemberName != null)
              Text(
                'For: $_selectedMemberName',
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
          icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: Color(0xFF0F172A)),
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
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF0D9488)))
          : RefreshIndicator(
              color: const Color(0xFF0D9488),
              onRefresh: _fetchDocuments,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  // 1. Member Switcher (Section 8: Family accounts)
                  SliverToBoxAdapter(
                    child: _buildMemberSelectionSection(),
                  ),

                  // 2. Upload CTA & Privacy Banner
                  SliverToBoxAdapter(
                    child: _buildUploadCtaSection(),
                  ),

                  // 3. Search Bar & Category Filter Chips (Section 21)
                  SliverToBoxAdapter(
                    child: _buildFilterSection(),
                  ),

                  // 4. Document List Cards
                  _buildDocumentsListSliver(),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF0D9488),
        elevation: 4,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text(
          'Upload Document',
          style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
        ),
        onPressed: _openUploadScreen,
      ),
    );
  }

  Widget _buildMemberSelectionSection() {
    if (_members.isEmpty) return const SizedBox.shrink();

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.people_outline_rounded, size: 16, color: Color(0xFF64748B)),
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
                          member.isSelf ? Icons.person_rounded : Icons.family_restroom_rounded,
                          size: 15,
                          color: isSelected ? Colors.white : const Color(0xFF475569),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          member.name + (member.isSelf ? ' (Me)' : ''),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                            color: isSelected ? Colors.white : const Color(0xFF1E293B),
                          ),
                        ),
                      ],
                    ),
                    selected: isSelected,
                    selectedColor: const Color(0xFF0D9488),
                    backgroundColor: const Color(0xFFF1F5F9),
                    side: BorderSide(
                      color: isSelected ? const Color(0xFF0D9488) : const Color(0xFFE2E8F0),
                    ),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
                  child: const Icon(Icons.shield_outlined, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Encrypted Health Records Vault',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Upload lab tests, diagnostic scans, and prescriptions for ${_selectedMemberName ?? 'this member'}. Seamlessly share with your clinical dietitian for nutrition planning.',
              style: TextStyle(
                fontSize: 12.5,
                color: Colors.white.withValues(alpha: 0.9),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 14),
            ElevatedButton.icon(
              onPressed: _openUploadScreen,
              icon: const Icon(Icons.cloud_upload_outlined, size: 18, color: Color(0xFF065F46)),
              label: const Text(
                'Upload New Document',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: Color(0xFF065F46),
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterSection() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search box
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: TextField(
              onChanged: (val) => setState(() => _searchQuery = val),
              decoration: const InputDecoration(
                hintText: 'Search documents by title or reference...',
                hintStyle: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                prefixIcon: Icon(Icons.search_rounded, size: 20, color: Color(0xFF94A3B8)),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Category Chips
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
            color: isSelected ? const Color(0xFF0D9488) : const Color(0xFF475569),
          ),
        ),
        backgroundColor: Colors.white,
        selectedColor: const Color(0xFFCCFBF1),
        checkmarkColor: const Color(0xFF0D9488),
        side: BorderSide(
          color: isSelected ? const Color(0xFF0D9488) : const Color(0xFFE2E8F0),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        onSelected: (selected) {
          setState(() {
            _selectedCategory = selected ? key : 'ALL';
          });
          _fetchDocuments();
        },
      ),
    );
  }

  Widget _buildDocumentsListSliver() {
    if (_isLoadingDocs) {
      return const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.all(40),
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
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.folder_open_outlined,
                    size: 48,
                    color: Color(0xFF94A3B8),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'No Health Documents Yet',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Upload recent blood reports, prescriptions, or doctor summaries to help your dietitian formulate precise meal recommendations.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 18),
                OutlinedButton.icon(
                  onPressed: _openUploadScreen,
                  icon: const Icon(Icons.add_rounded, size: 18, color: Color(0xFF0D9488)),
                  label: const Text(
                    'Upload Document',
                    style: TextStyle(color: Color(0xFF0D9488), fontWeight: FontWeight.w600),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF0D9488)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
        onTap: () => _openDocumentDetail(doc),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Format icon badge
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: isPdf ? const Color(0xFFFEE2E2) : const Color(0xFFE0F2FE),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        isPdf ? Icons.picture_as_pdf_rounded : Icons.image_rounded,
                        size: 22,
                        color: isPdf ? const Color(0xFFDC2626) : const Color(0xFF0284C7),
                      ),
                      Text(
                        doc.fileExtension,
                        style: TextStyle(
                          fontSize: 8.5,
                          fontWeight: FontWeight.w800,
                          color: isPdf ? const Color(0xFFDC2626) : const Color(0xFF0284C7),
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
                        _buildStatusBadge(doc.statusDisplay),
                      ],
                    ),
                    const SizedBox(height: 4),

                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
                          style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Date & Dietitian Sharing Indicator
                    Row(
                      children: [
                        Icon(Icons.calendar_today_outlined, size: 12, color: Colors.grey.shade500),
                        const SizedBox(width: 4),
                        Text(
                          doc.reportDate != null
                              ? '${doc.reportDate!.day.toString().padLeft(2, '0')} ${_monthName(doc.reportDate!.month)} ${doc.reportDate!.year}'
                              : 'Recent',
                          style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
                        ),
                        const Spacer(),

                        // Dietitian sharing badge (Section 29)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
                                doc.isSharedWithDietitian ? 'Dietitian Access' : 'Private',
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
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bg = const Color(0xFFECFDF5);
    Color fg = const Color(0xFF059669);

    if (status.toLowerCase().contains('uploading') || status.toLowerCase().contains('process')) {
      bg = const Color(0xFFFEF3C7);
      fg = const Color(0xFFD97706);
    } else if (status.toLowerCase().contains('failed') || status.toLowerCase().contains('unavail')) {
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
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: fg),
      ),
    );
  }

  String _monthName(int month) {
    const months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return (month >= 1 && month <= 12) ? months[month] : '';
  }

  Future<void> _openUploadScreen() async {
    if (_selectedMemberId == null) return;
    final uploaded = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => UploadHealthDocumentScreen(
          memberId: _selectedMemberId!,
          memberName: _selectedMemberName ?? 'Member',
          availableCategories: _categories,
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
}
