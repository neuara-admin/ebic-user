import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/routing/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/models/household_member_model.dart';
import '../../shared/widgets/ebic_button.dart';
import '../../shared/widgets/ebic_card.dart';
import 'diet_plan_service.dart';
import 'diet_plan_calendar_screen.dart';
import 'diet_plan_meal_detail_screen.dart';
import 'diet_plan_nutrition_screen.dart';
import 'diet_plan_history_screen.dart';
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
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initData();
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
            .map((json) => HouseholdMemberModel.fromJson(json as Map<String, dynamic>))
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
    final plan = await _dietPlanService.getActivePlan(memberId: _selectedMemberId);
    if (mounted) {
      setState(() {
        _planDetail = plan;
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
    final newStatus = meal.adherenceStatus == 'CONFIRMED_CONSUMED' ? 'PLANNED' : 'CONFIRMED_CONSUMED';

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
          backgroundColor: newStatus == 'CONFIRMED_CONSUMED' ? Colors.green : Colors.grey.shade800,
          duration: const Duration(seconds: 2),
        ),
      );
    }
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
          if (_planDetail?.id != null)
            IconButton(
              icon: const Icon(Icons.history),
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
          // Section 75: Household Member Selector (Rule 1: One member, one personalized plan)
          if (_householdMembers.length > 1) _buildMemberSelector(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : _buildBody(),
          ),
        ],
      ),
    );
  }

  Widget _buildMemberSelector() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'SELECT COVERED MEMBER',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _householdMembers.map((m) {
                final isSelected = m.id == _selectedMemberId;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          m.isSelf ? Icons.person : Icons.family_restroom,
                          size: 14,
                          color: isSelected ? Colors.white : AppColors.textPrimary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          m.name + (m.isSelf ? ' (Self)' : ''),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            color: isSelected ? Colors.white : AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    selected: isSelected,
                    selectedColor: AppColors.primary,
                    backgroundColor: Colors.grey.shade100,
                    side: BorderSide(
                      color: isSelected ? AppColors.primary : Colors.transparent,
                    ),
                    onSelected: (_) => _onMemberSelected(m),
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
    // Section 66: Empty states
    if (_planDetail == null || !_planDetail!.hasActivePlan) {
      return _buildEmptyState();
    }

    final plan = _planDetail!;
    final dateFormat = DateFormat('dd MMM yyyy');

    return RefreshIndicator(
      onRefresh: _fetchDietPlan,
      color: AppColors.primary,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Section 77: Plan Overview Card
          EbicCard(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Text(
                        plan.customerFacingStatus,
                        style: TextStyle(
                          color: Colors.green.shade800,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Text(
                      'Version ${plan.versionNumber}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w600,
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
                if (plan.dietitian != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.badge_outlined, size: 14, color: Colors.grey.shade600),
                      const SizedBox(width: 4),
                      Text(
                        'Created by ${plan.dietitian!.name}',
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                      ),
                    ],
                  ),
                ],
                if (plan.startDate != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.calendar_today_outlined, size: 14, color: Colors.grey.shade600),
                      const SizedBox(width: 4),
                      Text(
                        'Period: ${dateFormat.format(plan.startDate!)}${plan.reviewDate != null ? ' → ${dateFormat.format(plan.reviewDate!)}' : ''}',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ],
                if (plan.goals.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 10),
                  const Text(
                    'Primary Goals',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: plan.goals.map((g) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '• ${g.title}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Quick Action Navigation Bar
          Row(
            children: [
              Expanded(
                child: _buildActionButton(
                  icon: Icons.calendar_month,
                  label: '7-Day Calendar',
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
                  icon: Icons.track_changes,
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

          const SizedBox(height: 20),

          // Section 63 & 64: "Today's Plan" Primary Customer Experience
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'What should I eat today?',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    'Today: ${plan.todayDayOfWeek ?? 'Daily Plan'}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
              if (plan.dailyPlannedNutrition != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${plan.dailyPlannedNutrition!.calories} kcal planned',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 14),

          // Today's Meals List
          if (plan.todayMeals.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  'No meals scheduled for today.',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ),
            )
          else
            ...plan.todayMeals.map((meal) => _buildMealCard(plan, meal)),

          const SizedBox(height: 16),

          // Section 33: Daily Dietitian Instructions Card
          if (plan.specialInstructions != null && plan.specialInstructions!.isNotEmpty)
            EbicCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.lightbulb_outline, size: 18, color: Colors.amber.shade800),
                      const SizedBox(width: 6),
                      const Text(
                        'Daily Dietitian Instructions',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    plan.specialInstructions!,
                    style: const TextStyle(fontSize: 13, height: 1.4, color: AppColors.textPrimary),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 24),
        ],
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
          border: Border.all(color: Colors.grey.shade200),
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
            Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMealCard(DietPlanDetailModel plan, DietPlanMealModel meal) {
    final occasionColor = _getOccasionColor(meal.occasion);
    final isConsumed = meal.adherenceStatus == 'CONFIRMED_CONSUMED';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      child: EbicCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: occasionColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        meal.occasion.replaceAll('_', ' '),
                        style: TextStyle(
                          color: occasionColor,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (meal.isCheatMeal) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade100,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.amber.shade400),
                        ),
                        child: Text(
                          'CHEAT MEAL',
                          style: TextStyle(
                            color: Colors.amber.shade900,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),

                // Adherence Checkbox (Section 43)
                InkWell(
                  onTap: () => _toggleMealAdherence(meal),
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isConsumed ? Colors.green.shade50 : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isConsumed ? Colors.green.shade300 : Colors.grey.shade300,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isConsumed ? Icons.check_circle : Icons.circle_outlined,
                          size: 14,
                          color: isConsumed ? Colors.green : Colors.grey,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isConsumed ? 'Consumed' : 'Log eaten',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: isConsumed ? FontWeight.bold : FontWeight.normal,
                            color: isConsumed ? Colors.green.shade900 : Colors.grey.shade700,
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
                style: TextStyle(fontSize: 12, color: Colors.amber.shade900, fontStyle: FontStyle.italic),
              ),
            ],
            const SizedBox(height: 10),
            if (meal.plannedNutrition != null)
              Row(
                children: [
                  _buildNutritionChip('${meal.plannedNutrition!.calories} kcal'),
                  const SizedBox(width: 8),
                  _buildNutritionChip('${meal.plannedNutrition!.proteinG}g Protein'),
                  const SizedBox(width: 8),
                  _buildNutritionChip('${meal.plannedNutrition!.carbsG}g Carbs'),
                ],
              ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
                  child: const Text('View Meal', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                ),

                // Section 20 & 31: [Book Chef] action when eligible
                if (meal.bookChefEligible)
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal.shade700,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.soup_kitchen, size: 14),
                    label: const Text('Book Chef', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    onPressed: () {
                      Navigator.pushNamed(
                        context,
                        AppRoutes.bookChefAssigned,
                        arguments: {
                          'dietPlanMealId': meal.id,
                          'mealTitle': meal.title,
                          'dishes': meal.dishes.map((d) => {'dishId': d.dishId, 'name': d.name}).toList(),
                        },
                      );
                    },
                  ),
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
              child: const Icon(Icons.restaurant_menu, size: 64, color: AppColors.primary),
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
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600, height: 1.4),
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

  Widget _buildNutritionChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 11, color: Colors.grey.shade700, fontWeight: FontWeight.w500),
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
}
