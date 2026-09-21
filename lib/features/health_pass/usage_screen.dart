import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/models/health_pass_model.dart';
import '../../shared/widgets/ebic_card.dart';
import 'data/health_pass_repository.dart';

/// Module 4 — Sections 43 & 44: Health Pass Entitlements & Immutable Usage Ledger
class HealthPassUsageScreen extends StatefulWidget {
  final Map<String, dynamic> arguments;

  const HealthPassUsageScreen({super.key, required this.arguments});

  @override
  State<HealthPassUsageScreen> createState() => _HealthPassUsageScreenState();
}

class _HealthPassUsageScreenState extends State<HealthPassUsageScreen> {
  final HealthPassRepository _repository = HealthPassRepository();

  late String _healthPassId;
  HealthPassUsageLedgerModel? _data;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final id = widget.arguments['healthPassId']?.toString() ?? '';
    _healthPassId = id.trim().isEmpty ? 'current' : id.trim();
    _loadUsage();
  }

  Future<void> _loadUsage() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await _repository.fetchUsage(_healthPassId);
      if (mounted) {
        setState(() {
          _data = res;
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
        title: const Text('Entitlement Usage & Ledger'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(child: Text(_errorMessage!))
              : RefreshIndicator(
                  onRefresh: _loadUsage,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Section 58: Entitlement Balances Summary
                        Text(
                          'CURRENT PERIOD ALLOWANCES',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.slate500,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 10),
                        _buildEntitlementsSummary(isDark),
                        const SizedBox(height: 24),

                        // Section 60: Usage History Ledger
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'IMMUTABLE USAGE LEDGER',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppColors.slate500,
                                letterSpacing: 0.8,
                              ),
                            ),
                            Text(
                              '${_data?.usageLedger.length ?? 0} Events',
                              style: const TextStyle(fontSize: 11, color: AppColors.slate500),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Every consumption and order cancellation reversal is recorded as a permanent, auditable transaction.',
                          style: TextStyle(fontSize: 11, color: isDark ? AppColors.slate400 : AppColors.slate500),
                        ),
                        const SizedBox(height: 12),
                        _buildLedgerList(isDark),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildEntitlementsSummary(bool isDark) {
    final entitlements = _data?.entitlements ?? [];

    if (entitlements.isEmpty) {
      return EbicCard(
        child: const Center(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Text('No active entitlement allowances found.', style: TextStyle(color: AppColors.slate500)),
          ),
        ),
      );
    }

    return Column(
      children: entitlements.map((ent) {
        final total = ent.quantityTotal;
        final used = ent.quantityUsed;
        final remaining = ent.quantityRemaining;
        final progress = total > 0 ? (used / total).clamp(0.0, 1.0) : 0.0;

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? AppColors.slate900 : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: isDark ? AppColors.slate800 : AppColors.slate200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    ent.benefitName,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: isDark ? Colors.white : AppColors.slate900,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: remaining > 0 ? AppColors.emerald50 : AppColors.slate100,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '$remaining remaining',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: remaining > 0 ? AppColors.emerald700 : AppColors.slate600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Scope: ${ent.allowanceScope == 'SHARED' ? 'Shared Household Pool' : 'Per Covered Member (${ent.memberName})'}',
                style: const TextStyle(fontSize: 11, color: AppColors.slate500),
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 6,
                  backgroundColor: isDark ? AppColors.slate800 : AppColors.slate100,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    remaining > 0 ? AppColors.primary : AppColors.warning,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('$used of $total consumed', style: const TextStyle(fontSize: 11, color: AppColors.slate500)),
                  Text(
                    '${(progress * 100).toInt()}% utilized',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isDark ? AppColors.slate300 : AppColors.slate700),
                  ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildLedgerList(bool isDark) {
    final ledger = _data?.usageLedger ?? [];

    if (ledger.isEmpty) {
      return EbicCard(
        child: const Center(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              children: [
                Icon(Icons.history_toggle_off_rounded, size: 32, color: AppColors.slate400),
                SizedBox(height: 8),
                Text('No usage events recorded yet.', style: TextStyle(fontSize: 13, color: AppColors.slate500)),
                SizedBox(height: 4),
                Text('When you book chef visits, your consumption will appear here.', style: TextStyle(fontSize: 11, color: AppColors.slate400)),
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      children: ledger.map((entry) {
        final isReversal = entry.quantity < 0;

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? AppColors.slate900 : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: isDark ? AppColors.slate800 : AppColors.slate200),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isReversal ? AppColors.amber50 : AppColors.primarySubtle,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isReversal ? Icons.undo_rounded : Icons.check_circle_outline_rounded,
                  color: isReversal ? AppColors.amber700 : AppColors.primary,
                  size: 16,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          entry.service,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: isDark ? Colors.white : AppColors.slate900,
                          ),
                        ),
                        Text(
                          isReversal ? '+${-entry.quantity} restored' : '-${entry.quantity} used',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isReversal ? AppColors.primary : (isDark ? Colors.white : AppColors.slate800),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${entry.reason} • Member: ${entry.memberName}',
                      style: const TextStyle(color: AppColors.slate500, fontSize: 11),
                    ),
                    if (entry.orderNumber != null) ...[
                      const SizedBox(height: 2),
                      Text('Booking Ref: ${entry.orderNumber}', style: const TextStyle(color: AppColors.slate400, fontSize: 10)),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      '${entry.date.day}/${entry.date.month}/${entry.date.year} at ${entry.date.hour.toString().padLeft(2, '0')}:${entry.date.minute.toString().padLeft(2, '0')}',
                      style: const TextStyle(color: AppColors.slate400, fontSize: 10),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
