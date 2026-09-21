import 'package:flutter/foundation.dart';
import '../api/api_client.dart';
import '../api/api_endpoints.dart';
import '../api/api_response.dart';
import '../storage/token_storage.dart';
import 'session_manager.dart';

export 'session_manager.dart' show AuthSessionStatus;

typedef AuthStatus = AuthSessionStatus;

/// Service managing user authentication, registration, OTP lifecycle,
/// account recovery, deactivation, and deletion.
/// Aligns with Module 2 Sections 13–22 & Sections 1–78.
class AuthService extends ChangeNotifier {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal() {
    _sessionManager.addListener(_onSessionStateChanged);
  }

  final ApiClient _api = ApiClient();
  final SessionManager _sessionManager = SessionManager();

  void _onSessionStateChanged() {
    notifyListeners();
  }

  AuthSessionStatus get status => _sessionManager.status;
  bool get isAuthenticated => _sessionManager.isAuthenticated;
  bool get isUnauthenticated => _sessionManager.isUnauthenticated;
  Map<String, dynamic>? get currentUser => _sessionManager.currentUser;
  Map<String, dynamic>? get user => _sessionManager.currentUser;
  String? get sessionMessage => _sessionManager.sessionMessage;

  Future<void> initialize() async {
    await _sessionManager.restoreSession();
  }

  /// Request OTP for Login, Registration, or Recovery (Section 13, 17)
  Future<ApiResponse<Map<String, dynamic>>> requestOtp(
    String phone, {
    String purpose = 'LOGIN',
  }) async {
    final res = await _api.post<Map<String, dynamic>>(
      ApiEndpoints.requestOtp,
      body: {
        'phone': phone,
        'purpose': purpose,
      },
      requiresAuth: false,
    );
    return res;
  }

  /// Verify OTP and establish authenticated session (Section 15, 16, 17)
  Future<ApiResponse<Map<String, dynamic>>> verifyOtp({
    required String phone,
    required String code,
    String purpose = 'LOGIN',
    String? name,
    String? email,
    String? referralCode,
  }) async {
    _sessionManager.setAuthenticating();

    final res = await _api.post<Map<String, dynamic>>(
      ApiEndpoints.verifyOtp,
      body: {
        'phone': phone,
        'code': code,
        'purpose': purpose,
        if (name != null && name.isNotEmpty) 'name': name,
        if (email != null && email.isNotEmpty) 'email': email,
        if (referralCode != null && referralCode.isNotEmpty) 'referralCode': referralCode,
      },
      requiresAuth: false,
    );

    if (res.success && res.data != null) {
      final data = res.data!;
      final accessToken = data['accessToken'] as String?;
      final refreshToken = data['refreshToken'] as String?;

      if (accessToken != null) {
        final userData = <String, dynamic>{'phone': phone};
        if (name != null) userData['name'] = name;
        if (email != null) userData['email'] = email;

        await _sessionManager.onAuthenticated(
          accessToken: accessToken,
          refreshToken: refreshToken,
          userData: userData,
        );
        await fetchProfile();
      }
    } else {
      if (res.error?.code == 'ACCOUNT_RESTRICTED') {
        await _sessionManager.restoreSession();
      } else {
        _sessionManager.acknowledgeExpiration();
      }
    }
    return res;
  }

  /// Staff email/password login (Section 16 & 46)
  Future<ApiResponse<Map<String, dynamic>>> loginWithPassword({
    required String email,
    required String password,
  }) async {
    _sessionManager.setAuthenticating();

    final res = await _api.post<Map<String, dynamic>>(
      ApiEndpoints.login,
      body: {'email': email, 'password': password},
      requiresAuth: false,
    );

    if (res.success && res.data != null) {
      final data = res.data!;
      final accessToken = data['accessToken'] as String?;
      final refreshToken = data['refreshToken'] as String?;

      if (accessToken != null) {
        await _sessionManager.onAuthenticated(
          accessToken: accessToken,
          refreshToken: refreshToken,
        );
        await fetchProfile();
      }
    } else {
      _sessionManager.acknowledgeExpiration();
    }
    return res;
  }

  /// Start account recovery workflow (Section 20 & 32)
  Future<ApiResponse<Map<String, dynamic>>> startAccountRecovery(String identifier) async {
    return _api.post<Map<String, dynamic>>(
      ApiEndpoints.accountRecovery,
      body: {'identifier': identifier},
      requiresAuth: false,
    );
  }

  /// Initiate password reset email/link (Section 18)
  Future<ApiResponse<Map<String, dynamic>>> forgotPassword(String email) async {
    return _api.post<Map<String, dynamic>>(
      ApiEndpoints.forgotPassword,
      body: {'email': email},
      requiresAuth: false,
    );
  }

  /// Fetch and cache current user profile (Section 19 & 46)
  Future<void> fetchProfile() async {
    final res = await _api.get<Map<String, dynamic>>(ApiEndpoints.me);
    if (res.success && res.data != null) {
      _sessionManager.updateCurrentUser(res.data!);
      await TokenStorage.saveUser(
        id: res.data!['id'] ?? '',
        phone: res.data!['phone'] ?? '',
        name: res.data!['name'],
        email: res.data!['email'],
        avatarUrl: res.data!['avatarUrl'],
      );
      notifyListeners();
    }
  }

  /// Self-service account deactivation (Section 22 & 41)
  Future<ApiResponse<Map<String, dynamic>>> deactivateAccount() async {
    final res = await _api.post<Map<String, dynamic>>(
      ApiEndpoints.deactivateAccount,
      requiresAuth: true,
    );
    if (res.success) {
      await _sessionManager.terminateAccountSession();
    }
    return res;
  }

  /// Check active transactions prior to deletion (Section 45)
  Future<ApiResponse<Map<String, dynamic>>> checkDeletionEligibility() async {
    return _api.get<Map<String, dynamic>>(
      ApiEndpoints.deletionCheck,
      requiresAuth: true,
    );
  }

  /// Request controlled account deletion (Section 22, 43, 44, 45)
  Future<ApiResponse<Map<String, dynamic>>> requestAccountDeletion({String? reason}) async {
    final body = <String, dynamic>{};
    if (reason != null) body['reason'] = reason;
    final res = await _api.post<Map<String, dynamic>>(
      ApiEndpoints.deleteRequest,
      body: body,
      requiresAuth: true,
    );
    if (res.success) {
      await _sessionManager.terminateAccountSession();
    }
    return res;
  }

  /// Log out current device (Section 21)
  Future<void> logout() async {
    await _sessionManager.logout();
    notifyListeners();
  }

  /// Log out all active sessions/devices (Section 39)
  Future<ApiResponse<Map<String, dynamic>>> logoutAll() async {
    final res = await _api.post<Map<String, dynamic>>(
      ApiEndpoints.logoutAll,
      requiresAuth: true,
    );
    await _sessionManager.terminateAccountSession();
    return res;
  }

  /// Get active login sessions (Section 305)
  Future<ApiResponse<dynamic>> getSessions() async {
    return _api.get(ApiEndpoints.profileSessions, requiresAuth: true);
  }

  /// Revoke specific login session (Section 305)
  Future<ApiResponse<dynamic>> revokeSession(String sessionId) async {
    return _api.delete(ApiEndpoints.profileSession(sessionId), requiresAuth: true);
  }

  /// Update in-memory current user details
  void updateCurrentUser(Map<String, dynamic> user) {
    _sessionManager.updateCurrentUser(user);
    notifyListeners();
  }

  /// Helper for testing and preview mocks
  void setSessionForTesting({Map<String, dynamic>? user, String? token}) {
    _sessionManager.setSessionForTesting(user: user, token: token);
    notifyListeners();
  }
}

