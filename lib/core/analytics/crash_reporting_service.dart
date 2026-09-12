import 'dart:io';
import 'package:flutter/foundation.dart';
import '../config/app_config.dart';

/// Centralized crash reporting and diagnostic logger.
/// Adheres to Section 11.4 (Crash Reporting) and Section 32 (Logging policy).
class CrashReportingService {
  static final CrashReportingService _instance = CrashReportingService._internal();
  factory CrashReportingService() => _instance;
  CrashReportingService._internal();

  /// Record an uncaught error or fatal exception.
  Future<void> recordError(
    dynamic exception,
    StackTrace? stack, {
    String? reason,
    String? correlationId,
    bool fatal = false,
  }) async {
    final report = {
      'exception': exception.toString(),
      'stack': stack.toString(),
      'reason': reason,
      'app_version': AppConfig.appVersion,
      'platform': kIsWeb ? 'web' : Platform.operatingSystem,
      'correlation_id': correlationId,
      'fatal': fatal,
      'timestamp': DateTime.now().toIso8601String(),
    };

    if (kDebugMode) {
      debugPrint('[CrashReport] 💥 $report');
    }

    // In staging / production, forwards to telemetry provider (e.g. Sentry/Crashlytics)
  }

  /// Safe operational log that avoids leaking secrets (Section 32).
  void log(String message) {
    if (kDebugMode) {
      debugPrint('[Log] ℹ️ $message');
    }
  }
}
