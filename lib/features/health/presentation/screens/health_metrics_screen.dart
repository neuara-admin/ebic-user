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
    return Scaffold(
      backgroundColor: AppColors.slate50,
      appBar: AppBar(
        title: const Text('Health Metrics & Vitals'),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: AppColors.slate900,
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
                  const Text(
                    'Tracked Vitals (Section 97)',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.slate900),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Tap any metric card to view historical timeline and progress trends.',
                    style: TextStyle(fontSize: 12, color: AppColors.slate500),
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
                      childAspectRatio: 1.25,
                    ),
                    itemCount: _metricCardsConfig.length,
                    itemBuilder: (ctx, index) {
                      final cfg = _metricCardsConfig[index];
                      final latest = _getLatestForType(cfg['type']);
                      return _buildMetricCard(cfg, latest);
                    },
                  ),
                  const SizedBox(height: 24),

                  // Recent Activity Log
                  const Text(
                    'Recent Measurement Entries',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.slate900),
                  ),
                  const SizedBox(height: 10),

                  if (_recentMetrics.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(24),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.slate200),
                      ),
                      child: const Column(
                        children: [
                          Icon(Icons.monitor_heart_outlined, size: 40, color: AppColors.slate400),
                          SizedBox(height: 8),
                          Text('No metrics recorded yet', style: TextStyle(fontWeight: FontWeight.w600)),
                          SizedBox(height: 4),
                          Text('Tap "Log Metric" below to record your first vital.', style: TextStyle(fontSize: 12, color: AppColors.slate500)),
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
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.slate200),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppColors.primarySubtle,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.show_chart_rounded, color: AppColors.primary, size: 18),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${entry.metricType}: ${entry.value} ${entry.unit}',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(dateStr, style: const TextStyle(fontSize: 11, color: AppColors.slate400)),
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

  Widget _buildMetricCard(Map<String, dynamic> cfg, HealthMetricEntryModel? latest) {
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
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.slate200),
          boxShadow: [
            BoxShadow(
              color: AppColors.slate900.withOpacity(0.02),
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
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(cfg['icon'] as IconData, size: 18, color: color),
                ),
                if (latest != null)
                  ProvenanceBadge(source: latest.source, isCompact: true),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  cfg['title'] as String,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.slate600),
                ),
                const SizedBox(height: 2),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      hasVal ? latest.value.toStringAsFixed(1) : '--',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: hasVal ? AppColors.slate950 : AppColors.slate400,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      cfg['unit'] as String,
                      style: const TextStyle(fontSize: 11, color: AppColors.slate400),
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
