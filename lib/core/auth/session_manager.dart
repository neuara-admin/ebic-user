import 'package:flutter/foundation.dart';
import '../api/api_client.dart';
import '../api/api_endpoints.dart';
import '../storage/token_storage.dart';

/// Module 2 (Section 28 & 53) Authentication Session States
enum AuthSessionStatus {
  unknown,
  unauthenticated,
  authenticating,
  authenticated,
  refreshing,
  expired,
  restricted,
  loggingOut,
}

/// Centralized session manager governing the authentication lifecycle,
/// session persistence, and state transitions.
/// Adheres strictly to Module 2 Sections 19, 28, 29, 30, and 53.
class SessionManager extends ChangeNotifier {
  static final SessionManager _instance = SessionManager._internal();
  factory SessionManager() => _instance;
  SessionManager._internal() {
    // Connect to ApiClient coordinated refresh failure event (Section 26 & 30)
    ApiClient().onSessionExpired = _onSessionExpiredFromApi;
  }

  AuthSessionStatus _status = AuthSessionStatus.unknown;
  Map<String, dynamic>? _currentUser;
  String? _sessionMessage;

  AuthSessionStatus get status => _status;
  bool get isAuthenticated =>
      _status == AuthSessionStatus.authenticated ||
      _status == AuthSessionStatus.refreshing ||
      (_status == AuthSessionStatus.unknown && TokenStorage.hasCachedSession);
  bool get isUnauthenticated => _status == AuthSessionStatus.unauthenticated;
  Map<String, dynamic>? get currentUser => _currentUser;
  String? get sessionMessage => _sessionMessage;

  /// Startup session restoration & validation (Section 4, 13 & 29)
  Future<void> restoreSession() async {
    _status = AuthSessionStatus.unknown;
    notifyListeners();

    final hasToken = await TokenStorage.hasSession();
    if (!hasToken) {
      _status = AuthSessionStatus.unauthenticated;
      notifyListeners();
      return;
    }

    try {
      final res = await ApiClient().get<Map<String, dynamic>>(
        ApiEndpoints.me,
        requiresAuth: true,
      );

      if (res.success && res.data != null) {
        _currentUser = res.data;
        _status = AuthSessionStatus.authenticated;
        _sessionMessage = null;
        await TokenStorage.saveUser(
          id: res.data!['id'] ?? '',
          phone: res.data!['phone'] ?? '',
          name: res.data!['name'],
          email: res.data!['email'],
          avatarUrl: res.data!['avatarUrl'],
        );
      } else {
        if (res.error?.code == 'ACCOUNT_RESTRICTED') {
          _status = AuthSessionStatus.restricted;
          _sessionMessage = res.error?.message ?? 'Your account is currently restricted.';
        } else if (res.error?.code == 'NETWORK_ERROR' ||
                   res.error?.code == 'CLIENT_ERROR' ||
                   res.error?.code == 'SERVER_ERROR') {
          // Section 69: Network transient error must not purge authenticated session
          final cachedId = await TokenStorage.getUserId();
          final cachedPhone = await TokenStorage.getUserPhone();
          if (cachedId != null || await TokenStorage.hasSession()) {
            _currentUser = {
              'id': cachedId ?? 'cached_user',
              'phone': cachedPhone ?? '',
              'name': await TokenStorage.getUserName(),
              'email': await TokenStorage.getUserEmail(),
              'avatarUrl': await TokenStorage.getUserAvatar(),
              'offline': true,
            };
            _status = AuthSessionStatus.authenticated;
          } else {
            _status = AuthSessionStatus.unauthenticated;
          }
        } else {
          await TokenStorage.clear();
          _currentUser = null;
          _status = AuthSessionStatus.expired;
          _sessionMessage = 'Your session has expired. Please log in again.';
        }
      }
    } catch (_) {
      // In offline / transient error, allow cached user if token exists (Section 69)
      final cachedId = await TokenStorage.getUserId();
      final cachedPhone = await TokenStorage.getUserPhone();
      if (cachedId != null || await TokenStorage.hasSession()) {
        _currentUser = {
          'id': cachedId ?? 'cached_user',
          'phone': cachedPhone ?? '',
          'name': await TokenStorage.getUserName(),
          'email': await TokenStorage.getUserEmail(),
          'avatarUrl': await TokenStorage.getUserAvatar(),
          'offline': true,
        };
        _status = AuthSessionStatus.authenticated;
      } else {
        _status = AuthSessionStatus.unauthenticated;
      }
    }

    notifyListeners();
  }

  /// Transition to authenticating state
  void setAuthenticating() {
    _status = AuthSessionStatus.authenticating;
    _sessionMessage = null;
    notifyListeners();
  }

  /// Transition on successful authentication (Login / Registration)
  Future<void> onAuthenticated({
    required String accessToken,
    String? refreshToken,
    Map<String, dynamic>? userData,
  }) async {
    await TokenStorage.saveTokens(
      accessToken: accessToken,
      refreshToken: refreshToken,
    );

    if (userData != null) {
      _currentUser = userData;
      await TokenStorage.saveUser(
        id: userData['id'] ?? '',
        phone: userData['phone'] ?? '',
        name: userData['name'],
      );
    }

    _status = AuthSessionStatus.authenticated;
    _sessionMessage = null;
    notifyListeners();
  }

  /// Update user profile in session cache
  void updateCurrentUser(Map<String, dynamic> user) {
    _currentUser = user;
    notifyListeners();
  }

  /// Coordinated token refresh failure callback (Section 26 & 30)
  void _onSessionExpiredFromApi() {
    _currentUser = null;
    _status = AuthSessionStatus.expired;
    _sessionMessage = 'Your session has expired. Please log in again.';
    notifyListeners();
  }

  /// Explicit Logout (Section 21 & 37)
  Future<void> logout() async {
    _status = AuthSessionStatus.loggingOut;
    notifyListeners();

    try {
      final refreshToken = await TokenStorage.getRefreshToken();
      if (refreshToken != null && refreshToken.isNotEmpty) {
        // Attempt backend session revocation (Section 35)
        await ApiClient().post(
          ApiEndpoints.logout,
          body: {'refreshToken': refreshToken},
          requiresAuth: false,
        );
      }
    } catch (_) {
      // Network failure does not block local logout cleanup (Section 38)
    } finally {
      await TokenStorage.clear();
      _currentUser = null;
      _status = AuthSessionStatus.unauthenticated;
      _sessionMessage = null;
      notifyListeners();
    }
  }

  /// Terminate session when account is deactivated or deleted (Section 41 & 43)
  Future<void> terminateAccountSession() async {
    await TokenStorage.clear();
    _currentUser = null;
    _status = AuthSessionStatus.unauthenticated;
    _sessionMessage = null;
    notifyListeners();
  }

  /// Reset expired flag to unauthenticated
  void acknowledgeExpiration() {
    if (_status == AuthSessionStatus.expired) {
      _status = AuthSessionStatus.unauthenticated;
      _sessionMessage = null;
      notifyListeners();
    }
  }

  /// Helper for testing and preview mocks
  void setSessionForTesting({Map<String, dynamic>? user, String? token}) {
    _currentUser = user;
    _status = user != null ? AuthSessionStatus.authenticated : AuthSessionStatus.unauthenticated;
    notifyListeners();
  }
}
