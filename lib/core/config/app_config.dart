import 'package:flutter/foundation.dart';

class AppConfig {
  static const String appName = 'Ebic';
  static const String appTagline = 'Personalized Nutrition & In-Home Chefs';
  static const String appVersion = '1.0.0';

  /// Target environment: 'production', 'staging', or 'development'.
  /// Defaults to 'production' in release builds, or 'development' in debug/profile builds.
  /// Override with: `--dart-define=APP_ENV=production` or `--dart-define=APP_ENV=development`
  static const String environment = String.fromEnvironment(
    'APP_ENV',
    defaultValue: kReleaseMode ? 'production' : 'development',
  );

  static bool get isProduction => environment.toLowerCase() == 'production';
  static bool get isStaging => environment.toLowerCase() == 'staging';
  static bool get isDevelopment => !isProduction && !isStaging;

  // Override at build/run time for a physical device on the same Wi-Fi,
  // e.g. flutter run --dart-define=API_BASE_URL=http://192.168.1.5:3000/v1
  static const String _apiBaseUrlOverride = String.fromEnvironment(
    'API_BASE_URL',
  );

  static const String prodApiBaseUrl = 'https://api.ebic.in/v1';
  static const String prodWebSocketUrl = 'wss://api.ebic.in/realtime';

  static const String stagingApiBaseUrl = 'https://staging-api.ebic.in/v1';
  static const String stagingWebSocketUrl = 'wss://staging-api.ebic.in/realtime';

  /// Universal base URL configured for all regions currently
  static const String universalApiBaseUrl = 'http://100.61.151.169/v1';
  static const String universalWebSocketUrl = 'ws://100.61.151.169/realtime';

  // Base URL resolution: uses API_BASE_URL override if passed, otherwise universalApiBaseUrl
  static String get defaultBaseUrl {
    if (_apiBaseUrlOverride.isNotEmpty) {
      final trimmed = _apiBaseUrlOverride.trim().replaceAll(RegExp(r'/+$'), '');
      return trimmed.endsWith('/v1') ? trimmed : '$trimmed/v1';
    }
    return universalApiBaseUrl;
  }

  static String apiBaseUrl = defaultBaseUrl;

  static String get defaultWebSocketUrl {
    return universalWebSocketUrl;
  }

  /// Google Maps API Key for Geocoding, Places Autocomplete and Maps
  static const String googleMapsApiKey = String.fromEnvironment(
    'GOOGLE_MAPS_API_KEY',
    defaultValue: 'AIzaSyDVxeKff6sq5tHHfZhdugMKDSS6hvu47_w',
  );

  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 15);

  /// Resolves media/avatar URLs containing localhost or 127.0.0.1 to the active API host & port,
  /// and handles relative paths cleanly.
  static String? resolveMediaUrl(String? url) {
    if (url == null || url.trim().isEmpty) return null;
    final trimmed = url.trim();
    try {
      final baseUri = Uri.parse(apiBaseUrl);
      if (!trimmed.startsWith('http://') && !trimmed.startsWith('https://')) {
        final cleanBase = apiBaseUrl.replaceAll(RegExp(r'/v1/?$'), '');
        final slash = trimmed.startsWith('/') ? '' : '/';
        return '$cleanBase$slash$trimmed';
      }
      final mediaUri = Uri.parse(trimmed);
      if (mediaUri.host == 'localhost' || mediaUri.host == '127.0.0.1') {
        return mediaUri.replace(
          scheme: baseUri.scheme.isNotEmpty ? baseUri.scheme : 'http',
          host: baseUri.host,
          port: baseUri.hasPort ? baseUri.port : (mediaUri.hasPort ? mediaUri.port : 3000),
        ).toString();
      }
      return trimmed;
    } catch (_) {
      return trimmed;
    }
  }
}
