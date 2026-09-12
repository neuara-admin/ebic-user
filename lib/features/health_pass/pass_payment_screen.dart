import 'package:flutter/material.dart';
import '../../core/analytics/analytics_service.dart';
import '../../core/routing/app_routes.dart';
import '../../core/services/razorpay_service.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/models/household_member_model.dart';
import '../../shared/widgets/ebic_button.dart';
import '../../shared/widgets/ebic_card.dart';
import 'data/health_pass_repository.dart';

/// Module 4 — Section 40: Health Pass Payment Flow & States
class HealthPassPaymentScreen extends StatefulWidget {
  final Map<String, dynamic> arguments;

  const HealthPassPaymentScreen({super.key, required this.arguments});

  @override
  State<HealthPassPaymentScreen> createState() => _HealthPassPaymentScreenState();
}

enum PaymentUiState {
  notStarted,
  initiated,
  processing,
  success,
  failed,
  pending,
}

class _HealthPassPaymentScreenState extends State<HealthPassPaymentScreen> {
  final HealthPassRepository _repository = HealthPassRepository();

  late String _healthPassId;
  late String _planName;
  late double _amount;
  late int _durationMonths;
  late List<HouseholdMemberModel> _members;

  PaymentUiState _state = PaymentUiState.notStarted;
  String _selectedMethod = 'GATEWAY';
  String? _errorMessage;
  String? _idempotencyKey;

  @override
  void initState() {
    super.initState();
    _healthPassId = widget.arguments['healthPassId']?.toString() ?? '';
    _planName = widget.arguments['planName']?.toString() ?? 'EBIC Care';
    _amount = double.tryParse(widget.arguments['amount']?.toString() ?? '0') ?? 0.0;
    _durationMonths = int.tryParse(widget.arguments['durationMonths']?.toString() ?? '1') ?? 1;
    _members = (widget.arguments['members'] as List<dynamic>?)?.cast<HouseholdMemberModel>() ?? [];

    _idempotencyKey = 'pay_hp_${_healthPassId}_${DateTime.now().millisecondsSinceEpoch}';
  }

  Future<void> _processPayment() async {
    setState(() {
      _state = PaymentUiState.initiated;
      _errorMessage = null;
    });

    try {
      // Step 1: Initiate Payment Session with Backend
      AnalyticsService().logHealthPassPaymentStarted(_healthPassId);
      final initRes = await _repository.initiatePayment(
        healthPassId: _healthPassId,
        method: _selectedMethod,
        idempotencyKey: _idempotencyKey!,
      );

      setState(() => _state = PaymentUiState.processing);

      String gatewayPaymentId;
      String gatewaySignature;

      // Check if payment was immediately resolved (e.g., WALLET payment)
      if (initRes['status'] == 'SUCCEEDED') {
        gatewayPaymentId = initRes['gatewayRef']?.toString() ?? 'wallet_success';
        gatewaySignature = 'wallet_verified';
      } else if (initRes['gatewayOrderId'] != null && initRes['keyId'] != null) {
        // Step 2: Launch Real Razorpay Flutter Checkout
        final checkoutRes = await RazorpayService().openCheckout(
          keyId: initRes['keyId'].toString(),
          orderId: initRes['gatewayOrderId'].toString(),
          amountPaise: (initRes['amountPaise'] as num?) ?? (_amount * 100),
          currency: initRes['currency']?.toString() ?? 'INR',
          name: 'EBIC Health Pass',
          description: 'Subscription for $_planName ($_durationMonths Mo)',
        );

        if (!checkoutRes.isSuccess) {
          throw Exception(checkoutRes.errorMessage ?? 'Payment was cancelled or failed.');
        }

        gatewayPaymentId = checkoutRes.paymentId!;
        gatewaySignature = checkoutRes.signature!;
      } else {
        // Fallback for offline or local dev simulation
        gatewayPaymentId = 'pay_sim_${DateTime.now().millisecondsSinceEpoch}';
        gatewaySignature = 'sig_sim_verified';
      }

      // Step 3: Authoritative Backend Payment Verification & Activation
      await _repository.verifyPayment(
        healthPassId: _healthPassId,
        gatewayPaymentId: gatewayPaymentId,
        gatewaySignature: gatewaySignature,
        idempotencyKey: _idempotencyKey!,
      );

      AnalyticsService().logHealthPassPurchaseCompleted(_healthPassId);
      setState(() => _state = PaymentUiState.success);

      if (mounted) {
        Navigator.pushReplacementNamed(
          context,
          AppRoutes.healthPassActivation,
          arguments: {
            'isSuccess': true,
            'healthPassId': _healthPassId,
            'planName': _planName,
            'durationMonths': _durationMonths,
            'members': _members,
            'amountPaid': _amount,
            'paymentId': gatewayPaymentId,
          },
        );
      }
    } catch (e) {
      final errorMsg = e.toString().replaceAll('Exception: ', '');
      AnalyticsService().logHealthPassPurchaseFailed(errorMsg);
      if (mounted) {
        setState(() {
          _state = PaymentUiState.failed;
          _errorMessage = errorMsg;
        });
        Navigator.pushNamed(
          context,
          AppRoutes.healthPassActivation,
          arguments: {
            'isSuccess': false,
            'planName': _planName,
            'durationMonths': _durationMonths,
            'amountPaid': _amount,
            'errorMessage': errorMsg,
          },
        );
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
        title: const Text('Complete Payment'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Amount Header Card
              EbicCard(
                child: Column(
                  children: [
                    const Text('AMOUNT TO PAY', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.slate500, letterSpacing: 0.8)),
                    const SizedBox(height: 6),
                    Text(
                      '₹${_amount.toInt()}',
                      style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: AppColors.primary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$_planName • $_durationMonths ${_durationMonths == 1 ? 'Month' : 'Months'}',
                      style: TextStyle(fontSize: 12, color: isDark ? AppColors.slate300 : AppColors.slate600),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Payment Method Selector
              const Text(
                'PAYMENT METHOD',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.slate500, letterSpacing: 0.8),
              ),
              const SizedBox(height: 12),

              _buildPaymentOption('GATEWAY', 'UPI, Cards, Net Banking & Wallets', Icons.security_outlined, isDark),

              const Spacer(),

              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.danger.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.danger.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: AppColors.danger, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(_errorMessage!, style: const TextStyle(color: AppColors.danger, fontSize: 12)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Processing Indicator or Button
              if (_state == PaymentUiState.processing || _state == PaymentUiState.initiated)
                const Center(
                  child: Column(
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 12),
                      Text('Authorizing payment with gateway...', style: TextStyle(fontSize: 13, color: AppColors.slate500)),
                    ],
                  ),
                )
              else
                EbicButton(
                label: _state == PaymentUiState.failed ? 'Retry Payment' : 'Pay ₹${_amount.toInt()}',
                  onPressed: _processPayment,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentOption(String id, String label, IconData icon, bool isDark) {
    final isSelected = _selectedMethod == id;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => setState(() => _selectedMethod = id),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? AppColors.emerald700.withOpacity(0.2) : AppColors.emerald50)
              : (isDark ? AppColors.slate900 : Colors.white),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : (isDark ? AppColors.slate800 : AppColors.slate200),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? AppColors.primary : AppColors.slate500, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    id == 'GATEWAY' ? 'Razorpay 1-Tap Checkout' : id == 'UPI' ? 'UPI Instant Transfer' : id == 'CARD' ? 'Credit & Debit Cards' : 'Net Banking',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: isDark ? Colors.white : AppColors.slate900,
                    ),
                  ),
                  Text(label, style: const TextStyle(color: AppColors.slate500, fontSize: 11)),
                ],
              ),
            ),
            Radio<String>(
              value: id,
              groupValue: _selectedMethod,
              activeColor: AppColors.primary,
              onChanged: (val) {
                if (val != null) setState(() => _selectedMethod = val);
              },
            ),
          ],
        ),
      ),
    );
  }
}
