import 'package:flutter/material.dart';
import '../storage/local_preferences.dart';

/// Reactive Theme Controller managing app-wide theme mode (System, Light, Dark).
/// Ensures changes update MaterialApp dynamically and persist across app restarts.
class ThemeController extends ChangeNotifier {
  static final ThemeController _instance = ThemeController._internal();
  factory ThemeController() => _instance;
  ThemeController._internal();

  ThemeMode _themeMode = ThemeMode.system;
  ThemeMode get themeMode => _themeMode;

  String get themeModeString {
    switch (_themeMode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
        return 'system';
    }
  }

  bool get isDarkMode {
    if (_themeMode == ThemeMode.dark) return true;
    if (_themeMode == ThemeMode.light) return false;
    return WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.dark;
  }

  Future<void> initialize() async {
    final prefs = await LocalPreferences.getInstance();
    final savedMode = prefs.themeMode;
    _themeMode = _parseThemeMode(savedMode);
    notifyListeners();
  }

  Future<void> setThemeMode(String mode) async {
    final newMode = _parseThemeMode(mode);
    if (_themeMode == newMode) return;
    _themeMode = newMode;
    notifyListeners();
    final prefs = await LocalPreferences.getInstance();
    await prefs.setThemeMode(mode);
  }

  ThemeMode _parseThemeMode(String mode) {
    switch (mode.toLowerCase()) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      case 'system':
      default:
        return ThemeMode.system;
    }
  }
}
