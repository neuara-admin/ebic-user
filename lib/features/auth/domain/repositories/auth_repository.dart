import '../../../../core/api/api_response.dart';
import '../entities/account_deletion_eligibility.dart';
import '../entities/auth_session_entity.dart';
import '../entities/user_entity.dart';

/// Section 60 & 61 - Auth Repository Boundary
abstract class AuthRepository {
  Future<ApiResponse<Map<String, dynamic>>> requestOtp(String phone, {String purpose = 'LOGIN'});

  Future<ApiResponse<AuthSessionEntity>> verifyOtp({
    required String phone,
    required String code,
    String purpose = 'LOGIN',
    String? name,
    String? email,
    String? referralCode,
  });

  Future<ApiResponse<AuthSessionEntity>> loginWithPassword({
    required String email,
    required String password,
  });

  Future<ApiResponse<Map<String, dynamic>>> startAccountRecovery(String identifier);

  Future<ApiResponse<Map<String, dynamic>>> forgotPassword(String email);

  Future<ApiResponse<UserEntity>> getProfile();

  Future<ApiResponse<void>> logout();

  Future<ApiResponse<void>> logoutAll();

  Future<ApiResponse<void>> deactivateAccount();

  Future<ApiResponse<AccountDeletionEligibility>> checkDeletionEligibility();

  Future<ApiResponse<void>> requestAccountDeletion({String? reason});
}
