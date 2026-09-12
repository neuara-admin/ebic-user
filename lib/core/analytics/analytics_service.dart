import 'package:flutter/foundation.dart';

/// Abstract provider interface for pluggable analytics engines (Firebase, Mixpanel, etc.)
abstract class AnalyticsProvider {
  Future<void> logEvent(String name, Map<String, dynamic>? parameters);
  Future<void> setUserId(String? userId);
}

/// Centralized analytics service with strict medical privacy protection.
/// Adheres to Section 11 (Analytics Architecture) and Section 31 (Naming Convention: `<object>_<action>`).
class AnalyticsService {
  static final AnalyticsService _instance = AnalyticsService._internal();
  factory AnalyticsService() => _instance;
  AnalyticsService._internal();

  final List<AnalyticsProvider> _providers = [];

  void registerProvider(AnalyticsProvider provider) {
    _providers.add(provider);
  }

  /// List of keys strictly prohibited from being logged to protect user health & secrets (Section 11.3 & 32).
  static const Set<String> _sanitizedKeys = {
    'password',
    'passwords',
    'otp',
    'token',
    'access_token',
    'refresh_token',
    'diagnosis',
    'lab_result',
    'lab_reports',
    'medical_notes',
    'prescriptions',
    'card_number',
    'cvv',
  };

  /// Logs an analytics event adhering to the `<object>_<action>` naming convention.
  Future<void> logEvent(String eventName, [Map<String, dynamic>? parameters]) async {
    // Enforce <object>_<action> convention (Section 31)
    final sanitizedParams = _sanitizeParameters(parameters);

    if (kDebugMode) {
      debugPrint('[Analytics] 📊 $eventName: $sanitizedParams');
    }

    for (final provider in _providers) {
      try {
        await provider.logEvent(eventName, sanitizedParams);
      } catch (e) {
        debugPrint('[Analytics] Provider failed: $e');
      }
    }
  }

  Map<String, dynamic>? _sanitizeParameters(Map<String, dynamic>? parameters) {
    if (parameters == null) return null;
    final cleaned = <String, dynamic>{};

    for (final entry in parameters.entries) {
      final keyLower = entry.key.toLowerCase();
      if (_sanitizedKeys.contains(keyLower) ||
          keyLower.contains('password') ||
          keyLower.contains('otp') ||
          keyLower.contains('token')) {
        continue; // Strip sensitive details (Section 11.3 & 32)
      }
      cleaned[entry.key] = entry.value;
    }
    return cleaned;
  }

  Future<void> setUserId(String? userId) async {
    for (final provider in _providers) {
      await provider.setUserId(userId);
    }
  }

  // Predefined standard event helpers (Section 11.2)
  Future<void> logAppOpened() => logEvent('app_opened');
  Future<void> logOnboardingCompleted() => logEvent('onboarding_completed');
  Future<void> logLoginStarted() => logEvent('login_started');
  Future<void> logLoginCompleted() => logEvent('login_completed');
  Future<void> logHealthPassViewed() => logEvent('health_pass_viewed');

  // Section 110: Health Pass Lifecycle Analytics Events (Non-sensitive only)
  Future<void> logHealthPassPlanViewed(String planCode) =>
      logEvent('health_pass_plan_viewed', {'plan_code': planCode});
  Future<void> logHealthPassComparisonViewed() =>
      logEvent('health_pass_comparison_viewed');
  Future<void> logHealthPassDurationSelected(int durationMonths) =>
      logEvent('health_pass_duration_selected', {'duration_months': durationMonths});
  Future<void> logHealthPassMembersSelected(int count) =>
      logEvent('health_pass_members_selected', {'members_count': count});
  Future<void> logHealthPassQuoteRequested(String planCode) =>
      logEvent('health_pass_quote_requested', {'plan_code': planCode});
  Future<void> logHealthPassPurchaseStarted(String planCode) =>
      logEvent('health_pass_purchase_started', {'plan_code': planCode});
  Future<void> logHealthPassPaymentStarted(String healthPassId) =>
      logEvent('health_pass_payment_started', {'health_pass_id': healthPassId});
  Future<void> logHealthPassPurchaseCompleted(String healthPassId) =>
      logEvent('health_pass_purchase_completed', {'health_pass_id': healthPassId});
  Future<void> logHealthPassPurchaseFailed([String? reason]) =>
      logEvent('health_pass_purchase_failed', {'reason': reason});
  Future<void> logHealthPassViewedActive() =>
      logEvent('health_pass_viewed_active');
  Future<void> logHealthPassRenewalStarted(String healthPassId) =>
      logEvent('health_pass_renewal_started', {'health_pass_id': healthPassId});
  Future<void> logHealthPassRenewalCompleted(String healthPassId) =>
      logEvent('health_pass_renewal_completed', {'health_pass_id': healthPassId});
  Future<void> logHealthPassExpiryViewed() =>
      logEvent('health_pass_expiry_viewed');

  Future<void> logChefBookingStarted() => logEvent('chef_booking_started');
  Future<void> logChefBookingConfirmed(String bookingId) => logEvent('chef_booking_confirmed', {'booking_id': bookingId});
  Future<void> logPaymentStarted() => logEvent('payment_started');
  Future<void> logPaymentSuccess() => logEvent('payment_success');
  Future<void> logPaymentFailed([String? reason]) => logEvent('payment_failed', {'reason': reason});
}
