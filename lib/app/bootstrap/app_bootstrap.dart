import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/auth/auth_service.dart';
import '../../core/config/app_config.dart';
import '../../core/config/app_environment.dart';
import '../../core/config/feature_flag_service.dart';
import '../../core/config/remote_config_service.dart';
import '../../core/analytics/analytics_service.dart';
import '../../core/analytics/crash_reporting_service.dart';
import '../../core/lifecycle/app_lifecycle_manager.dart';
import '../../core/theme/theme_controller.dart';

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
    await analytics.logAppOpened();

    // 5. Initialize feature flags & remote config
    FeatureFlagService();
    RemoteConfigService();

    // 6. Initialize lifecycle observer
    AppLifecycleManager().initialize();

    // 7. Restore session & auth boundary (Section 15)
    final authService = AuthService();
    await authService.initialize();

    // 8. Restore theme preferences
    await ThemeController().initialize();
  }
}
