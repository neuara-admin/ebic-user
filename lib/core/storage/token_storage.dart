import 'package:shared_preferences/shared_preferences.dart';

class TokenStorage {
  static const String _keyAccessToken = 'ebic_access_token';
  static const String _keyRefreshToken = 'ebic_refresh_token';
  static const String _keyUserId = 'ebic_auth_user_id';
  static const String _keyUserPhone = 'ebic_auth_user_phone';
  static const String _keyUserName = 'ebic_auth_user_name';
  static const String _keyUserEmail = 'ebic_auth_user_email';
  static const String _keyUserAvatar = 'ebic_auth_user_avatar';
  static const String _keyActiveMemberId = 'ebic_auth_active_member_id';

  static bool _hasSessionCache = false;
  static bool get hasCachedSession => _hasSessionCache;

  static Future<void> saveTokens({
    required String accessToken,
    String? refreshToken,
  }) async {
    _hasSessionCache = accessToken.isNotEmpty;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyAccessToken, accessToken);
    if (refreshToken != null) {
      await prefs.setString(_keyRefreshToken, refreshToken);
    }
  }

  static Future<String?> getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyAccessToken);
  }

  static Future<String?> getRefreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyRefreshToken);
  }

  static Future<void> saveUser({
    required String id,
    required String phone,
    String? name,
    String? email,
    String? avatarUrl,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUserId, id);
    await prefs.setString(_keyUserPhone, phone);
    if (name != null) {
      await prefs.setString(_keyUserName, name);
    } else {
      await prefs.remove(_keyUserName);
    }
    if (email != null) {
      await prefs.setString(_keyUserEmail, email);
    } else {
      await prefs.remove(_keyUserEmail);
    }
    if (avatarUrl != null) {
      await prefs.setString(_keyUserAvatar, avatarUrl);
    } else {
      await prefs.remove(_keyUserAvatar);
    }
  }

  static Future<String?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUserId);
  }

  static Future<String?> getUserPhone() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUserPhone);
  }

  static Future<String?> getUserName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUserName);
  }

  static Future<String?> getUserEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUserEmail);
  }

  static Future<String?> getUserAvatar() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUserAvatar);
  }

  static Future<void> setActiveMemberId(String memberId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyActiveMemberId, memberId);
  }

  static Future<String?> getActiveMemberId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyActiveMemberId);
  }

  static Future<void> clear() async {
    _hasSessionCache = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyAccessToken);
    await prefs.remove(_keyRefreshToken);
    await prefs.remove(_keyUserId);
    await prefs.remove(_keyUserPhone);
    await prefs.remove(_keyUserName);
    await prefs.remove(_keyUserEmail);
    await prefs.remove(_keyUserAvatar);
    await prefs.remove(_keyActiveMemberId);
  }

  static Future<bool> hasSession() async {
    final token = await getAccessToken();
    _hasSessionCache = token != null && token.isNotEmpty;
    return _hasSessionCache;
  }
}
