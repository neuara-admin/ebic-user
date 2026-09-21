import 'package:flutter/material.dart';
import '../../core/analytics/analytics_service.dart';
import '../../core/routing/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/models/health_pass_model.dart';
import '../../shared/widgets/ebic_button.dart';
import '../../shared/widgets/ebic_card.dart';
import 'data/health_pass_repository.dart';

/// Module 4 — Section 34: Health Pass Plans Screen
/// Strictly displays authoritatively configured active plans from the backend catalog.
class HealthPassPlansScreen extends StatefulWidget {
  const HealthPassPlansScreen({super.key});

  @override
  State<HealthPassPlansScreen> createState() => _HealthPassPlansScreenState();
}

class _HealthPassPlansScreenState extends State<HealthPassPlansScreen> {
  final HealthPassRepository _repository = HealthPassRepository();

  List<HealthPassPlanModel> _plans = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchPlans();
  }

  Future<void> _fetchPlans() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final plans = await _repository.fetchPlans();
      if (mounted) {
        setState(() {
          _plans = plans;
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
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        titleSpacing: 16,
        title: const FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            'Choose Your Health Pass',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.compare_arrows_rounded),
            tooltip: 'Compare Plans',
            onPressed: () => Navigator.pushNamed(context, AppRoutes.healthPassComparison),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 48, color: AppColors.danger),
                        const SizedBox(height: 12),
                        Text(_errorMessage!, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        EbicButton(
                label: 'Retry', onPressed: _fetchPlans),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _fetchPlans,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Subtitle & Comparison CTA
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.slate900 : AppColors.primarySubtle.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: isDark ? AppColors.slate800 : AppColors.primarySubtle),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.verified_user_rounded, color: AppColors.primary, size: 22),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Choose a plan that fits your lifestyle. Enjoy personal dietitian guidance, custom meal plans, and in-home chef visits.',
                                  style: TextStyle(fontSize: 12, color: isDark ? AppColors.slate300 : AppColors.primaryDark, height: 1.3),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Section 34: Authoritative Plan Cards
                        ..._plans.map((plan) => _buildPlanCard(plan, isDark)),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildPlanCard(HealthPassPlanModel plan, bool isDark) {
    final isRecommended = plan.code == 'CARE_V1';

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: EbicCard(
        border: isRecommended
            ? Border.all(color: AppColors.primary, width: 2)
            : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (plan.imageUrl != null || plan.images.isNotEmpty) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  children: [
                    Image.network(
                      plan.imageUrl ?? plan.images.first.url,
                      height: 140,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    ),
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.transparent, Colors.black.withOpacity(0.55)],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],

            if (isRecommended) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'MOST POPULAR • BEST FOR FAMILIES',
                  style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                ),
              ),
              const SizedBox(height: 12),
            ],

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        plan.displayName,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: isDark ? Colors.white : AppColors.slate900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        plan.shortDescription,
                        style: const TextStyle(fontSize: 12, color: AppColors.slate500, height: 1.3),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '₹${plan.basePrice.toInt()}',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: AppColors.primary,
                      ),
                    ),
                    const Text('/ month', style: TextStyle(fontSize: 10.5, color: AppColors.slate500, fontWeight: FontWeight.w500)),
                  ],
                ),
              ],
            ),
            const Divider(height: 24),

            // Supported Durations Badges (Section 36)
            if (plan.durations.isNotEmpty) ...[
              const Text(
                'CHOOSE DURATION',
                style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppColors.slate500, letterSpacing: 0.5),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: plan.durations.map((d) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.slate800 : AppColors.slate100,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      d.discountPercent > 0 ? '${d.label} (-${d.discountPercent.toInt()}%)' : d.label,
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isDark ? AppColors.slate300 : AppColors.slate700),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
            ],

            // Key Benefits Checklist (Section 34)
            const Text(
              'WHAT\'S INCLUDED',
              style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppColors.slate500, letterSpacing: 0.5),
            ),
            const SizedBox(height: 8),
            ...plan.benefits.take(5).map((b) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.check_circle, size: 16, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          b.name,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark ? AppColors.slate200 : AppColors.slate800,
                          ),
                        ),
                      ),
                    ],
                  ),
                )),

            const SizedBox(height: 16),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () {
                      Navigator.pushNamed(
                        context,
                        AppRoutes.healthPassBenefits,
                        arguments: {
                          'planCode': plan.code,
                          'planName': plan.displayName,
                          'plan': plan,
                        },
                      );
                    },
                    child: const Text('View Benefits', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: EbicButton(
                    label: 'Choose Plan',
                    onPressed: () {
                      AnalyticsService().logHealthPassPlanViewed(plan.code);
                      Navigator.pushNamed(
                        context,
                        AppRoutes.healthPassConfigure,
                        arguments: {'planCode': plan.code, 'planName': plan.name},
                      );
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
