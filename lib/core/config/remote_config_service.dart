import 'package:flutter/foundation.dart';
import '../api/api_client.dart';
import '../api/api_endpoints.dart';
import 'feature_flag_service.dart';

/// Business-controlled runtime configuration service.
/// Adheres strictly to Section 12.4 & 12.5 and Module 20 (Sections 313, 314, 337, 338).
class RemoteConfigService {
  static final RemoteConfigService _instance = RemoteConfigService._internal();
  factory RemoteConfigService() => _instance;
  RemoteConfigService._internal();

  final Map<String, dynamic> _config = {
    'quote_expiry_seconds': 300,
    'booking_cancellation_window_minutes': 30,
    'max_retry_attempts': 3,
    'supported_booking_modes': ['INSTANT'],
    'support_phone': '+91 8000 123 456',
    'support_email': 'support@ebic.com',
    'addon_window_policy': 'BEFORE_CHEF_ARRIVAL',
    'maintenance_mode': false,
    'maintenance_message': 'EBIC is temporarily unavailable. We\'re working to restore the service. Please try again later.',
    'minimum_supported_version': '1.0.0',
    'latest_version': '1.0.0',
    'force_update': false,
    'update_url': 'https://play.google.com/store/apps/details?id=com.ebic.user',
    'supported_languages': ['en', 'te', 'hi'],
  };

  bool get isMaintenanceMode => _config['maintenance_mode'] as bool? ?? false;
  String get maintenanceMessage =>
      _config['maintenance_message'] as String? ??
      'EBIC is temporarily unavailable. We\'re working to restore the service. Please try again later.';
  DateTime? get maintenanceStartTime => _config['maintenance_start_time'] != null
      ? DateTime.tryParse(_config['maintenance_start_time'].toString())
      : null;
  DateTime? get maintenanceEndTime => _config['maintenance_expected_end_time'] != null
      ? DateTime.tryParse(_config['maintenance_expected_end_time'].toString())
      : null;

  String get minimumSupportedVersion =>
      _config['minimum_supported_version'] as String? ?? '1.0.0';
  String get latestVersion =>
      _config['latest_version'] as String? ?? '1.0.0';
  bool get forceUpdate => _config['force_update'] as bool? ?? false;
  String get updateUrl =>
      _config['update_url'] as String? ??
      'https://play.google.com/store/apps/details?id=com.ebic.user';
  List<String> get supportedLanguages =>
      List<String>.from(_config['supported_languages'] ?? ['en', 'te', 'hi']);

  int get quoteExpirySeconds => (_config['quote_expiry_seconds'] as num?)?.toInt() ?? 300;
  int get maxRetryAttempts => (_config['max_retry_attempts'] as num?)?.toInt() ?? 3;
  List<String> get supportedBookingModes => List<String>.from(_config['supported_booking_modes'] ?? ['INSTANT']);
  String get supportPhone => _config['support_phone'] as String? ?? '';
  String get supportEmail => _config['support_email'] as String? ?? '';

  dynamic get(String key, [dynamic defaultValue]) {
    return _config[key] ?? defaultValue;
  }

  void updateConfig(Map<String, dynamic> newConfig) {
    _config.addAll(newConfig);
  }

  /// Fetches runtime configuration from backend /config endpoint (Section 338).
  Future<bool> fetchRemoteConfig() async {
    try {
      final response = await ApiClient().get(ApiEndpoints.appConfig);
      if (response.success && response.data != null) {
        var data = response.data as Map<String, dynamic>;
        if (data.containsKey('data') && data['data'] is Map<String, dynamic>) {
          data = data['data'] as Map<String, dynamic>;
        }
        
        // App Version
        if (data['appVersion'] is Map<String, dynamic>) {
          final ver = data['appVersion'] as Map<String, dynamic>;
          _config['minimum_supported_version'] = ver['minimumSupportedVersion'] ?? '1.0.0';
          _config['latest_version'] = ver['latestVersion'] ?? '1.0.0';
          _config['force_update'] = ver['forceUpdate'] ?? false;
          if (ver['updateUrl'] != null) {
            _config['update_url'] = ver['updateUrl'];
          }
        }

        // Maintenance
        if (data['maintenance'] is Map<String, dynamic>) {
          final maint = data['maintenance'] as Map<String, dynamic>;
          _config['maintenance_mode'] = maint['maintenanceMode'] ?? false;
          if (maint['message'] != null) {
            _config['maintenance_message'] = maint['message'];
          }
          _config['maintenance_start_time'] = maint['startTime'];
          _config['maintenance_expected_end_time'] = maint['expectedEndTime'];
        }

        // Feature Flags
        if (data['featureFlags'] is Map<String, dynamic>) {
          FeatureFlagService().updateFlags(data['featureFlags'] as Map<String, dynamic>);
        }

        // Languages
        if (data['supportedLanguages'] is List) {
          _config['supported_languages'] = List<String>.from(data['supportedLanguages']);
        }

        return true;
      }
    } catch (e) {
      debugPrint('[RemoteConfigService] Failed to fetch remote config: $e');
    }
    return false;
  }

  /// Evaluates whether a forced app update is required per Section 313.
  bool isForceUpdateRequired(String currentVersionString) {
    if (forceUpdate) return true;
    final current = _parseVersion(currentVersionString);
    final minRequired = _parseVersion(minimumSupportedVersion);
    return _compareVersions(current, minRequired) < 0;
  }

  /// Evaluates whether an optional app update is available per Section 313.
  bool isOptionalUpdateAvailable(String currentVersionString) {
    final current = _parseVersion(currentVersionString);
    final latest = _parseVersion(latestVersion);
    return _compareVersions(current, latest) < 0;
  }

  List<int> _parseVersion(String versionStr) {
    final clean = versionStr.split(' ').first.trim();
    final parts = clean.split('.').map((p) => int.tryParse(p) ?? 0).toList();
    while (parts.length < 3) {
      parts.add(0);
    }
    return parts.take(3).toList();
  }

  int _compareVersions(List<int> v1, List<int> v2) {
    for (int i = 0; i < 3; i++) {
      if (v1[i] < v2[i]) return -1;
      if (v1[i] > v2[i]) return 1;
    }
    return 0;
  }
}

