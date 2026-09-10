import 'package:flutter/foundation.dart';
import '../api/api_client.dart';
import '../api/api_endpoints.dart';
import '../api/api_response.dart';
import '../storage/token_storage.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthService extends ChangeNotifier {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final ApiClient _api = ApiClient();
  AuthStatus _status = AuthStatus.unknown;
  Map<String, dynamic>? _currentUser;

  AuthStatus get status => _status;
  bool get isAuthenticated => _status == AuthStatus.authenticated;
  Map<String, dynamic>? get currentUser => _currentUser;
  Map<String, dynamic>? get user => _currentUser;

  Future<void> initialize() async {
    final hasToken = await TokenStorage.hasSession();
    if (!hasToken) {
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return;
    }

    // Validate existing session with /me
    final res = await _api.get<Map<String, dynamic>>(ApiEndpoints.me);
    if (res.success && res.data != null) {
      _currentUser = res.data;
      _status = AuthStatus.authenticated;
    } else {
      // Session expired
      await TokenStorage.clear();
      _status = AuthStatus.unauthenticated;
    }
    notifyListeners();
  }

  Future<ApiResponse<Map<String, dynamic>>> requestOtp(String phone) async {
    final res = await _api.post<Map<String, dynamic>>(
      ApiEndpoints.requestOtp,
      body: {'phone': phone},
      requiresAuth: false,
    );
    return res;
  }

  Future<ApiResponse<Map<String, dynamic>>> verifyOtp({
    required String phone,
    required String code,
    String? referralCode,
  }) async {
    final res = await _api.post<Map<String, dynamic>>(
      ApiEndpoints.verifyOtp,
      body: {
        'phone': phone,
        'code': code,
        if (referralCode != null && referralCode.isNotEmpty) 'referralCode': referralCode,
      },
      requiresAuth: false,
    );

    if (res.success && res.data != null) {
      final data = res.data!;
      final accessToken = data['accessToken'] as String?;
      final refreshToken = data['refreshToken'] as String?;

      if (accessToken != null) {
        await TokenStorage.saveTokens(
          accessToken: accessToken,
          refreshToken: refreshToken,
        );
        await fetchProfile();
        _status = AuthStatus.authenticated;
        notifyListeners();
      }
    }
    return res;
  }

  Future<ApiResponse<Map<String, dynamic>>> loginWithPassword({
    required String email,
    required String password,
  }) async {
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
        await TokenStorage.saveTokens(
          accessToken: accessToken,
          refreshToken: refreshToken,
        );
        await fetchProfile();
        _status = AuthStatus.authenticated;
        notifyListeners();
      }
    }
    return res;
  }

  Future<void> fetchProfile() async {
    final res = await _api.get<Map<String, dynamic>>(ApiEndpoints.me);
    if (res.success && res.data != null) {
      _currentUser = res.data;
      await TokenStorage.saveUser(
        id: res.data!['id'] ?? '',
        phone: res.data!['phone'] ?? '',
        name: res.data!['name'],
      );
      notifyListeners();
    }
  }

  Future<void> logout() async {
    await TokenStorage.clear();
    _currentUser = null;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }
}
