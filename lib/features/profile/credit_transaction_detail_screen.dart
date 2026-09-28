import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/ebic_card.dart';

class CreditTransactionDetailScreen extends StatelessWidget {
  final Map<String, dynamic> transaction;

  const CreditTransactionDetailScreen({
    super.key,
    required this.transaction,
  });

  @override
  Widget build(BuildContext context) {
    final isCredit = transaction['type'] == 'CREDIT';
    final amount = (transaction['amount'] as num?)?.toDouble() ?? 0.0;
    final reason = transaction['reason']?.toString() ?? 'EBIC Credit Transaction';
    final date = transaction['date']?.toString() ?? 'Recent';
    final expiry = transaction['expiry']?.toString() ?? 'No Expiry';
    final balanceAfter = (transaction['balanceAfter'] as num?)?.toDouble();
    final sourceType = transaction['sourceType']?.toString() ?? (isCredit ? 'PROMOTIONAL_CREDIT' : 'PURCHASE_REDEMPTION');
    final referenceId = transaction['referenceId']?.toString() ?? 'REF-${DateTime.now().millisecondsSinceEpoch.toString().substring(6)}';
    final status = transaction['status']?.toString() ?? 'CONFIRMED';

    return Scaffold(
      backgroundColor: AppColors.slate50,
      appBar: AppBar(
        title: const Text('Transaction Details'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Summary card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.slate200),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isCredit ? AppColors.emerald50 : AppColors.rose50,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isCredit ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                        color: isCredit ? AppColors.emerald600 : AppColors.danger,
                        size: 32,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      '${isCredit ? '+' : '-'}₹${amount.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: isCredit ? AppColors.emerald700 : AppColors.slate900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isCredit ? AppColors.successLight : AppColors.slate200,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        isCredit ? 'CREDIT ADDED' : 'CREDIT REDEEMED',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isCredit ? AppColors.emerald700 : AppColors.slate700,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      reason,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.slate800,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Ledger & Accounting Attributes (Section 11)
              const Text(
                'Financial & Ledger Attributes',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.slate900,
                ),
              ),
              const SizedBox(height: 12),

              EbicCard(
                child: Column(
                  children: [
                    _buildRow('Status', status, isBadge: true),
                    const Divider(height: 20),
                    _buildRow('Source Type', sourceType),
                    const Divider(height: 20),
                    _buildRow('Transaction Date', date),
                    const Divider(height: 20),
                    _buildRow('Expiry Date', expiry),
                    const Divider(height: 20),
                    _buildRow('Currency', 'INR (Paise-level precision)'),
                    const Divider(height: 20),
                    _buildRow('Reference ID', referenceId),
                    if (balanceAfter != null) ...[
                      const Divider(height: 20),
                      _buildRow('Balance After', '₹${balanceAfter.toStringAsFixed(0)}'),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Regulatory & Non-transferable Notice (Section 4, 8, 9)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.slate100,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.slate200),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.verified_user_outlined, size: 20, color: AppColors.slate600),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'Closed-System Credit',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.slate800),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'EBIC Credits are non-transferable between users, cannot be withdrawn to bank accounts or third-party wallets, and are backed by immutable double-entry ledger entries.',
                            style: TextStyle(fontSize: 11.5, color: AppColors.slate600, height: 1.4),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRow(String label, String value, {bool isBadge = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(child: Text(
          label,
          style: const TextStyle(fontSize: 13, color: AppColors.slate500, fontWeight: FontWeight.w500),
        )),
        if (isBadge)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.emerald50,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppColors.primaryLight.withOpacity(0.3)),
            ),
            child: Text(
              value,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.emerald700),
            ),
          )
        else
          Text(
            value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.slate800),
          ),
      ],
    );
  }
}
