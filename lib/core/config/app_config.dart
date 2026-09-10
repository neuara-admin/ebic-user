import 'package:flutter/foundation.dart';

class AppConfig {
  static const String appName = 'Every Bite Counts';
  static const String appTagline = 'Personalized Nutrition & In-Home Chefs';
  static const String appVersion = '1.0.0 (V1 Instant)';

  // For Android Emulator: 10.0.2.2 points to host machine's localhost:3000
  // For Web / Windows / Desktop / iOS: localhost:3000
  static String get defaultBaseUrl {
    if (kIsWeb) return 'http://localhost:3000/v1';
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'http://10.0.2.2:3000/v1';
      default:
        return 'http://localhost:3000/v1';
    }
  }

  static String apiBaseUrl = defaultBaseUrl;

  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 15);
}
