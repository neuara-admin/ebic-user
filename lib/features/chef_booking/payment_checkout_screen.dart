import 'package:flutter/material.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/routing/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/models/quote_model.dart';
import '../../shared/widgets/ebic_card.dart';
import '../../shared/widgets/ebic_button.dart';
import '../catalogue/cart_service.dart';

class PaymentCheckoutScreen extends StatefulWidget {
  final Map<String, dynamic> checkoutData;

  const PaymentCheckoutScreen({super.key, required this.checkoutData});

  @override
  State<PaymentCheckoutScreen> createState() => _PaymentCheckoutScreenState();
}

class _PaymentCheckoutScreenState extends State<PaymentCheckoutScreen> {
  final ApiClient _api = ApiClient();
  String _selectedMethod = 'UPI'; // UPI, CARD, WALLET, NETBANKING
  bool _isProcessing = false;
  String? _errorMessage;

  Future<void> _handlePayment() async {
    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      final quote = widget.checkoutData['quote'] as QuoteModel?;
      final addressId = widget.checkoutData['addressId'];

      // 1. Create order draft via /orders
      final orderRes = await _api.post<Map<String, dynamic>>(
        ApiEndpoints.orders,
        body: {
          'addressId': addressId ?? '00000000-0000-0000-0000-000000000001',
          'orderType': 'INSTANT',
          'bookingOption': widget.checkoutData['bookingOption'] ?? 'L',
          'memberIds': widget.checkoutData['memberId'] != null
              ? [widget.checkoutData['memberId']]
              : [],
        },
      );

      String orderId = 'ord_${DateTime.now().millisecondsSinceEpoch}';
      if (orderRes.success && orderRes.data != null) {
        orderId = orderRes.data!['id'] ?? orderId;
      }

      // 2. Initiate idempotent payment (Section 51 & 67)
      final idempotencyKey = 'pay_${orderId}_${DateTime.now().millisecondsSinceEpoch}';
      await _api.post<Map<String, dynamic>>(
        ApiEndpoints.orderPayInitiate(orderId),
        body: {
          'method': _selectedMethod,
        },
        requiresIdempotency: true,
        explicitIdempotencyKey: idempotencyKey,
      );

      // 3. Clear cart
      CartService().clear();

      setState(() => _isProcessing = false);

      if (!mounted) return;

      // 4. Navigate to confirmation (Section 47)
      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoutes.bookChefConfirmation,
        (route) => route.isFirst,
        arguments: {
          'orderId': orderId,
          'bookingType': 'Instant',
          'cookingTime': quote?.cookingTimeMinutes ?? 35,
          'total': quote?.total ?? 0.0,
        },
      );
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _errorMessage = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final quote = widget.checkoutData['quote'] as QuoteModel?;
    final finalAmount = quote?.total ?? 0.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment & Checkout'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Total payable banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  children: [
                    const Text(
                      'TOTAL PAYABLE AMOUNT',
                      style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '₹${finalAmount.toStringAsFixed(0)}',
                      style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Inclusive of statutory 5% GST & in-home chef dispatch',
                      style: TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.danger.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(_errorMessage!, style: const TextStyle(color: AppColors.danger, fontSize: 13)),
                ),
                const SizedBox(height: 16),
              ],

              const Text('Select Payment Method', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 12),

              _buildPaymentOption('UPI', 'Google Pay, PhonePe, Paytm UPI', Icons.account_balance_wallet_outlined),
              const SizedBox(height: 10),
              _buildPaymentOption('CARD', 'Credit / Debit Card (Visa, Mastercard, RuPay)', Icons.credit_card_outlined),
              const SizedBox(height: 10),
              _buildPaymentOption('WALLET', 'EBIC Wallet Credits Balance', Icons.wallet_outlined),
              const SizedBox(height: 10),
              _buildPaymentOption('NETBANKING', 'Net Banking (All Indian Banks)', Icons.account_balance_outlined),
              const SizedBox(height: 32),

              EbicButton(
                label: finalAmount == 0.0 ? 'Confirm Free Health Pass Booking' : 'Pay ₹${finalAmount.toStringAsFixed(0)}',
                icon: Icons.lock_outline,
                isLoading: _isProcessing,
                onPressed: _handlePayment,
              ),
              const SizedBox(height: 14),

              const Center(
                child: Text(
                  '100% Secure Checkout • Authoritative Backend Processing',
                  style: TextStyle(color: AppColors.slate400, fontSize: 11),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentOption(String key, String subtitle, IconData icon) {
    final isSelected = _selectedMethod == key;

    return EbicCard(
      onTap: () => setState(() => _selectedMethod = key),
      border: Border.all(
        color: isSelected ? AppColors.primary : AppColors.slate200,
        width: isSelected ? 2 : 1,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primarySubtle : AppColors.slate100,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: isSelected ? AppColors.primary : AppColors.slate600, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  key,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: isSelected ? AppColors.primaryDark : AppColors.slate900,
                  ),
                ),
                Text(subtitle, style: const TextStyle(color: AppColors.slate500, fontSize: 12)),
              ],
            ),
          ),
          Radio<String>(
            value: key,
            groupValue: _selectedMethod,
            activeColor: AppColors.primary,
            onChanged: (val) {
              if (val != null) setState(() => _selectedMethod = val);
            },
          ),
        ],
      ),
    );
  }
}
