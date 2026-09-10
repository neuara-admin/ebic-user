import 'package:flutter/material.dart';
import '../../core/routing/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/ebic_card.dart';
import '../../shared/widgets/ebic_button.dart';

class BookingConfirmationScreen extends StatelessWidget {
  final Map<String, dynamic> confirmationData;

  const BookingConfirmationScreen({super.key, required this.confirmationData});

  @override
  Widget build(BuildContext context) {
    final orderId = confirmationData['orderId']?.toString() ?? 'EBIC-8829';
    final bookingType = confirmationData['bookingType']?.toString() ?? 'Instant';
    final cookingTime = confirmationData['cookingTime']?.toString() ?? '35';
    final total = confirmationData['total'] ?? 0.0;
    final estimatedArrival = confirmationData['arrivalMinutes']?.toString() ?? '22';

    return WillPopScope(
      onWillPop: () async {
        Navigator.pushNamedAndRemoveUntil(context, AppRoutes.mainShell, (r) => false);
        return false;
      },
      child: Scaffold(
        backgroundColor: AppColors.slate50,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: const Text('Booking Confirmed'),
          actions: [
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                Navigator.pushNamedAndRemoveUntil(context, AppRoutes.mainShell, (r) => false);
              },
            ),
          ],
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const SizedBox(height: 16),
                // Success Badge Animation / Icon
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 54),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Booking Confirmed ✓',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.slate900),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Your private chef has been automatically dispatched!',
                  style: TextStyle(color: AppColors.slate500, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),

                // Confirmation card summary
                EbicCard(
                  child: Column(
                    children: [
                      _buildInfoRow('Booking ID', orderId.toUpperCase(), isHighlight: true),
                      const Divider(height: 20),
                      _buildInfoRow('Booking Type', bookingType),
                      const Divider(height: 20),
                      _buildInfoRow('Chef Status', 'Assigned & En Route', valueColor: AppColors.primary),
                      const Divider(height: 20),
                      _buildInfoRow('Estimated Arrival', '$estimatedArrival minutes', isHighlight: true),
                      const Divider(height: 20),
                      _buildInfoRow('Estimated Cooking Time', '$cookingTime minutes'),
                      const Divider(height: 20),
                      _buildInfoRow('Total Amount', '₹${total is num ? total.toStringAsFixed(0) : total}', isHighlight: true),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Primary Action: Track Chef
                EbicButton(
                  label: 'Track Chef',
                  icon: Icons.navigation_outlined,
                  onPressed: () {
                    Navigator.pushNamed(
                      context,
                      AppRoutes.chefTracking,
                      arguments: {'orderId': orderId},
                    );
                  },
                ),
                const SizedBox(height: 12),

                // Secondary Action: View Preparation List
                EbicButton(
                  label: 'View Preparation List',
                  icon: Icons.checklist_rtl_rounded,
                  variant: EbicButtonVariant.outline,
                  onPressed: () {
                    Navigator.pushNamed(
                      context,
                      AppRoutes.preparationChecklist,
                      arguments: {'orderId': orderId},
                    );
                  },
                ),
                const SizedBox(height: 12),

                // Tertiary Action: View Booking / Orders
                EbicButton(
                  label: 'View Booking Details',
                  icon: Icons.receipt_outlined,
                  variant: EbicButtonVariant.ghost,
                  onPressed: () {
                    Navigator.pushNamed(
                      context,
                      AppRoutes.orderDetail,
                      arguments: {'orderId': orderId},
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isHighlight = false, Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: AppColors.slate500, fontSize: 13)),
        Text(
          value,
          style: TextStyle(
            fontSize: isHighlight ? 15 : 13,
            fontWeight: isHighlight ? FontWeight.bold : FontWeight.w600,
            color: valueColor ?? (isHighlight ? AppColors.slate900 : AppColors.slate800),
          ),
        ),
      ],
    );
  }
}
