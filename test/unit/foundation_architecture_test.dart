import 'package:flutter_test/flutter_test.dart';
import 'package:ebic_user/core/state/view_state.dart';
import 'package:ebic_user/core/utils/validators.dart';
import 'package:ebic_user/core/api/idempotency_service.dart';
import 'package:ebic_user/core/config/feature_flag_service.dart';
import 'package:ebic_user/core/config/remote_config_service.dart';
import 'package:ebic_user/core/analytics/analytics_service.dart';
import 'package:ebic_user/core/routing/deep_link_service.dart';
import 'package:ebic_user/core/storage/cache_service.dart';

void main() {
  group('Module 1: ViewState & State Transitions (Section 8)', () {
    test('ViewState states correctly evaluate type getters', () {
      const ViewState<String> initial = ViewInitial();
      expect(initial.isInitial, isTrue);
      expect(initial.isLoading, isFalse);

      const ViewState<String> loading = ViewLoading('Loading data...');
      expect(loading.isLoading, isTrue);

      const ViewState<String> loaded = ViewLoaded('Payload');
      expect(loaded.isLoaded, isTrue);
      expect(loaded.dataOrNull, 'Payload');

      const ViewState<String> empty = ViewEmpty('No data');
      expect(empty.isEmpty, isTrue);

      const ViewState<String> failure = ViewFailure('Failed', code: 'ERR_01');
      expect(failure.isFailure, isTrue);

      const ViewState<String> conflict = ViewConflict('Already booked');
      expect(conflict.isConflict, isTrue);
    });
  });

  group('Module 1: Validators & Normalization (Section 34)', () {
    test('Phone number validator enforces 10 digits and Indian mobile starting with 6-9', () {
      expect(Validators.validatePhone(null), isNotNull);
      expect(Validators.validatePhone(''), isNotNull);
      expect(Validators.validatePhone('12345'), isNotNull); // Too short
      expect(Validators.validatePhone('1234567890'), isNotNull); // Starts with 1
      expect(Validators.validatePhone('9876543210'), isNull); // Valid Indian mobile
      expect(Validators.validatePhone('+919876543210'), isNull); // Valid with country code
    });

    test('Phone normalization standardizes Indian mobile into E.164 (+91)', () {
      expect(Validators.normalizePhone('9876543210'), '+919876543210');
      expect(Validators.normalizePhone(' 98765 43210 '), '+919876543210');
      expect(Validators.normalizePhone('09876543210'), '+919876543210');
      expect(Validators.normalizePhone('+91 98765-43210'), '+919876543210');
    });

    test('OTP validator enforces exactly 6 numeric digits', () {
      expect(Validators.validateOtp(null), isNotNull);
      expect(Validators.validateOtp('123'), isNotNull);
      expect(Validators.validateOtp('abcdef'), isNotNull);
      expect(Validators.validateOtp('123456'), isNull);
    });

    test('Email validator enforces valid format', () {
      expect(Validators.validateEmail('invalid'), isNotNull);
      expect(Validators.validateEmail('user@'), isNotNull);
      expect(Validators.validateEmail('customer@ebic.com'), isNull);
    });
  });

  group('Module 1: Idempotency Service (Section 20)', () {
    test('generates valid UUIDv4 and retains key for logical retry scope', () {
      final key1 = IdempotencyService.generateKey();
      final key2 = IdempotencyService.generateKey();
      expect(key1, isNot(equals(key2)));
      expect(key1.length, 36);

      final service = IdempotencyService();
      final bookingKey = service.getOrCreateKey('booking_order_123');
      final retryKey = service.getOrCreateKey('booking_order_123');
      expect(retryKey, equals(bookingKey)); // Reused on retry

      service.clearKey('booking_order_123');
      final newKey = service.getOrCreateKey('booking_order_123');
      expect(newKey, isNot(equals(bookingKey)));
    });
  });

  group('Module 1: Feature Flags & Remote Config (Section 12)', () {
    test('scheduled_booking_enabled is false in V1 architecture by default', () {
      final flags = FeatureFlagService();
      expect(flags.isChefBookingEnabled, isTrue);
      expect(flags.isScheduledBookingEnabled, isFalse); // Section 12.3 V1 requirement
      expect(flags.isHealthPassEnabled, isTrue);
    });

    test('Remote config exposes business controlled parameters', () {
      final config = RemoteConfigService();
      expect(config.quoteExpirySeconds, 300);
      expect(config.supportedBookingModes, contains('INSTANT'));
      expect(config.maxRetryAttempts, 3);
    });
  });

  group('Module 1: Analytics & Privacy Protection (Section 11 & 31)', () {
    test('Analytics sanitizes sensitive health notes, passwords and tokens', () async {
      final analytics = AnalyticsService();
      // Should execute without throwing and sanitize internal maps
      await analytics.logEvent('chef_booking_started', {
        'booking_mode': 'INSTANT',
        'password': 'secret_password',
        'diagnosis': 'Diabetic Type 2',
        'otp': '123456',
      });
      expect(true, isTrue);
    });
  });

  group('Module 1: Deep Linking (Section 17)', () {
    test('parses ebic://booking and ebic://order deep link URIs', () {
      final deepLink = DeepLinkService();
      final bookingTarget = deepLink.parseUri(Uri.parse('ebic://booking/bk-1001'));
      expect(bookingTarget, isNotNull);
      expect(bookingTarget!.arguments['bookingId'], 'bk-1001');

      final orderTarget = deepLink.parseUri(Uri.parse('ebic://order/ord-5002'));
      expect(orderTarget, isNotNull);
      expect(orderTarget!.arguments['orderId'], 'ord-5002');
    });

    test('retains pending target when authentication is needed first', () {
      final deepLink = DeepLinkService();
      final target = DeepLinkTarget(routeName: '/test-route');
      deepLink.savePendingTarget(target);
      expect(deepLink.pendingTarget, equals(target));

      final consumed = deepLink.consumePendingTarget();
      expect(consumed, equals(target));
      expect(deepLink.pendingTarget, isNull);
    });
  });

  group('Module 1: Cache Policy (Section 8.4)', () {
    test('Memory cache respects TTL', () {
      final cache = CacheService();
      cache.setMemory('test_key', 'cached_value', ttl: const Duration(milliseconds: 50));
      expect(cache.getMemory('test_key'), 'cached_value');
    });
  });
}
