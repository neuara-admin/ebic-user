import 'dart:async';
import 'dart:collection';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import '../config/app_config.dart';
import 'phi_scrubber.dart';

enum DiagnosticLogLevel { info, warning, error, fatal }

class DiagnosticLogEntry {
  final DateTime timestamp;
  final DiagnosticLogLevel level;
  final String message;
  final String? error;
  final String? stackTrace;
  final String? context;
  final Map<String, dynamic>? extras;

  DiagnosticLogEntry({
    required this.timestamp,
    required this.level,
    required this.message,
    this.error,
    this.stackTrace,
    this.context,
    this.extras,
  });

  Map<String, dynamic> toJson() => {
    'timestamp': timestamp.toIso8601String(),
    'level': level.name,
    'message': message,
    if (error != null) 'error': error,
    if (stackTrace != null) 'stack': stackTrace,
    if (context != null) 'context': context,
    if (extras != null) 'extras': extras,
  };

  @override
  String toString() {
    final errStr = error != null ? ' - $error' : '';
    return '[${timestamp.toIso8601String()}] [${level.name.toUpperCase()}] $message$errStr';
  }
}

/// Centralized crash reporting and observability service for EBIC Customer App.
/// Adheres strictly to Section 11.4 (Crash Reporting) and Section 32 (Logging Policy).
class CrashReportingService {
  static final CrashReportingService _instance = CrashReportingService._internal();
  factory CrashReportingService() => _instance;
  static CrashReportingService get instance => _instance;
  CrashReportingService._internal();

  static const int _maxBufferSize = 60;
  final Queue<DiagnosticLogEntry> _logBuffer = Queue<DiagnosticLogEntry>();

  bool _initialized = false;
  bool _sentryEnabled = false;
  String _environment = 'development';
  String _release = 'ebic_user@${AppConfig.appVersion}';

  bool get isInitialized => _initialized;
  bool get isSentryEnabled => _sentryEnabled;
  String get environment => _environment;
  String get release => _release;

  /// Initializes crash reporting.
  /// If [dsn] (or `--dart-define=SENTRY_DSN`) is provided, Sentry Flutter telemetry
  /// is wired with automated crash capturing and strict PHI scrubbing.
  /// If DSN is omitted, the app executes [appRunner] in local diagnostic mode.
  Future<void> init({
    String? dsn,
    String? environment,
    String? release,
    FutureOr<void> Function()? appRunner,
    bool enableSentry = true,
  }) async {
    const defineDsn = String.fromEnvironment('SENTRY_DSN');
    final effectiveDsn = (dsn ?? defineDsn).trim();

    const defineEnv = String.fromEnvironment('ENVIRONMENT');
    _environment = (environment ?? (defineEnv.isNotEmpty ? defineEnv : (kReleaseMode ? 'production' : (kProfileMode ? 'profile' : 'development')))).trim();

    const defineRelease = String.fromEnvironment('APP_RELEASE');
    _release = (release ?? (defineRelease.isNotEmpty ? defineRelease : 'ebic_user@${AppConfig.appVersion}')).trim();

    if (enableSentry && effectiveDsn.isNotEmpty) {
      await SentryFlutter.init(
        (options) {
          options.dsn = effectiveDsn;
          options.environment = _environment;
          options.release = _release;
          options.tracesSampleRate = kReleaseMode ? 0.2 : 1.0;
          options.sendDefaultPii = false; // Strictly disabled for user health privacy
          options.attachStacktrace = true;
          options.enableAutoSessionTracking = true;

          // Wire PHI scrubbing hooks
          options.beforeSend = (event, hint) => PhiScrubber.scrubSentryEvent(event);
          options.beforeBreadcrumb = (breadcrumb, hint) =>
              breadcrumb != null ? PhiScrubber.scrubBreadcrumb(breadcrumb) : null;
        },
        appRunner: appRunner,
      );
      _sentryEnabled = true;
    } else {
      _sentryEnabled = false;
      if (appRunner != null) {
        await appRunner();
      }
    }

    _initialized = true;

    addBreadcrumb(
      'CrashReportingService initialized (Sentry: $_sentryEnabled, Env: $_environment)',
      category: 'lifecycle',
    );
  }

  /// Records an uncaught exception, platform error, or caught failure.
  Future<void> recordError(
    dynamic exception,
    StackTrace? stack, {
    String? reason,
    String? correlationId,
    bool fatal = false,
    Map<String, dynamic>? extras,
    String? context,
  }) async {
    final scrubbedReason = reason != null ? PhiScrubber.scrubString(reason) : null;
    final scrubbedContext = context != null ? PhiScrubber.scrubString(context) : null;
    final scrubbedExtras = extras != null ? PhiScrubber.scrubMap(extras) : null;
    final scrubbedErrorStr = PhiScrubber.scrubString(exception.toString());
    final scrubbedStackStr = stack != null ? PhiScrubber.scrubString(stack.toString()) : null;

    final entry = DiagnosticLogEntry(
      timestamp: DateTime.now(),
      level: fatal ? DiagnosticLogLevel.fatal : DiagnosticLogLevel.error,
      message: scrubbedReason ?? (fatal ? 'Fatal unhandled exception' : 'Application error'),
      error: scrubbedErrorStr,
      stackTrace: scrubbedStackStr,
      context: scrubbedContext,
      extras: scrubbedExtras,
    );

    _appendLog(entry);

    if (kDebugMode) {
      debugPrint('🚨 [CrashReporting] ${fatal ? "💥 FATAL: " : ""}$scrubbedErrorStr');
      if (scrubbedReason != null) debugPrint('   Reason: $scrubbedReason');
      if (scrubbedContext != null) debugPrint('   Context: $scrubbedContext');
      if (correlationId != null) debugPrint('   Correlation ID: $correlationId');
      if (stack != null) debugPrint('   Stack:\n$stack');
    }

    if (_sentryEnabled) {
      try {
        await Sentry.captureException(
          exception,
          stackTrace: stack,
          withScope: (scope) {
            if (fatal) {
              scope.level = SentryLevel.fatal;
              scope.setTag('fatal', 'true');
            }
            if (scrubbedReason != null) {
              scope.setTag('reason', scrubbedReason);
            }
            if (scrubbedContext != null) {
              scope.setTag('context', scrubbedContext);
            }
            if (correlationId != null) {
              scope.setTag('correlation_id', correlationId);
            }
            if (scrubbedExtras != null) {
              scope.setContexts('extra_details', scrubbedExtras);
            }
          },
        );
      } catch (sentryErr) {
        if (kDebugMode) {
          debugPrint('⚠️ [CrashReporting] Failed to dispatch to Sentry: $sentryErr');
        }
      }
    }
  }

  /// Specialized handler for Flutter framework errors.
  void recordFlutterError(FlutterErrorDetails details) {
    if (kDebugMode) {
      FlutterError.presentError(details);
    }

    unawaited(
      recordError(
        details.exception,
        details.stack,
        reason: details.context?.toString(),
        context: 'FlutterFramework',
        fatal: false,
      ),
    );
  }

  /// Appends a safe, sanitized breadcrumb to the diagnostic log and Sentry.
  void addBreadcrumb(
    String message, {
    String? category,
    Map<String, dynamic>? data,
    SentryLevel? level,
  }) {
    final scrubbedMessage = PhiScrubber.scrubString(message);
    final scrubbedData = data != null ? PhiScrubber.scrubMap(data) : null;

    final entry = DiagnosticLogEntry(
      timestamp: DateTime.now(),
      level: DiagnosticLogLevel.info,
      message: scrubbedMessage,
      context: category,
      extras: scrubbedData,
    );
    _appendLog(entry);

    if (kDebugMode) {
      debugPrint('ℹ️ [Breadcrumb] [${category ?? "general"}] $scrubbedMessage');
    }

    if (_sentryEnabled) {
      try {
        Sentry.addBreadcrumb(
          Breadcrumb(
            message: scrubbedMessage,
            category: category,
            data: scrubbedData,
            level: level ?? SentryLevel.info,
          ),
        );
      } catch (_) {}
    }
  }

  /// Safe operational log that avoids leaking secrets (Section 32).
  void log(String message) {
    addBreadcrumb(message, category: 'log');
  }

  /// Sets user context using ONLY an opaque identifier.
  /// Strictly rejects patient PII, names, or email addresses to comply with privacy laws.
  void setUserContext({
    required String userId,
    String? role,
  }) {
    final sanitizedId = PhiScrubber.scrubString(userId);
    addBreadcrumb('User session authenticated', category: 'auth');

    if (_sentryEnabled) {
      Sentry.configureScope((scope) {
        scope.setUser(
          SentryUser(
            id: sanitizedId,
            data: {'role': role ?? 'CUSTOMER'},
          ),
        );
      });
    }
  }

  /// Clears user context upon sign-out or session expiration.
  void clearUserContext() {
    addBreadcrumb('User session cleared', category: 'auth');

    if (_sentryEnabled) {
      Sentry.configureScope((scope) {
        scope.setUser(null);
      });
    }
  }

  void _appendLog(DiagnosticLogEntry entry) {
    if (_logBuffer.length >= _maxBufferSize) {
      _logBuffer.removeFirst();
    }
    _logBuffer.addLast(entry);
  }

  /// Returns recent diagnostic log entries.
  List<DiagnosticLogEntry> getRecentLogs() {
    return List.unmodifiable(_logBuffer);
  }

  /// Clears in-memory diagnostic buffer (primarily for testing).
  void clearLogs() {
    _logBuffer.clear();
  }

  /// Generates a sanitized text diagnostic summary for support tickets or audit.
  String exportDiagnosticSummary() {
    final buffer = StringBuffer();
    final platform = kIsWeb ? 'web' : Platform.operatingSystem;

    buffer.writeln('=== EBIC USER DIAGNOSTIC REPORT ===');
    buffer.writeln('Release: $_release');
    buffer.writeln('Environment: $_environment');
    buffer.writeln('Platform: $platform');
    buffer.writeln('Sentry Wired: $_sentryEnabled');
    buffer.writeln('Report Time: ${DateTime.now().toUtc().toIso8601String()}');
    buffer.writeln('Buffered Logs Count: ${_logBuffer.length}');
    buffer.writeln('-----------------------------------');

    for (final log in _logBuffer) {
      buffer.writeln(log.toString());
      if (log.context != null) {
        buffer.writeln('  Context: ${log.context}');
      }
      if (log.extras != null && log.extras!.isNotEmpty) {
        buffer.writeln('  Extras: ${log.extras}');
      }
    }
    buffer.writeln('===================================');

    return buffer.toString();
  }
}
