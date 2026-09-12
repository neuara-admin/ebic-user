/// Centralized feature flags service.
/// Adheres strictly to Section 12 (Feature Flags & Remote Configuration).
/// Enables/disables features dynamically without app store releases.
class FeatureFlagService {
  static final FeatureFlagService _instance = FeatureFlagService._internal();
  factory FeatureFlagService() => _instance;
  FeatureFlagService._internal();

  final Map<String, bool> _flags = {
    // V1 Core Features
    'onboarding_enabled': true,
    'chef_booking_enabled': true,
    'health_pass_enabled': true,
    'dietitian_booking_enabled': true,
    'catalogue_enabled': true,
    'chef_addons_enabled': true,
    'promotions_enabled': true,
    'support_enabled': true,
    'new_home_screen_enabled': true,

    // V2 Architecture Preparation (Section 12.3: scheduled_booking_enabled = false in V1)
    'scheduled_booking_enabled': false,
  };

  /// Check if a feature is enabled.
  bool isEnabled(String featureKey, {bool defaultValue = false}) {
    return _flags[featureKey] ?? defaultValue;
  }

  /// Convenience getters for standard flags
  bool get isOnboardingEnabled => isEnabled('onboarding_enabled', defaultValue: true);
  bool get isChefBookingEnabled => isEnabled('chef_booking_enabled', defaultValue: true);
  bool get isScheduledBookingEnabled => isEnabled('scheduled_booking_enabled', defaultValue: false);
  bool get isHealthPassEnabled => isEnabled('health_pass_enabled', defaultValue: true);
  bool get isDietitianBookingEnabled => isEnabled('dietitian_booking_enabled', defaultValue: true);
  bool get isCatalogueEnabled => isEnabled('catalogue_enabled', defaultValue: true);
  bool get isSupportEnabled => isEnabled('support_enabled', defaultValue: true);

  /// Updates flags from backend or remote config payload.
  void updateFlags(Map<String, dynamic> remoteFlags) {
    for (final entry in remoteFlags.entries) {
      if (entry.value is bool) {
        _flags[entry.key] = entry.value as bool;
      }
    }
  }

  /// Override flag locally for testing or development.
  void setOverride(String featureKey, bool isEnabled) {
    _flags[featureKey] = isEnabled;
  }
}
