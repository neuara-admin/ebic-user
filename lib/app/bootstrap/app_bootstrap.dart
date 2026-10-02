import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/config/app_config.dart';
import '../../core/config/app_environment.dart';
import '../../core/config/feature_flag_service.dart';
import '../../core/config/remote_config_service.dart';
import 'package:firebase_core/firebase_core.dart';
import '../../core/analytics/analytics_service.dart';
import '../../core/analytics/crash_reporting_service.dart';
import '../../core/lifecycle/app_lifecycle_manager.dart';
import '../../core/notifications/device_registration_service.dart';
import '../../core/realtime/realtime_notification_banner.dart';
import '../../core/realtime/realtime_service.dart';
import '../../core/theme/theme_controller.dart';
import '../../firebase_options.dart';

/// Deterministic Application Bootstrap sequence.
/// Adheres strictly to Section 13 (Application Bootstrap):
/// 1. Initialize Flutter
/// 2. Load environment
/// 3. Initialize logging & crash reporting
/// 4. Initialize storage & local preferences
/// 5. Initialize API client
/// 6. Initialize analytics
/// 7. Load remote configuration & feature flags
/// 8. Restore session & auth boundary
/// 9. Initialize lifecycle & router
class AppBootstrap {
  AppBootstrap._();

  static Future<void> initialize({
    EnvironmentType environment = EnvironmentType.development,
  }) async {
    // 1. Initialize Flutter bindings
    WidgetsFlutterBinding.ensureInitialized();

    // Initialize Firebase Core
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } catch (e) {
      debugPrint('⚠️ [Firebase] initializeApp: $e');
    }

    // Phones are portrait-only (like Swiggy / Uber); tablets may rotate — their
    // content is width-capped by ResponsiveAppFrame.
    final view = WidgetsBinding.instance.platformDispatcher.views.first;
    if (view.physicalSize.shortestSide / view.devicePixelRatio < 600) {
      unawaited(SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]));
    }

    // System overlay styling
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
    );

    // 2. Load environment
    AppEnvironment.initialize(
      type: environment,
      apiBaseUrlOverride: AppConfig.defaultBaseUrl,
    );

    // 3. Initialize logging & crash reporting
    final crashReporting = CrashReportingService();
    FlutterError.onError = (details) {
      if (kDebugMode) FlutterError.presentError(details);
      crashReporting.recordError(details.exception, details.stack, fatal: true);
    };

    // 4. Initialize analytics
    final analytics = AnalyticsService();
    unawaited(analytics.logAppOpened());

    // 5. Initialize feature flags & remote config
    FeatureFlagService();
    RemoteConfigService();

    // 6. Initialize lifecycle observer
    AppLifecycleManager().initialize();

    // 7. Session restore (network-bound, Section 15) is performed by
    //    SplashScreen so it never blocks the first frame.

    // 8. Restore theme preferences
    await ThemeController().initialize();

    // 9. Live updates: the socket follows the session (connects once the
    //    splash screen restores it / the user logs in), and new
    //    notifications pop up as an in-app banner on any screen.
    RealtimeService().bindToSession();
    RealtimeNotificationBanner.start();
    unawaited(DeviceRegistrationService().initialize());
  }
}
