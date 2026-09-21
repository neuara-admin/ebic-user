import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/datasources/health_remote_datasource.dart';
import '../../data/models/health_metric_entry_model.dart';
import '../widgets/provenance_badge.dart';
import 'health_metric_entry_screen.dart';
import 'health_metric_history_screen.dart';

class HealthMetricsScreen extends StatefulWidget {
  final String memberId;

  const HealthMetricsScreen({super.key, required this.memberId});

  @override
  State<HealthMetricsScreen> createState() => _HealthMetricsScreenState();
}

class _HealthMetricsScreenState extends State<HealthMetricsScreen> {
  final HealthRemoteDataSource _dataSource = HealthRemoteDataSource();
  List<HealthMetricEntryModel> _recentMetrics = [];
  bool _isLoading = true;

  final List<Map<String, dynamic>> _metricCardsConfig = [
    {'type': 'WEIGHT', 'title': 'Weight', 'icon': Icons.monitor_weight_outlined, 'unit': 'kg', 'color': AppColors.primary},
    {'type': 'BMI', 'title': 'BMI', 'icon': Icons.speed_rounded, 'unit': 'kg/m²', 'color': AppColors.secondary},
    {'type': 'WATER', 'title': 'Hydration', 'icon': Icons.water_drop_outlined, 'unit': 'ml', 'color': const Color(0xFF0284C7)},
    {'type': 'STEPS', 'title': 'Steps', 'icon': Icons.directions_walk_rounded, 'unit': 'count', 'color': const Color(0xFFD97706)},
    {'type': 'SLEEP_HOURS', 'title': 'Sleep', 'icon': Icons.nightlight_round_outlined, 'unit': 'hours', 'color': const Color(0xFF7C3AED)},
    {'type': 'CALORIES', 'title': 'Calories', 'icon': Icons.local_fire_department_outlined, 'unit': 'kcal', 'color': const Color(0xFFEA580C)},
    {'type': 'PROTEIN', 'title': 'Protein', 'icon': Icons.fitness_center_rounded, 'unit': 'g', 'color': const Color(0xFF059669)},
  ];

  @override
  void initState() {
    super.initState();
    _loadMetrics();
  }

  Future<void> _loadMetrics() async {
    setState(() => _isLoading = true);
    try {
      final list = await _dataSource.getMetrics(widget.memberId);
      if (mounted) {
        setState(() {
          _recentMetrics = list;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  HealthMetricEntryModel? _getLatestForType(String type) {
    try {
      return _recentMetrics.firstWhere((m) => m.metricType == type);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppColors.slate900 : Colors.white;
    final cardBorder = isDark ? AppColors.slate800 : AppColors.slate200;
    final textPrimary = isDark ? Colors.white : AppColors.slate900;
    final textSecondary = isDark ? AppColors.slate300 : AppColors.slate700;
    final textMuted = isDark ? AppColors.slate400 : AppColors.slate600;

    return Scaffold(
      backgroundColor: isDark ? AppColors.slate950 : AppColors.slate50,
      appBar: AppBar(
        title: Text('Health Metrics & Vitals', style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold)),
        backgroundColor: isDark ? AppColors.slate900 : Colors.white,
        elevation: 0,
        foregroundColor: textPrimary,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => HealthMetricEntryScreen(memberId: widget.memberId),
            ),
          );
          if (result == true) _loadMetrics();
        },
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('Log Metric', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tracked Vitals',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textPrimary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tap any metric card to view historical timeline and progress trends.',
                    style: TextStyle(fontSize: 12, color: textMuted),
                  ),
                  const SizedBox(height: 14),

                  // Grid of metric cards
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.15,
                    ),
                    itemCount: _metricCardsConfig.length,
                    itemBuilder: (ctx, index) {
                      final cfg = _metricCardsConfig[index];
                      final latest = _getLatestForType(cfg['type']);
                      return _buildMetricCard(cfg, latest, isDark, cardBg, cardBorder, textPrimary, textSecondary, textMuted);
                    },
                  ),
                  const SizedBox(height: 24),

                  // Recent Activity Log
                  Text(
                    'Recent Measurement Entries',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textPrimary),
                  ),
                  const SizedBox(height: 10),

                  if (_recentMetrics.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(24),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: cardBorder),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.monitor_heart_outlined, size: 40, color: textMuted),
                          const SizedBox(height: 8),
                          Text('No metrics recorded yet', style: TextStyle(fontWeight: FontWeight.w600, color: textPrimary)),
                          const SizedBox(height: 4),
                          Text('Tap "Log Metric" below to record your first vital.', style: TextStyle(fontSize: 12, color: textMuted)),
                        ],
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _recentMetrics.take(8).length,
                      itemBuilder: (ctx, index) {
                        final entry = _recentMetrics[index];
                        final date = DateTime.tryParse(entry.recordedAt);
                        final dateStr = date != null ? DateFormat('dd MMM, hh:mm a').format(date) : entry.recordedAt;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: cardBorder),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: isDark ? AppColors.primary.withOpacity(0.2) : AppColors.primarySubtle,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(Icons.show_chart_rounded, color: isDark ? AppColors.primaryLight : AppColors.primary, size: 18),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${entry.metricType}: ${entry.value} ${entry.unit}',
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textPrimary),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(dateStr, style: TextStyle(fontSize: 11, color: textMuted)),
                                  ],
                                ),
                              ),
                              ProvenanceBadge(source: entry.source, isCompact: true),
                            ],
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildMetricCard(
    Map<String, dynamic> cfg,
    HealthMetricEntryModel? latest,
    bool isDark,
    Color cardBg,
    Color cardBorder,
    Color textPrimary,
    Color textSecondary,
    Color textMuted,
  ) {
    final hasVal = latest != null;
    final color = cfg['color'] as Color;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => HealthMetricHistoryScreen(
              memberId: widget.memberId,
              metricType: cfg['type'],
              title: cfg['title'],
              unit: cfg['unit'],
            ),
          ),
        ).then((_) => _loadMetrics());
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
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
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: color.withOpacity(isDark ? 0.22 : 0.14),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(cfg['icon'] as IconData, size: 18, color: color),
                ),
                const SizedBox(width: 6),
                if (latest != null)
                  Flexible(
                    child: ProvenanceBadge(source: latest.source, isCompact: true),
                  ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  cfg['title'] as String,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textSecondary),
                ),
                const SizedBox(height: 2),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Flexible(
                      child: Text(
                        hasVal ? latest.value.toStringAsFixed(1) : '--',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: hasVal ? textPrimary : textMuted,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      cfg['unit'] as String,
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: textMuted),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
