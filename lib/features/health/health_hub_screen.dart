import 'package:flutter/material.dart';
import '../../core/routing/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/ebic_card.dart';
import '../../shared/widgets/ebic_button.dart';
import '../../shared/widgets/ebic_outlined_button.dart';
import '../../shared/widgets/member_switcher_widget.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';

/// Section 31 & 35: Health Hub Screen
/// Designed as a cohesive health dashboard rather than a list of disconnected features.
class HealthHubScreen extends StatefulWidget {
  const HealthHubScreen({super.key});

  @override
  State<HealthHubScreen> createState() => _HealthHubScreenState();
}

class _HealthHubScreenState extends State<HealthHubScreen> {
  final ApiClient _api = ApiClient();
  Map<String, dynamic>? _healthSnapshot;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadHealthData();
  }

  Future<void> _loadHealthData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await _api.get<Map<String, dynamic>>(ApiEndpoints.home);
      if (res.success && res.data != null) {
        if (mounted) {
          setState(() {
            _healthSnapshot = res.data!['health_snapshot'] as Map<String, dynamic>?;
            _isLoading = false;
            _errorMessage = null;
          });
        }
        return;
      } else {
        if (mounted) {
          setState(() {
            _errorMessage = res.error?.message ?? 'Unable to fetch health snapshot';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Network connection interrupted. Please try again.';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final weightVal = _healthSnapshot?['weight'];
    final waterVal = _healthSnapshot?['water'];
    final stepsVal = _healthSnapshot?['steps'];
    final sleepVal = _healthSnapshot?['sleep'];

    final weightDisplay = weightVal != null ? '$weightVal kg' : '—';
    final weightSub = weightVal != null ? 'Synced vital' : 'Tap to record';

    final waterDisplay = waterVal != null ? '$waterVal L' : '—';
    final waterSub = waterVal != null ? 'Daily intake' : 'Tap to log';

    final stepsDisplay = stepsVal != null && stepsVal > 0 ? '$stepsVal' : '—';
    final stepsSub = stepsVal != null && stepsVal > 0 ? 'Steps taken' : 'Sync wearable';

    final sleepDisplay = sleepVal != null ? '$sleepVal' : '—';
    final sleepSub = sleepVal != null ? 'Rest recorded' : 'Tap to log';

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppColors.slate900 : Colors.white;
    final cardBorder = isDark ? AppColors.slate800 : AppColors.slate200;
    final textPrimary = isDark ? Colors.white : AppColors.slate900;
    final textSecondary = isDark ? AppColors.slate300 : AppColors.slate700;
    final textMuted = isDark ? AppColors.slate400 : AppColors.slate500;

    return Scaffold(
      backgroundColor: isDark ? AppColors.slate950 : AppColors.slate50,
      appBar: AppBar(
        title: Text('Health Dashboard', style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold)),
        backgroundColor: isDark ? AppColors.slate900 : Colors.white,
        foregroundColor: textPrimary,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.shield_outlined, color: isDark ? AppColors.primaryLight : AppColors.primary),
            tooltip: 'Privacy & Consent',
            onPressed: () => Navigator.pushNamed(context, AppRoutes.privacy),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadHealthData,
          color: AppColors.primary,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Member Selector Bar (Section 18 & 35)
                const MemberSwitcherBar(),
                const SizedBox(height: 16),

                // Offline / Server Unreachable Banner
                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.danger.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.danger.withOpacity(0.2)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.wifi_off_rounded, color: AppColors.danger, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(fontSize: 12, color: AppColors.danger),
                          ),
                        ),
                        TextButton(
                          onPressed: _loadHealthData,
                          child: const Text('Retry', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Today's Overview (Section 35: Weight, Water, Activity, Sleep)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Today's Overview",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: textPrimary,
                      ),
                    ),
                    if (_isLoading)
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildMetricTile(
                        icon: Icons.monitor_weight_outlined,
                        color: AppColors.primary,
                        title: 'Weight',
                        value: weightDisplay,
                        subtitle: weightSub,
                        onTap: () => Navigator.pushNamed(context, AppRoutes.healthMetrics).then((_) => _loadHealthData()),
                        isDark: isDark,
                        cardBg: cardBg,
                        cardBorder: cardBorder,
                        textPrimary: textPrimary,
                        textSecondary: textSecondary,
                        textMuted: textMuted,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildMetricTile(
                        icon: Icons.water_drop_outlined,
                        color: Colors.blue,
                        title: 'Hydration',
                        value: waterDisplay,
                        subtitle: waterSub,
                        onTap: () => Navigator.pushNamed(context, AppRoutes.healthMetrics).then((_) => _loadHealthData()),
                        isDark: isDark,
                        cardBg: cardBg,
                        cardBorder: cardBorder,
                        textPrimary: textPrimary,
                        textSecondary: textSecondary,
                        textMuted: textMuted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildMetricTile(
                        icon: Icons.directions_walk_rounded,
                        color: AppColors.accent,
                        title: 'Activity',
                        value: stepsDisplay,
                        subtitle: stepsSub,
                        onTap: () => Navigator.pushNamed(context, AppRoutes.healthMetrics).then((_) => _loadHealthData()),
                        isDark: isDark,
                        cardBg: cardBg,
                        cardBorder: cardBorder,
                        textPrimary: textPrimary,
                        textSecondary: textSecondary,
                        textMuted: textMuted,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildMetricTile(
                        icon: Icons.bedtime_outlined,
                        color: Colors.purple,
                        title: 'Sleep',
                        value: sleepDisplay,
                        subtitle: sleepSub,
                        onTap: () => Navigator.pushNamed(context, AppRoutes.healthMetrics).then((_) => _loadHealthData()),
                        isDark: isDark,
                        cardBg: cardBg,
                        cardBorder: cardBorder,
                        textPrimary: textPrimary,
                        textSecondary: textSecondary,
                        textMuted: textMuted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

              // Diet Plan Card (Section 35)
              EbicCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.primary.withOpacity(0.2) : AppColors.primarySubtle,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.restaurant_menu_rounded, color: isDark ? AppColors.primaryLight : AppColors.primary, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Diet Plan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: textPrimary)),
                              const SizedBox(height: 2),
                              Text('Clinical nutrition planned around your goals', style: TextStyle(color: textSecondary, fontSize: 12)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: EBICOutlinedButton(
                        label: "View Today's Plan",
                        icon: Icons.calendar_today_rounded,
                        onPressed: () => Navigator.pushNamed(context, AppRoutes.dietPlan),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Health Progress Card (Section 35)
              EbicCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.emerald700.withOpacity(0.25) : AppColors.emerald50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.insights_rounded, color: isDark ? AppColors.emerald400 : AppColors.emerald700, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Health Progress & Timeline', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: textPrimary)),
                              const SizedBox(height: 2),
                              Text('30-day vitals, adherence & nutritional outcomes', style: TextStyle(color: textSecondary, fontSize: 12)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: EBICOutlinedButton(
                        label: 'View Progress',
                        icon: Icons.trending_up_rounded,
                        onPressed: () => Navigator.pushNamed(context, AppRoutes.healthProgress),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Health Profile Card (Section 35 & 44)
              EbicCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.slate800 : AppColors.slate100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.assignment_ind_outlined, color: isDark ? AppColors.slate300 : AppColors.slate700, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Health Profile', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: textPrimary)),
                              const SizedBox(height: 2),
                              Text('Allergies, dietary preferences & clinical vitals', style: TextStyle(color: textSecondary, fontSize: 12)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: EBICOutlinedButton(
                        label: 'View Profile',
                        icon: Icons.person_outline,
                        onPressed: () => Navigator.pushNamed(context, AppRoutes.healthProfile),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Diagnostic Documents Vault (Section 35 & 45)
              EbicCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF78350F).withOpacity(0.35) : const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.folder_shared_outlined, color: isDark ? const Color(0xFFFCD34D) : const Color(0xFFB45309), size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Health Documents', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: textPrimary)),
                              const SizedBox(height: 2),
                              Text('Lab reports, prescriptions & dietitian evaluations', style: TextStyle(color: textSecondary, fontSize: 12)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: EBICOutlinedButton(
                        label: 'View Documents',
                        icon: Icons.upload_file_rounded,
                        onPressed: () => Navigator.pushNamed(context, AppRoutes.healthDocuments),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Dietitian Consultations (Section 35 & 46)
              EbicCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.primary.withOpacity(0.2) : AppColors.primarySubtle,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.video_call_outlined, color: isDark ? AppColors.primaryLight : AppColors.primaryDark, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Consultations', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: textPrimary)),
                              const SizedBox(height: 2),
                              Text('Video sessions with assigned clinical dietitians', style: TextStyle(color: textSecondary, fontSize: 12)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: EBICOutlinedButton(
                        label: 'View Consultations',
                        icon: Icons.event_available_rounded,
                        onPressed: () => Navigator.pushNamed(context, AppRoutes.consultationsList),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Talk to Dietitian CTA (Section 31 & 35)
              SizedBox(
                width: double.infinity,
                child: EbicButton(
                  label: 'Talk to Dietitian',
                  icon: Icons.chat_bubble_outline_rounded,
                  onPressed: () => Navigator.pushNamed(context, AppRoutes.dietitian),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    ),
  );
}

  Widget _buildMetricTile({
    required IconData icon,
    required Color color,
    required String title,
    required String value,
    required String subtitle,
    required VoidCallback onTap,
    required bool isDark,
    required Color cardBg,
    required Color cardBorder,
    required Color textPrimary,
    required Color textSecondary,
    required Color textMuted,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cardBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.2 : 0.02),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: isDark ? color.withOpacity(0.9) : color, size: 18),
                const SizedBox(width: 6),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 11,
                color: textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
