import 'package:ebic_user/core/analytics/crash_reporting_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    CrashReportingService.instance.clearLogs();
  });

  group('User App CrashReportingService Lifecycle & Buffering', () {
    test('initializes gracefully in diagnostic mode when DSN is empty', () async {
      final service = CrashReportingService.instance;
      await service.init(dsn: '', enableSentry: false, environment: 'test');

      expect(service.isInitialized, isTrue);
      expect(service.isSentryEnabled, isFalse);
      expect(service.environment, 'test');
    });

    test('records application errors with PHI scrubbing into bounded buffer', () async {
      final service = CrashReportingService.instance;
      await service.init(dsn: '', enableSentry: false);

      await service.recordError(
        Exception('Network failure for customer rohit@test.com on 9876543210'),
        StackTrace.current,
        reason: 'Payment verification failed for customer ananya',
        context: 'RazorpayCheckout',
        extras: const {'customer_name': 'Ananya', 'amount': 1500},
      );

      final logs = service.getRecentLogs();
      expect(logs.isNotEmpty, isTrue);

      final entry = logs.last;
      expect(entry.level, DiagnosticLogLevel.error);
      expect(entry.error, contains('[REDACTED_EMAIL]'));
      expect(entry.error, contains('[REDACTED_PHONE]'));
      expect(entry.context, 'RazorpayCheckout');
      expect(entry.extras?['customer_name'], '[REDACTED]');
      expect(entry.extras?['amount'], 1500);
    });

    test('records fatal errors properly', () async {
      final service = CrashReportingService.instance;
      await service.init(dsn: '', enableSentry: false);

      await service.recordError(
        StateError('Critical state machine crash'),
        null,
        fatal: true,
        reason: 'Unrecoverable session corruption',
      );

      final logs = service.getRecentLogs();
      final fatalEntry = logs.last;
      expect(fatalEntry.level, DiagnosticLogLevel.fatal);
      expect(fatalEntry.message, 'Unrecoverable session corruption');
    });

    test('records Flutter framework errors via recordFlutterError', () {
      final service = CrashReportingService.instance;
      final details = FlutterErrorDetails(
        exception: FlutterError('RenderFlex overflowed by 16 pixels'),
        context: ErrorDescription('during layout pass in CartView'),
        stack: StackTrace.empty,
      );

      service.recordFlutterError(details);

      final logs = service.getRecentLogs();
      expect(logs.isNotEmpty, isTrue);
      final entry = logs.last;
      expect(entry.context, 'FlutterFramework');
      expect(entry.error, contains('RenderFlex overflowed'));
    });

    test('adds sanitized breadcrumbs', () {
      final service = CrashReportingService.instance;
      service.addBreadcrumb(
        'Navigated to ChefProfile: priya@clinic.in',
        category: 'navigation',
        data: const {'member_email': 'priya@clinic.in', 'chef_id': 'chef_123'},
      );

      final logs = service.getRecentLogs();
      final breadcrumb = logs.last;
      expect(breadcrumb.level, DiagnosticLogLevel.info);
      expect(breadcrumb.message, contains('[REDACTED_EMAIL]'));
      expect(breadcrumb.extras?['member_email'], '[REDACTED]');
      expect(breadcrumb.extras?['chef_id'], 'chef_123');
    });

    test('sets and clears user context without leaking PII', () {
      final service = CrashReportingService.instance;
      service.setUserContext(userId: 'cust_9988_anon', role: 'CUSTOMER');

      final logsAfterSet = service.getRecentLogs();
      expect(logsAfterSet.last.message, 'User session authenticated');

      service.clearUserContext();
      final logsAfterClear = service.getRecentLogs();
      expect(logsAfterClear.last.message, 'User session cleared');
    });

    test('enforces circular FIFO buffer limit without growing unbounded', () async {
      final service = CrashReportingService.instance;
      service.clearLogs();

      for (var i = 0; i < 80; i++) {
        service.addBreadcrumb('Breadcrumb index $i', category: 'test');
      }

      final logs = service.getRecentLogs();
      expect(logs.length, 60); // Max buffer size is 60
      expect(logs.first.message, 'Breadcrumb index 20');
      expect(logs.last.message, 'Breadcrumb index 79');
    });

    test('generates diagnostic summary without leaking PHI', () async {
      final service = CrashReportingService.instance;
      service.clearLogs();
      service.addBreadcrumb('Initiated checkout for 9876543210', category: 'order');
      await service.recordError(
        Exception('Token expired: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxIn0.sig'),
        null,
        reason: 'Payment callback failed for ananya@ebic.in with otp="123456"',
      );

      final summary = service.exportDiagnosticSummary();
      expect(summary, contains('=== EBIC USER DIAGNOSTIC REPORT ==='));
      expect(summary, contains('Release:'));
      expect(summary, contains('[REDACTED_PHONE]'));
      expect(summary, contains('[REDACTED_TOKEN]'));
      expect(summary, contains('[REDACTED_EMAIL]'));
      expect(summary, contains('[REDACTED_SECRET]'));
      expect(summary, isNot(contains('9876543210')));
      expect(summary, isNot(contains('ananya@ebic.in')));
      expect(summary, isNot(contains('123456')));
    });
  });
}

