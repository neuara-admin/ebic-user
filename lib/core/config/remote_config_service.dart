/// Business-controlled runtime configuration service.
/// Adheres strictly to Section 12.4 & 12.5 (Configuration vs Feature Flags).
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
  };

  bool get isMaintenanceMode => _config['maintenance_mode'] as bool? ?? false;
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
}
