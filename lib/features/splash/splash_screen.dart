import 'package:flutter/material.dart';
import '../../core/auth/auth_service.dart';
import '../../core/config/app_config.dart';
import '../../core/config/feature_flag_service.dart';
import '../../core/config/remote_config_service.dart';
import '../../core/routing/app_routes.dart';
import '../../core/storage/local_preferences.dart';
import '../../core/theme/app_colors.dart';

/// Module 2 Section 13 — Splash & App Startup
/// Determines initial application state based on session validation and onboarding completion.
/// Adheres strictly to Section 4 & 5 startup state machine:
/// App Launch -> Initialize Core Services -> Load Secure Session -> Check Config ->
/// Validate Session -> Determine Onboarding State -> Route User.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _scaleAnimation = Tween<double>(begin: 0.82, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutBack),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );

    _animationController.forward();
    _startStartupSequence();
  }

  Future<void> _startStartupSequence() async {
    // 1. Minimum brand presentation delay for smooth visual transition
    final minDelayFuture = Future.delayed(const Duration(milliseconds: 1800));

    // 2. Load preferences & restore session
    final prefsFuture = LocalPreferences.getInstance();
    final auth = AuthService();
    final authInitFuture = auth.initialize();

    final results = await Future.wait([minDelayFuture, prefsFuture, authInitFuture]);
    final prefs = results[1] as LocalPreferences;

    if (!mounted) return;

    // 3. Check Maintenance Mode (Section 4.2 & Section 5)
    final remoteConfig = RemoteConfigService();
    if (remoteConfig.isMaintenanceMode) {
      _showMaintenanceNotice();
      return;
    }

    // 4. Routing decision (Section 4.3, Section 5, & Section 6.2)
    final featureFlags = FeatureFlagService();
    if (auth.isAuthenticated) {
      // Authenticated user -> Home
      Navigator.pushReplacementNamed(context, AppRoutes.mainShell);
    } else if (auth.status == AuthSessionStatus.expired) {
      // Session expired -> Login with prompt
      Navigator.pushReplacementNamed(context, AppRoutes.login);
    } else if (featureFlags.isOnboardingEnabled && !prefs.isOnboardingCompleted) {
      // First-time install / uncompleted onboarding -> Onboarding
      Navigator.pushReplacementNamed(context, AppRoutes.onboarding);
    } else {
      // Existing unauthenticated user -> Welcome / Login
      Navigator.pushReplacementNamed(context, AppRoutes.welcome);
    }
  }

  void _showMaintenanceNotice() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(Icons.build_circle_outlined, color: AppColors.primary),
            SizedBox(width: 8),
            Text('Scheduled Maintenance', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: const Text(
          'EBIC is currently undergoing scheduled maintenance to upgrade our nutrition platform. Please check back shortly.',
          style: TextStyle(fontSize: 14, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _startStartupSequence();
            },
            child: const Text('Retry', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.slate950,
      body: Stack(
        children: [
          // Background ambient gradient glow
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.primary.withOpacity(0.2),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -80,
            left: -80,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.primaryDark.withOpacity(0.25),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // Central Branding
          Center(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Icon Box with Shadow & Glow
                    Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.45),
                            blurRadius: 30,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.restaurant_menu_rounded,
                          color: Colors.white,
                          size: 50,
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),

                    // App Name
                    const Text(
                      'EBIC',
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 4,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Tagline
                    const Text(
                      'EVERY BITE COUNTS',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryLight,
                        letterSpacing: 3.5,
                      ),
                    ),
                    const SizedBox(height: 48),

                    // Modern subtle spinner
                    SizedBox(
                      width: 26,
                      height: 26,
                      child: CircularProgressIndicator(
                        valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primaryLight),
                        strokeWidth: 2.5,
                        backgroundColor: Colors.white.withOpacity(0.1),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Footer version info
          Positioned(
            bottom: 24,
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                '${AppConfig.appName} • ${AppConfig.appVersion}',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.35),
                  fontSize: 11,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
