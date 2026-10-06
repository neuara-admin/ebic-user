import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/routing/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/models/dietitian_model.dart';
import '../../shared/models/household_member_model.dart';
import '../../shared/widgets/ebic_button.dart';
import '../../shared/widgets/ebic_card.dart';
import '../../shared/widgets/ebic_dish_image.dart';
import '../catalogue/dish_detail_screen.dart';
import '../dietitian/dietitian_profile_screen.dart';
import 'diet_plan_calendar_screen.dart';
import 'diet_plan_history_screen.dart';
import 'diet_plan_meal_detail_screen.dart';
import 'diet_plan_nutrition_screen.dart';
import 'diet_plan_service.dart';
import 'models/diet_plan_models.dart';

class DietPlanScreen extends StatefulWidget {
  const DietPlanScreen({super.key});

  @override
  State<DietPlanScreen> createState() => _DietPlanScreenState();
}

class _DietPlanScreenState extends State<DietPlanScreen> {
  final ApiClient _api = ApiClient();
  final DietPlanService _dietPlanService = DietPlanService();

  List<HouseholdMemberModel> _householdMembers = [];
  String? _selectedMemberId;
  String _selectedMemberName = 'My Plan';

  DietPlanDetailModel? _planDetail;
  Map<String, List<DietPlanMealModel>> _calendarMealsByDay = {};
  bool _isLoading = true;

  // Multi-month subscription state
  int _selectedMonthIndex = 0; // 0 for Month 1, 1 for Month 2, etc.
  DateTime _selectedDate = DateTime.now();
  final ScrollController _dateStripScrollController = ScrollController();

  // Filters & Search
  String _selectedOccasionFilter = 'ALL'; // ALL, BREAKFAST, LUNCH, SNACK, DINNER
  String _selectedDietaryFilter = 'ALL'; // ALL, VEG, HIGH_PROTEIN, CHEAT
  String _searchQuery = '';
  bool _showSearch = false;
  final TextEditingController _searchController = TextEditingController();

  // Plan Details collapsible state (hidden by default)
  bool _showPlanDetails = false;

  void _openDietitianConsultation() {
    final d = _planDetail?.dietitian;
    final dietitian = DietitianModel(
      id: (d != null && d.id.isNotEmpty) ? d.id : 'dietitian-default',
      name: (d != null && d.name.isNotEmpty)
          ? d.name
          : 'Dr. Ananya Sharma',
      qualification: d?.qualification ?? 'M.Sc Clinical Nutrition, RD, CDE',
      specialization: 'Clinical & Preventive Dietetics',
      experienceYears: 9,
      photoUrl: d?.photoUrl,
      bio:
          'Prescribing personalized meal recommendations, macro-nutrient balancing, and clinical wellness coaching.',
      languages: 'English, Hindi',
      rating: 4.9,
    );
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DietitianProfileScreen(dietitian: dietitian),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDate = DateTime(now.year, now.month, now.day);
    _initData();
  }

  @override
  void dispose() {
    _dateStripScrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _initData() async {
    setState(() => _isLoading = true);
    await _fetchMembers();
    await _fetchDietPlan();
  }

  Future<void> _fetchMembers() async {
    try {
      final res = await _api.get<List<dynamic>>(ApiEndpoints.householdMembers);
      if (res.success && res.data != null) {
        final list = res.data!
            .map(
              (json) =>
                  HouseholdMemberModel.fromJson(json as Map<String, dynamic>),
            )
            .toList();
        setState(() {
          _householdMembers = list;
          if (list.isNotEmpty && _selectedMemberId == null) {
            _selectedMemberId = list.first.id;
            _selectedMemberName = list.first.name;
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _fetchDietPlan() async {
    setState(() => _isLoading = true);
    final plan = await _dietPlanService.getActivePlan(
      memberId: _selectedMemberId,
    );

    Map<String, List<DietPlanMealModel>> mealsByDay = {};
    Map<String, dynamic>? calendarRes;

    if (plan != null && plan.id != null) {
      calendarRes = await _dietPlanService.getCalendar(plan.id!);
      if (calendarRes != null && calendarRes['calendar'] is List) {
        for (final item in (calendarRes['calendar'] as List<dynamic>)) {
          if (item is Map<String, dynamic>) {
            final dayName = (item['dayOfWeek'] ?? '').toString().toUpperCase();
            final rawMeals = item['meals'] as List<dynamic>? ?? [];
            mealsByDay[dayName] = rawMeals
                .map((m) => DietPlanMealModel.fromJson(m as Map<String, dynamic>))
                .toList();
          }
        }
      }
    }

    if (mounted) {
      setState(() {
        _planDetail = plan;
        _calendarMealsByDay = mealsByDay;
        _isLoading = false;
      });
    }
  }

  void _onMemberSelected(HouseholdMemberModel member) {
    if (_selectedMemberId == member.id) return;
    setState(() {
      _selectedMemberId = member.id;
      _selectedMemberName = member.name;
    });
    _fetchDietPlan();
  }

  Future<void> _toggleMealAdherence(DietPlanMealModel meal) async {
    if (_planDetail?.id == null) return;
    final newStatus = meal.adherenceStatus == 'CONFIRMED_CONSUMED'
        ? 'PLANNED'
        : 'CONFIRMED_CONSUMED';

    final ok = await _dietPlanService.recordMealAdherence(
      _planDetail!.id!,
      meal.id,
      status: newStatus,
    );

    if (ok && mounted) {
      setState(() {
        _fetchDietPlan();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            newStatus == 'CONFIRMED_CONSUMED'
                ? 'Great! Logged ${meal.title} as consumed.'
                : 'Meal reset to planned.',
          ),
          backgroundColor: newStatus == 'CONFIRMED_CONSUMED'
              ? Colors.green
              : Colors.grey.shade800,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  DateTime get _subscriptionStart {
    final s = _planDetail?.subscriptionStartDate ?? _planDetail?.startDate;
    if (s != null) {
      return DateTime(s.year, s.month, s.day);
    }
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  int get _totalMonths {
    final m = _planDetail?.subscriptionDurationMonths ?? 1;
    return m < 1 ? 1 : m;
  }

  List<DietPlanMealModel> _getMealsForSelectedDate() {
    if (_planDetail == null) return [];
    final now = DateTime.now();
    final isToday = _selectedDate.year == now.year &&
        _selectedDate.month == now.month &&
        _selectedDate.day == now.day;

    List<DietPlanMealModel> baseMeals = [];
    if (isToday && _planDetail!.todayMeals.isNotEmpty) {
      baseMeals = _planDetail!.todayMeals;
    } else {
      const dayNames = [
        'SUNDAY',
        'MONDAY',
        'TUESDAY',
        'WEDNESDAY',
        'THURSDAY',
        'FRIDAY',
        'SATURDAY'
      ];
      final dayOfWeek = dayNames[_selectedDate.weekday % 7];
      baseMeals = _calendarMealsByDay[dayOfWeek] ?? [];
    }

    return _applyFilters(baseMeals);
  }

  List<DietPlanMealModel> _applyFilters(List<DietPlanMealModel> meals) {
    return meals.where((meal) {
      if (_selectedOccasionFilter != 'ALL') {
        final occ = meal.occasion.toUpperCase();
        if (_selectedOccasionFilter == 'SNACK') {
          if (!occ.contains('SNACK')) return false;
        } else if (!occ.contains(_selectedOccasionFilter)) {
          return false;
        }
      }

      if (_selectedDietaryFilter == 'VEG') {
        final allVeg = meal.dishes.every((d) => d.dietaryTags.any(
            (t) => t.toLowerCase() == 'vegetarian' || t.toLowerCase() == 'vegan'));
        if (!allVeg) return false;
      } else if (_selectedDietaryFilter == 'HIGH_PROTEIN') {
        final hasProtein = meal.dishes.any((d) =>
            d.dietaryTags.any((t) => t.toUpperCase().contains('PROTEIN')));
        if (!hasProtein) return false;
      } else if (_selectedDietaryFilter == 'CHEAT') {
        if (!meal.isCheatMeal) return false;
      }

      if (_searchQuery.trim().isNotEmpty) {
        final q = _searchQuery.trim().toLowerCase();
        final matchesTitle = meal.title.toLowerCase().contains(q);
        final matchesDishes = meal.dishes.any((d) => d.name.toLowerCase().contains(q));
        if (!matchesTitle && !matchesDishes) return false;
      }

      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Diet Plan',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        actions: [
          IconButton(
            icon: Icon(
              _showSearch ? Icons.search_off_rounded : Icons.search_rounded,
              color: _showSearch ? AppColors.primary : AppColors.slate700,
            ),
            tooltip: 'Search dishes',
            onPressed: () {
              setState(() {
                _showSearch = !_showSearch;
                if (!_showSearch) {
                  _searchQuery = '';
                  _searchController.clear();
                }
              });
            },
          ),
          if (_planDetail?.id != null)
            IconButton(
              icon: const Icon(Icons.history_rounded),
              tooltip: 'Plan History',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => DietPlanHistoryScreen(
                      memberId: _selectedMemberId,
                      memberName: _selectedMemberName,
                    ),
                  ),
                );
              },
            ),
        ],
      ),
      body: Column(
        children: [
          // Section: Luxury Covered Family Member Selector
          if (_householdMembers.isNotEmpty) _buildMemberSelector(),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  )
                : _buildBody(),
          ),
        ],
      ),
    );
  }

  // 1. Redesigned Luxury Covered Member Selector
  Widget _buildMemberSelector() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      color: isDark ? AppColors.slate900 : Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: AppColors.primarySubtle,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(
                        Icons.family_restroom_rounded,
                        size: 15,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Covered Family Member',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : AppColors.slate800,
                          letterSpacing: 0.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.slate800 : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isDark ? AppColors.slate700 : const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.verified_user_rounded,
                        size: 11, color: AppColors.primary),
                    const SizedBox(width: 4),
                    Text(
                      '${_householdMembers.length} Covered',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppColors.slate300 : AppColors.slate700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _householdMembers.map((m) {
                final isSelected = m.id == _selectedMemberId;
                final initials = m.name.isNotEmpty
                    ? m.name
                        .split(' ')
                        .map((n) => n.isNotEmpty ? n[0] : '')
                        .take(2)
                        .join()
                        .toUpperCase()
                    : '?';

                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: InkWell(
                    onTap: () => _onMemberSelected(m),
                    borderRadius: BorderRadius.circular(12),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 7),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? (isDark ? AppColors.primary.withOpacity(0.18) : const Color(0xFFECFDF5))
                            : (isDark ? AppColors.slate800 : const Color(0xFFF8FAFC)),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.primary
                              : (isDark ? AppColors.slate700 : AppColors.slate200),
                          width: isSelected ? 1.5 : 1,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: AppColors.primary.withOpacity(0.12),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Stack(
                            children: [
                              CircleAvatar(
                                radius: 14,
                                backgroundColor: isSelected
                                    ? AppColors.primary
                                    : (isDark ? AppColors.slate700 : AppColors.slate300),
                                child: Text(
                                  initials,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              if (isSelected)
                                Positioned(
                                  right: 0,
                                  bottom: 0,
                                  child: Container(
                                    decoration: const BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.check_circle,
                                      size: 10,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                m.name,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: isSelected
                                      ? (isDark ? AppColors.primaryLight : AppColors.primaryDark)
                                      : (isDark ? Colors.white : AppColors.slate800),
                                ),
                              ),
                              Text(
                                m.isSelf ? 'Primary (Self)' : m.relationship,
                                style: TextStyle(
                                  fontSize: 9.5,
                                  color: isSelected
                                      ? AppColors.primary
                                      : AppColors.slate500,
                                  fontWeight: FontWeight.w600,
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
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_planDetail == null || !_planDetail!.hasActivePlan) {
      return _buildEmptyState();
    }

    final plan = _planDetail!;
    final dateFormat = DateFormat('dd MMM yyyy');
    final displayedMeals = _getMealsForSelectedDate();

    return RefreshIndicator(
      onRefresh: _fetchDietPlan,
      color: AppColors.primary,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Section: Plan Overview / Details (Collapsible & Hidden by default)
          _buildPlanDetailsSection(plan, dateFormat),

          const SizedBox(height: 14),

          // Quick Action Navigation Bar
          Row(
            children: [
              Expanded(
                child: _buildActionButton(
                  icon: Icons.calendar_month_rounded,
                  label: '$_totalMonths-Month Schedule',
                  onTap: () {
                    if (plan.id != null) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => DietPlanCalendarScreen(
                            dietPlanId: plan.id!,
                            planName: plan.planName,
                          ),
                        ),
                      );
                    }
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildActionButton(
                  icon: Icons.track_changes_rounded,
                  label: 'Nutrition Targets',
                  onTap: () {
                    if (plan.id != null) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => DietPlanNutritionScreen(
                            planId: plan.id!,
                            plannedNutrition: plan.dailyPlannedNutrition,
                          ),
                        ),
                      );
                    }
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          // Search Field (if toggled)
          if (_showSearch) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primary),
              ),
              child: TextField(
                controller: _searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Search dishes in schedule (e.g. Oatmeal, Salad)...',
                  hintStyle: const TextStyle(fontSize: 12.5),
                  prefixIcon:
                      const Icon(Icons.search, size: 18, color: AppColors.primary),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 16),
                          onPressed: () {
                            setState(() {
                              _searchQuery = '';
                              _searchController.clear();
                            });
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
                onChanged: (val) {
                  setState(() => _searchQuery = val);
                },
              ),
            ),
          ],

          // Multi-Month Subscription Timeline Header
          _buildSubscriptionTimelineSection(),

          const SizedBox(height: 14),

          // Interactive Filters Bar (Occasion & Dietary)
          _buildFiltersBar(),

          const SizedBox(height: 14),

          // Meals List for Selected Date
          if (displayedMeals.isEmpty)
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.slate200),
              ),
              child: Column(
                children: [
                  Icon(Icons.no_meals_rounded,
                      size: 40, color: Colors.grey.shade400),
                  const SizedBox(height: 10),
                  Text(
                    _selectedOccasionFilter != 'ALL' ||
                            _selectedDietaryFilter != 'ALL' ||
                            _searchQuery.isNotEmpty
                        ? 'No meals match your active filters.'
                        : 'No meals scheduled for this day.',
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  if (_selectedOccasionFilter != 'ALL' ||
                      _selectedDietaryFilter != 'ALL' ||
                      _searchQuery.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _selectedOccasionFilter = 'ALL';
                          _selectedDietaryFilter = 'ALL';
                          _searchQuery = '';
                          _searchController.clear();
                        });
                      },
                      child: const Text('Reset Filters'),
                    ),
                  ],
                ],
              ),
            )
          else
            ...displayedMeals.map((meal) => _buildMealCard(plan, meal)),

          const SizedBox(height: 16),

          // Daily Dietitian Guidance Card
          if (plan.specialInstructions != null &&
              plan.specialInstructions!.isNotEmpty)
            EbicCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.lightbulb_outline_rounded,
                        size: 18,
                        color: Colors.amber.shade800,
                      ),
                      const SizedBox(width: 6),
                      const Expanded(
                        child: Text(
                          'Dietitian Clinical Instructions',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    plan.specialInstructions!,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.45,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // 1.5 Collapsible Plan Details with Dietitian Redirection
  Widget _buildPlanDetailsSection(
      DietPlanDetailModel plan, DateFormat dateFormat) {
    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _showPlanDetails
              ? AppColors.primary.withOpacity(0.5)
              : AppColors.slate200,
          width: _showPlanDetails ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Bar - Tapping toggles plan details
          InkWell(
            onTap: () {
              setState(() {
                _showPlanDetails = !_showPlanDetails;
              });
            },
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primarySubtle,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.assignment_outlined,
                      size: 20,
                      color: AppColors.primaryDark,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Flexible(
                              child: Text(
                                'Plan Details',
                                style: TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.slate900,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                  border:
                                      Border.all(color: Colors.green.shade200),
                                ),
                                child: Text(
                                  plan.customerFacingStatus,
                                  style: TextStyle(
                                    color: Colors.green.shade800,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _showPlanDetails
                              ? 'Tap to hide plan summary'
                              : plan.planName,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.slate500,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Quick Redirection to Dietitian
                  InkWell(
                    onTap: _openDietitianConsultation,
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFBFDBFE)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(
                            Icons.medical_services_rounded,
                            size: 13,
                            color: Color(0xFF1D4ED8),
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Dietitian',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1D4ED8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),

                  // Expand / Collapse Chevron
                  AnimatedRotation(
                    turns: _showPlanDetails ? 0.5 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: AppColors.slate500,
                      size: 22,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Collapsible Detailed Content
          if (_showPlanDetails) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.green.shade200),
                        ),
                        child: Text(
                          plan.customerFacingStatus,
                          style: TextStyle(
                            color: Colors.green.shade800,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Version ${plan.versionNumber}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.slate600,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    plan.planName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),

                  // Dietitian Section with Call to Action
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: AppColors.primarySubtle,
                          child: const Icon(
                            Icons.person_rounded,
                            color: AppColors.primary,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                plan.dietitian?.name ?? 'Assigned Dietitian',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.slate900,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                plan.dietitian?.qualification ??
                                    'Clinical Nutrition & Dietetics',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.slate500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: _openDietitianConsultation,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 7,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          icon: const Icon(Icons.chat_bubble_outline_rounded,
                              size: 13),
                          label: const Text(
                            'Consult',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today_outlined,
                        size: 13,
                        color: Colors.grey.shade600,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '$_totalMonths Month${_totalMonths > 1 ? 's' : ''} Coverage (${_totalMonths * 30} Days)${plan.startDate != null ? ' • ${dateFormat.format(plan.startDate!)}' : ''}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),

                  if (plan.goals.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Divider(height: 1),
                    const SizedBox(height: 10),
                    const Text(
                      'Primary Nutritional Goals',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: AppColors.slate600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: plan.goals.map((g) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: AppColors.primary.withOpacity(0.2),
                            ),
                          ),
                          child: Text(
                            '• ${g.title}',
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primaryDark,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // 2. Subscription Timeline & Calendar Component
  Widget _buildSubscriptionTimelineSection() {
    final now = DateTime.now();
    final todayMidnight = DateTime(now.year, now.month, now.day);
    final isSelectedToday = _selectedDate.year == todayMidnight.year &&
        _selectedDate.month == todayMidnight.month &&
        _selectedDate.day == todayMidnight.day;

    final monthStart = _subscriptionStart.add(Duration(days: _selectedMonthIndex * 30));
    final daysInThisMonth = List.generate(30, (i) => monthStart.add(Duration(days: i)));

    final dayFormatter = DateFormat('EEE');
    final numFormatter = DateFormat('d');
    final monthFormatter = DateFormat('MMM');
    final selectedDayText = DateFormat('EEEE, d MMMM').format(_selectedDate);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.slate200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Timeline Title & Quick "Jump to Today"
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Meal Calendar & Schedule',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.slate900,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '$_totalMonths Month${_totalMonths > 1 ? 's' : ''} Subscription • ${_totalMonths * 30} Days Planned',
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppColors.slate500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (!isSelectedToday) ...[
                const SizedBox(width: 8),
                InkWell(
                  onTap: () {
                    setState(() {
                      _selectedDate = todayMidnight;
                      // Calculate which month index today falls in
                      final diffDays = todayMidnight.difference(_subscriptionStart).inDays;
                      if (diffDays >= 0) {
                        _selectedMonthIndex = (diffDays ~/ 30).clamp(0, _totalMonths - 1);
                      }
                    });
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primarySubtle,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.today_rounded, size: 12, color: AppColors.primaryDark),
                        SizedBox(width: 4),
                        Text(
                          'Today',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),

          // Multi-Month Switcher Tabs (if subscription >= 2 months)
          if (_totalMonths > 1) ...[
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: List.generate(_totalMonths, (idx) {
                  final isCurrentMonth = _selectedMonthIndex == idx;
                  final startDay = idx * 30 + 1;
                  final endDay = (idx + 1) * 30;

                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          _selectedMonthIndex = idx;
                          // Set selected date to first day of selected month
                          _selectedDate = _subscriptionStart.add(Duration(days: idx * 30));
                        });
                      },
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: isCurrentMonth
                              ? AppColors.primary
                              : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isCurrentMonth
                                ? AppColors.primary
                                : const Color(0xFFE2E8F0),
                          ),
                        ),
                        child: Text(
                          'Month ${idx + 1} (Days $startDay–$endDay)',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: isCurrentMonth
                                ? FontWeight.bold
                                : FontWeight.w600,
                            color: isCurrentMonth
                                ? Colors.white
                                : AppColors.slate700,
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ],

          const SizedBox(height: 12),

          // 30-Day Horizontal Interactive Date Strip
          SizedBox(
            height: 84,
            child: ListView.separated(
              controller: _dateStripScrollController,
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: daysInThisMonth.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, idx) {
                final date = daysInThisMonth[idx];
                final isSelected = date.year == _selectedDate.year &&
                    date.month == _selectedDate.month &&
                    date.day == _selectedDate.day;
                final isToday = date.year == todayMidnight.year &&
                    date.month == todayMidnight.month &&
                    date.day == todayMidnight.day;

                return InkWell(
                  onTap: () {
                    setState(() => _selectedDate = date);
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 56,
                    padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 2),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primary
                          : (isToday
                              ? AppColors.primarySubtle
                              : const Color(0xFFF8FAFC)),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.primary
                            : (isToday
                                ? AppColors.primary.withOpacity(0.5)
                                : AppColors.slate200),
                        width: isSelected || isToday ? 1.5 : 1,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: AppColors.primary.withOpacity(0.2),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          dayFormatter.format(date).toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            height: 1.1,
                            color: isSelected
                                ? Colors.white70
                                : (isToday
                                    ? AppColors.primaryDark
                                    : AppColors.slate500),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          numFormatter.format(date),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            height: 1.1,
                            color: isSelected
                                ? Colors.white
                                : (isToday
                                    ? AppColors.primaryDark
                                    : AppColors.slate900),
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          monthFormatter.format(date),
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w600,
                            height: 1.1,
                            color: isSelected
                                ? Colors.white70
                                : AppColors.slate400,
                          ),
                        ),
                        if (isToday)
                          Container(
                            margin: const EdgeInsets.only(top: 2),
                            width: 4,
                            height: 4,
                            decoration: BoxDecoration(
                              color: isSelected ? Colors.white : AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 10),

          // Selected Day Sub-Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(
                      Icons.event_available_rounded,
                      size: 16,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        isSelectedToday ? 'Today ($selectedDayText)' : selectedDayText,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppColors.slate900,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              if (_planDetail?.dailyPlannedNutrition != null) ...[
                const SizedBox(width: 8),
                Text(
                  '${_planDetail!.dailyPlannedNutrition!.calories} kcal target',
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryDark,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  // 3. Interactive Filters Bar (Occasion, Dietary)
  Widget _buildFiltersBar() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Occasion Filter Pills
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: [
              _buildFilterChip('All Meals', 'ALL', Icons.restaurant_menu_rounded, _selectedOccasionFilter, (val) {
                setState(() => _selectedOccasionFilter = val);
              }),
              _buildFilterChip('Breakfast', 'BREAKFAST', Icons.wb_sunny_rounded, _selectedOccasionFilter, (val) {
                setState(() => _selectedOccasionFilter = val);
              }),
              _buildFilterChip('Lunch', 'LUNCH', Icons.lunch_dining_rounded, _selectedOccasionFilter, (val) {
                setState(() => _selectedOccasionFilter = val);
              }),
              _buildFilterChip('Snacks', 'SNACK', Icons.cookie_outlined, _selectedOccasionFilter, (val) {
                setState(() => _selectedOccasionFilter = val);
              }),
              _buildFilterChip('Dinner', 'DINNER', Icons.nights_stay_rounded, _selectedOccasionFilter, (val) {
                setState(() => _selectedOccasionFilter = val);
              }),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // Dietary Filter Pills
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: [
              _buildDietaryFilterChip('All Dishes', 'ALL', Icons.tune_rounded),
              _buildDietaryFilterChip('Veg Only', 'VEG', Icons.eco_rounded),
              _buildDietaryFilterChip('High Protein', 'HIGH_PROTEIN', Icons.fitness_center_rounded),
              _buildDietaryFilterChip('Cheat Meals', 'CHEAT', Icons.local_pizza_rounded),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(
      String label, String value, IconData icon, String currentSelected, ValueChanged<String> onSelected) {
    final isSelected = currentSelected == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: () => onSelected(value),
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? AppColors.primary : AppColors.slate200,
              width: 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.2),
                      blurRadius: 4,
                      offset: const Offset(0, 1.5),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 14,
                color: isSelected ? Colors.white : AppColors.slate600,
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                  color: isSelected ? Colors.white : AppColors.slate700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDietaryFilterChip(String label, String value, IconData icon) {
    final isSelected = _selectedDietaryFilter == value;
    final activeColor = value == 'VEG'
        ? Colors.green.shade700
        : (value == 'HIGH_PROTEIN'
            ? Colors.indigo.shade700
            : (value == 'CHEAT' ? Colors.orange.shade800 : AppColors.primary));

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: () {
          setState(() => _selectedDietaryFilter = isSelected ? 'ALL' : value);
        },
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6.5),
          decoration: BoxDecoration(
            color: isSelected ? activeColor.withOpacity(0.12) : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? activeColor : Colors.transparent,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 13,
                color: isSelected ? activeColor : AppColors.slate500,
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                  color: isSelected ? activeColor : AppColors.slate600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.slate200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: AppColors.primary),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12.5,
                  color: AppColors.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 4. Upgraded Meal Card with Overflow Prevention & Sleek Tags
  Widget _buildMealCard(DietPlanDetailModel plan, DietPlanMealModel meal) {
    final occasionColor = _getOccasionColor(meal.occasion);
    final isConsumed = meal.adherenceStatus == 'CONFIRMED_CONSUMED';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      child: EbicCard(
        onTap: () {
          if (plan.id != null) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => DietPlanMealDetailScreen(
                  planId: plan.id!,
                  mealId: meal.id,
                ),
              ),
            );
          }
        },
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Occasion Tag + Cheat Badge & Adherence Toggle (Guaranteed 0 Overflow)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: occasionColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: occasionColor.withOpacity(0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _getOccasionIcon(meal.occasion),
                              size: 12,
                              color: occasionColor,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              meal.occasion.replaceAll('_', ' '),
                              style: TextStyle(
                                color: occasionColor,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (meal.isCheatMeal)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3.5,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFFBEB),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFFFDE68A)),
                          ),
                          child: const Text(
                            'CHEAT MEAL',
                            style: TextStyle(
                              color: Color(0xFF92400E),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // Adherence Checkbox
                InkWell(
                  onTap: () => _toggleMealAdherence(meal),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isConsumed
                          ? Colors.green.shade50
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isConsumed
                            ? Colors.green.shade300
                            : Colors.grey.shade300,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isConsumed
                              ? Icons.check_circle
                              : Icons.circle_outlined,
                          size: 13,
                          color: isConsumed ? Colors.green : Colors.grey,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isConsumed ? 'Consumed' : 'Log eaten',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: isConsumed
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: isConsumed
                                ? Colors.green.shade900
                                : Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              meal.title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            if (meal.guidance != null && meal.guidance!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                meal.guidance!,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontStyle: FontStyle.italic,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            if (meal.plannedNutrition != null) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  _buildNutritionChip(
                    '${meal.plannedNutrition!.calories} kcal',
                    isPrimary: true,
                  ),
                  _buildNutritionChip(
                    'P: ${meal.plannedNutrition!.proteinG}g',
                  ),
                  _buildNutritionChip(
                    'C: ${meal.plannedNutrition!.carbsG}g',
                  ),
                  _buildNutritionChip(
                    'F: ${meal.plannedNutrition!.fatG}g',
                  ),
                ],
              ),
            ],

            // Horizontal Dishes Preview Carousel
            if (meal.dishes.isNotEmpty) ...[
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      '${meal.dishes.length} ${meal.dishes.length == 1 ? "Dish" : "Dishes"} Planned',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.slate800,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Tap dish to view recipe',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.slate500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 72,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: meal.dishes.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, idx) {
                    final d = meal.dishes[idx];
                    final isVeg = d.dietaryTags.any(
                      (t) =>
                          t.toLowerCase() == 'vegetarian' ||
                          t.toLowerCase() == 'vegan',
                    );

                    return InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                DishDetailScreen(dish: d.toDishModel()),
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        width: 175,
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: AppColors.slate50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.slate200),
                        ),
                        child: Row(
                          children: [
                            EBICDishImage(
                              imageUrl: d.imageUrl,
                              width: 48,
                              height: 48,
                              borderRadius: 8,
                              isVegetarian: isVeg,
                              showVegIndicator: true,
                              fit: BoxFit.cover,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    d.name,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.slate900,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${d.servingQuantity} ${d.servingUnit}',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: AppColors.primaryDark,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],

            const SizedBox(height: 14),

            // Bottom Actions (Guaranteed 0 Overflow with Expanded on each button)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 9,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    icon: const Icon(Icons.restaurant_menu_rounded, size: 14),
                    label: const Text(
                      'View Details',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onPressed: () {
                      if (plan.id != null) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => DietPlanMealDetailScreen(
                              planId: plan.id!,
                              mealId: meal.id,
                            ),
                          ),
                        );
                      }
                    },
                  ),
                ),
                if (meal.bookChefEligible) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal.shade700,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 9,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      icon: const Icon(Icons.soup_kitchen, size: 14),
                      label: const Text(
                        'Cook this Meal',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onPressed: () {
                        Navigator.pushNamed(
                          context,
                          AppRoutes.bookChefAssigned,
                          arguments: {
                            'dietPlanMealId': meal.id,
                            'occasion': meal.occasion,
                            'mealTitle': meal.title,
                            'dishes': meal.dishes
                                .map((d) => {'dishId': d.dishId, 'name': d.name})
                                .toList(),
                          },
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.restaurant_menu,
                size: 64,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Your diet plan is being prepared',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Your dietitian will publish your personalized nutrition plan after reviewing your consultation.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            EbicButton(
              label: 'Book Dietitian Consultation',
              icon: Icons.video_camera_front,
              onPressed: () {
                Navigator.pushNamed(context, AppRoutes.dietitian);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNutritionChip(String text, {bool isPrimary = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isPrimary ? AppColors.primarySubtle : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isPrimary ? AppColors.primary.withOpacity(0.2) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10.5,
          color: isPrimary ? AppColors.primaryDark : AppColors.slate700,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Color _getOccasionColor(String occasion) {
    switch (occasion.toUpperCase()) {
      case 'BREAKFAST':
        return Colors.orange.shade700;
      case 'MID_MORNING':
        return Colors.amber.shade700;
      case 'LUNCH':
        return Colors.teal.shade700;
      case 'EVENING_SNACK':
        return Colors.purple.shade600;
      case 'DINNER':
        return Colors.indigo.shade700;
      default:
        return AppColors.primary;
    }
  }

  IconData _getOccasionIcon(String occasion) {
    switch (occasion.toUpperCase()) {
      case 'BREAKFAST':
        return Icons.wb_sunny_rounded;
      case 'MID_MORNING':
        return Icons.coffee_rounded;
      case 'LUNCH':
        return Icons.lunch_dining_rounded;
      case 'EVENING_SNACK':
      case 'SNACK':
        return Icons.cookie_outlined;
      case 'DINNER':
        return Icons.nights_stay_rounded;
      default:
        return Icons.restaurant_menu_rounded;
    }
  }
}
