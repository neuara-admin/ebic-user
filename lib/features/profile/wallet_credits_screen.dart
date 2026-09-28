import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/routing/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/ebic_card.dart';

class WalletCreditsScreen extends StatefulWidget {
  const WalletCreditsScreen({super.key});

  @override
  State<WalletCreditsScreen> createState() => _WalletCreditsScreenState();
}

class _WalletCreditsScreenState extends State<WalletCreditsScreen> {
  final ApiClient _api = ApiClient();
  double _balance = 0.0;
  List<Map<String, dynamic>> _ledger = [];
  bool _isLoading = true;
  String _selectedFilter = 'ALL'; // ALL | CREDIT | DEBIT

  @override
  void initState() {
    super.initState();
    _fetchWallet();
  }

  Future<void> _fetchWallet() async {
    setState(() => _isLoading = true);
    try {
      final balanceRes = await _api.get<Map<String, dynamic>>(ApiEndpoints.walletBalance);
      final txRes = await _api.get<dynamic>(ApiEndpoints.walletTransactions);

      double newBalance = _balance;
      if (balanceRes.success && balanceRes.data != null) {
        newBalance = double.tryParse(balanceRes.data!['balance']?.toString() ?? '0') ?? 0.0;
      }

      List<Map<String, dynamic>> newLedger = [];
      if (txRes.success && txRes.data != null) {
        List<dynamic> rawList = [];
        if (txRes.data is Map && txRes.data['items'] is List) {
          rawList = txRes.data['items'] as List<dynamic>;
        } else if (txRes.data is List) {
          rawList = txRes.data as List<dynamic>;
        }
        newLedger = rawList.map((item) {
          final m = Map<String, dynamic>.from(item as Map);
          final rawAmount = double.tryParse(m['amount']?.toString() ?? '0') ?? 0.0;
          final direction = m['direction']?.toString().toUpperCase() ?? (rawAmount >= 0 ? 'CREDIT' : 'DEBIT');
          final createdAt = m['createdAt'] != null ? DateTime.tryParse(m['createdAt'].toString()) : null;
          final dateStr = createdAt != null ? DateFormat('dd MMM yyyy, hh:mm a').format(createdAt) : (m['date']?.toString() ?? 'Recent');
          final expiry = m['expiresAt'] != null ? DateFormat('dd MMM yyyy').format(DateTime.parse(m['expiresAt'].toString())) : 'No Expiry';

          return {
            'id': m['id']?.toString() ?? 'TX-${DateTime.now().millisecondsSinceEpoch}',
            'type': direction,
            'amount': rawAmount.abs(),
            'reason': m['reason']?.toString() ?? m['description']?.toString() ?? 'EBIC Credits Activity',
            'sourceType': m['sourceType']?.toString() ?? (direction == 'CREDIT' ? 'PROMOTIONAL_CREDIT' : 'CHECKOUT_REDEMPTION'),
            'referenceId': m['referenceId']?.toString() ?? m['orderId']?.toString() ?? 'REF-EBIC',
            'status': m['status']?.toString() ?? 'CONFIRMED',
            'balanceAfter': m['balanceAfter'] != null ? double.tryParse(m['balanceAfter'].toString()) : null,
            'expiry': expiry,
            'date': dateStr,
          };
        }).toList();
      }

      if (mounted) {
        setState(() {
          _balance = newBalance;
          _ledger = newLedger;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredLedger = _selectedFilter == 'ALL'
        ? _ledger
        : _ledger.where((tx) => tx['type'] == _selectedFilter).toList();

    return Scaffold(
      backgroundColor: AppColors.slate50,
      appBar: AppBar(
        title: const Text('EBIC Credits'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: RefreshIndicator(
                onRefresh: _fetchWallet,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Section 9: Available Credits Card
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          gradient: AppColors.primaryGradient,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withOpacity(0.3),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'AVAILABLE CREDITS',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '₹${_balance.toStringAsFixed(0)}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 38,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Eligible credits applied automatically at checkout for bookings & health passes.',
                              style: TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Section 9: "How your credits work"
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.slate200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: const [
                                Icon(Icons.info_outline, size: 18, color: AppColors.primary),
                                SizedBox(width: 8),
                                Text(
                                  'How your credits work',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.slate900,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              '• Earn credits through referrals, promotions, goodwill, and approved refunds.\n'
                              '• Use eligible EBIC credits toward EBIC services and purchases.\n'
                              '• Credits are closed-system platform benefits: non-transferable and non-withdrawable to bank accounts.\n'
                              '• Credits are held in an immutable double-entry ledger.',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.slate600,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Section 9 & 10: Recent Activity Header & Filters
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Recent Activity',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: AppColors.slate900,
                            ),
                          ),
                          Text(
                            '${_ledger.length} items',
                            style: const TextStyle(fontSize: 12, color: AppColors.slate500),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Filter tabs
                      Row(
                        children: [
                          _buildFilterChip('ALL', 'All'),
                          const SizedBox(width: 8),
                          _buildFilterChip('CREDIT', 'Earned (+₹)'),
                          const SizedBox(width: 8),
                          _buildFilterChip('DEBIT', 'Spent (-₹)'),
                        ],
                      ),
                      const SizedBox(height: 14),

                      if (filteredLedger.isEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.slate200),
                          ),
                          child: Column(
                            children: const [
                              Icon(Icons.receipt_long_outlined, size: 40, color: AppColors.slate300),
                              SizedBox(height: 10),
                              Text(
                                'No credit activity yet',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.slate700,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Refer friends, join promotional campaigns, or receive service recovery credits to see them here.',
                                style: TextStyle(fontSize: 12, color: AppColors.slate500),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        )
                      else
                        ...filteredLedger.map((tx) {
                          final isCredit = tx['type'] == 'CREDIT';
                          final amount = tx['amount'] as num;
                          final balanceAfter = tx['balanceAfter'] as num?;

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () {
                                Navigator.pushNamed(
                                  context,
                                  AppRoutes.creditTransactionDetail,
                                  arguments: tx,
                                );
                              },
                              child: EbicCard(
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: isCredit ? AppColors.emerald50 : AppColors.rose50,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Icon(
                                        isCredit ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                                        color: isCredit ? AppColors.emerald600 : AppColors.danger,
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            tx['reason'] ?? 'Transaction',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                              color: AppColors.slate900,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '${tx['date']}${tx['expiry'] != null && tx['expiry'] != 'No Expiry' ? ' • Expiry: ${tx['expiry']}' : ''}',
                                            style: const TextStyle(color: AppColors.slate500, fontSize: 11),
                                          ),
                                          if (balanceAfter != null) ...[
                                            const SizedBox(height: 2),
                                            Text(
                                              'Balance: ₹${balanceAfter.toStringAsFixed(0)}',
                                              style: const TextStyle(
                                                color: AppColors.slate400,
                                                fontSize: 10.5,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          '${isCredit ? '+' : '-'}₹${amount.toStringAsFixed(0)}',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                            color: isCredit ? AppColors.emerald700 : AppColors.slate900,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        const Icon(
                                          Icons.chevron_right,
                                          size: 16,
                                          color: AppColors.slate400,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildFilterChip(String key, String label) {
    final isSelected = _selectedFilter == key;
    return InkWell(
      onTap: () => setState(() => _selectedFilter = key),
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.slate100,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : AppColors.slate700,
          ),
        ),
      ),
    );
  }
}
