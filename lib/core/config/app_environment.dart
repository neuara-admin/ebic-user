enum EnvironmentType { development, staging, production }

/// Centralized environment configuration.
/// Adheres to Section 14 (Environment Configuration).
class AppEnvironment {
  final EnvironmentType type;
  final String apiBaseUrl;
  final String webSocketUrl;
  final String identifier;

  const AppEnvironment({
    required this.type,
    required this.apiBaseUrl,
    required this.webSocketUrl,
    required this.identifier,
  });

  static late AppEnvironment current;

  static void initialize({
    EnvironmentType type = EnvironmentType.development,
    String? apiBaseUrlOverride,
  }) {
    final baseUrl = apiBaseUrlOverride ??
        (type == EnvironmentType.production
            ? 'https://api.ebic.com/v1'
            : type == EnvironmentType.staging
                ? 'https://staging-api.ebic.com/v1'
                : 'http://localhost:3000/v1');

    final wsUrl = type == EnvironmentType.production
        ? 'wss://api.ebic.com/realtime'
        : type == EnvironmentType.staging
            ? 'wss://staging-api.ebic.com/realtime'
            : 'ws://localhost:3000/realtime';

    current = AppEnvironment(
      type: type,
      apiBaseUrl: baseUrl,
      webSocketUrl: wsUrl,
      identifier: type.name,
    );
  }

  bool get isProduction => type == EnvironmentType.production;
  bool get isDevelopment => type == EnvironmentType.development;
}
