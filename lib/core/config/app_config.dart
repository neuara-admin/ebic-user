import 'package:flutter/foundation.dart';

class AppConfig {
  static const String appName = 'Every Bite Counts';
  static const String appTagline = 'Personalized Nutrition & In-Home Chefs';
  static const String appVersion = '1.0.0 (V1 Instant)';

  // Override at build/run time for a physical device on the same Wi-Fi,
  // e.g. flutter run --dart-define=API_BASE_URL=http://192.168.1.5:3000/v1
  static const String _apiBaseUrlOverride = String.fromEnvironment(
    'API_BASE_URL',
  );

  // For Android Emulator: 10.0.2.2 points to host machine's localhost:3000
  // For Web / Windows / Desktop / iOS: localhost:3000
  static String get defaultBaseUrl {
    if (_apiBaseUrlOverride.isNotEmpty) return _apiBaseUrlOverride;
    if (kIsWeb) return 'http://localhost:3000/v1';
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'http://10.0.2.2:3000/v1';
      default:
        return 'http://localhost:3000/v1';
    }
  }

  static String apiBaseUrl = defaultBaseUrl;

  /// Google Maps API Key for Geocoding, Places Autocomplete and Maps
  static const String googleMapsApiKey = String.fromEnvironment(
    'GOOGLE_MAPS_API_KEY',
    defaultValue: 'AIzaSyDVxeKff6sq5tHHfZhdugMKDSS6hvu47_w',
  );

  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 15);

  /// Resolves media/avatar URLs containing localhost or 127.0.0.1 to the active API host
  static String? resolveMediaUrl(String? url) {
    if (url == null || url.trim().isEmpty) return null;
    final trimmed = url.trim();
    if (!trimmed.contains('localhost') && !trimmed.contains('127.0.0.1')) {
      return trimmed;
    }
    try {
      final baseUri = Uri.parse(apiBaseUrl);
      final mediaUri = Uri.parse(trimmed);
      return mediaUri.replace(host: baseUri.host).toString();
    } catch (_) {
      return trimmed;
    }
  }
}
