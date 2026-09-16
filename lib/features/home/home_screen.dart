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
import '../health_pass/data/health_pass_repository.dart';

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
  ConsultationModel? _completedConsultation;
  OrderModel? _activeOrder;
  Map<String, dynamic>? _todayMeal;

  @override
  void initState() {
    super.initState();
    _loadHomeData();
    HealthPassRepository.passUpdateNotifier.addListener(_loadHomeData);
  }

  @override
  void dispose() {
    HealthPassRepository.passUpdateNotifier.removeListener(_loadHomeData);
    super.dispose();
  }

  Future<void> _loadHomeData() async {
    setState(() => _isLoading = true);

    try {
      // 1. Health Pass
      final hpRes = await _api.get<List<dynamic>>(ApiEndpoints.myHealthPass);
      if (hpRes.success && hpRes.data != null && hpRes.data!.isNotEmpty) {
        _healthPass = MyHealthPassModel.fromJson(hpRes.data!.first as Map<String, dynamic>);
      }

      // 2. Consultations (Active/In-Progress, Scheduled, and Completed)
      final consultRes = await _api.get<List<dynamic>>(ApiEndpoints.consultations);
      if (consultRes.success && consultRes.data != null && consultRes.data!.isNotEmpty) {
        final list = consultRes.data!
            .map((json) => ConsultationModel.fromJson(json as Map<String, dynamic>))
            .toList();
        list.sort((a, b) => b.scheduledAt.compareTo(a.scheduledAt));

        final upcomingOrActive = list.where(
          (c) => c.status == 'SCHEDULED' || c.status == 'IN_PROGRESS' || c.status == 'PENDING',
        ).toList();
        _upcomingConsultation = upcomingOrActive.isNotEmpty ? upcomingOrActive.first : null;

        final completed = list.where((c) => c.status == 'COMPLETED').toList();
        _completedConsultation = completed.isNotEmpty ? completed.first : null;
      } else {
        _upcomingConsultation = null;
        _completedConsultation = null;
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
        } else {
          _activeOrder = null;
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

              // Upcoming Consultation or Assigned Dietitian (Module 5: Section 50 & 56)
              if (_upcomingConsultation != null) ...[
                _buildConsultationCard(_upcomingConsultation!),
                const SizedBox(height: 16),
              ] else if (_completedConsultation != null) ...[
                _buildAssignedDietitianCard(_completedConsultation!),
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
                ? (_healthPass!.endDate != null
                    ? 'Valid until ${_formatDate(_healthPass!.endDate!)} • ${_healthPass!.coveredMembersCount} Covered'
                    : 'Starts upon initial consultation • ${_healthPass!.coveredMembersCount} Covered')
                : 'Unlock personalized dietitian consultations and home-chef dining benefits.',
            style: const TextStyle(color: AppColors.slate500, fontSize: 13),
          ),
          if (hasPass) ...[
            const SizedBox(height: 10),
            if (_upcomingConsultation != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: _upcomingConsultation!.status == 'IN_PROGRESS'
                      ? const Color(0xFFFEF3C7)
                      : const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _upcomingConsultation!.status == 'IN_PROGRESS'
                        ? const Color(0xFFF59E0B).withOpacity(0.4)
                        : const Color(0xFF93C5FD).withOpacity(0.5),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _upcomingConsultation!.status == 'IN_PROGRESS'
                          ? Icons.hourglass_top_rounded
                          : Icons.event_available_rounded,
                      size: 14,
                      color: _upcomingConsultation!.status == 'IN_PROGRESS'
                          ? const Color(0xFFB45309)
                          : const Color(0xFF1D4ED8),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _upcomingConsultation!.status == 'IN_PROGRESS'
                            ? 'Consultation in-progress with Dr. ${_upcomingConsultation!.dietitianName}'
                            : 'Consultation confirmed for ${_formatDateTime(_upcomingConsultation!.scheduledAt)} with Dr. ${_upcomingConsultation!.dietitianName}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _upcomingConsultation!.status == 'IN_PROGRESS'
                              ? const Color(0xFF92400E)
                              : const Color(0xFF1E40AF),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ] else if (_healthPass!.endDate == null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.video_call_rounded, size: 14, color: Color(0xFFB45309)),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Step 1 Kickoff: Schedule consultation to activate pass countdown',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF92400E)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
          const SizedBox(height: 14),
          EbicButton(
            label: hasPass
                ? (_upcomingConsultation != null
                    ? (_upcomingConsultation!.status == 'IN_PROGRESS' ? 'Join Video Call' : 'View Consultation')
                    : (_healthPass!.endDate == null ? 'Schedule Kickoff Call' : 'View Health Pass'))
                : 'Explore Health Pass Plans',
            isOutlined: hasPass && _upcomingConsultation == null && _healthPass!.endDate != null,
            icon: (hasPass && _upcomingConsultation != null)
                ? Icons.video_call_rounded
                : (hasPass && _healthPass!.endDate == null ? Icons.calendar_today_rounded : null),
            onPressed: () {
              if (hasPass) {
                if (_upcomingConsultation != null) {
                  if (_upcomingConsultation!.status == 'IN_PROGRESS') {
                    Navigator.pushNamed(
                      context,
                      AppRoutes.consultationVideo,
                      arguments: {'consultation': _upcomingConsultation},
                    ).then((_) => _loadHomeData());
                  } else {
                    Navigator.pushNamed(
                      context,
                      AppRoutes.consultationDetail,
                      arguments: {'consultation': _upcomingConsultation},
                    ).then((_) => _loadHomeData());
                  }
                } else if (_healthPass!.endDate == null) {
                  Navigator.pushNamed(context, AppRoutes.consultationBook).then((_) => _loadHomeData());
                } else {
                  widget.onNavigateTab?.call(2); // Go to Health tab
                }
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
    final isInProgress = consultation.status == 'IN_PROGRESS';

    return EbicCard(
      onTap: () {
        Navigator.pushNamed(
          context,
          AppRoutes.consultationDetail,
          arguments: {'consultation': consultation},
        ).then((_) => _loadHomeData());
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    isInProgress ? Icons.hourglass_top_rounded : Icons.video_camera_front_outlined,
                    color: isInProgress ? const Color(0xFFD97706) : AppColors.primary,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isInProgress ? 'Consultation In Progress' : 'Upcoming Consultation',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ],
              ),
              StatusBadge(
                label: isInProgress ? 'IN PROGRESS' : 'CONFIRMED',
                color: isInProgress ? const Color(0xFFF59E0B) : AppColors.info,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'With Dr. ${consultation.dietitianName}',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          if (consultation.dietitianQualification != null) ...[
            const SizedBox(height: 2),
            Text(
              consultation.dietitianQualification!,
              style: const TextStyle(fontSize: 11.5, color: AppColors.primary, fontWeight: FontWeight.w500),
            ),
          ],
          const SizedBox(height: 4),
          Text(
            isInProgress
                ? 'Video session active • Dietitian is finalizing clinical recommendations'
                : '${_formatDateTime(consultation.scheduledAt)} • 45-min HD Video Call',
            style: TextStyle(
              color: isInProgress ? const Color(0xFFB45309) : AppColors.slate500,
              fontSize: 12.5,
              fontWeight: isInProgress ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                flex: 5,
                child: EbicButton(
                  label: isInProgress ? 'Re-join Video Call' : 'Join Video Call',
                  icon: Icons.video_call_rounded,
                  onPressed: () {
                    Navigator.pushNamed(
                      context,
                      AppRoutes.consultationVideo,
                      arguments: {'consultation': consultation},
                    ).then((_) => _loadHomeData());
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 4,
                child: EbicButton(
                  label: 'View Details',
                  isOutlined: true,
                  onPressed: () {
                    Navigator.pushNamed(
                      context,
                      AppRoutes.consultationDetail,
                      arguments: {'consultation': consultation},
                    ).then((_) => _loadHomeData());
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAssignedDietitianCard(ConsultationModel consultation) {
    return EbicCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.verified_user_rounded, color: AppColors.primary, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'My Assigned Dietitian',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primarySubtle,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text('ASSIGNED', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: AppColors.primaryDark)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: AppColors.primary.withOpacity(0.12),
                backgroundImage: consultation.dietitianPhotoUrl != null ? NetworkImage(consultation.dietitianPhotoUrl!) : null,
                onBackgroundImageError: consultation.dietitianPhotoUrl != null ? (_, __) {} : null,
                child: consultation.dietitianPhotoUrl == null
                    ? const Icon(Icons.person, color: AppColors.primary, size: 22)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Dr. ${consultation.dietitianName}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    Text(
                      consultation.dietitianQualification ?? 'Clinical Nutritionist (RD)',
                      style: const TextStyle(fontSize: 11.5, color: AppColors.primary, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: EbicButton(
                  label: 'View Diet Plan',
                  icon: Icons.restaurant_menu_rounded,
                  onPressed: () => Navigator.pushNamed(context, AppRoutes.dietPlan),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: EbicButton(
                  label: 'Book Session',
                  isOutlined: true,
                  icon: Icons.video_call_rounded,
                  onPressed: () => Navigator.pushNamed(context, AppRoutes.consultationBook).then((_) => _loadHomeData()),
                ),
              ),
            ],
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

  String _formatDate(DateTime? dt) {
    if (dt == null) return 'Pending';
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
