import 'package:ebic_user/core/analytics/phi_scrubber.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

void main() {
  group('User App PhiScrubber string and pattern scrubbing', () {
    test('redacts email addresses', () {
      const input = 'User email ananya.sharma@example.com was verified';
      final scrubbed = PhiScrubber.scrubString(input);
      expect(scrubbed, 'User email [REDACTED_EMAIL] was verified');
    });

    test('redacts phone numbers (Indian & standard 10-digit formats)', () {
      const input1 = 'Customer OTP sent to +91 9876543210';
      expect(PhiScrubber.scrubString(input1), 'Customer OTP sent to [REDACTED_PHONE]');

      const input2 = 'Phone: 9876543210 and 8123456789';
      expect(PhiScrubber.scrubString(input2), 'Phone: [REDACTED_PHONE] and [REDACTED_PHONE]');
    });

    test('redacts Bearer tokens and raw JWTs', () {
      const jwt = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4ifQ.SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c';
      const input1 = 'Authorization: Bearer $jwt';
      expect(PhiScrubber.scrubString(input1), contains('Bearer [REDACTED_TOKEN]'));

      const input2 = 'Stored token: $jwt';
      expect(PhiScrubber.scrubString(input2), contains('[REDACTED_TOKEN]'));
      expect(PhiScrubber.scrubString(input2), isNot(contains('eyJhbGci')));
    });

    test('redacts passwords, OTPs and secrets in key-value patterns', () {
      const input1 = 'Credentials: password="SecretPassword123"';
      expect(PhiScrubber.scrubString(input1), contains('password: [REDACTED_SECRET]'));

      const input2 = 'Verification failure: otp="456789"';
      expect(PhiScrubber.scrubString(input2), contains('otp: [REDACTED_SECRET]'));

      const input3 = 'apiKey: "ak_test_123456789"';
      expect(PhiScrubber.scrubString(input3), contains('apiKey: [REDACTED_SECRET]'));
    });

    test('redacts government identifiers (Aadhaar & PAN)', () {
      const aadhaar = 'Aadhaar 2345 6789 0123 submitted';
      expect(PhiScrubber.scrubString(aadhaar), 'Aadhaar [REDACTED_ID] submitted');

      const pan = 'PAN ABCDE1234F provided';
      expect(PhiScrubber.scrubString(pan), 'PAN [REDACTED_ID] provided');
    });

    test('scrubs URL query parameters while preserving path', () {
      const url = 'https://api.ebic.in/v1/customer/orders?search=biryani&phone=9876543210&token=abc';
      final scrubbed = PhiScrubber.scrubUrl(url);
      expect(scrubbed, 'https://api.ebic.in/v1/customer/orders?query_params_redacted=1');
      expect(scrubbed, isNot(contains('9876543210')));
      expect(scrubbed, isNot(contains('abc')));
    });
  });

  group('User App PhiScrubber Map and List scrubbing', () {
    test('replaces clinical and sensitive keys with [REDACTED]', () {
      final input = {
        'status': 'error',
        'code': 500,
        'customer_name': 'Ramesh Kumar',
        'notes': 'Allergic to peanuts and shellfish',
        'diagnosis': 'Type 2 Diabetes',
        'allergies': ['Peanuts'],
        'blood_sugar': 140,
        'email': 'customer@ebic.in',
        'otp': '654321',
        'metadata': {
          'order_id': 'ord_123',
          'phone': '9876543210',
          'comment': 'Contact customer at customer@test.com',
        },
      };

      final scrubbed = PhiScrubber.scrubMap(input);

      expect(scrubbed['status'], 'error');
      expect(scrubbed['code'], 500);
      expect(scrubbed['customer_name'], '[REDACTED]');
      expect(scrubbed['notes'], '[REDACTED]');
      expect(scrubbed['diagnosis'], '[REDACTED]');
      expect(scrubbed['allergies'], '[REDACTED]');
      expect(scrubbed['blood_sugar'], '[REDACTED]');
      expect(scrubbed['email'], '[REDACTED]');
      expect(scrubbed['otp'], '[REDACTED]');

      final meta = scrubbed['metadata'] as Map<String, dynamic>;
      expect(meta['order_id'], 'ord_123');
      expect(meta['phone'], '[REDACTED]');
      expect(meta['comment'], contains('[REDACTED_EMAIL]'));
    });
  });

  group('User App PhiScrubber SentryEvent & Breadcrumb scrubbing', () {
    test('scrubs breadcrumb messages and data', () {
      final breadcrumb = Breadcrumb(
        message: 'Order placed by user ananya@example.com',
        category: 'order',
        data: const {
          'customer_name': 'Ananya',
          'phone': '9876543210',
          'view': 'CheckoutScreen',
        },
      );

      final scrubbed = PhiScrubber.scrubBreadcrumb(breadcrumb);
      expect(scrubbed.message, 'Order placed by user [REDACTED_EMAIL]');
      expect(scrubbed.data?['view'], 'CheckoutScreen');
      expect(scrubbed.data?['customer_name'], '[REDACTED]');
      expect(scrubbed.data?['phone'], '[REDACTED]');
    });

    test('scrubs SentryEvent user to strictly opaque ID (removes email, ip, username)', () {
      final user = SentryUser(
        id: 'cust_456',
        email: 'customer@ebic.in',
        username: 'ananya_s',
        ipAddress: '10.0.0.1',
      );

      final event = SentryEvent(
        message: SentryMessage('Failed checkout for cust_456 on user@test.com'),
        user: user,
      );

      final scrubbed = PhiScrubber.scrubSentryEvent(event);
      expect(scrubbed, isNotNull);
      expect(scrubbed!.message?.formatted, contains('[REDACTED_EMAIL]'));
      expect(scrubbed.user?.id, 'cust_456');
      expect(scrubbed.user?.email, isNull);
      expect(scrubbed.user?.username, isNull);
      expect(scrubbed.user?.ipAddress, isNull);
      expect(scrubbed.user?.data?['role'], 'CUSTOMER');
    });

    test('scrubs SentryEvent request (drops body, cookies, queryString, auth headers)', () {
      final request = SentryRequest(
        url: 'https://api.ebic.in/v1/customer/orders?id=99&token=abc',
        method: 'POST',
        queryString: 'id=99&token=abc',
        cookies: 'session_id=xyz',
        data: '{"notes": "Low sodium requested"}',
        headers: const {
          'Authorization': 'Bearer eyJhbGciOi...',
          'Cookie': 'auth=token',
          'X-Client-Platform': 'Android',
        },
      );

      final event = SentryEvent(request: request);
      final scrubbed = PhiScrubber.scrubSentryEvent(event);

      expect(scrubbed!.request?.data, isNull);
      expect(scrubbed.request?.cookies, isNull);
      expect(scrubbed.request?.queryString, isNull);
      expect(scrubbed.request?.url, 'https://api.ebic.in/v1/customer/orders?query_params_redacted=1');
      expect(scrubbed.request?.headers.containsKey('Authorization'), isFalse);
      expect(scrubbed.request?.headers.containsKey('Cookie'), isFalse);
      expect(scrubbed.request?.headers['X-Client-Platform'], 'Android');
    });
  });
}

