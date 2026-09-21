import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/datasources/health_remote_datasource.dart';
import '../../data/models/health_metric_entry_model.dart';
import '../widgets/provenance_badge.dart';
import 'health_metric_entry_screen.dart';

class HealthMetricHistoryScreen extends StatefulWidget {
  final String memberId;
  final String metricType;
  final String title;
  final String unit;

  const HealthMetricHistoryScreen({
    super.key,
    required this.memberId,
    required this.metricType,
    required this.title,
    required this.unit,
  });

  @override
  State<HealthMetricHistoryScreen> createState() => _HealthMetricHistoryScreenState();
}

class _HealthMetricHistoryScreenState extends State<HealthMetricHistoryScreen> {
  final HealthRemoteDataSource _dataSource = HealthRemoteDataSource();
  List<HealthMetricEntryModel> _history = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    try {
      final list = await _dataSource.getMetricHistory(widget.memberId, widget.metricType);
      if (mounted) {
        setState(() {
          _history = list;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppColors.slate900 : Colors.white;
    final cardBorder = isDark ? AppColors.slate800 : AppColors.slate200;
    final textPrimary = isDark ? Colors.white : AppColors.slate900;
    final textSecondary = isDark ? AppColors.slate300 : AppColors.slate700;
    final textMuted = isDark ? AppColors.slate400 : AppColors.slate500;

    return Scaffold(
      backgroundColor: isDark ? AppColors.slate950 : AppColors.slate50,
      appBar: AppBar(
        title: Text('${widget.title} History', style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold)),
        backgroundColor: isDark ? AppColors.slate900 : Colors.white,
        elevation: 0,
        foregroundColor: textPrimary,
        actions: [
          IconButton(
            icon: Icon(Icons.add_chart_rounded, color: isDark ? AppColors.primaryLight : AppColors.primary),
            onPressed: () async {
              final res = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => HealthMetricEntryScreen(
                    memberId: widget.memberId,
                    initialMetricType: widget.metricType,
                    initialUnit: widget.unit,
                  ),
                ),
              );
              if (res == true) _loadHistory();
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _history.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.timeline_rounded, size: 48, color: textMuted),
                      const SizedBox(height: 12),
                      Text(
                        'No ${widget.title} Entries',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textPrimary),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Tap + above to add your first recorded measurement.',
                        style: TextStyle(fontSize: 12, color: textMuted),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _history.length,
                  itemBuilder: (ctx, index) {
                    final item = _history[index];
                    final date = DateTime.tryParse(item.recordedAt);
                    final dateStr = date != null ? DateFormat('dd MMM yyyy').format(date) : item.recordedAt;
                    final timeStr = date != null ? DateFormat('hh:mm a').format(date) : '';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: cardBorder),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(isDark ? 0.2 : 0.02),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: isDark ? AppColors.primary.withOpacity(0.2) : AppColors.primarySubtle,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(Icons.fitness_center_rounded, color: isDark ? AppColors.primaryLight : AppColors.primary, size: 20),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        '${item.value} ${item.unit}',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w800,
                                          color: textPrimary,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    ProvenanceBadge(source: item.source, isCompact: true),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '$dateStr  •  $timeStr',
                                  style: TextStyle(fontSize: 12, color: textMuted),
                                ),
                                if (item.notes != null && item.notes!.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    item.notes!,
                                    style: TextStyle(fontSize: 11, color: textSecondary, fontStyle: FontStyle.italic),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
