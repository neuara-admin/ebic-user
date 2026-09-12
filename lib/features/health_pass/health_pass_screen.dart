import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/analytics/analytics_service.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/routing/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/models/consultation_model.dart';
import '../../shared/models/health_pass_model.dart';
import '../../shared/widgets/ebic_button.dart';
import '../../shared/widgets/ebic_card.dart';
import 'data/health_pass_repository.dart';

/// Module 4 — Section 33: Health Pass Overview Screen
/// Dynamically renders customer state: No Health Pass vs Active Health Pass with Live Entitlements.
class HealthPassScreen extends StatefulWidget {
  const HealthPassScreen({super.key});

  @override
  State<HealthPassScreen> createState() => _HealthPassScreenState();
}

class _HealthPassScreenState extends State<HealthPassScreen> {
  final HealthPassRepository _repository = HealthPassRepository();
  final ApiClient _api = ApiClient();

  ActiveHealthPassModel? _activePass;
  ConsultationModel? _activeConsultation;
  ConsultationModel? _completedConsultation;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    AnalyticsService().logHealthPassViewed();
    _loadCurrentPass();
    HealthPassRepository.passUpdateNotifier.addListener(_loadCurrentPass);
  }

  @override
  void dispose() {
    HealthPassRepository.passUpdateNotifier.removeListener(_loadCurrentPass);
    super.dispose();
  }

  Future<void> _loadCurrentPass() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final pass = await _repository.fetchCurrentPass();
      ConsultationModel? activeConsult = pass?.activeConsultation;
      ConsultationModel? completedConsult = pass?.latestCompletedConsultation;

      // Also directly query consultations API for live synchronization
      try {
        final consultRes = await _api.get<List<dynamic>>(ApiEndpoints.consultations);
        if (consultRes.success && consultRes.data != null) {
          final list = consultRes.data!
              .map((json) => ConsultationModel.fromJson(json as Map<String, dynamic>))
              .toList();
          list.sort((a, b) => b.scheduledAt.compareTo(a.scheduledAt));

          final upcomingOrActive = list.where(
            (c) => c.status == 'SCHEDULED' || c.status == 'IN_PROGRESS' || c.status == 'PENDING',
          ).toList();
          if (upcomingOrActive.isNotEmpty) {
            activeConsult = upcomingOrActive.first;
          }

          final completedList = list.where((c) => c.status == 'COMPLETED').toList();
          if (completedList.isNotEmpty) {
            completedConsult = completedList.first;
          }
        }
      } catch (_) {}

      if (mounted) {
        setState(() {
          _activePass = pass;
          _activeConsultation = activeConsult;
          _completedConsultation = completedConsult;
          _isLoading = false;
        });
        if (pass != null) {
          AnalyticsService().logHealthPassViewedActive();
          if (pass.isExpiringSoon || pass.isExpired) {
            AnalyticsService().logHealthPassExpiryViewed();
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Health Pass'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month_outlined),
            tooltip: 'My Consultations',
            onPressed: () => Navigator.pushNamed(context, AppRoutes.consultationsList).then((_) => _loadCurrentPass()),
          ),
          IconButton(
            icon: const Icon(Icons.history_rounded),
            tooltip: 'Subscription History',
            onPressed: () => Navigator.pushNamed(context, AppRoutes.healthPassHistory),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadCurrentPass,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: _errorMessage != null && _activePass == null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 40),
                          child: Column(
                            children: [
                              const Icon(Icons.error_outline, size: 48, color: AppColors.danger),
                              const SizedBox(height: 12),
                              Text(_errorMessage!, textAlign: TextAlign.center),
                              const SizedBox(height: 16),
                              SizedBox(
                                width: 120,
                                child: EbicButton(
                                  label: 'Retry',
                                  onPressed: _loadCurrentPass,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : _activePass == null
                        ? _buildCustomerWithoutPass(isDark)
                        : _buildCustomerWithActivePass(_activePass!, isDark),
              ),
            ),
    );
  }

  // Section 8: Overview — Customer Without Health Pass
  Widget _buildCustomerWithoutPass(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Hero Card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.25),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'HEALTH & NUTRITION ECOSYSTEM',
                  style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.6),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Personalized Nutrition\n& Health Support',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Dedicated clinical dietitians, customized diet plans, and monthly in-home chef visit entitlements for your family.',
                style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.primaryDark,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => Navigator.pushNamed(context, AppRoutes.healthPassPlans),
                child: const Text('Explore Health Pass Plans', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // What You Get Section
        const Text(
          'WHAT YOU GET WITH HEALTH PASS',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: AppColors.slate500,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 12),

        _buildBenefitFeature(
          icon: Icons.restaurant_menu_rounded,
          title: 'In-Home Chef Visit Entitlements',
          description: 'Free chef visits each month for preparing healthy, prescribed meals in your kitchen.',
          isDark: isDark,
        ),
        const SizedBox(height: 10),
        _buildBenefitFeature(
          icon: Icons.video_camera_front_outlined,
          title: 'Clinical Dietitian Consultations',
          description: 'One-on-one video appointments, clinical assessments, and ongoing coaching.',
          isDark: isDark,
        ),
        const SizedBox(height: 10),
        _buildBenefitFeature(
          icon: Icons.description_outlined,
          title: 'Personalized Clinical Diet Plan',
          description: 'Tailored nutrition charts matching your medical conditions and family taste preferences.',
          isDark: isDark,
        ),
        const SizedBox(height: 10),
        _buildBenefitFeature(
          icon: Icons.family_restroom_rounded,
          title: 'Cover Entire Household',
          description: 'Add family members with individualized health profiles and covered allowances.',
          isDark: isDark,
        ),
        const SizedBox(height: 20),

        // Comparison Banner
        EbicCard(
          onTap: () => Navigator.pushNamed(context, AppRoutes.healthPassComparison),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.slate800 : AppColors.slate100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.compare_arrows_rounded, color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Compare Essential vs Care Plans', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    SizedBox(height: 2),
                    Text('View full side-by-side entitlement comparison', style: TextStyle(color: AppColors.slate500, fontSize: 11)),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.slate400),
            ],
          ),
        ),
      ],
    );
  }

  // Section 9 & 10: Overview — Customer With Active Health Pass
  Widget _buildCustomerWithActivePass(ActiveHealthPassModel pass, bool isDark) {
    final activeConsult = _activeConsultation ?? pass.activeConsultation;
    final completedConsult = _completedConsultation ?? pass.latestCompletedConsultation;

    final isInProgress = activeConsult?.status == 'IN_PROGRESS';
    final isScheduled = activeConsult != null &&
        (activeConsult.status == 'SCHEDULED' || activeConsult.status == 'PENDING');
    final isCompleted = completedConsult != null || !pass.isConsultationPending;
    final hasDietitian = pass.assignedDietitian != null;

    // Determine status badge properties
    Color pillBg;
    Color pillText;
    IconData pillIcon;
    String pillLabel;

    if (pass.isExpired) {
      pillBg = const Color(0xFFFEE2E2);
      pillText = const Color(0xFFB91C1C);
      pillIcon = Icons.cancel_outlined;
      pillLabel = 'EXPIRED';
    } else if (isInProgress) {
      pillBg = const Color(0xFFFEF3C7);
      pillText = const Color(0xFFB45309);
      pillIcon = Icons.hourglass_top_rounded;
      pillLabel = 'IN PROGRESS';
    } else if (isScheduled) {
      pillBg = const Color(0xFFDBEAFE);
      pillText = const Color(0xFF1D4ED8);
      pillIcon = Icons.event_available_rounded;
      pillLabel = 'KICKOFF BOOKED';
    } else if (isCompleted) {
      pillBg = const Color(0xFFD1FAE5);
      pillText = const Color(0xFF047857);
      pillIcon = Icons.verified_rounded;
      pillLabel = pass.status.replaceAll('_', ' ');
    } else {
      pillBg = const Color(0xFFFEF3C7);
      pillText = const Color(0xFFB45309);
      pillIcon = Icons.pending_actions_rounded;
      pillLabel = 'PENDING KICKOFF';
    }

    // Determine card status label
    String cardStatusText;
    if (pass.isExpired) {
      cardStatusText = 'Pass Expired';
    } else if (isInProgress) {
      cardStatusText = 'Session Active';
    } else if (isScheduled) {
      cardStatusText = 'Kickoff: ${DateFormat('dd MMM').format(activeConsult.scheduledAt)}';
    } else if (isCompleted) {
      cardStatusText = '${pass.daysRemaining} Days Remaining';
    } else {
      cardStatusText = 'Awaiting Kickoff';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Executive VIP Membership Card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: isDark
                ? const LinearGradient(
                    colors: [Color(0xFF064E3B), Color(0xFF0F172A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : const LinearGradient(
                    colors: [Color(0xFF047857), Color(0xFF065F46)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.3),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Brand Row & Status Badge
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.18),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.shield_rounded, color: Colors.white, size: 15),
                        ),
                        const SizedBox(width: 6),
                        const Flexible(
                          child: Text(
                            'EBIC HEALTH PASS',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.white70,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
                    decoration: BoxDecoration(
                      color: pillBg,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          pillIcon,
                          size: 11,
                          color: pillText,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          pillLabel,
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                            color: pillText,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Plan Title & Description
              Text(
                pass.displayName,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${pass.durationMonths} ${pass.durationMonths == 1 ? 'Month' : 'Months'} Term • ${pass.coveredMembers.length} ${pass.coveredMembers.length == 1 ? 'Member' : 'Members'} Covered',
                style: const TextStyle(fontSize: 12.5, color: Colors.white70),
              ),
              const SizedBox(height: 16),

              // Bottom VIP Card Details Divider
              Container(height: 1, color: Colors.white.withOpacity(0.15)),
              const SizedBox(height: 12),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('MEMBERSHIP REF', style: TextStyle(fontSize: 9, color: Colors.white60, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                        const SizedBox(height: 2),
                        Text(
                          '#${pass.id.length > 8 ? pass.id.substring(pass.id.length - 8).toUpperCase() : pass.id.toUpperCase()}',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white, fontFamily: 'monospace'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text('STATUS', style: TextStyle(fontSize: 9, color: Colors.white60, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                        const SizedBox(height: 2),
                        Text(
                          cardStatusText,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 2. Consultation & Assigned Dietitian Lifecycle Section (Contextual: In-Progress, Scheduled, Completed, or Pending Booking)
        _buildConsultationLifecycleSection(pass, isDark),
        const SizedBox(height: 16),

        // 3. Validity Details Card
        EbicCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Text(
                      'SUBSCRIPTION VALIDITY',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.slate500, letterSpacing: 0.5),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.slate800 : AppColors.slate100,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      pass.isExpired
                          ? 'Expired'
                          : isInProgress
                              ? 'Session Active'
                              : isScheduled
                                  ? 'Kickoff: ${DateFormat('dd MMM').format(activeConsult.scheduledAt)}'
                                  : isCompleted
                                      ? '${pass.daysRemaining} Days Left'
                                      : 'Awaiting Kickoff',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        color: pass.isExpired
                            ? AppColors.danger
                            : isInProgress
                                ? const Color(0xFFB45309)
                                : isScheduled
                                    ? const Color(0xFF1D4ED8)
                                    : isCompleted
                                        ? (isDark ? AppColors.slate300 : AppColors.slate700)
                                        : AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('START DATE', style: TextStyle(fontSize: 10, color: AppColors.slate400, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 2),
                        Text(
                          pass.startDate != null
                              ? '${pass.startDate!.day}/${pass.startDate!.month}/${pass.startDate!.year}'
                              : isScheduled
                                  ? 'Starts ${DateFormat('dd MMM yyyy').format(activeConsult.scheduledAt)}'
                                  : isInProgress
                                      ? 'Starts upon consultation'
                                      : 'Starts upon kickoff',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: pass.startDate != null
                                ? (isDark ? Colors.white : AppColors.slate900)
                                : isScheduled
                                    ? const Color(0xFF1D4ED8)
                                    : AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text('EXPIRY DATE', style: TextStyle(fontSize: 10, color: AppColors.slate400, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 2),
                        Text(
                          pass.endDate != null
                              ? '${pass.endDate!.day}/${pass.endDate!.month}/${pass.endDate!.year}'
                              : '+${pass.durationMonths} Months upon kickoff',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: pass.endDate != null
                                ? (isDark ? Colors.white : AppColors.slate900)
                                : AppColors.primary,
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
        const SizedBox(height: 16),

        // 4. Live Entitlements Allowance Card
        EbicCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Text(
                      'LIVE ENTITLEMENT ALLOWANCES',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.slate500, letterSpacing: 0.5),
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () {
                      Navigator.pushNamed(
                        context,
                        AppRoutes.healthPassUsage,
                        arguments: {'healthPassId': pass.id},
                      );
                    },
                    child: const Text('View Ledger →', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary)),
                  ),
                ],
              ),
              const Divider(height: 16),

              // In-Home Chef Visits
              _buildEntitlementCounter(
                title: 'In-Home Chef Visits',
                allocated: pass.chefVisitsAllocated,
                used: pass.chefVisitsUsed,
                remaining: pass.chefVisitsRemaining,
                isDark: isDark,
              ),
              const SizedBox(height: 14),

              // Dietitian Consultations
              _buildEntitlementCounter(
                title: 'Clinical Dietitian Consultations',
                allocated: pass.consultationsAllocated,
                used: pass.consultationsUsed,
                remaining: pass.consultationsRemaining,
                isDark: isDark,
              ),

              const Divider(height: 20),
              Row(
                children: [
                  const Icon(Icons.autorenew_rounded, size: 14, color: AppColors.slate400),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Period ${pass.anniversaryMonthIndex}: Resets on ${pass.anniversaryEndDate.day}/${pass.anniversaryEndDate.month}/${pass.anniversaryEndDate.year} (monthly anniversary).',
                      style: const TextStyle(fontSize: 11, color: AppColors.slate500),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 5. Covered Household Members
        EbicCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Text(
                      'COVERED HOUSEHOLD MEMBERS',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.slate500, letterSpacing: 0.5),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${pass.coveredMembers.length} Members',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: pass.coveredMembers.map((m) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.slate800 : AppColors.slate100,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: m.isPrimary
                            ? AppColors.primary.withOpacity(0.4)
                            : (isDark ? AppColors.slate700 : AppColors.slate200),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          m.isPrimary ? Icons.star_rounded : Icons.person_outline,
                          size: 14,
                          color: m.isPrimary ? AppColors.accent : AppColors.primary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${m.name} (${m.relationship})',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : AppColors.slate800,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 6. Assigned Dietitian Card (only if not already displayed in completed consultation lifecycle)
        if (!isCompleted && hasDietitian) ...[
          EbicCard(
            onTap: () => Navigator.pushNamed(context, AppRoutes.consultationBook).then((_) => _loadCurrentPass()),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: AppColors.primarySubtle,
                  backgroundImage: pass.assignedDietitian!.photoUrl != null
                      ? NetworkImage(pass.assignedDietitian!.photoUrl!)
                      : null,
                  child: pass.assignedDietitian!.photoUrl == null
                      ? const Icon(Icons.person, color: AppColors.primary)
                      : null,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('ASSIGNED CLINICAL DIETITIAN', style: TextStyle(fontSize: 10, color: AppColors.slate400, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      Text(
                        pass.assignedDietitian!.name,
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isDark ? Colors.white : AppColors.slate900),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        pass.assignedDietitian!.specializations.isNotEmpty
                            ? pass.assignedDietitian!.specializations.join(' • ')
                            : 'Clinical Nutritionist',
                        style: const TextStyle(color: AppColors.slate500, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.video_call_outlined, color: AppColors.primary, size: 24),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // 7. Quick Navigation Action Grid
        Row(
          children: [
            Expanded(
              child: EbicButton(
                label: 'Book Chef Visit',
                icon: Icons.soup_kitchen_rounded,
                onPressed: () {
                  Navigator.pushNamed(context, AppRoutes.bookChef);
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: EbicButton(
                label: 'Book Video Call',
                icon: Icons.video_call_rounded,
                isOutlined: true,
                onPressed: () {
                  Navigator.pushNamed(context, AppRoutes.consultationBook).then((_) => _loadCurrentPass());
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: EbicButton(
                label: 'My Consultations',
                icon: Icons.calendar_month_rounded,
                variant: EbicButtonVariant.outline,
                onPressed: () {
                  Navigator.pushNamed(context, AppRoutes.consultationsList).then((_) => _loadCurrentPass());
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: EbicButton(
                label: 'View Benefits',
                icon: Icons.stars_rounded,
                variant: EbicButtonVariant.outline,
                onPressed: () {
                  Navigator.pushNamed(
                    context,
                    AppRoutes.healthPassBenefits,
                    arguments: {'planName': pass.planName, 'planCode': pass.planCode},
                  );
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: EbicButton(
            label: 'Renew Pass',
            variant: EbicButtonVariant.ghost,
            icon: Icons.autorenew_rounded,
            onPressed: () {
              Navigator.pushNamed(
                context,
                AppRoutes.healthPassRenew,
                arguments: {'healthPassId': pass.id, 'planName': pass.planName, 'planCode': pass.planCode},
              );
            },
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildEntitlementCounter({
    required String title,
    required int allocated,
    required int used,
    required int remaining,
    required bool isDark,
  }) {
    final progress = allocated > 0 ? (used / allocated).clamp(0.0, 1.0) : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: isDark ? Colors.white : AppColors.slate800),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '$used/$allocated used ($remaining left)',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: remaining > 0 ? AppColors.primary : AppColors.warning),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 6,
            backgroundColor: isDark ? AppColors.slate800 : AppColors.slate100,
            valueColor: AlwaysStoppedAnimation<Color>(remaining > 0 ? AppColors.primary : AppColors.warning),
          ),
        ),
      ],
    );
  }

  Widget _buildBenefitFeature({
    required IconData icon,
    required String title,
    required String description,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.slate900 : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? AppColors.slate800 : AppColors.slate200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isDark ? AppColors.slate800 : AppColors.primarySubtle,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: isDark ? Colors.white : AppColors.slate900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: const TextStyle(color: AppColors.slate500, fontSize: 11, height: 1.3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConsultationLifecycleSection(ActiveHealthPassModel pass, bool isDark) {
    final activeConsult = _activeConsultation ?? pass.activeConsultation;
    final completedConsult = _completedConsultation ?? pass.latestCompletedConsultation;
    final hasCompleted = completedConsult != null || !pass.isConsultationPending;

    if (activeConsult != null) {
      if (activeConsult.status == 'IN_PROGRESS') {
        return _buildConsultationInProgressCard(activeConsult, isDark);
      } else if (activeConsult.status == 'SCHEDULED' || activeConsult.status == 'PENDING') {
        return _buildConsultationScheduledCard(pass, activeConsult, isDark);
      }
    }

    if (hasCompleted) {
      return _buildConsultationCompletedSection(pass, completedConsult, isDark);
    } else {
      return _buildConsultationPendingBookingCard(pass, isDark);
    }
  }

  Widget _buildConsultationInProgressCard(ConsultationModel c, bool isDark) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        Navigator.pushNamed(
          context,
          AppRoutes.consultationDetail,
          arguments: {'consultation': c},
        ).then((_) => _loadCurrentPass());
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E12) : const Color(0xFFFFFBEB),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFFF59E0B).withOpacity(0.5),
            width: 1.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.hourglass_top_rounded, size: 12, color: Color(0xFFB45309)),
                      SizedBox(width: 4),
                      Text(
                        'SESSION IN PROGRESS',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFB45309)),
                      ),
                    ],
                  ),
                ),
                const Row(
                  children: [
                    Text(
                      'Details',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFB45309)),
                    ),
                    SizedBox(width: 2),
                    Icon(Icons.arrow_forward_ios, size: 10, color: Color(0xFFB45309)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: const Color(0xFFF59E0B).withOpacity(0.2),
                  backgroundImage: c.dietitianPhotoUrl != null ? NetworkImage(c.dietitianPhotoUrl!) : null,
                  child: c.dietitianPhotoUrl == null
                      ? const Icon(Icons.person, color: Color(0xFFB45309), size: 22)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Dr. ${c.dietitianName}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14.5,
                          color: isDark ? Colors.white : AppColors.slate900,
                        ),
                      ),
                      Text(
                        c.dietitianQualification ?? 'Clinical Nutrition Specialist',
                        style: const TextStyle(fontSize: 11, color: Color(0xFFB45309), fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Your video consultation session is currently active. Dr. ${c.dietitianName} is recording family vitals, allergies, and health goals to finalize your personalized plan.',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? AppColors.slate300 : const Color(0xFF78350F),
                height: 1.35,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  flex: 5,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD97706),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.videocam_rounded, size: 16),
                    label: const Text('Re-join Video Call', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                    onPressed: () {
                      Navigator.pushNamed(
                        context,
                        AppRoutes.consultationVideo,
                        arguments: {'consultation': c},
                      ).then((_) => _loadCurrentPass());
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 4,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: isDark ? Colors.white70 : AppColors.slate800,
                      side: BorderSide(color: isDark ? AppColors.slate700 : const Color(0xFFCBD5E1)),
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () {
                      Navigator.pushNamed(
                        context,
                        AppRoutes.consultationDetail,
                        arguments: {'consultation': c},
                      ).then((_) => _loadCurrentPass());
                    },
                    child: const Text('Consultation Details', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConsultationScheduledCard(ActiveHealthPassModel pass, ConsultationModel c, bool isDark) {
    final dateFormat = DateFormat('EEEE, dd MMM yyyy • hh:mm a');

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        Navigator.pushNamed(
          context,
          AppRoutes.consultationDetail,
          arguments: {'consultation': c},
        ).then((_) => _loadCurrentPass());
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF0FDF4),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? AppColors.primary.withOpacity(0.4) : const Color(0xFF86EFAC),
            width: 1.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.event_available_rounded, size: 12, color: Color(0xFF15803D)),
                      SizedBox(width: 4),
                      Text(
                        'APPOINTMENT CONFIRMED',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF15803D)),
                      ),
                    ],
                  ),
                ),
                const Row(
                  children: [
                    Text(
                      'Details',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF15803D)),
                    ),
                    SizedBox(width: 2),
                    Icon(Icons.arrow_forward_ios, size: 10, color: Color(0xFF15803D)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: AppColors.primary.withOpacity(0.15),
                  backgroundImage: c.dietitianPhotoUrl != null ? NetworkImage(c.dietitianPhotoUrl!) : null,
                  child: c.dietitianPhotoUrl == null
                      ? const Icon(Icons.person, color: AppColors.primary, size: 22)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Dr. ${c.dietitianName}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14.5,
                          color: isDark ? Colors.white : AppColors.slate900,
                        ),
                      ),
                      Text(
                        c.dietitianQualification ?? 'Clinical Nutritionist (RD)',
                        style: const TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isDark ? AppColors.slate800 : Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: isDark ? AppColors.slate700 : const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.access_time_rounded, size: 14, color: AppColors.primary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      dateFormat.format(c.scheduledAt),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : AppColors.slate800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Your appointment is scheduled. Your ${pass.durationMonths}-month subscription validity countdown commences immediately once this initial consultation is completed by your dietitian.',
              style: TextStyle(
                fontSize: 11.5,
                color: isDark ? AppColors.slate400 : AppColors.slate600,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  flex: 5,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.videocam_rounded, size: 16),
                    label: const Text('Join Video Call', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                    onPressed: () {
                      Navigator.pushNamed(
                        context,
                        AppRoutes.consultationVideo,
                        arguments: {'consultation': c},
                      ).then((_) => _loadCurrentPass());
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 4,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: isDark ? Colors.white70 : AppColors.slate800,
                      side: BorderSide(color: isDark ? AppColors.slate700 : const Color(0xFFCBD5E1)),
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () {
                      Navigator.pushNamed(
                        context,
                        AppRoutes.consultationDetail,
                        arguments: {'consultation': c},
                      ).then((_) => _loadCurrentPass());
                    },
                    child: const Text('Details / Change', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConsultationCompletedSection(ActiveHealthPassModel pass, ConsultationModel? completedConsult, bool isDark) {
    final dietitianName = completedConsult?.dietitianName ?? pass.assignedDietitian?.name ?? 'Dr. Ananya Sharma';
    final dietitianQual = completedConsult?.dietitianQualification ?? 'Clinical Nutritionist (RD)';
    final photoUrl = completedConsult?.dietitianPhotoUrl ?? pass.assignedDietitian?.photoUrl;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Kickoff Completed Banner (Tappable to view consultation details)
        InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: completedConsult != null
              ? () {
                  Navigator.pushNamed(
                    context,
                    AppRoutes.consultationDetail,
                    arguments: {'consultation': completedConsult},
                  ).then((_) => _loadCurrentPass());
                }
              : null,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF064E3B).withOpacity(0.3) : const Color(0xFFECFDF5),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF10B981).withOpacity(0.4)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: Color(0xFF10B981),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check, color: Colors.white, size: 14),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Consultation Completed • Pass Active',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Color(0xFF065F46)),
                            ),
                          ),
                          if (completedConsult != null) ...[
                            const Text('Details', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF047857))),
                            const SizedBox(width: 2),
                            const Icon(Icons.arrow_forward_ios, size: 10, color: Color(0xFF047857)),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Your subscription countdown is active (${pass.daysRemaining} days remaining). Personalized diet plan is ready.',
                        style: TextStyle(fontSize: 11, color: isDark ? AppColors.slate300 : const Color(0xFF047857), height: 1.3),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),

        // Assigned Clinical Dietitian Card (Module 5: Sections 50 & 56)
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? AppColors.slate900 : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isDark ? AppColors.slate800 : const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.2 : 0.03),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'MY ASSIGNED CLINICAL DIETITIAN',
                    style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppColors.slate500, letterSpacing: 0.5),
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
                    radius: 24,
                    backgroundColor: AppColors.primary.withOpacity(0.12),
                    backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
                    child: photoUrl == null
                        ? const Icon(Icons.person, color: AppColors.primary, size: 24)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Dr. $dietitianName',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14.5,
                            color: isDark ? Colors.white : AppColors.slate900,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          dietitianQual,
                          style: const TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w500),
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
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.restaurant_menu_rounded, size: 15),
                      label: const Text('View Diet Plan', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      onPressed: () => Navigator.pushNamed(context, AppRoutes.dietPlan),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: isDark ? Colors.white70 : AppColors.slate800,
                        side: BorderSide(color: isDark ? AppColors.slate700 : const Color(0xFFCBD5E1)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.video_call_rounded, size: 15, color: AppColors.primary),
                      label: const Text('Book Session', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      onPressed: () => Navigator.pushNamed(context, AppRoutes.consultationBook).then((_) => _loadCurrentPass()),
                    ),
                  ),
                ],
              ),
              if (completedConsult != null) ...[
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: TextButton.icon(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      visualDensity: VisualDensity.compact,
                    ),
                    icon: const Icon(Icons.receipt_long_rounded, size: 14, color: AppColors.primary),
                    label: const Text(
                      'View Kickoff Consultation Notes & Summary',
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppColors.primary),
                    ),
                    onPressed: () {
                      Navigator.pushNamed(
                        context,
                        AppRoutes.consultationDetail,
                        arguments: {'consultation': completedConsult},
                      ).then((_) => _loadCurrentPass());
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildConsultationPendingBookingCard(ActiveHealthPassModel pass, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [AppColors.slate800, AppColors.slate800.withOpacity(0.85)]
              : [AppColors.primarySubtle, Colors.white],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.primary.withOpacity(0.3) : AppColors.primaryLight.withOpacity(0.6),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.video_call_rounded, color: AppColors.primary, size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Step 1: Complete Initial Consultation',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : AppColors.slate900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Your validity begins upon consultation completion',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            pass.validityNote ??
                'Your ${pass.durationMonths}-month plan countdown commences immediately once this initial dietitian consultation is completed. Schedule your 1-on-1 video call below to commence!',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? AppColors.slate300 : AppColors.slate700,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.calendar_today_rounded, size: 16),
              label: const Text('Schedule First Consultation', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              onPressed: () {
                Navigator.pushNamed(context, AppRoutes.consultationBook).then((_) => _loadCurrentPass());
              },
            ),
          ),
        ],
      ),
    );
  }
}
