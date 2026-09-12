import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import 'ebic_button.dart';

class EmptyStateView extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyStateView({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  // Section 77 Predefined Empty States
  factory EmptyStateView.noHealthPass({VoidCallback? onExplore}) => EmptyStateView(
        icon: Icons.card_membership_outlined,
        title: 'No Health Pass',
        message: "You don't have an active Health Pass.",
        actionLabel: 'Explore Health Pass',
        onAction: onExplore,
      );

  factory EmptyStateView.noDietPlan() => const EmptyStateView(
        icon: Icons.restaurant_menu_outlined,
        title: 'No Diet Plan',
        message: "Your diet plan isn't available yet.",
      );

  factory EmptyStateView.noConsultation({VoidCallback? onBook}) => EmptyStateView(
        icon: Icons.video_call_outlined,
        title: 'No Upcoming Consultation',
        message: "You don't have an upcoming consultation.",
        actionLabel: 'Book Consultation',
        onAction: onBook,
      );

  factory EmptyStateView.noOrders({VoidCallback? onBookChef}) => EmptyStateView(
        icon: Icons.receipt_long_outlined,
        title: 'No Orders',
        message: 'Your Chef Bookings will appear here.',
        actionLabel: 'Book a Chef',
        onAction: onBookChef,
      );

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.primarySubtle,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppColors.primary, size: 32),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.slate900,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.slate500,
              ),
              textAlign: TextAlign.center,
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 20),
              SizedBox(
                width: 200,
                child: EbicButton(
                  label: actionLabel!,
                  onPressed: onAction,
                  isFullWidth: false,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Typedef matching Section 6.2 specification naming.
typedef EBICEmptyView = EmptyStateView;
