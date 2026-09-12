import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import 'ebic_button.dart';

enum SystemNoticeType { maintenance, forceUpdate }

/// Screen shown when the backend is undergoing maintenance or when a force update is required.
/// Adheres to Section 23 (Global UI States: Maintenance, Force Update).
class MaintenanceScreen extends StatelessWidget {
  final SystemNoticeType type;
  final String? customMessage;
  final VoidCallback? onAction;

  const MaintenanceScreen({
    super.key,
    this.type = SystemNoticeType.maintenance,
    this.customMessage,
    this.onAction,
  });

  const MaintenanceScreen.forceUpdate({
    super.key,
    this.customMessage,
    this.onAction,
  }) : type = SystemNoticeType.forceUpdate;

  @override
  Widget build(BuildContext context) {
    final isMaintenance = type == SystemNoticeType.maintenance;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: (isMaintenance ? AppColors.accent : AppColors.primary).withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isMaintenance ? Icons.build_circle_outlined : Icons.system_update_rounded,
                    color: isMaintenance ? AppColors.accent : AppColors.primary,
                    size: 44,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  isMaintenance ? 'EBIC is Temporarily Unavailable' : 'Update Required',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.slate900,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  customMessage ??
                      (isMaintenance
                          ? 'We are currently performing scheduled maintenance to improve your culinary and nutrition experience. Please check back shortly.'
                          : 'A new version of EBIC is available with critical improvements. Please update your app to continue.'),
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.slate500,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 36),
                SizedBox(
                  width: 200,
                  child: EbicButton(
                    label: isMaintenance ? 'Check Again' : 'Update Now',
                    icon: isMaintenance ? Icons.refresh_rounded : Icons.open_in_new_rounded,
                    onPressed: onAction,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
