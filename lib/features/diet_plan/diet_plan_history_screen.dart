import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/ebic_card.dart';
import 'diet_plan_service.dart';
import 'diet_plan_calendar_screen.dart';

class DietPlanHistoryScreen extends StatefulWidget {
  final String? memberId;
  final String memberName;

  const DietPlanHistoryScreen({
    super.key,
    this.memberId,
    required this.memberName,
  });

  @override
  State<DietPlanHistoryScreen> createState() => _DietPlanHistoryScreenState();
}

class _DietPlanHistoryScreenState extends State<DietPlanHistoryScreen> {
  final DietPlanService _service = DietPlanService();
  bool _isLoading = true;
  List<Map<String, dynamic>> _plans = [];

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  Future<void> _fetchHistory() async {
    setState(() => _isLoading = true);
    final list = await _service.getPlanHistory(memberId: widget.memberId);
    if (mounted) {
      setState(() {
        _plans = list;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMM yyyy');

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('${widget.memberName}\'s Diet Plans'),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _plans.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.history, size: 54, color: Colors.grey.shade400),
                        const SizedBox(height: 12),
                        const Text(
                          'No historical plans yet',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Past versions will be archived here whenever your dietitian redesigns your plan.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _plans.length,
                  itemBuilder: (context, index) {
                    final p = _plans[index];
                    final isCurrent = p['status'] == 'PUBLISHED';
                    final version = p['versionNumber'] ?? 1;
                    final planName = p['planName'] ?? 'Diet Plan V$version';
                    final dietitian = p['dietitian']?['name'] ?? 'Dietitian';
                    final startDate = p['startDate'] != null
                        ? dateFormat.format(DateTime.parse(p['startDate']))
                        : 'Start';
                    final reviewDate = p['reviewDate'] != null
                        ? dateFormat.format(DateTime.parse(p['reviewDate']))
                        : 'Ongoing';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: EbicCard(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: isCurrent ? Colors.green.shade50 : Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: isCurrent ? Colors.green.shade300 : Colors.grey.shade300,
                                    ),
                                  ),
                                  child: Text(
                                    isCurrent ? 'Current Plan' : 'Version $version',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: isCurrent ? Colors.green.shade800 : Colors.grey.shade700,
                                    ),
                                  ),
                                ),
                                Text(
                                  p['customerFacingStatus'] ?? '',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: isCurrent ? Colors.green : Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              planName,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Prescribed by $dietitian',
                              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Icon(Icons.date_range, size: 14, color: Colors.grey.shade500),
                                const SizedBox(width: 4),
                                Text(
                                  'Period: $startDate — $reviewDate',
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton.icon(
                                style: TextButton.styleFrom(
                                  foregroundColor: AppColors.primary,
                                  padding: EdgeInsets.zero,
                                ),
                                icon: const Icon(Icons.calendar_month, size: 16),
                                label: const Text('View Calendar & Meals'),
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => DietPlanCalendarScreen(
                                        dietPlanId: p['id'],
                                        planName: planName,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
