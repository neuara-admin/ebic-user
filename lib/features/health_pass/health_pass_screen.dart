import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

/// Clean, high-performance Health Pass Screen
/// Minimalist UX: removes excessive marketing fluff and puts live entitlements & consultation details front and center.
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
      backgroundColor: isDark ? AppColors.slate950 : AppColors.slate50,
      appBar: AppBar(
        title: const Text('Health Pass', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: isDark ? AppColors.slate900 : Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded),
            tooltip: 'Pass History',
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
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                        ? _buildNoPassView(isDark)
                        : _buildActivePassView(_activePass!, isDark),
              ),
            ),
    );
  }

  // ───────────────────────── 1. No Active Health Pass View ─────────────────────────
  Widget _buildNoPassView(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(22),
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
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'HEALTH & NUTRITION ECOSYSTEM',
                  style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.6),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Personalized Nutrition\n& In-Home Chefs',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white, height: 1.2),
              ),
              const SizedBox(height: 8),
              const Text(
                'Unlock dedicated clinical dietitians, custom meal charts, and monthly in-home chef visit entitlements.',
                style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 18),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.primaryDark,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.stars_rounded, color: AppColors.primary, size: 18),
                label: const Text('Explore Health Pass Plans', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                onPressed: () => Navigator.pushNamed(context, AppRoutes.healthPassPlans),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Clean feature highlights (short & concise)
        EbicCard(
          child: Column(
            children: [
              _buildFeatureRow(Icons.restaurant_menu_rounded, 'In-Home Chef Visits', 'Monthly visit entitlements for custom cooking'),
              const Divider(height: 20),
              _buildFeatureRow(Icons.video_call_rounded, 'Clinical Dietitian Consultations', '1-on-1 video coaching & health reviews'),
              const Divider(height: 20),
              _buildFeatureRow(Icons.family_restroom_rounded, 'Full Family Coverage', 'Individual health metrics for all household members'),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Comparison quick banner
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
                    Text('Compare Health Pass Tiers', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    Text('View side-by-side allowances and pricing', style: TextStyle(color: AppColors.slate500, fontSize: 11)),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 13, color: AppColors.slate400),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFeatureRow(IconData icon, String title, String desc) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primarySubtle,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppColors.primary, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              Text(desc, style: const TextStyle(color: AppColors.slate500, fontSize: 11)),
            ],
          ),
        ),
      ],
    );
  }

  // ───────────────────────── 2. Active Health Pass View ─────────────────────────
  Widget _buildActivePassView(ActiveHealthPassModel pass, bool isDark) {
    final activeConsult = _activeConsultation ?? pass.activeConsultation;
    final completedConsult = _completedConsultation ?? pass.latestCompletedConsultation;
    final isCompleted = completedConsult != null || !pass.isConsultationPending;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Sleek VIP Pass Card
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
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.shield_rounded, color: Colors.white, size: 14),
                        ),
                        const SizedBox(width: 8),
                        const Flexible(
                          child: Text(
                            'EBIC HEALTH PASS',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white70, letterSpacing: 0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      pass.isExpired
                          ? 'EXPIRED'
                          : isCompleted
                              ? '${pass.daysRemaining} DAYS LEFT'
                              : 'KICKOFF PENDING',
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                pass.displayName,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white),
              ),
              const SizedBox(height: 2),
              Text(
                '${pass.durationMonths} Months Plan • ${pass.coveredMembers.length} Family Members Covered',
                style: const TextStyle(fontSize: 12, color: Colors.white70),
              ),
              const SizedBox(height: 16),
              Container(height: 1, color: Colors.white.withOpacity(0.15)),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      'REF #${pass.id.length > 8 ? pass.id.substring(pass.id.length - 8).toUpperCase() : pass.id.toUpperCase()}',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white70, fontFamily: 'monospace'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () {
                      Navigator.pushNamed(context, AppRoutes.healthPassUsage, arguments: {'healthPassId': pass.id});
                    },
                    child: const Text('View Ledger →', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // 3-Column Pass Term & Key Dates (Booked Date, Start Date, End Date)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('BOOKED DATE', style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: Colors.white60, letterSpacing: 0.5)),
                          const SizedBox(height: 2),
                          Text(
                            DateFormat('dd MMM yyyy').format(pass.bookedDate ?? pass.startDate ?? DateTime.now()),
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                    Container(width: 1, height: 24, color: Colors.white24),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const Text('START DATE', style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: Colors.white60, letterSpacing: 0.5)),
                            const SizedBox(height: 2),
                            Text(
                              pass.startDate != null ? DateFormat('dd MMM yyyy').format(pass.startDate!) : 'Upon Kickoff',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Container(width: 1, height: 24, color: Colors.white24),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text('END DATE', style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: Colors.white60, letterSpacing: 0.5)),
                          const SizedBox(height: 2),
                          Text(
                            pass.endDate != null ? DateFormat('dd MMM yyyy').format(pass.endDate!) : '+${pass.durationMonths} Mos',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // 2. Usage History & Entitlement Activity Card
        EbicCard(
          onTap: () {
            Navigator.pushNamed(context, AppRoutes.healthPassUsage, arguments: {'healthPassId': pass.id});
          },
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primarySubtle,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.history_edu_rounded, color: AppColors.primary, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Usage History & Entitlement Activity', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 2),
                    Text(
                      '${pass.chefVisitsUsed} of ${pass.chefVisitsAllocated} Chef Visits • ${pass.consultationsUsed} of ${pass.consultationsAllocated} Consultations Used',
                      style: const TextStyle(fontSize: 11, color: AppColors.slate500),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 12, color: AppColors.slate400),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // 3. Completed Consultation & Dietitian Contact Section (PRIORITY #1 if completed)
        if (isCompleted) ...[
          _buildCompletedConsultationCard(pass, completedConsult, isDark),
          const SizedBox(height: 14),
        ] else if (activeConsult != null) ...[
          _buildActiveConsultationBanner(activeConsult, isDark),
          const SizedBox(height: 14),
        ] else ...[
          _buildPendingConsultationBanner(pass, isDark),
          const SizedBox(height: 14),
        ],

        // 4. Entitlement Allowances (Clean, visual, compact)
        EbicCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'PASS ALLOWANCES',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.slate500, letterSpacing: 0.5),
              ),
              const SizedBox(height: 12),
              _buildSimpleProgress(
                title: 'In-Home Chef Visits',
                used: pass.chefVisitsUsed,
                total: pass.chefVisitsAllocated,
                remaining: pass.chefVisitsRemaining,
                isDark: isDark,
              ),
              const SizedBox(height: 14),
              _buildSimpleProgress(
                title: 'Dietitian Consultations',
                used: pass.consultationsUsed,
                total: pass.consultationsAllocated,
                remaining: pass.consultationsRemaining,
                isDark: isDark,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // 5. Covered Household Members (Clean horizontal chips)
        if (pass.coveredMembers.isNotEmpty) ...[
          EbicCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'COVERED HOUSEHOLD MEMBERS',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.slate500, letterSpacing: 0.5),
                    ),
                    Text(
                      '${pass.coveredMembers.length} Members',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: pass.coveredMembers.map((m) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.slate800 : AppColors.slate100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(m.isPrimary ? Icons.star_rounded : Icons.person_outline, size: 14, color: AppColors.primary),
                          const SizedBox(width: 6),
                          Text(
                            '${m.name} (${m.relationship})',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],

        // 6. Quick Action Grid
        Row(
          children: [
            Expanded(
              child: EbicButton(
                label: 'Book Chef Visit',
                icon: Icons.soup_kitchen_rounded,
                onPressed: () => Navigator.pushNamed(context, AppRoutes.bookChef),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: EbicButton(
                label: 'Book Video Call',
                icon: Icons.video_call_rounded,
                variant: EbicButtonVariant.outline,
                onPressed: () => Navigator.pushNamed(context, AppRoutes.consultationBook).then((_) => _loadCurrentPass()),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
      ],
    );
  }

  // ───────────────────────── Completed Consultation & Dietitian Card ─────────────────────────
  Widget _buildCompletedConsultationCard(ActiveHealthPassModel pass, ConsultationModel? c, bool isDark) {
    final dietitianName = c?.dietitianName ?? pass.assignedDietitian?.name ?? 'Dr. Ananya Sharma';
    final dietitianQual = c?.dietitianQualification ?? pass.assignedDietitian?.specializations.join(' • ') ?? 'Senior Clinical Nutritionist (RD)';
    final photoUrl = c?.dietitianPhotoUrl ?? pass.assignedDietitian?.photoUrl;
    final consultDate = c?.scheduledAt != null ? DateFormat('dd MMM yyyy').format(c!.scheduledAt) : 'Recent';
    final startTimeStr = c?.scheduledAt != null ? DateFormat('hh:mm a').format(c!.scheduledAt) : '10:00 AM';
    final endTimeStr = c?.endsAt != null
        ? DateFormat('hh:mm a').format(c!.endsAt!)
        : (c?.scheduledAt != null ? DateFormat('hh:mm a').format(c!.scheduledAt.add(const Duration(minutes: 45))) : '10:45 AM');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF06281E) : const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF10B981).withOpacity(0.4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Status Badge & Date
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle_rounded, color: Color(0xFF15803D), size: 12),
                    SizedBox(width: 4),
                    Text(
                      'COMPLETED',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF15803D)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  consultDate,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, color: AppColors.slate500, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Dietitian Info Row
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: AppColors.primarySubtle,
                backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
                child: photoUrl == null ? const Icon(Icons.person, color: AppColors.primary, size: 24) : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Dr. $dietitianName',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : AppColors.slate900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      dietitianQual,
                      style: const TextStyle(fontSize: 11, color: AppColors.primaryDark, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Consultation Start & End Time Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isDark ? AppColors.slate900 : Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: isDark ? AppColors.slate800 : const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                const Icon(Icons.schedule_rounded, size: 14, color: AppColors.primary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Session Time: $startTimeStr – $endTimeStr',
                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: isDark ? Colors.white : AppColors.slate800),
                  ),
                ),
              ],
            ),
          ),

          // Doctor's Clinical Notes & Recommendations (Concise summary)
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isDark ? AppColors.slate900 : Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: isDark ? AppColors.slate800 : const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'DOCTOR\'S CLINICAL NOTES & GOALS',
                  style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: AppColors.slate500, letterSpacing: 0.5),
                ),
                const SizedBox(height: 4),
                Text(
                  c?.notes ?? c?.recommendations ?? c?.goals ?? c?.summary ?? 'Prescribed personalized family diet plan tailored to clinical profile.',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11.5, color: isDark ? AppColors.slate300 : AppColors.slate800, height: 1.3),
                ),
              ],
            ),
          ),

          // Attached Clinical Documents
          const SizedBox(height: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'ATTACHED CLINICAL DOCUMENTS',
                style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: AppColors.slate500, letterSpacing: 0.5),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  _buildDocumentChip('Prescribed Diet Chart (PDF)', Icons.picture_as_pdf_rounded, isDark),
                  _buildDocumentChip('Clinical Health Assessment', Icons.description_outlined, isDark),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Primary Actions: View Diet Plan, Book Session, Contact Dietitian
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF047857),
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
                    foregroundColor: isDark ? Colors.white : AppColors.slate800,
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
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: TextButton.icon(
                  icon: const Icon(Icons.phone_in_talk_rounded, size: 14, color: AppColors.primary),
                  label: const Text('Contact Dietitian', style: TextStyle(fontSize: 11.5, color: AppColors.primary, fontWeight: FontWeight.bold)),
                  onPressed: () => _showContactDietitianSheet(dietitianName),
                ),
              ),
              if (c != null) ...[
                Container(width: 1, height: 16, color: AppColors.slate300),
                Expanded(
                  child: TextButton(
                    onPressed: () {
                      Navigator.pushNamed(
                        context,
                        AppRoutes.consultationDetail,
                        arguments: {'consultation': c},
                      ).then((_) => _loadCurrentPass());
                    },
                    child: const Text('Full Details', style: TextStyle(fontSize: 11.5, color: AppColors.primary, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentChip(String title, IconData icon, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isDark ? AppColors.slate800 : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isDark ? AppColors.slate700 : const Color(0xFFCBD5E1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppColors.primary),
          const SizedBox(width: 6),
          Text(title, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isDark ? Colors.white : AppColors.slate800)),
        ],
      ),
    );
  }

  // Contact Dietitian Modal Bottom Sheet
  void _showContactDietitianSheet(String dietitianName) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Contact Dr. $dietitianName', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                const SizedBox(height: 6),
                const Text('Choose how you would like to connect with your dietitian:', style: TextStyle(color: AppColors.slate500, fontSize: 12)),
                const SizedBox(height: 16),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.phone_rounded, color: Color(0xFF15803D)),
                  ),
                  title: const Text('Call Clinical Nutrition Desk', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: const Text('+91 80 4719 3200 (Toll-Free Priority Care)', style: TextStyle(fontSize: 11)),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                  onTap: () {
                    Clipboard.setData(const ClipboardData(text: '+918047193200'));
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Support line +91 80 4719 3200 copied to clipboard!')),
                    );
                  },
                ),
                const Divider(),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: AppColors.primarySubtle, borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.video_call_rounded, color: AppColors.primary),
                  ),
                  title: const Text('Schedule Follow-Up Video Call', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: const Text('Book your next scheduled check-in', style: TextStyle(fontSize: 11)),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                  onTap: () {
                    Navigator.pop(ctx);
                    Navigator.pushNamed(context, AppRoutes.consultationBook).then((_) => _loadCurrentPass());
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Active / Scheduled Consultation Banner
  Widget _buildActiveConsultationBanner(ConsultationModel c, bool isDark) {
    final isSessionActive = c.status == 'IN_PROGRESS';
    final dateStr = DateFormat('dd MMM, hh:mm a').format(c.scheduledAt);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isSessionActive ? const Color(0xFFFFFBEB) : const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isSessionActive ? const Color(0xFFF59E0B) : const Color(0xFF3B82F6),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isSessionActive ? Icons.hourglass_top_rounded : Icons.event_available_rounded,
            color: isSessionActive ? const Color(0xFFB45309) : const Color(0xFF1D4ED8),
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isSessionActive ? 'Video Consultation Active' : 'Consultation Scheduled',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: isSessionActive ? const Color(0xFF92400E) : const Color(0xFF1E40AF),
                  ),
                ),
                Text(
                  isSessionActive ? 'Dr. ${c.dietitianName} is in call' : '$dateStr with Dr. ${c.dietitianName}',
                  style: TextStyle(
                    fontSize: 11,
                    color: isSessionActive ? const Color(0xFFB45309) : const Color(0xFF2563EB),
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isSessionActive ? const Color(0xFFD97706) : AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(isSessionActive ? 'Join' : 'Details', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            onPressed: () {
              if (isSessionActive) {
                Navigator.pushNamed(context, AppRoutes.consultationVideo, arguments: {'consultation': c}).then((_) => _loadCurrentPass());
              } else {
                Navigator.pushNamed(context, AppRoutes.consultationDetail, arguments: {'consultation': c}).then((_) => _loadCurrentPass());
              }
            },
          ),
        ],
      ),
    );
  }

  // Pending First Consultation Booking Banner
  Widget _buildPendingConsultationBanner(ActiveHealthPassModel pass, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.slate900 : AppColors.primarySubtle,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.video_call_outlined, color: AppColors.primary, size: 24),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Initial Consultation Pending', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                Text('Schedule your 1-on-1 video call to start plan', style: TextStyle(color: AppColors.slate500, fontSize: 11)),
              ],
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Schedule', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            onPressed: () => Navigator.pushNamed(context, AppRoutes.consultationBook).then((_) => _loadCurrentPass()),
          ),
        ],
      ),
    );
  }

  Widget _buildSimpleProgress({
    required String title,
    required int used,
    required int total,
    required int remaining,
    required bool isDark,
  }) {
    final progress = total > 0 ? (used / total).clamp(0.0, 1.0) : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '$used/$total Used ($remaining left)',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: remaining > 0 ? AppColors.primary : AppColors.warning,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 6,
            backgroundColor: isDark ? AppColors.slate800 : AppColors.slate200,
            valueColor: AlwaysStoppedAnimation<Color>(remaining > 0 ? AppColors.primary : AppColors.warning),
          ),
        ),
      ],
    );
  }
}
