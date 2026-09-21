import 'package:flutter/material.dart';
import '../../core/routing/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/models/health_pass_model.dart';
import '../../shared/widgets/ebic_card.dart';
import '../../shared/widgets/ebic_button.dart';
import 'data/health_pass_repository.dart';

/// Module 4 — Section 48: Health Pass History Screen
class HealthPassHistoryScreen extends StatefulWidget {
  const HealthPassHistoryScreen({super.key});

  @override
  State<HealthPassHistoryScreen> createState() => _HealthPassHistoryScreenState();
}

class _HealthPassHistoryScreenState extends State<HealthPassHistoryScreen> {
  final HealthPassRepository _repository = HealthPassRepository();

  List<HealthPassHistoryItemModel> _history = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final items = await _repository.fetchHistory();
      if (mounted) {
        setState(() {
          _history = items;
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
        title: const Text('Health Pass History'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(child: Text(_errorMessage!))
              : _history.isEmpty
                  ? _buildEmptyState(isDark)
                  : RefreshIndicator(
                      onRefresh: _loadHistory,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _history.length,
                        itemBuilder: (context, index) {
                          final item = _history[index];
                          final isActive = item.status == 'ACTIVE';
                          final bookedStr = '${item.createdAt.day.toString().padLeft(2, '0')}/${item.createdAt.month.toString().padLeft(2, '0')}/${item.createdAt.year}';
                          final startStr = item.startDate != null
                              ? '${item.startDate!.day.toString().padLeft(2, '0')}/${item.startDate!.month.toString().padLeft(2, '0')}/${item.startDate!.year}'
                              : 'Pending';
                          final endStr = item.endDate != null
                              ? '${item.endDate!.day.toString().padLeft(2, '0')}/${item.endDate!.month.toString().padLeft(2, '0')}/${item.endDate!.year}'
                              : '—';

                          return Container(
                            margin: const EdgeInsets.only(bottom: 14),
                            child: EbicCard(
                              onTap: () => _showPassDetailsModal(context, item, isDark),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          item.displayName,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                            color: isDark ? Colors.white : AppColors.slate900,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: isActive ? AppColors.emerald50 : AppColors.slate100,
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          item.status,
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: isActive ? AppColors.emerald700 : AppColors.slate600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${item.durationLabel} • ${item.memberCount} ${item.memberCount == 1 ? 'member' : 'members'} covered',
                                    style: const TextStyle(fontSize: 12, color: AppColors.slate500),
                                  ),
                                  const Divider(height: 18),

                                  // 3-Column Dates Breakdown: Booked, Start, End
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: isDark ? AppColors.slate800.withOpacity(0.6) : AppColors.slate50,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: isDark ? AppColors.slate700 : AppColors.slate200,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: _dateColumn('BOOKED', bookedStr, isDark),
                                        ),
                                        Container(width: 1, height: 26, color: isDark ? AppColors.slate700 : AppColors.slate200),
                                        Expanded(
                                          child: _dateColumn('START', startStr, isDark),
                                        ),
                                        Container(width: 1, height: 26, color: isDark ? AppColors.slate700 : AppColors.slate200),
                                        Expanded(
                                          child: _dateColumn('END', endStr, isDark),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 12),

                                  // Bottom Row: Total Paid & Quick Action Buttons
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'TOTAL PAID',
                                            style: TextStyle(fontSize: 9.5, color: AppColors.slate400, fontWeight: FontWeight.bold),
                                          ),
                                          const SizedBox(height: 1),
                                          Text(
                                            '₹${item.finalAmount.toInt()}',
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.primary),
                                          ),
                                        ],
                                      ),
                                      Row(
                                        children: [
                                          OutlinedButton.icon(
                                            style: OutlinedButton.styleFrom(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                              side: BorderSide(color: isDark ? AppColors.slate700 : AppColors.slate300),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                            ),
                                            icon: const Icon(Icons.receipt_long_rounded, size: 14, color: AppColors.primary),
                                            label: const Text('Usage History', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                                            onPressed: () {
                                              Navigator.pushNamed(
                                                context,
                                                AppRoutes.healthPassUsage,
                                                arguments: {'healthPassId': item.id},
                                              );
                                            },
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }

  Widget _dateColumn(String label, String value, bool isDark) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.slate400, letterSpacing: 0.4),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : AppColors.slate800,
          ),
        ),
      ],
    );
  }

  void _showPassDetailsModal(BuildContext context, HealthPassHistoryItemModel item, bool isDark) {
    final isActive = item.status == 'ACTIVE';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? AppColors.slate900 : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.slate700 : AppColors.slate300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        item.displayName,
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : AppColors.slate900),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isActive ? AppColors.emerald50 : AppColors.slate100,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        item.status,
                        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: isActive ? AppColors.emerald700 : AppColors.slate600),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${item.durationLabel} • Purchased on ${item.createdAt.day}/${item.createdAt.month}/${item.createdAt.year}',
                  style: const TextStyle(fontSize: 12, color: AppColors.slate500),
                ),
                const Divider(height: 24),

                // Details Rows
                _modalRow('Total Paid', '₹${item.finalAmount.toInt()}', isDark, isHighlight: true),
                const SizedBox(height: 10),
                _modalRow(
                  'Booked Date',
                  '${item.createdAt.day.toString().padLeft(2, '0')}/${item.createdAt.month.toString().padLeft(2, '0')}/${item.createdAt.year}',
                  isDark,
                ),
                const SizedBox(height: 10),
                _modalRow(
                  'Start Date',
                  item.startDate != null
                      ? '${item.startDate!.day.toString().padLeft(2, '0')}/${item.startDate!.month.toString().padLeft(2, '0')}/${item.startDate!.year}'
                      : 'Pending Consultation Kickoff',
                  isDark,
                ),
                const SizedBox(height: 10),
                _modalRow(
                  'End Date',
                  item.endDate != null
                      ? '${item.endDate!.day.toString().padLeft(2, '0')}/${item.endDate!.month.toString().padLeft(2, '0')}/${item.endDate!.year}'
                      : '—',
                  isDark,
                ),
                const SizedBox(height: 10),
                _modalRow('Covered Members', '${item.memberCount} members', isDark),
                if (item.members.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: item.members.map((m) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.slate800 : AppColors.slate100,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${m.name} (${m.relationship})',
                          style: TextStyle(fontSize: 11, color: isDark ? Colors.white : AppColors.slate800),
                        ),
                      );
                    }).toList(),
                  ),
                ],
                const SizedBox(height: 20),

                // View Usage History Button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: const BorderSide(color: AppColors.primary),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.receipt_long_rounded, size: 16, color: AppColors.primary),
                    label: const Text(
                      'View Usage History & Entitlement Ledger',
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppColors.primary),
                    ),
                    onPressed: () {
                      Navigator.pop(ctx);
                      Navigator.pushNamed(
                        context,
                        AppRoutes.healthPassUsage,
                        arguments: {'healthPassId': item.id},
                      );
                    },
                  ),
                ),
                const SizedBox(height: 10),

                // Action Buttons
                if (isActive) ...[
                  EbicButton(
                    label: 'Go to Health Pass Dashboard',
                    isFullWidth: true,
                    onPressed: () {
                      Navigator.pop(ctx);
                      HealthPassRepository.notifyPassUpdated();
                      Navigator.pushNamedAndRemoveUntil(context, AppRoutes.mainShell, (r) => false, arguments: 2);
                    },
                  ),
                ] else ...[
                  EbicButton(
                    label: 'Renew / Purchase Plan',
                    isFullWidth: true,
                    onPressed: () {
                      Navigator.pop(ctx);
                      Navigator.pushNamed(context, AppRoutes.healthPassPlans);
                    },
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _modalRow(String label, String value, bool isDark, {bool isHighlight = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: isDark ? AppColors.slate400 : AppColors.slate500)),
        Text(
          value,
          style: TextStyle(
            fontSize: isHighlight ? 14 : 12,
            fontWeight: FontWeight.bold,
            color: isHighlight ? AppColors.primary : (isDark ? Colors.white : AppColors.slate900),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? AppColors.slate800 : AppColors.slate100,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.history_rounded, size: 40, color: AppColors.slate400),
            ),
            const SizedBox(height: 16),
            Text(
              'No Subscription History',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white : AppColors.slate800),
            ),
            const SizedBox(height: 6),
            const Text(
              'Your past Health Pass purchases and renewal receipts will be archived here.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppColors.slate500),
            ),
          ],
        ),
      ),
    );
  }
}
