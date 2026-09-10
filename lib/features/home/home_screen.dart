import 'package:flutter/material.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/auth/auth_service.dart';
import '../../core/routing/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/models/order_model.dart';
import '../../shared/models/health_pass_model.dart';
import '../../shared/models/consultation_model.dart';
import '../../shared/widgets/ebic_card.dart';
import '../../shared/widgets/ebic_button.dart';
import '../../shared/widgets/status_badge.dart';

class HomeScreen extends StatefulWidget {
  final Function(int tabIndex)? onNavigateTab;

  const HomeScreen({super.key, this.onNavigateTab});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ApiClient _api = ApiClient();
  bool _isLoading = true;

  MyHealthPassModel? _healthPass;
  ConsultationModel? _upcomingConsultation;
  OrderModel? _activeOrder;
  Map<String, dynamic>? _todayMeal;

  @override
  void initState() {
    super.initState();
    _loadHomeData();
  }

  Future<void> _loadHomeData() async {
    setState(() => _isLoading = true);

    try {
      // 1. Health Pass
      final hpRes = await _api.get<List<dynamic>>(ApiEndpoints.myHealthPass);
      if (hpRes.success && hpRes.data != null && hpRes.data!.isNotEmpty) {
        _healthPass = MyHealthPassModel.fromJson(hpRes.data!.first as Map<String, dynamic>);
      }

      // 2. Upcoming consultation
      final consultRes = await _api.get<List<dynamic>>(
        ApiEndpoints.consultations,
        queryParameters: {'tab': 'upcoming'},
      );
      if (consultRes.success && consultRes.data != null && consultRes.data!.isNotEmpty) {
        _upcomingConsultation =
            ConsultationModel.fromJson(consultRes.data!.first as Map<String, dynamic>);
      }

      // 3. Active order
      final ordersRes = await _api.get<Map<String, dynamic>>(
        ApiEndpoints.orders,
        queryParameters: {'tab': 'active', 'limit': 1},
      );
      if (ordersRes.success && ordersRes.data != null) {
        final items = ordersRes.data!['items'] as List<dynamic>?;
        if (items != null && items.isNotEmpty) {
          _activeOrder = OrderModel.fromJson(items.first as Map<String, dynamic>);
        }
      }

      // 4. Today's diet plan
      final mealRes = await _api.get<Map<String, dynamic>>(ApiEndpoints.todayDietPlan);
      if (mealRes.success && mealRes.data != null) {
        _todayMeal = mealRes.data;
      }
    } catch (_) {}

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning 👋';
    if (hour < 17) return 'Good Afternoon ☀️';
    return 'Good Evening 🌙';
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService().currentUser;
    final userName = user?['name'] ?? 'There';

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _getGreeting(),
              style: const TextStyle(fontSize: 13, color: AppColors.slate500, fontWeight: FontWeight.normal),
            ),
            Text(
              userName,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none_rounded),
            onPressed: () => Navigator.pushNamed(context, AppRoutes.notifications),
          ),
          IconButton(
            icon: const Icon(Icons.support_agent_rounded),
            onPressed: () => Navigator.pushNamed(context, AppRoutes.support),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadHomeData,
              color: AppColors.primary,
              child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Active Order Tracker Banner (if an order is currently active/in progress)
              if (_activeOrder != null) ...[
                _buildActiveOrderCard(_activeOrder!),
                const SizedBox(height: 16),
              ],

              // Health Pass Card (Section 7 & 8)
              _buildHealthPassCard(),
              const SizedBox(height: 16),

              // Today's Meal Card (Section 7)
              _buildTodayMealCard(),
              const SizedBox(height: 16),

              // Need a Chef Card (Section 7)
              _buildNeedChefCard(),
              const SizedBox(height: 16),

              // Upcoming Consultation (Section 7)
              if (_upcomingConsultation != null) ...[
                _buildConsultationCard(_upcomingConsultation!),
                const SizedBox(height: 16),
              ],

              // Health Progress Highlights (Section 7)
              _buildProgressHighlights(),
              const SizedBox(height: 16),

              // Promotions banner (Section 7 & 52)
              _buildPromotionBanner(),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActiveOrderCard(OrderModel order) {
    return EbicCard(
      onTap: () => Navigator.pushNamed(
        context,
        AppRoutes.chefTracking,
        arguments: {'orderId': order.id},
      ),
      gradient: const LinearGradient(
        colors: [Color(0xFF064E3B), Color(0xFF065F46)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppColors.primaryLight,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'ACTIVE CHEF BOOKING',
                    style: TextStyle(
                      color: AppColors.primaryLight,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
              StatusBadge.success(order.customerStatusLabel),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            order.assignedChef != null
                ? 'Chef ${order.assignedChef!.name} is ${order.customerStatusLabel.toLowerCase()}'
                : 'Searching for nearest certified home chef...',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.timer_outlined, color: Colors.white70, size: 14),
              const SizedBox(width: 6),
              Text(
                'Estimated Cook Time: ${order.visitCookTimeMin} mins',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: EbicButton(
                  label: 'Track Chef & ETA',
                  icon: Icons.navigation_rounded,
                  onPressed: () => Navigator.pushNamed(
                    context,
                    AppRoutes.chefTracking,
                    arguments: {'orderId': order.id},
                  ),
                ),
              ),
              const SizedBox(width: 10),
              IconButton.filledTonal(
                icon: const Icon(Icons.checklist_rounded, color: Colors.white),
                style: IconButton.styleFrom(backgroundColor: Colors.white.withOpacity(0.15)),
                onPressed: () => Navigator.pushNamed(
                  context,
                  AppRoutes.preparationChecklist,
                  arguments: {'orderId': order.id},
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHealthPassCard() {
    final hasPass = _healthPass != null && _healthPass!.isActive;

    return EbicCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.primarySubtle,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.health_and_safety, color: AppColors.primary, size: 18),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Health Pass',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ],
              ),
              StatusBadge(
                label: hasPass ? 'ACTIVE' : 'INACTIVE',
                color: hasPass ? AppColors.success : AppColors.slate400,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            hasPass ? _healthPass!.planName : 'EBIC Health Pass Membership',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            hasPass
                ? 'Valid until ${_formatDate(_healthPass!.endDate)} • ${_healthPass!.coveredMembersCount} Covered'
                : 'Unlock personalized dietitian consultations and home-chef dining benefits.',
            style: const TextStyle(color: AppColors.slate500, fontSize: 13),
          ),
          const SizedBox(height: 16),
          EbicButton(
            label: hasPass ? 'View Health Pass' : 'Explore Health Pass Plans',
            isOutlined: hasPass,
            onPressed: () {
              if (hasPass) {
                widget.onNavigateTab?.call(2); // Go to Health tab
              } else {
                Navigator.pushNamed(context, AppRoutes.healthPassPlans);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTodayMealCard() {
    return EbicCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.restaurant_outlined, color: AppColors.accent, size: 18),
                  SizedBox(width: 8),
                  Text(
                    "Today's Meal",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ],
              ),
              StatusBadge.warning('Lunch Plan'),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _todayMeal?['name']?.toString() ?? 'Grilled Herb Chicken + Brown Rice Bowl',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          const Text(
            'High Protein • 520 kcal • 48g Protein • 12g Fat',
            style: TextStyle(color: AppColors.slate500, fontSize: 13),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: EbicButton(
                  label: 'View Diet Plan',
                  isOutlined: true,
                  onPressed: () {
                    Navigator.pushNamed(context, AppRoutes.dietPlan);
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: EbicButton(
                  label: 'Cook This Meal',
                  onPressed: () {
                    Navigator.pushNamed(context, AppRoutes.bookChefAssigned);
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNeedChefCard() {
    return EbicCard(
      gradient: const LinearGradient(
        colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Need a Chef?',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Instant V1 home booking. Choose your favorite recipes or assigned diet meal.',
                  style: TextStyle(fontSize: 13, color: Colors.white70),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: 160,
                  child: EbicButton(
                    label: 'Book a Chef',
                    icon: Icons.soup_kitchen_rounded,
                    onPressed: () {
                      Navigator.pushNamed(context, AppRoutes.bookChef);
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.dining_rounded, color: AppColors.primaryLight, size: 40),
          ),
        ],
      ),
    );
  }

  Widget _buildConsultationCard(ConsultationModel consultation) {
    return EbicCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.video_camera_front_outlined, color: AppColors.info, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'Upcoming Consultation',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ],
              ),
              StatusBadge.info('CONFIRMED'),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'With ${consultation.dietitianName}',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            '${_formatDateTime(consultation.scheduledAt)} • Video Call',
            style: const TextStyle(color: AppColors.slate500, fontSize: 13),
          ),
          const SizedBox(height: 16),
          EbicButton(
            label: 'Join Consultation',
            icon: Icons.video_call_rounded,
            onPressed: () {
              Navigator.pushNamed(
                context,
                AppRoutes.consultationVideo,
                arguments: {'consultationId': consultation.id},
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildProgressHighlights() {
    return EbicCard(
      onTap: () => Navigator.pushNamed(context, AppRoutes.healthProgress),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Health Progress', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              Row(
                children: const [
                  Text('View Details', style: TextStyle(color: AppColors.primary, fontSize: 13, fontWeight: FontWeight.w600)),
                  Icon(Icons.chevron_right, size: 18, color: AppColors.primary),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildProgressMetric('Calories', '1,850', 'kcal', Icons.local_fire_department_outlined, Colors.orange),
              _buildProgressMetric('Protein', '112', 'g', Icons.fitness_center_outlined, Colors.blue),
              _buildProgressMetric('Water', '2.6', 'L', Icons.water_drop_outlined, Colors.cyan),
              _buildProgressMetric('Steps', '8,420', 'steps', Icons.directions_walk_outlined, Colors.green),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProgressMetric(String label, String value, String unit, IconData icon, Color color) {
    return Expanded(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          Text(unit, style: const TextStyle(color: AppColors.slate500, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildPromotionBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.accentSubtle,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.accent.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.discount_outlined, color: AppColors.accent, size: 28),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'HEALTHYFIRST • 20% OFF',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF92400E)),
                ),
                SizedBox(height: 2),
                Text(
                  'Use code on your first chef booking or Health Pass.',
                  style: TextStyle(fontSize: 12, color: Color(0xFFB45309)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day} ${_monthName(dt.month)} ${dt.year}';
  }

  String _formatDateTime(DateTime dt) {
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    final min = dt.minute.toString().padLeft(2, '0');
    return '${dt.day} ${_monthName(dt.month)} • $hour:$min $ampm';
  }

  String _monthName(int m) {
    const names = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return names[m - 1];
  }
}
