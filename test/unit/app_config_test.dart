import 'package:flutter_test/flutter_test.dart';
import 'package:ebic_user/core/config/app_config.dart';
import 'package:ebic_user/core/config/app_environment.dart';

void main() {
  group('AppConfig & Environment Setup Tests (User App)', () {
    test('Verifies default development environment values in test mode', () {
      expect(AppConfig.environment, isNotEmpty);
      expect(AppConfig.prodApiBaseUrl, equals('https://api.ebic.in/v1'));
      expect(AppConfig.prodWebSocketUrl, equals('wss://api.ebic.in/realtime'));
      expect(AppConfig.stagingApiBaseUrl, equals('https://staging-api.ebic.in/v1'));
      expect(AppConfig.stagingWebSocketUrl, equals('wss://staging-api.ebic.in/realtime'));
      expect(AppConfig.apiBaseUrl, isNotEmpty);
      expect(AppConfig.defaultWebSocketUrl, isNotEmpty);
    });

    test('Verifies AppEnvironment initialization for production & development', () {
      AppEnvironment.initialize(type: EnvironmentType.production);
      expect(AppEnvironment.current.isProduction, isTrue);
      expect(AppEnvironment.current.isDevelopment, isFalse);
      expect(AppEnvironment.current.apiBaseUrl, equals('https://api.ebic.in/v1'));
      expect(AppEnvironment.current.webSocketUrl, equals('wss://api.ebic.in/realtime'));

      AppEnvironment.initialize(type: EnvironmentType.development);
      expect(AppEnvironment.current.isProduction, isFalse);
      expect(AppEnvironment.current.isDevelopment, isTrue);
      expect(AppEnvironment.current.apiBaseUrl, equals('http://localhost:3000/v1'));
      expect(AppEnvironment.current.webSocketUrl, equals('ws://localhost:3000/realtime'));
    });

    test('Verifies resolveMediaUrl for relative and localhost URLs', () {
      expect(AppConfig.resolveMediaUrl(null), isNull);
      expect(AppConfig.resolveMediaUrl(''), isNull);
      expect(AppConfig.resolveMediaUrl('https://images.example.com/photo.jpg'),
          equals('https://images.example.com/photo.jpg'));

      final relativeUrl = AppConfig.resolveMediaUrl('uploads/avatar.png');
      expect(relativeUrl, isNotNull);
      expect(relativeUrl!.endsWith('/uploads/avatar.png'), isTrue);
    });
  });
}
