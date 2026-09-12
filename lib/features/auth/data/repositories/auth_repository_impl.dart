import '../../../../core/api/api_response.dart';
import '../../../../core/auth/auth_service.dart';
import '../../domain/entities/account_deletion_eligibility.dart';
import '../../domain/entities/auth_session_entity.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';

/// Concrete implementation of AuthRepository calling AuthService / ApiClient.
class AuthRepositoryImpl implements AuthRepository {
  final AuthService _authService;

  AuthRepositoryImpl({AuthService? authService})
      : _authService = authService ?? AuthService();

  @override
  Future<ApiResponse<Map<String, dynamic>>> requestOtp(
    String phone, {
    String purpose = 'LOGIN',
  }) {
    return _authService.requestOtp(phone, purpose: purpose);
  }

  @override
  Future<ApiResponse<AuthSessionEntity>> verifyOtp({
    required String phone,
    required String code,
    String purpose = 'LOGIN',
    String? name,
    String? email,
    String? referralCode,
  }) async {
    final res = await _authService.verifyOtp(
      phone: phone,
      code: code,
      purpose: purpose,
      name: name,
      email: email,
      referralCode: referralCode,
    );

    if (res.success && res.data != null) {
      final session = AuthSessionEntity(
        accessToken: res.data!['accessToken'] as String?,
        refreshToken: res.data!['refreshToken'] as String?,
        status: AuthSessionStatus.authenticated,
      );
      return ApiResponse<AuthSessionEntity>(
        success: true,
        data: session,
        message: res.message,
      );
    }

    return ApiResponse<AuthSessionEntity>(
      success: false,
      error: res.error,
    );
  }

  @override
  Future<ApiResponse<AuthSessionEntity>> loginWithPassword({
    required String email,
    required String password,
  }) async {
    final res = await _authService.loginWithPassword(
      email: email,
      password: password,
    );

    if (res.success && res.data != null) {
      final session = AuthSessionEntity(
        accessToken: res.data!['accessToken'] as String?,
        refreshToken: res.data!['refreshToken'] as String?,
        status: AuthSessionStatus.authenticated,
      );
      return ApiResponse<AuthSessionEntity>(
        success: true,
        data: session,
        message: res.message,
      );
    }

    return ApiResponse<AuthSessionEntity>(
      success: false,
      error: res.error,
    );
  }

  @override
  Future<ApiResponse<Map<String, dynamic>>> startAccountRecovery(String identifier) {
    return _authService.startAccountRecovery(identifier);
  }

  @override
  Future<ApiResponse<Map<String, dynamic>>> forgotPassword(String email) {
    return _authService.forgotPassword(email);
  }

  @override
  Future<ApiResponse<UserEntity>> getProfile() async {
    final user = _authService.currentUser;
    if (user != null) {
      return ApiResponse<UserEntity>(
        success: true,
        data: UserEntity.fromJson(user),
      );
    }
    await _authService.fetchProfile();
    final updated = _authService.currentUser;
    if (updated != null) {
      return ApiResponse<UserEntity>(
        success: true,
        data: UserEntity.fromJson(updated),
      );
    }
    return ApiResponse<UserEntity>(
      success: false,
      error: ApiError(code: 'NO_PROFILE', message: 'Profile unavailable.'),
    );
  }

  @override
  Future<ApiResponse<void>> logout() async {
    await _authService.logout();
    return ApiResponse<void>(success: true, message: 'Logged out successfully.');
  }

  @override
  Future<ApiResponse<void>> logoutAll() async {
    final res = await _authService.logoutAll();
    return ApiResponse<void>(
      success: res.success,
      message: res.message,
      error: res.error,
    );
  }

  @override
  Future<ApiResponse<void>> deactivateAccount() async {
    final res = await _authService.deactivateAccount();
    return ApiResponse<void>(
      success: res.success,
      message: res.message,
      error: res.error,
    );
  }

  @override
  Future<ApiResponse<AccountDeletionEligibility>> checkDeletionEligibility() async {
    final res = await _authService.checkDeletionEligibility();
    if (res.success && res.data != null) {
      return ApiResponse<AccountDeletionEligibility>(
        success: true,
        data: AccountDeletionEligibility.fromJson(res.data!),
      );
    }
    return ApiResponse<AccountDeletionEligibility>(
      success: false,
      error: res.error,
    );
  }

  @override
  Future<ApiResponse<void>> requestAccountDeletion({String? reason}) async {
    final res = await _authService.requestAccountDeletion(reason: reason);
    return ApiResponse<void>(
      success: res.success,
      message: res.message,
      error: res.error,
    );
  }
}
