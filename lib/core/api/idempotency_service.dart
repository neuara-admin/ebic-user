import 'dart:math';

/// Service managing device-generated unique keys for transactional mutations.
/// Adheres strictly to Section 20 (Idempotency Foundation).
///
/// Operations requiring idempotency:
/// - Chef Booking
/// - Health Pass Purchase
/// - Consultation Booking
/// - Payment
/// - Refund
/// - Credit Grant/Usage
/// - Coupon Redemption
/// - Entitlement Usage
/// - Chef Booking Add-on
class IdempotencyService {
  static final IdempotencyService _instance = IdempotencyService._internal();
  factory IdempotencyService() => _instance;
  IdempotencyService._internal();

  final Map<String, String> _operationKeys = {};

  /// Generates a RFC 4122 v4 UUID without external dependencies.
  static String generateKey() {
    final random = Random.secure();
    final values = List<int>.generate(16, (i) => random.nextInt(256));

    // Set version to 4
    values[6] = (values[6] & 0x0f) | 0x40;
    // Set variant to 10xxxxxx
    values[8] = (values[8] & 0x3f) | 0x80;

    final hex = values.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20, 32)}';
  }

  /// Retrieves an existing key for an in-flight operation scope (for retries),
  /// or creates a fresh one.
  String getOrCreateKey(String operationScope) {
    if (!_operationKeys.containsKey(operationScope)) {
      _operationKeys[operationScope] = generateKey();
    }
    return _operationKeys[operationScope]!;
  }

  /// Clears the idempotency key once an operation succeeds or is cancelled.
  void clearKey(String operationScope) {
    _operationKeys.remove(operationScope);
  }
}
