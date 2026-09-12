import 'package:shared_preferences/shared_preferences.dart';

/// Manages non-sensitive user and UI preferences.
/// Adheres to Section 9.2 (Local preferences).
class LocalPreferences {
  static const String _keyLanguage = 'pref_language';
  static const String _keyThemeMode = 'pref_theme_mode';
  static const String _keyOnboardingDone = 'pref_onboarding_completed';
  static const String _keyLastNavIndex = 'pref_last_navigation_index';
  static const String _keyLastSelectedMember = 'pref_last_selected_member_id';

  static LocalPreferences? _instance;
  late SharedPreferences _prefs;

  LocalPreferences._();

  static Future<LocalPreferences> getInstance() async {
    if (_instance == null) {
      _instance = LocalPreferences._();
      _instance!._prefs = await SharedPreferences.getInstance();
    }
    return _instance!;
  }

  // Language
  String get language => _prefs.getString(_keyLanguage) ?? 'en';
  Future<bool> setLanguage(String code) => _prefs.setString(_keyLanguage, code);

  // Theme Mode ('light', 'dark', 'system')
  String get themeMode => _prefs.getString(_keyThemeMode) ?? 'system';
  Future<bool> setThemeMode(String mode) => _prefs.setString(_keyThemeMode, mode);

  // Onboarding
  bool get isOnboardingCompleted => _prefs.getBool(_keyOnboardingDone) ?? false;
  Future<bool> setOnboardingCompleted(bool value) => _prefs.setBool(_keyOnboardingDone, value);

  // Navigation state (e.g. Tab index)
  int get lastNavigationIndex => _prefs.getInt(_keyLastNavIndex) ?? 0;
  Future<bool> setLastNavigationIndex(int index) => _prefs.setInt(_keyLastNavIndex, index);

  // Section 28 & 39: Last selected household member ID
  String? get lastSelectedMemberId => _prefs.getString(_keyLastSelectedMember);
  Future<bool> setLastSelectedMemberId(String? id) {
    if (id == null) {
      return _prefs.remove(_keyLastSelectedMember);
    }
    return _prefs.setString(_keyLastSelectedMember, id);
  }

  // Clear non-sensitive preferences
  Future<void> clearAll() async {
    await _prefs.remove(_keyLanguage);
    await _prefs.remove(_keyThemeMode);
    await _prefs.remove(_keyOnboardingDone);
    await _prefs.remove(_keyLastNavIndex);
    await _prefs.remove(_keyLastSelectedMember);
  }
}
