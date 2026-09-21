import 'package:flutter/material.dart';
import '../../core/routing/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/ebic_card.dart';
import '../../shared/widgets/ebic_button.dart';

class BookingFailureScreen extends StatelessWidget {
  final Map<String, dynamic> failureData;

  const BookingFailureScreen({super.key, required this.failureData});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final orderId = failureData['orderId']?.toString();
    final errorMessage = failureData['errorMessage']?.toString() ??
        'The payment transaction could not be completed or was cancelled.';
    final total = failureData['total'] ?? 0.0;
    final selectedMethod = failureData['selectedMethod']?.toString() ?? 'UPI / Gateway';
    final checkoutData = failureData['checkoutData'] as Map<String, dynamic>?;

    final bookingRef = orderId != null && orderId.length >= 8
        ? 'EBIC-${orderId.substring(0, 4).toUpperCase()}'
        : (orderId ?? 'Not Generated');

    return WillPopScope(
      onWillPop: () async {
        Navigator.pushNamedAndRemoveUntil(context, AppRoutes.mainShell, (r) => false);
        return false;
      },
      child: Scaffold(
        backgroundColor: isDark ? AppColors.slate950 : const Color(0xFFF8FAFC),
        appBar: AppBar(
          automaticallyImplyLeading: false,
          elevation: 0,
          backgroundColor: isDark ? AppColors.slate900 : Colors.white,
          title: Text(
            'Booking Payment Status',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 17,
              color: isDark ? Colors.white : AppColors.slate900,
            ),
          ),
          actions: [
            IconButton(
              icon: Icon(Icons.close_rounded, color: isDark ? Colors.white70 : AppColors.slate700),
              tooltip: 'Return Home',
              onPressed: () {
                Navigator.pushNamedAndRemoveUntil(context, AppRoutes.mainShell, (r) => false);
              },
            ),
          ],
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 12),

                // 1. Failure Hero Badge
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFFCA5A5), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.danger.withOpacity(0.18),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(Icons.cancel_rounded, color: Color(0xFFDC2626), size: 48),
                  ),
                ),
                const SizedBox(height: 18),

                // 2. Title & Subtitle
                Text(
                  'Payment Unsuccessful',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.3,
                    color: isDark ? Colors.white : AppColors.slate900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'We were unable to verify payment for your chef booking.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13.5,
                    color: isDark ? AppColors.slate400 : AppColors.slate600,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 24),

                // 3. Reassurance & Refund Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: Color(0xFFFDE68A),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.shield_outlined, size: 18, color: Color(0xFFB45309)),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Your Money is Safe',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: Color(0xFF92400E),
                              ),
                            ),
                            SizedBox(height: 3),
                            Text(
                              'If any amount was deducted from your bank account or UPI app, it will be automatically reversed within 2-4 business days.',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: Color(0xFFB45309),
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // 4. Booking Reference & Failure Details Card
                EbicCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'TRANSACTION DETAILS',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.slate500,
                          letterSpacing: 0.6,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildRow('Booking Reference', bookingRef, isDark),
                      const SizedBox(height: 8),
                      _buildRow('Attempted Method', selectedMethod, isDark),
                      const SizedBox(height: 8),
                      _buildRow('Amount Payable', '₹${total is num ? total.toStringAsFixed(0) : total}', isDark),
                      const Divider(height: 20),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.error_outline_rounded, size: 16, color: Color(0xFFDC2626)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              errorMessage,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFFDC2626),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // 5. Action Buttons
                if (checkoutData != null) ...[
                  EbicButton(
                    label: 'Retry Payment',
                    icon: Icons.refresh_rounded,
                    onPressed: () {
                      Navigator.pushReplacementNamed(
                        context,
                        AppRoutes.bookChefPayment,
                        arguments: checkoutData,
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                ],

                EbicButton(
                  label: 'View Chef Bookings List',
                  icon: Icons.receipt_long_rounded,
                  variant: EbicButtonVariant.outline,
                  onPressed: () {
                    Navigator.pushNamedAndRemoveUntil(
                      context,
                      AppRoutes.orders,
                      (route) => route.isFirst,
                    );
                  },
                ),
                const SizedBox(height: 12),

                EbicButton(
                  label: 'Return to Home',
                  icon: Icons.home_rounded,
                  variant: EbicButtonVariant.ghost,
                  onPressed: () {
                    Navigator.pushNamedAndRemoveUntil(context, AppRoutes.mainShell, (r) => false);
                  },
                ),
                const SizedBox(height: 8),

                TextButton.icon(
                  icon: const Icon(Icons.support_agent_rounded, size: 16, color: AppColors.primary),
                  label: const Text(
                    'Need assistance? Contact 24/7 Support',
                    style: TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600),
                  ),
                  onPressed: () {
                    Navigator.pushNamed(context, AppRoutes.support);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRow(String label, String value, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12.5, color: AppColors.slate500),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : AppColors.slate800,
          ),
        ),
      ],
    );
  }
}
