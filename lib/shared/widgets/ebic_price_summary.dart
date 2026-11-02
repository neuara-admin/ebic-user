import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/design_tokens.dart';

/// Price summary breakdown component.
/// Adheres strictly to Section 27 (Money Handling): displays authoritative backend numbers
/// without performing client-side floating point calculation.
class EBICPriceSummary extends StatelessWidget {
  final String currency;
  final num subtotal;
  final num? discount;
  final String? discountLabel;
  final num? tax;
  final String? taxLabel;
  final num grandTotal;
  final List<PriceSummaryLine>? customLines;

  const EBICPriceSummary({
    super.key,
    this.currency = 'INR',
    required this.subtotal,
    this.discount,
    this.discountLabel,
    this.tax,
    this.taxLabel,
    required this.grandTotal,
    this.customLines,
  });

  String _formatAmount(num amount) {
    final symbol = currency.toUpperCase() == 'INR' ? '₹' : '$currency ';
    final formatter = NumberFormat('#,##,###.##');
    return '$symbol${formatter.format(amount)}';
  }

  @override
  Widget build(BuildContext context) {
    
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: DesignTokens.borderRadiusMD,
        border: Border.all(
          color: AppColors.hairlineBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Icon(Icons.receipt_long_rounded, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Tax Invoice & Payment Summary',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                    color: AppColors.slate900,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.emerald50,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: AppColors.emerald600.withValues(alpha: 0.25),
                  ),
                ),
                child: Text(
                  'GST COMPLIANT',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: AppColors.emerald700,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildRow('Item Subtotal', _formatAmount(subtotal)),

          if (customLines != null) ...[
            for (final line in customLines!)
              _buildRow(
                line.title,
                line.isDeduction ? '- ${_formatAmount(line.amount)}' : _formatAmount(line.amount),
                
                color: line.isDeduction ? AppColors.emerald700 : null,
              ),
          ],

          if (discount != null && discount! > 0)
            _buildRow(
              discountLabel ?? 'Promotions & Discounts',
              '- ${_formatAmount(discount!)}',
              
              color: AppColors.emerald700,
            ),

          if (tax != null && tax! > 0)
            _buildRow(
              taxLabel ?? 'Taxes & GST',
              _formatAmount(tax!),
              
            ),

          const SizedBox(height: 12),
          Row(
            children: List.generate(
              26,
              (i) => Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 1.5),
                  height: 1.5,
                  color: AppColors.hairlineBorder,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total Amount Payable',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.slate900,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Inclusive of all taxes & GST',
                      style: TextStyle(fontSize: 11, color: AppColors.slate500),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _formatAmount(grandTotal),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.slate600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: color ?? AppColors.slate900,
            ),
          ),
        ],
      ),
    );
  }
}

class PriceSummaryLine {
  final String title;
  final num amount;
  final bool isDeduction;

  const PriceSummaryLine({
    required this.title,
    required this.amount,
    this.isDeduction = false,
  });
}
