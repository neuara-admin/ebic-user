import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/api/api_client.dart';
import '../../core/routing/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/ebic_button.dart';

/// Full-screen bespoke Network Error & Offline screen (Section 315 / 322).
/// Displays when internet connectivity is lost or DNS fails to resolve.
class NetworkErrorScreen extends StatefulWidget {
  final VoidCallback? onRetry;
  final String? customMessage;

  const NetworkErrorScreen({
    super.key,
    this.onRetry,
    this.customMessage,
  });

  @override
  State<NetworkErrorScreen> createState() => _NetworkErrorScreenState();
}

class _NetworkErrorScreenState extends State<NetworkErrorScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  bool _isChecking = false;
  String? _statusNotice;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _handleCheckConnection() async {
    if (_isChecking) return;
    HapticFeedback.lightImpact();
    setState(() {
      _isChecking = true;
      _statusNotice = null;
    });

    try {
      // Probe backend connectivity
      final res = await ApiClient().get('/config').timeout(
            const Duration(seconds: 4),
          );

      if (mounted) {
        if (res.success) {
          // Reconnection successful
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
            _isChecking = false;
            _statusNotice = 'Still unable to connect. Please check your data or Wi-Fi.';
          });
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isChecking = false;
          _statusNotice = 'Network unreachable. Please check your connection.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.close_rounded, color: AppColors.slate700),
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
                // Pulsing Icon Frame
                AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    final scale = 1.0 + (_pulseController.value * 0.05);
                    return Transform.scale(
                      scale: scale,
                      child: Container(
                        width: 104,
                        height: 104,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFFFFFBEB), // amber-50
                          border: Border.all(
                            color: const Color(0xFFFDE68A), // amber-200
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                              blurRadius: 24,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.wifi_off_rounded,
                          size: 46,
                          color: Color(0xFFD97706), // amber-600
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 28),

                // Title
                const Text(
                  'No Internet Connection',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.slate900,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 10),

                // Description
                Text(
                  widget.customMessage ??
                      'We could not establish a connection to EBIC servers. Please verify your mobile data or Wi-Fi connection.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14.5,
                    height: 1.45,
                    color: AppColors.slate600,
                  ),
                ),

                if (_statusNotice != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFFECACA)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFFDC2626)),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            _statusNotice!,
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: Color(0xFFB91C1C),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 36),

                // Reconnect Button
                SizedBox(
                  width: double.infinity,
                  child: EbicButton(
                    label: _isChecking ? 'Checking Connection...' : 'Try Again',
                    icon: Icons.refresh_rounded,
                    isLoading: _isChecking,
                    onPressed: _handleCheckConnection,
                  ),
                ),
                const SizedBox(height: 14),

                // Browse Offline Option
                SizedBox(
                  width: double.infinity,
                  child: TextButton.icon(
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      Navigator.pushNamedAndRemoveUntil(
                        context,
                        AppRoutes.mainShell,
                        (r) => false,
                      );
                    },
                    icon: const Icon(Icons.offline_bolt_outlined, size: 18, color: AppColors.slate700),
                    label: const Text(
                      'Browse Cached Data Offline',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.slate800,
                      ),
                    ),
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
