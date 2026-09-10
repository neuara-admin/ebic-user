import 'package:flutter/material.dart';
import '../../core/routing/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/ebic_card.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  // Section 57 & 58 Notification entries with deep links
  final List<Map<String, dynamic>> _notifications = [
    {
      'id': 'n_1',
      'category': 'Chef Booking',
      'title': 'Your Chef is on the way',
      'body': 'Executive Chef Vikram Rathore has departed and will reach your kitchen in ~18 minutes.',
      'time': 'Just now',
      'icon': Icons.moped_outlined,
      'route': AppRoutes.chefTracking,
      'args': {'orderId': 'EBIC-8829'},
      'isUnread': true,
    },
    {
      'id': 'n_2',
      'category': 'Ingredient Preparation',
      'title': 'Please prepare your ingredients',
      'body': 'Check off the olive oil, washed broccoli, and brown rice before your chef arrives.',
      'time': '5 mins ago',
      'icon': Icons.checklist_rtl_rounded,
      'route': AppRoutes.preparationChecklist,
      'args': {'orderId': 'EBIC-8829'},
      'isUnread': true,
    },
    {
      'id': 'n_3',
      'category': 'Diet Plan',
      'title': 'Your diet plan has been updated',
      'body': 'Clinical Dietitian Dr. Ananya has updated your weekly high-protein dinner guidelines.',
      'time': '2 hours ago',
      'icon': Icons.restaurant_menu_rounded,
      'route': AppRoutes.dietPlan,
      'args': null,
      'isUnread': false,
    },
    {
      'id': 'n_4',
      'category': 'Consultation',
      'title': 'Your consultation is tomorrow',
      'body': 'Upcoming video session scheduled for tomorrow at 10:00 AM with Dr. Ananya.',
      'time': 'Yesterday',
      'icon': Icons.video_camera_front_outlined,
      'route': AppRoutes.consultationsList,
      'args': null,
      'isUnread': false,
    },
    {
      'id': 'n_5',
      'category': 'Payment',
      'title': 'Your payment was successful',
      'body': 'Payment of ₹1,128 processed successfully via UPI for order #EBIC-8829.',
      'time': '2 days ago',
      'icon': Icons.receipt_long_outlined,
      'route': AppRoutes.orders,
      'args': null,
      'isUnread': false,
    },
    {
      'id': 'n_6',
      'category': 'Health Pass',
      'title': 'Your Health Pass is active',
      'body': 'EBIC Care 3-Month Plan is active for 2 covered household members until 09 Oct 2026.',
      'time': '5 days ago',
      'icon': Icons.health_and_safety_outlined,
      'route': AppRoutes.healthPass,
      'args': null,
      'isUnread': false,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.slate50,
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                for (var n in _notifications) {
                  n['isUnread'] = false;
                }
              });
            },
            child: const Text('Mark all read'),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView.separated(
          padding: const EdgeInsets.all(20),
          itemCount: _notifications.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (ctx, idx) {
            final n = _notifications[idx];
            final isUnread = n['isUnread'] == true;

            return EbicCard(
              border: isUnread ? Border.all(color: AppColors.primary, width: 1.5) : null,
              onTap: () {
                setState(() => n['isUnread'] = false);
                // Section 58: Deep Link navigation
                if (n['route'] != null) {
                  Navigator.pushNamed(context, n['route'], arguments: n['args']);
                }
              },
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isUnread ? AppColors.primarySubtle : AppColors.slate100,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(n['icon'] as IconData, color: isUnread ? AppColors.primary : AppColors.slate600, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              n['category']!,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isUnread ? AppColors.primaryDark : AppColors.slate500,
                              ),
                            ),
                            Text(n['time']!, style: const TextStyle(fontSize: 10, color: AppColors.slate400)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          n['title']!,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: isUnread ? AppColors.slate900 : AppColors.slate800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          n['body']!,
                          style: const TextStyle(fontSize: 12, color: AppColors.slate600, height: 1.3),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
