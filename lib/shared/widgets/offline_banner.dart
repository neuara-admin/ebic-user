import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

/// Top banner displayed when the device loses network connectivity.
/// Adheres to Section 10.3 & 23 (Offline State).
class OfflineBanner extends StatelessWidget {
  final VoidCallback? onRetry;

  const OfflineBanner({
    super.key,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.slate900,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            const Icon(Icons.wifi_off_rounded, color: AppColors.accent, size: 16),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                "You're offline. Some actions are temporarily unavailable.",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (onRetry != null)
              GestureDetector(
                onTap: onRetry,
                child: const Padding(
                  padding: EdgeInsets.only(left: 8),
                  child: Text(
                    'Retry',
                    style: TextStyle(
                      color: AppColors.primaryLight,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
