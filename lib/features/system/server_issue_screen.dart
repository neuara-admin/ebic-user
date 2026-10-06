import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/api/api_client.dart';
import '../../core/routing/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/ebic_button.dart';

/// Full-screen Server Issue and Maintenance screen (Section 316 / 317).
/// Handles 500 (Internal Server Error) and 503 (Scheduled Maintenance).
class ServerIssueScreen extends StatefulWidget {
  final bool isMaintenance;
  final String? estimatedDowntime;
  final VoidCallback? onRetry;

  const ServerIssueScreen({
    super.key,
    this.isMaintenance = false,
    this.estimatedDowntime,
    this.onRetry,
  });

  @override
  State<ServerIssueScreen> createState() => _ServerIssueScreenState();
}

class _ServerIssueScreenState extends State<ServerIssueScreen> {
  bool _isRetrying = false;
  String? _statusError;

  Future<void> _handleRetry() async {
    if (_isRetrying) return;
    HapticFeedback.lightImpact();
    setState(() {
      _isRetrying = true;
      _statusError = null;
    });

    try {
      final res = await ApiClient().get('/config').timeout(
            const Duration(seconds: 4),
          );

      if (mounted) {
        if (res.success) {
          if (widget.onRetry != null) {
            widget.onRetry!();
          } else if (Navigator.canPop(context)) {
            Navigator.pop(context, true);
          } else {
            Navigator.pushNamedAndRemoveUntil(
              context,
              AppRoutes.mainShell,
              (r) => false,
            );
          }
        } else {
          setState(() {
            _isRetrying = false;
            _statusError = 'System is still undergoing updates. Please try again soon.';
          });
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isRetrying = false;
          _statusError = 'Servers are still unreachable. Our engineering team is on it.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.isMaintenance
        ? 'Under Scheduled Maintenance'
        : 'Our Kitchen Servers Are Busy';
    final subtitle = widget.isMaintenance
        ? 'We are upgrading our culinary & nutrition infrastructure to serve you better. We will be back online shortly.'
        : 'We encountered an unexpected server glitch. No data was lost. Our engineering team has been automatically alerted.';

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.slate950 : Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: Icon(Icons.arrow_back_rounded, color: isDark ? Colors.white : AppColors.slate700),
                onPressed: () => Navigator.pop(context),
              )
            : null,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Icon Capsule
                Container(
                  width: 104,
                  height: 104,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.isMaintenance
                        ? (isDark ? const Color(0xFF1E3A8A).withOpacity(0.5) : const Color(0xFFEFF6FF)) // blue
                        : (isDark ? const Color(0xFF4C0519).withOpacity(0.5) : const Color(0xFFFFF1F2)), // rose
                    border: Border.all(
                      color: widget.isMaintenance
                          ? (isDark ? const Color(0xFF1D4ED8) : const Color(0xFFBFDBFE))
                          : (isDark ? const Color(0xFFBE123C) : const Color(0xFFFECDD3)),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: widget.isMaintenance
                            ? const Color(0xFF3B82F6).withValues(alpha: isDark ? 0.25 : 0.12)
                            : const Color(0xFFF43F5E).withValues(alpha: isDark ? 0.25 : 0.12),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Icon(
                    widget.isMaintenance
                        ? Icons.build_circle_outlined
                        : Icons.cloud_off_rounded,
                    size: 46,
                    color: widget.isMaintenance
                        ? const Color(0xFF3B82F6)
                        : const Color(0xFFF43F5E),
                  ),
                ),
                const SizedBox(height: 28),

                // Title
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : AppColors.slate900,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 12),

                // Subtitle
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14.5,
                    height: 1.45,
                    color: isDark ? AppColors.slate400 : AppColors.slate600,
                  ),
                ),

                if (widget.estimatedDowntime != null) ...[
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.slate900 : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isDark ? AppColors.slate800 : AppColors.slate200),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.timer_outlined, size: 18, color: isDark ? AppColors.slate400 : AppColors.slate600),
                        const SizedBox(width: 8),
                        Text(
                          'Estimated completion: ${widget.estimatedDowntime}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isDark ? AppColors.slate300 : AppColors.slate700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                if (_statusError != null) ...[
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF450A0A) : const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: isDark ? const Color(0xFF991B1B) : const Color(0xFFFECACA)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline_rounded, size: 16, color: Color(0xFFDC2626)),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            _statusError!,
                            style: TextStyle(
                              fontSize: 12.5,
                              color: isDark ? const Color(0xFFF87171) : const Color(0xFFB91C1C),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 36),

                // Retry Button
                SizedBox(
                  width: double.infinity,
                  child: EbicButton(
                    label: _isRetrying ? 'Checking Status...' : 'Check Server Status',
                    icon: Icons.refresh_rounded,
                    isLoading: _isRetrying,
                    onPressed: _handleRetry,
                  ),
                ),
                const SizedBox(height: 14),

                // Support & Home
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton.icon(
                      onPressed: () {
                        Navigator.pushNamed(context, AppRoutes.support);
                      },
                      icon: Icon(Icons.support_agent_rounded, size: 18, color: isDark ? AppColors.slate300 : AppColors.slate700),
                      label: Text(
                        'Contact Support',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : AppColors.slate800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    TextButton.icon(
                      onPressed: () {
                        Navigator.pushNamedAndRemoveUntil(
                          context,
                          AppRoutes.mainShell,
                          (r) => false,
                        );
                      },
                      icon: Icon(Icons.home_outlined, size: 18, color: isDark ? AppColors.slate300 : AppColors.slate700),
                      label: Text(
                        'Back to Home',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : AppColors.slate800,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
