import 'dart:async';
import 'package:flutter/material.dart';
import '../routing/app_routes.dart';
import '../theme/app_colors.dart';
import 'realtime_service.dart';

/// App-wide keys so a live notification can be shown (and tapped) on
/// whatever screen the user happens to be on.
class AppKeys {
  static final navigatorKey = GlobalKey<NavigatorState>();
  static final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();
}

/// Shows each live `notification.created` event as an in-app banner.
class RealtimeNotificationBanner {
  static StreamSubscription<StandardSocketEnvelope>? _sub;

  static void start() {
    _sub ??= RealtimeService().notifications.listen(_show);
  }

  static void _show(StandardSocketEnvelope e) {
    showBanner(
      title: e.data['title']?.toString() ?? 'Notification',
      body: e.data['body']?.toString() ?? '',
      data: e.data,
    );
  }

  /// Displays an in-app banner for any real-time notification (WebSocket or FCM foreground).
  static void showBanner({
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) {
    final messenger = AppKeys.scaffoldMessengerKey.currentState;
    if (messenger == null) return;

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.slate900,
          duration: const Duration(seconds: 6),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
              if (body.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(body, style: const TextStyle(color: Colors.white70, fontSize: 12.5)),
              ],
            ],
          ),
          action: SnackBarAction(
            label: 'VIEW',
            textColor: AppColors.primaryLight,
            onPressed: () {
              if (data != null) {
                navigateForPayload(data);
              } else {
                AppKeys.navigatorKey.currentState?.pushNamed(AppRoutes.notifications);
              }
            },
          ),
        ),
      );
  }

  /// Universal deep-link navigation for notifications (socket, in-app, or FCM push).
  static void navigateForPayload(Map<String, dynamic> data) {
    final nav = AppKeys.navigatorKey.currentState;
    if (nav == null) return;

    final type = data['type']?.toString().toUpperCase();
    final link = data['deepLink']?.toString().toLowerCase() ?? '';
    final entityType = data['entityType']?.toString().toUpperCase() ?? '';
    final entityId = data['entityId']?.toString();

    if (entityType == 'CHAT_THREAD' || type == 'DIETITIAN_CHAT_MESSAGE' || link.contains('/chat')) {
      nav.pushNamed(AppRoutes.consultationsList);
    } else if (entityType == 'DIET_PLAN' || type == 'DIET_PLAN_READY' || link.contains('/diet-plan')) {
      nav.pushNamed(AppRoutes.dietPlan);
    } else if ((entityType == 'ORDER' || entityType == 'CHEF_BOOKING') && entityId != null) {
      nav.pushNamed(AppRoutes.orderDetail, arguments: {'orderId': entityId});
    } else if (entityType == 'CONSULTATION' && entityId != null) {
      nav.pushNamed(AppRoutes.consultationDetail, arguments: {'consultationId': entityId});
    } else if (entityType == 'HEALTH_PASS' || link.contains('/health-pass')) {
      nav.pushNamed(AppRoutes.healthPass);
    } else {
      nav.pushNamed(AppRoutes.notifications);
    }
  }
}
