import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import 'ebic_button.dart';
import 'ebic_outlined_button.dart';

/// Section 322 & 323 Reusable Global Components
/// Provides AppLoading, AppError, AppEmpty, AppOffline, AppRetry, AppSkeleton

/// Global standardized loading indicator
class AppLoading extends StatelessWidget {
  final String? message;
  final double size;
  final Color color;

  const AppLoading({
    super.key,
    this.message,
    this.size = 36.0,
    this.color = AppColors.primary,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: size,
              height: size,
              child: CircularProgressIndicator(
                strokeWidth: 3.0,
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
            if (message != null && message!.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                message!,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.slate600,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Global standardized error component (Section 316, 317, 322)
/// Never exposes stack traces, SQL errors, or internal details
class AppError extends StatelessWidget {
  final String title;
  final String message;
  final IconData icon;
  final VoidCallback? onRetry;
  final String retryLabel;

  const AppError({
    super.key,
    this.title = 'Something went wrong',
    this.message = 'Please try again.',
    this.icon = Icons.error_outline_rounded,
    this.onRetry,
    this.retryLabel = 'Retry',
  });

  factory AppError.generic({VoidCallback? onRetry, String? message}) => AppError(
        title: 'Something went wrong',
        message: message ?? 'We encountered an unexpected error. Please try again.',
        onRetry: onRetry,
      );

  factory AppError.network({VoidCallback? onRetry}) => AppError(
        title: 'Connection Issue',
        message: 'Something went wrong while connecting to EBIC. Please try again.',
        icon: Icons.wifi_off_rounded,
        onRetry: onRetry,
      );

  factory AppError.server({VoidCallback? onRetry}) => AppError(
        title: 'Server Error',
        message: 'Something went wrong on our end. Please try again later.',
        icon: Icons.cloud_off_rounded,
        onRetry: onRetry,
      );

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.danger.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppColors.danger, size: 32),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
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
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 24),
              SizedBox(
                width: 140,
                child: EbicButton(
                  label: retryLabel,
                  icon: Icons.refresh_rounded,
                  onPressed: onRetry,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Global standardized empty state component (Section 323)
class AppEmpty extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const AppEmpty({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  /// Section 323: Orders - "No orders yet."
  factory AppEmpty.orders({VoidCallback? onAction}) => AppEmpty(
        icon: Icons.receipt_long_outlined,
        title: 'No orders yet.',
        message: 'Your past and active chef bookings will appear here.',
        actionLabel: onAction != null ? 'Book a Chef' : null,
        onAction: onAction,
      );

  /// Section 323: Notifications - "You're all caught up."
  factory AppEmpty.notifications() => const AppEmpty(
        icon: Icons.notifications_none_rounded,
        title: "You're all caught up.",
        message: 'No new updates or alerts at the moment.',
      );

  /// Section 323: Support - "No support tickets."
  factory AppEmpty.support({VoidCallback? onAction}) => AppEmpty(
        icon: Icons.support_agent_outlined,
        title: 'No support tickets.',
        message: 'If you need help, raise a ticket and our team will assist you.',
        actionLabel: onAction != null ? 'Get Help' : null,
        onAction: onAction,
      );

  /// Section 323: Addresses - "No saved addresses."
  factory AppEmpty.addresses({VoidCallback? onAction}) => AppEmpty(
        icon: Icons.location_on_outlined,
        title: 'No saved addresses.',
        message: 'Save kitchen delivery addresses for quick booking.',
        actionLabel: onAction != null ? 'Add Address' : null,
        onAction: onAction,
      );

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.slate100,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppColors.slate400, size: 36),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.slate800,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.slate500,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 24),
              EbicButton(
                label: actionLabel!,
                onPressed: onAction,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Global standardized offline state component (Section 315)
/// Distinguishes between No Internet vs Server Unavailable
class AppOffline extends StatelessWidget {
  final bool isNoInternet;
  final VoidCallback? onRetry;

  const AppOffline({
    super.key,
    this.isNoInternet = true,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final title = isNoInternet ? "You're offline" : "EBIC Server Unavailable";
    final message = isNoInternet
        ? 'Please check your internet connection.'
        : "We're having trouble connecting to EBIC servers. Please try again in a moment.";
    final icon = isNoInternet ? Icons.wifi_off_rounded : Icons.cloud_off_rounded;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.warning.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppColors.warning, size: 36),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
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
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 24),
              SizedBox(
                width: 140,
                child: EbicButton(
                  label: 'Try Again',
                  icon: Icons.refresh_rounded,
                  onPressed: onRetry,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Global reusable retry action widget (Section 322)
class AppRetry extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  final String buttonText;

  const AppRetry({
    super.key,
    this.message = 'Something went wrong. Please try again.',
    required this.onRetry,
    this.buttonText = 'Retry',
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontSize: 13, color: AppColors.slate600),
            ),
          ),
          const SizedBox(width: 12),
          EBICOutlinedButton(
            label: buttonText,
            icon: Icons.refresh,
            isFullWidth: false,
            onPressed: onRetry,
          ),
        ],
      ),
    );
  }
}

/// Global shimmer/skeleton placeholder component (Section 322)
class AppSkeleton extends StatefulWidget {
  final double width;
  final double height;
  final BorderRadius? borderRadius;

  const AppSkeleton({
    super.key,
    this.width = double.infinity,
    required this.height,
    this.borderRadius,
  });

  const AppSkeleton.card({
    super.key,
    this.width = double.infinity,
    this.height = 80.0,
  }) : borderRadius = const BorderRadius.all(Radius.circular(12));

  const AppSkeleton.avatar({
    super.key,
    double size = 48.0,
  })  : width = size,
        height = size,
        borderRadius = const BorderRadius.all(Radius.circular(999));

  @override
  State<AppSkeleton> createState() => _AppSkeletonState();
}

class _AppSkeletonState extends State<AppSkeleton>
    with SingleTickerProviderStateMixin {
  late AnimationController _anim;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, child) {
        final opacity = 0.4 + (_anim.value * 0.4);
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: AppColors.slate200.withOpacity(opacity),
            borderRadius: widget.borderRadius ?? BorderRadius.circular(8),
          ),
        );
      },
    );
  }
}
