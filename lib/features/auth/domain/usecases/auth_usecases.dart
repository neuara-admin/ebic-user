import '../../../../core/api/api_response.dart';
import '../entities/account_deletion_eligibility.dart';
import '../entities/auth_session_entity.dart';
import '../repositories/auth_repository.dart';

/// Section 60 - UseCases for Authentication & Account

class LoginUseCase {
  final AuthRepository repository;
  LoginUseCase(this.repository);

  Future<ApiResponse<Map<String, dynamic>>> requestLoginOtp(String phone) {
    return repository.requestOtp(phone, purpose: 'LOGIN');
  }

  Future<ApiResponse<AuthSessionEntity>> verifyLoginOtp({
    required String phone,
    required String code,
  }) {
    return repository.verifyOtp(phone: phone, code: code, purpose: 'LOGIN');
  }

  Future<ApiResponse<AuthSessionEntity>> loginWithPassword({
    required String email,
    required String password,
  }) {
    return repository.loginWithPassword(email: email, password: password);
  }
}

class RegisterUseCase {
  final AuthRepository repository;
  RegisterUseCase(this.repository);

  Future<ApiResponse<Map<String, dynamic>>> requestRegistrationOtp(String phone) {
    return repository.requestOtp(phone, purpose: 'REGISTRATION');
  }

  Future<ApiResponse<AuthSessionEntity>> completeRegistration({
    required String phone,
    required String code,
    required String name,
    required String email,
    String? referralCode,
  }) {
    return repository.verifyOtp(
      phone: phone,
      code: code,
      purpose: 'REGISTRATION',
      name: name,
      email: email,
      referralCode: referralCode,
    );
  }
}

class VerifyOtpUseCase {
  final AuthRepository repository;
  VerifyOtpUseCase(this.repository);

  Future<ApiResponse<AuthSessionEntity>> call({
    required String phone,
    required String code,
    String purpose = 'LOGIN',
    String? name,
    String? email,
    String? referralCode,
  }) {
    return repository.verifyOtp(
      phone: phone,
      code: code,
      purpose: purpose,
      name: name,
      email: email,
      referralCode: referralCode,
    );
  }
}

class LogoutUseCase {
  final AuthRepository repository;
  LogoutUseCase(this.repository);

  Future<ApiResponse<void>> logout() => repository.logout();
  Future<ApiResponse<void>> logoutAll() => repository.logoutAll();
}

class DeleteAccountUseCase {
  final AuthRepository repository;
  DeleteAccountUseCase(this.repository);

  Future<ApiResponse<AccountDeletionEligibility>> checkEligibility() {
    return repository.checkDeletionEligibility();
  }

  Future<ApiResponse<void>> requestDeletion({String? reason}) {
    return repository.requestAccountDeletion(reason: reason);
  }

  Future<ApiResponse<void>> deactivate() {
    return repository.deactivateAccount();
  }
}
