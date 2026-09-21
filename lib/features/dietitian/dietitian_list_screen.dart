import 'package:flutter/material.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/routing/app_router.dart';
import '../../core/routing/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/models/dietitian_model.dart';
import '../../shared/widgets/ebic_card.dart';
import '../../shared/widgets/ebic_button.dart';
import 'dietitian_profile_screen.dart';

class DietitianListScreen extends StatefulWidget {
  const DietitianListScreen({super.key});

  @override
  State<DietitianListScreen> createState() => _DietitianListScreenState();
}

class _DietitianListScreenState extends State<DietitianListScreen> {
  final ApiClient _api = ApiClient();
  final TextEditingController _searchController = TextEditingController();

  List<DietitianModel> _allDietitians = [];
  List<DietitianModel> _filteredDietitians = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _selectedCategory = 'All';

  final List<String> _categories = [
    'All',
    'Weight Management',
    'Diabetes & Endocrine',
    'Clinical Care',
    'Gut & Digestive',
    'Sports & Performance',
  ];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_applyFilters);
    _fetchDietitians();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchDietitians() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await _api.get<List<dynamic>>(ApiEndpoints.dietitians);
      if (res.success && res.data != null) {
        final list = res.data!
            .map((json) => DietitianModel.fromJson(json as Map<String, dynamic>))
            .toList();
        setState(() {
          _allDietitians = list;
          _isLoading = false;
        });
        _applyFilters();
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = res.message ?? 'No clinical dietitians currently available';
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  void _applyFilters() {
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      _filteredDietitians = _allDietitians.where((d) {
        // Search query match
        final matchesQuery = query.isEmpty ||
            d.name.toLowerCase().contains(query) ||
            (d.specialization ?? '').toLowerCase().contains(query) ||
            (d.qualification ?? '').toLowerCase().contains(query) ||
            (d.languages ?? '').toLowerCase().contains(query) ||
            (d.hubName ?? '').toLowerCase().contains(query);

        // Category filter match
        bool matchesCategory = true;
        if (_selectedCategory != 'All') {
          final spec = (d.specialization ?? '').toLowerCase();
          switch (_selectedCategory) {
            case 'Weight Management':
              matchesCategory = spec.contains('weight') || spec.contains('metabolic') || spec.contains('obesity');
              break;
            case 'Diabetes & Endocrine':
              matchesCategory = spec.contains('diabet') || spec.contains('pcos') || spec.contains('endocrine') || spec.contains('thyroid');
              break;
            case 'Clinical Care':
              matchesCategory = spec.contains('clinical') || spec.contains('cardio') || spec.contains('renal') || spec.contains('medical');
              break;
            case 'Gut & Digestive':
              matchesCategory = spec.contains('gut') || spec.contains('digest') || spec.contains('gastro') || spec.contains('ibs');
              break;
            case 'Sports & Performance':
              matchesCategory = spec.contains('sport') || spec.contains('fitness') || spec.contains('athlet');
              break;
          }
        }

        return matchesQuery && matchesCategory;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.slate950 : const Color(0xFFF8FAFC),
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: isDark ? AppColors.slate900 : Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Clinical Dietitians',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            Text(
              'Verified medical nutrition specialists',
              style: TextStyle(
                fontSize: 11,
                color: isDark ? AppColors.slate400 : AppColors.slate500,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.primarySubtle,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.calendar_month_rounded, color: AppColors.primary, size: 20),
            ),
            tooltip: 'My Consultations',
            onPressed: () => Navigator.pushNamed(context, AppRoutes.consultationsList),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _fetchDietitians,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // Hero Intro Banner
            SliverToBoxAdapter(
              child: _buildHeroBanner(isDark),
            ),

            // Search Bar & Filter Chips
            SliverToBoxAdapter(
              child: _buildSearchAndFilters(isDark),
            ),

            // Content Area
            if (_isLoading)
              const SliverFillRemaining(
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
              )
            else if (_errorMessage != null && _allDietitians.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.wifi_off_rounded, size: 48, color: AppColors.danger),
                        const SizedBox(height: 12),
                        Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: AppColors.slate700, fontSize: 14),
                        ),
                        const SizedBox(height: 16),
                        EbicButton(
                          label: 'Retry Connection',
                          icon: Icons.refresh,
                          onPressed: _fetchDietitians,
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else if (_filteredDietitians.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.slate800 : AppColors.slate100,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.search_off_rounded, size: 36, color: AppColors.slate400),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'No dietitians match your criteria',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Try clearing your search query or selecting "All" categories.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 13, color: isDark ? AppColors.slate400 : AppColors.slate500),
                        ),
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _selectedCategory = 'All');
                            _applyFilters();
                          },
                          icon: const Icon(Icons.clear_rounded, size: 16),
                          label: const Text('Reset Filters'),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, idx) {
                      final dietitian = _filteredDietitians[idx];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: _buildDietitianCard(dietitian, isDark),
                      );
                    },
                    childCount: _filteredDietitians.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroBanner(bool isDark) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF064E3B), const Color(0xFF0F172A)]
              : [const Color(0xFFECFDF5), const Color(0xFFE0F2FE)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.emerald700.withOpacity(0.4) : AppColors.emerald400.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? AppColors.emerald900 : Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.15),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: const Icon(Icons.health_and_safety_rounded, color: AppColors.primary, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Flexible(
                      child: Text(
                        'Expert Clinical Nutrition',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'VERIFIED',
                        style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Book 1-on-1 video consultations. Personalized diet charts seamlessly sync with your home chef.',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: isDark ? AppColors.slate300 : AppColors.slate700,
                    height: 1.35,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilters(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Search Input
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.slate900 : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? AppColors.slate800 : const Color(0xFFE2E8F0),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.2 : 0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by doctor name, specialty, language...',
                hintStyle: TextStyle(
                  fontSize: 13,
                  color: isDark ? AppColors.slate500 : AppColors.slate400,
                ),
                prefixIcon: const Icon(Icons.search_rounded, color: AppColors.primary, size: 20),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.cancel_rounded, size: 18, color: AppColors.slate400),
                        onPressed: () {
                          _searchController.clear();
                          _applyFilters();
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
          ),
        ),

        // Horizontal Category Chips
        SizedBox(
          height: 38,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: _categories.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (ctx, i) {
              final cat = _categories[i];
              final isSelected = cat == _selectedCategory;
              return InkWell(
                onTap: () {
                  setState(() => _selectedCategory = cat);
                  _applyFilters();
                },
                borderRadius: BorderRadius.circular(20),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primary
                        : (isDark ? AppColors.slate900 : Colors.white),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.primary
                          : (isDark ? AppColors.slate800 : const Color(0xFFE2E8F0)),
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: AppColors.primary.withOpacity(0.25),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Center(
                    child: Text(
                      cat,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        color: isSelected
                            ? Colors.white
                            : (isDark ? AppColors.slate300 : AppColors.slate700),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildDietitianCard(DietitianModel d, bool isDark) {
    // Parse specializations into chips
    final specList = (d.specialization ?? 'Clinical Nutrition, Weight Management')
        .split(RegExp(r'[,•|]'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .take(3)
        .toList();

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.slate900 : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.slate800 : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.25 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Avatar, Name, Verified, Qualifications, Rating
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar
              Stack(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppColors.primarySubtle, AppColors.emerald400.withOpacity(0.3)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                    ),
                    child: Center(
                      child: Text(
                        d.name.isNotEmpty
                            ? d.name.replaceAll('Dr. ', '').split(' ').map((w) => w.isNotEmpty ? w[0] : '').take(2).join()
                            : 'RD',
                        style: const TextStyle(
                          color: AppColors.primaryDark,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: -2,
                    right: -2,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isDark ? AppColors.slate900 : Colors.white,
                          width: 2,
                        ),
                      ),
                      child: const Icon(Icons.check, size: 10, color: Colors.white),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 14),

              // Doctor Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            d.name,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: isDark ? Colors.white : AppColors.slate900,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.accentSubtle,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppColors.accent.withOpacity(0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.star_rounded, color: AppColors.accent, size: 14),
                              const SizedBox(width: 2),
                              Text(
                                d.rating.toStringAsFixed(1),
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.amber800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      d.qualification ?? 'Registered Dietitian (RD)',
                      style: TextStyle(
                        color: isDark ? AppColors.slate400 : AppColors.slate500,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.slate800 : AppColors.slate100,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${d.experienceYears} Years Exp.',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isDark ? AppColors.slate300 : AppColors.slate700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (d.hubName != null)
                          Expanded(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.location_on_outlined, size: 12, color: AppColors.slate400),
                                const SizedBox(width: 2),
                                Expanded(
                                  child: Text(
                                    d.hubName!,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isDark ? AppColors.slate400 : AppColors.slate500,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
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

          const SizedBox(height: 12),

          // Specialization Badges
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: specList.map((spec) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF064E3B).withOpacity(0.5) : AppColors.primarySubtle,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isDark ? AppColors.emerald700.withOpacity(0.3) : AppColors.emerald400.withOpacity(0.2),
                  ),
                ),
                child: Text(
                  spec,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.primaryDark,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 10),

          // Spoken Languages
          Row(
            children: [
              const Icon(Icons.translate_rounded, size: 13, color: AppColors.slate400),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  'Speaks: ${d.languages ?? 'English, Hindi'}',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: isDark ? AppColors.slate400 : AppColors.slate500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),
          Divider(height: 1, color: isDark ? AppColors.slate800 : const Color(0xFFE2E8F0)),
          const SizedBox(height: 12),

          // Actions Row: View Profile & Book Consultation
          Row(
            children: [
              Expanded(
                flex: 4,
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => DietitianProfileScreen(dietitian: d),
                      ),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    side: BorderSide(
                      color: isDark ? AppColors.slate700 : const Color(0xFFCBD5E1),
                    ),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text(
                    'View Profile',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : AppColors.slate800,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 6,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pushNamed(
                      context,
                      AppRoutes.consultationBook,
                      arguments: {'dietitian': d},
                    );
                  },
                  icon: const Icon(Icons.calendar_today_rounded, size: 14, color: Colors.white),
                  label: const Text(
                    'Book Session',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
