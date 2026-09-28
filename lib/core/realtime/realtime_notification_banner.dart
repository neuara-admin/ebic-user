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
    final messenger = AppKeys.scaffoldMessengerKey.currentState;
    if (messenger == null) return;
    final title = e.data['title']?.toString() ?? 'Notification';
    final body = e.data['body']?.toString() ?? '';
    final entityType = e.data['entityType']?.toString();
    final entityId = e.data['entityId']?.toString();

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
              final nav = AppKeys.navigatorKey.currentState;
              if (nav == null) return;
              if (entityType == 'CONSULTATION' && entityId != null) {
                nav.pushNamed(AppRoutes.consultationDetail, arguments: {'consultationId': entityId});
              } else {
                nav.pushNamed(AppRoutes.notifications);
              }
            },
          ),
        ),
      );
  }
}
