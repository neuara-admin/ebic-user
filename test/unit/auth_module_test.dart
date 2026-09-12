import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ebic_user/core/auth/session_manager.dart';
import 'package:ebic_user/core/storage/token_storage.dart';
import 'package:ebic_user/core/utils/validators.dart';
import 'package:ebic_user/features/auth/domain/entities/account_deletion_eligibility.dart';
import 'package:ebic_user/features/auth/domain/entities/auth_session_entity.dart';
import 'package:ebic_user/features/auth/domain/entities/user_entity.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Module 2 — Section 70.1 Unit Tests: Registration & Validation', () {
    test('Validate phone accepts valid 10-digit Indian mobile numbers', () {
      expect(Validators.validatePhone('9876543210'), isNull);
      expect(Validators.validatePhone('+919876543210'), isNull);
      expect(Validators.validatePhone('+91 98765 43210'), isNull);
    });

    test('Validate phone rejects invalid formats', () {
      expect(Validators.validatePhone(''), isNotNull);
      expect(Validators.validatePhone('12345'), isNotNull);
      expect(Validators.validatePhone('5876543210'), isNotNull); // Doesn't start with 6-9
      expect(Validators.validatePhone('abcdefghij'), isNotNull);
    });

    test('Normalize phone adds +91 prefix consistently', () {
      expect(Validators.normalizePhone('9876543210'), equals('+919876543210'));
      expect(Validators.normalizePhone('+919876543210'), equals('+919876543210'));
      expect(Validators.normalizePhone('+91 98765 43210'), equals('+919876543210'));
    });

    test('Validate email checks RFC format', () {
      expect(Validators.validateEmail('user@ebic.in'), isNull);
      expect(Validators.validateEmail('user.name+tag@example.co.uk'), isNull);
      expect(Validators.validateEmail('invalid-email'), isNotNull);
      expect(Validators.validateEmail(''), isNotNull);
    });

    test('Validate password enforces minimum length & complexity', () {
      expect(Validators.validatePassword('Password123', minLength: 8), isNull);
      expect(Validators.validatePassword('short', minLength: 8), isNotNull);
      expect(Validators.validatePassword('onlyletters', minLength: 8), isNotNull);
    });

    test('Validate referral code allows 3-20 alphanumeric characters', () {
      expect(Validators.validateReferralCode('EBIC2026'), isNull);
      expect(Validators.validateReferralCode('SAVE-10'), isNull);
      expect(Validators.validateReferralCode('ab'), isNotNull); // Too short
      expect(Validators.validateReferralCode('toolongreferralcodestringoverflow'), isNotNull);
    });

    test('Validate OTP accepts 6 digits only', () {
      expect(Validators.validateOtp('123456'), isNull);
      expect(Validators.validateOtp('12345'), isNotNull);
      expect(Validators.validateOtp('1234567'), isNotNull);
      expect(Validators.validateOtp('12345a'), isNotNull);
    });
  });

  group('Module 2 — Section 28 & 53: Session State Machine', () {
    test('SessionManager initializes to unauthenticated without tokens', () async {
      final sm = SessionManager();
      await sm.restoreSession();

      expect(sm.status, equals(AuthSessionStatus.unauthenticated));
      expect(sm.isAuthenticated, isFalse);
      expect(sm.currentUser, isNull);
    });

    test('SessionManager transitions to authenticated when tokens saved', () async {
      final sm = SessionManager();
      await sm.onAuthenticated(
        accessToken: 'access_jwt_token',
        refreshToken: 'refresh_jwt_token',
        userData: {'id': 'user_123', 'phone': '+919876543210', 'name': 'John Doe'},
      );

      expect(sm.status, equals(AuthSessionStatus.authenticated));
      expect(sm.isAuthenticated, isTrue);
      expect(sm.currentUser?['name'], equals('John Doe'));

      final storedAccess = await TokenStorage.getAccessToken();
      expect(storedAccess, equals('access_jwt_token'));
    });

    test('SessionManager logout clears state and tokens (Section 21 & 37)', () async {
      final sm = SessionManager();
      await sm.onAuthenticated(
        accessToken: 'test_token',
        refreshToken: 'test_refresh',
      );
      expect(sm.isAuthenticated, isTrue);

      await sm.logout();
      expect(sm.status, equals(AuthSessionStatus.unauthenticated));
      expect(sm.currentUser, isNull);
      expect(await TokenStorage.getAccessToken(), isNull);
      expect(await TokenStorage.getRefreshToken(), isNull);
    });

    test('SessionManager handles expiration transition (Section 26 & 30)', () {
      final sm = SessionManager();
      sm.acknowledgeExpiration();
      expect(sm.status, equals(AuthSessionStatus.unauthenticated));
    });
  });

  group('Module 2 — Section 44 & 45: Account Deletion Eligibility', () {
    test('AccountDeletionEligibility parses active blocking transactions correctly', () {
      final blockedJson = {
        'eligible': false,
        'blockingReasons': [
          'Active meal orders or chef visits currently in progress.',
          'Active Health Pass subscription is currently running.',
        ],
        'activeTransactions': {
          'activeOrders': 2,
          'activePasses': 1,
          'pendingRefunds': 0,
        },
      };

      final eligibility = AccountDeletionEligibility.fromJson(blockedJson);
      expect(eligibility.eligible, isFalse);
      expect(eligibility.blockingReasons.length, equals(2));
      expect(eligibility.activeOrders, equals(2));
      expect(eligibility.activePasses, equals(1));
    });

    test('AccountDeletionEligibility recognizes eligible accounts with zero blockers', () {
      final eligibleJson = {
        'eligible': true,
        'blockingReasons': [],
        'activeTransactions': {
          'activeOrders': 0,
          'activePasses': 0,
          'pendingRefunds': 0,
        },
      };

      final eligibility = AccountDeletionEligibility.fromJson(eligibleJson);
      expect(eligibility.eligible, isTrue);
      expect(eligibility.blockingReasons, isEmpty);
      expect(eligibility.activeOrders, equals(0));
    });
  });

  group('Module 2 — Domain Entities Serialization', () {
    test('UserEntity parses json correctly', () {
      final user = UserEntity.fromJson({
        'id': 'u_1',
        'phone': '+919876543210',
        'name': 'Anita Roy',
        'email': 'anita@ebic.in',
        'role': 'CUSTOMER',
        'isActive': true,
      });

      expect(user.id, equals('u_1'));
      expect(user.phone, equals('+919876543210'));
      expect(user.name, equals('Anita Roy'));
      expect(user.isActive, isTrue);
    });

    test('AuthSessionEntity copyWith and status checks', () {
      final session = AuthSessionEntity(
        accessToken: 'tok_abc',
        refreshToken: 'tok_ref',
        status: AuthSessionStatus.authenticated,
      );

      expect(session.isAuthenticated, isTrue);
      final expired = session.copyWith(status: AuthSessionStatus.expired);
      expect(expired.isAuthenticated, isFalse);
    });
  });
}
