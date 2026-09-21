import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/auth/auth_service.dart';
import '../../core/config/app_config.dart';
import '../../core/config/feature_flag_service.dart';
import '../../core/config/remote_config_service.dart';
import '../../core/routing/app_routes.dart';
import '../../core/storage/local_preferences.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/maintenance_screen.dart';
import '../system/app_update_screen.dart';

/// Module 2 Section 13 & Module 20 Sections 310–314 — Splash & App Startup
/// Determines initial application state based on session validation, remote config, and onboarding completion.
/// Adheres strictly to Section 4 & 5 startup state machine:
/// App Launch -> Initialize Core Services -> Load Secure Session -> Check Remote Config ->
/// Maintenance / App Update Check -> Validate Session -> Determine Onboarding State -> Route User.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _introController;
  late AnimationController _pulseController;
  late AnimationController _progressController;

  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _pulseGlow;

  String _loadingMilestone = 'Initializing clinical engine...';
  Timer? _milestoneTimer;

  @override
  void initState() {
    super.initState();

    // 1. Entrance animation
    _introController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _scaleAnimation = Tween<double>(begin: 0.82, end: 1.0).animate(
      CurvedAnimation(parent: _introController, curve: Curves.easeOutBack),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _introController, curve: const Interval(0.0, 0.7, curve: Curves.easeOut)),
    );
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero).animate(
      CurvedAnimation(parent: _introController, curve: Curves.easeOutCubic),
    );

    // 2. Ambient breathing glow
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);

    _pulseGlow = Tween<double>(begin: 0.85, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOutSine),
    );

    // 3. Progress bar animation
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );

    _introController.forward();
    _progressController.forward();

    _cycleMilestones();
    _startStartupSequence();
  }

  void _cycleMilestones() {
    final milestones = [
      'Initializing clinical engine...',
      'Securing certified chef network...',
      'Personalizing nutrition matrix...',
      'Welcome to EBIC',
    ];
    var index = 0;
    _milestoneTimer = Timer.periodic(const Duration(milliseconds: 550), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      index++;
      if (index < milestones.length) {
        setState(() {
          _loadingMilestone = milestones[index];
        });
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> _startStartupSequence() async {
    try {
      // 1. Minimum brand presentation delay for smooth visual transition
      final minDelayFuture = Future.delayed(const Duration(milliseconds: 2200));

      // 2. Load preferences & restore session & remote config concurrently (Section 311)
      final prefsFuture = LocalPreferences.getInstance();
      final auth = AuthService();
      final authInitFuture = auth.initialize();
      final remoteConfig = RemoteConfigService();
      final remoteConfigFuture = remoteConfig.fetchRemoteConfig();

      final results = await Future.wait([minDelayFuture, prefsFuture, authInitFuture, remoteConfigFuture]);
      final prefs = results[1] as LocalPreferences;

      if (!mounted) return;

      // 3. Check Maintenance Mode (Section 314)
      if (remoteConfig.isMaintenanceMode) {
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => MaintenanceScreen(
              customMessage: remoteConfig.maintenanceMessage,
              onAction: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const SplashScreen()),
                );
              },
            ),
            transitionsBuilder: (_, a, __, c) => FadeTransition(opacity: a, child: c),
          ),
        );
        return;
      }

      // 4. Check App Update / Force Update (Section 313)
      if (remoteConfig.isForceUpdateRequired(AppConfig.appVersion)) {
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => const AppUpdateScreen(isForced: true),
            transitionsBuilder: (_, a, __, c) => FadeTransition(opacity: a, child: c),
          ),
        );
        return;
      }

      // 5. Routing decision (Section 310 & 312)
      final featureFlags = FeatureFlagService();
      String destinationRoute;
      if (auth.isAuthenticated) {
        // Authenticated user -> Home shell
        destinationRoute = AppRoutes.mainShell;
      } else if (auth.status == AuthSessionStatus.expired) {
        // Session expired -> Login with prompt
        destinationRoute = AppRoutes.login;
      } else if (featureFlags.isOnboardingEnabled && !prefs.isOnboardingCompleted) {
        // First-time install / uncompleted onboarding -> Onboarding
        destinationRoute = AppRoutes.onboarding;
      } else {
        // Existing unauthenticated user -> Welcome
        destinationRoute = AppRoutes.welcome;
      }

      Navigator.pushReplacementNamed(context, destinationRoute);
    } catch (_) {
      // Fallback safety route in case of unforeseen initialization error
      if (mounted) {
        Navigator.pushReplacementNamed(context, AppRoutes.welcome);
      }
    }
  }

  @override
  void dispose() {
    _milestoneTimer?.cancel();
    _introController.dispose();
    _pulseController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.slate950,
      body: Stack(
        children: [
          // Dynamic ambient radiant backgrounds
          AnimatedBuilder(
            animation: _pulseGlow,
            builder: (context, child) {
              return Stack(
                children: [
                  // Top-Right Emerald Aura
                  Positioned(
                    top: -120 * _pulseGlow.value,
                    right: -100 * _pulseGlow.value,
                    child: Container(
                      width: 380 * _pulseGlow.value,
                      height: 380 * _pulseGlow.value,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            AppColors.primaryLight.withOpacity(0.22),
                            AppColors.primary.withOpacity(0.08),
                            Colors.transparent,
                          ],
                          stops: const [0.0, 0.45, 1.0],
                        ),
                      ),
                    ),
                  ),

                  // Center Culinary Amber Aura
                  Positioned(
                    top: MediaQuery.of(context).size.height * 0.25,
                    left: MediaQuery.of(context).size.width * 0.1,
                    child: Container(
                      width: 260 * _pulseGlow.value,
                      height: 260 * _pulseGlow.value,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            AppColors.accent.withOpacity(0.12),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Bottom-Left Deep Emerald / Forest Glow
                  Positioned(
                    bottom: -110 * _pulseGlow.value,
                    left: -90 * _pulseGlow.value,
                    child: Container(
                      width: 360 * _pulseGlow.value,
                      height: 360 * _pulseGlow.value,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            AppColors.primaryDark.withOpacity(0.35),
                            const Color(0xFF064E3B).withOpacity(0.15),
                            Colors.transparent,
                          ],
                          stops: const [0.0, 0.5, 1.0],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),

          // Central Cinematic Branding
          Center(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Dual-ring emblem container
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          // Outer ambient halo
                          AnimatedBuilder(
                            animation: _pulseGlow,
                            builder: (context, child) {
                              return Container(
                                width: 114 * _pulseGlow.value,
                                height: 114 * _pulseGlow.value,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.primaryLight.withOpacity(0.08),
                                  border: Border.all(
                                    color: AppColors.primaryLight.withOpacity(0.18),
                                    width: 1.5,
                                  ),
                                ),
                              );
                            },
                          ),

                          // Inner Luxury Emblem Box
                          Container(
                            width: 96,
                            height: 96,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFF10B981),
                                  Color(0xFF059669),
                                  Color(0xFF047857),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(28),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.28),
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primaryLight.withOpacity(0.45),
                                  blurRadius: 36,
                                  offset: const Offset(0, 14),
                                  spreadRadius: 2,
                                ),
                                BoxShadow(
                                  color: AppColors.accent.withOpacity(0.2),
                                  blurRadius: 24,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                // Chef & Nutrition Combined Icon
                                const Icon(
                                  Icons.restaurant_menu_rounded,
                                  color: Colors.white,
                                  size: 46,
                                ),
                                // Sparkle badge top right
                                Positioned(
                                  top: 14,
                                  right: 14,
                                  child: Container(
                                    padding: const EdgeInsets.all(3),
                                    decoration: BoxDecoration(
                                      color: AppColors.accentLight,
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppColors.accentLight.withOpacity(0.6),
                                          blurRadius: 6,
                                        ),
                                      ],
                                    ),
                                    child: const Icon(
                                      Icons.auto_awesome,
                                      color: AppColors.slate950,
                                      size: 11,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),

                      // Brand Wordmark
                      Text(
                        'EBIC',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 42,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 6,
                          height: 1.0,
                          shadows: [
                            Shadow(
                              color: AppColors.primaryLight.withOpacity(0.5),
                              blurRadius: 20,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Tagline
                      Text(
                        'EVERY BITE COUNTS',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: AppColors.emerald400,
                          letterSpacing: 4.5,
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Clinical & Culinary Pill Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.slate900.withOpacity(0.75),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: AppColors.primaryLight.withOpacity(0.25),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.verified_rounded,
                              color: AppColors.primaryLight,
                              size: 14,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Clinical Nutrition • In-Home Chefs',
                              style: GoogleFonts.inter(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: Colors.white.withOpacity(0.85),
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 52),

                      // Animated Progress Track
                      AnimatedBuilder(
                        animation: _progressController,
                        builder: (context, child) {
                          return Container(
                            width: 160,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(2),
                            ),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Container(
                                width: 160 * _progressController.value,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      AppColors.primaryLight,
                                      AppColors.accentLight,
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(2),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.primaryLight.withOpacity(0.6),
                                      blurRadius: 6,
                                      offset: const Offset(0, 1),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 14),

                      // Milestone Status Label with Animated Switcher
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        transitionBuilder: (child, animation) {
                          return FadeTransition(
                            opacity: animation,
                            child: SlideTransition(
                              position: Tween<Offset>(
                                begin: const Offset(0, 0.2),
                                end: Offset.zero,
                              ).animate(animation),
                              child: child,
                            ),
                          );
                        },
                        child: Text(
                          _loadingMilestone,
                          key: ValueKey<String>(_loadingMilestone),
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppColors.slate400,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Security & Compliance Footer
          Positioned(
            bottom: 24,
            left: 20,
            right: 20,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.lock_outline_rounded,
                      size: 11,
                      color: Colors.white.withOpacity(0.3),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'HIPAA & FSSAI Compliant Health Infrastructure',
                      style: GoogleFonts.inter(
                        color: Colors.white.withOpacity(0.32),
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  '${AppConfig.appName} • v${AppConfig.appVersion}',
                  style: GoogleFonts.inter(
                    color: Colors.white.withOpacity(0.22),
                    fontSize: 10,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

