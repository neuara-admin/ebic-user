import 'package:flutter/material.dart';
import '../../core/analytics/analytics_service.dart';
import '../../core/routing/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/models/health_pass_model.dart';
import '../../shared/widgets/ebic_button.dart';
import '../../shared/widgets/ebic_card.dart';
import 'data/health_pass_repository.dart';

/// Module 4 — Section 35: Health Pass Plan Comparison Screen
/// Generates benefit comparison matrix authoritatively from backend configuration.
class HealthPassComparisonScreen extends StatefulWidget {
  const HealthPassComparisonScreen({super.key});

  @override
  State<HealthPassComparisonScreen> createState() => _HealthPassComparisonScreenState();
}

class _HealthPassComparisonScreenState extends State<HealthPassComparisonScreen> {
  final HealthPassRepository _repository = HealthPassRepository();
  HealthPassComparisonModel? _comparison;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    AnalyticsService().logHealthPassComparisonViewed();
    _loadComparison();
  }

  Future<void> _loadComparison() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final data = await _repository.fetchComparison();
      if (mounted) {
        setState(() {
          _comparison = data;
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
        title: const Text('Compare Health Passes'),
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
                label: 'Retry', onPressed: _loadComparison),
                      ],
                    ),
                  ),
                )
              : _buildComparisonMatrix(isDark),
    );
  }

  Widget _buildComparisonMatrix(bool isDark) {
    final comparison = _comparison!;
    final plans = comparison.plans;
    final matrix = comparison.matrix;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section 35 Intro Banner
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? AppColors.slate900 : AppColors.primarySubtle.withOpacity(0.5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isDark ? AppColors.slate800 : AppColors.primarySubtle),
            ),
            child: Row(
              children: [
                Icon(Icons.compare_arrows_rounded, color: isDark ? AppColors.primaryLight : AppColors.primary, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Compare features and allowances across EBIC Health Pass plans. All benefits are backend-configured.',
                    style: TextStyle(fontSize: 12, color: isDark ? AppColors.slate200 : AppColors.primaryDark, height: 1.3),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Plan Headers Cards
          Row(
            children: [
              const Expanded(
                flex: 2,
                child: Text(
                  'BENEFITS & PRIVILEGES',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.slate500, letterSpacing: 0.5),
                ),
              ),
              ...plans.map((p) => Expanded(
                    flex: 3,
                    child: Container(
                      margin: const EdgeInsets.only(left: 6),
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                      decoration: BoxDecoration(
                        color: p.code == 'CARE_V1'
                            ? (isDark ? AppColors.emerald700.withOpacity(0.2) : AppColors.emerald50)
                            : (isDark ? AppColors.slate900 : AppColors.slate100),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: p.code == 'CARE_V1' ? AppColors.primary : (isDark ? AppColors.slate800 : AppColors.slate200),
                          width: p.code == 'CARE_V1' ? 1.5 : 1,
                        ),
                      ),
                      child: Column(
                        children: [
                          if (p.code == 'CARE_V1')
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              margin: const EdgeInsets.only(bottom: 4),
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text('RECOMMENDED', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
                            ),
                          Text(
                            p.name,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: isDark ? Colors.white : AppColors.slate900,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '₹${p.basePrice.toInt()}/mo',
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppColors.primary),
                          ),
                          const SizedBox(height: 8),
                          InkWell(
                            onTap: () {
                              Navigator.pushNamed(
                                context,
                                AppRoutes.healthPassConfigure,
                                arguments: {'planCode': p.code, 'planName': p.name},
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                              decoration: BoxDecoration(
                                color: p.code == 'CARE_V1' ? AppColors.primary : AppColors.slate800,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text('Select', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )),
            ],
          ),
          const SizedBox(height: 16),

          // Comparison Matrix Rows
          ...matrix.map((row) {
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
              decoration: BoxDecoration(
                color: isDark ? AppColors.slate900 : Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: isDark ? AppColors.slate800 : AppColors.slate200),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          row.name,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : AppColors.slate900,
                          ),
                        ),
                        if (row.description.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            row.description,
                            style: const TextStyle(fontSize: 10, color: AppColors.slate500),
                          ),
                        ],
                      ],
                    ),
                  ),
                  ...plans.map((p) {
                    final avail = row.availability[p.code];
                    final included = avail?.included ?? false;
                    final label = avail?.label ?? '—';

                    return Expanded(
                      flex: 3,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (included) ...[
                              const Icon(Icons.check_circle, size: 18, color: AppColors.primary),
                              const SizedBox(height: 2),
                              Text(
                                label,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? AppColors.slate300 : AppColors.slate700,
                                ),
                              ),
                            ] else ...[
                              const Text('—', style: TextStyle(fontSize: 16, color: AppColors.slate400)),
                            ],
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),
            );
          }),

          const SizedBox(height: 24),
          EbicCard(
            child: Row(
              children: [
                const Icon(Icons.info_outline, size: 18, color: AppColors.slate400),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Entitlements reset on your monthly anniversary date. All pricing is determined authoritatively by the backend pricing engine.',
                    style: TextStyle(fontSize: 11, color: isDark ? AppColors.slate400 : AppColors.slate500, height: 1.3),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
