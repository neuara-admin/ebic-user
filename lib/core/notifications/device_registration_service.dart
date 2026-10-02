import 'dart:async';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../api/api_client.dart';
import '../api/api_endpoints.dart';
import '../auth/session_manager.dart';
import '../realtime/realtime_notification_banner.dart';
import '../storage/token_storage.dart';

/// Manages physical device registration and push token sync with the backend.
/// Automatically binds to authentication status and registers device metadata
/// for real push notification delivery.
class DeviceRegistrationService {
  static final DeviceRegistrationService _instance = DeviceRegistrationService._internal();
  factory DeviceRegistrationService() => _instance;
  DeviceRegistrationService._internal();

  final ApiClient _api = ApiClient();
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();
  bool _isInitialized = false;
  String? _cachedDeviceId;

  static const String _prefKeyPushToken = 'ebic_push_token';
  static const String _prefKeyDeviceId = 'ebic_registered_device_id';

  Future<void> initialize() async {
    if (_isInitialized) return;
    _isInitialized = true;

    // Request OS notification permissions (Android 13+ / iOS)
    try {
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      // Listen for token updates
      messaging.onTokenRefresh.listen((newToken) {
        if (newToken.isNotEmpty) {
          updatePushToken(newToken);
        }
      });

      // Handle foreground push notifications with in-app banner
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        final notification = message.notification;
        final title = notification?.title ?? message.data['title']?.toString() ?? 'Notification';
        final body = notification?.body ?? message.data['body']?.toString() ?? '';
        RealtimeNotificationBanner.showBanner(
          title: title,
          body: body,
          data: message.data,
        );
      });

      // Handle notification click when app resumes from background
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        RealtimeNotificationBanner.navigateForPayload(message.data);
      });

      // Handle notification click when app launched from terminated state
      FirebaseMessaging.instance.getInitialMessage().then((RemoteMessage? message) {
        if (message != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            RealtimeNotificationBanner.navigateForPayload(message.data);
          });
        }
      });
    } catch (e) {
      debugPrint('⚠️ [FirebaseMessaging] setup notice: $e');
    }

    // Listen to session changes to sync device registration upon authentication
    SessionManager().addListener(_onSessionChanged);

    // Initial check
    if (SessionManager().isAuthenticated || TokenStorage.hasCachedSession) {
      unawaited(registerCurrentDevice());
    }
  }

  void _onSessionChanged() {
    if (SessionManager().isAuthenticated) {
      unawaited(registerCurrentDevice());
    }
  }

  /// Sets or updates the active push token (e.g. from Firebase Cloud Messaging).
  Future<void> updatePushToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKeyPushToken, token);
    await registerCurrentDevice(pushTokenOverride: token);
  }

  /// Resolves hardware details and registers the device in the backend.
  Future<bool> registerCurrentDevice({String? pushTokenOverride}) async {
    try {
      final token = await TokenStorage.getAccessToken();
      final isAuth = SessionManager().isAuthenticated || (token != null && token.isNotEmpty);
      if (!isAuth) return false;

      final prefs = await SharedPreferences.getInstance();
      String pushToken = pushTokenOverride ?? prefs.getString(_prefKeyPushToken) ?? '';

      String deviceId = prefs.getString(_prefKeyDeviceId) ?? '';
      String platform = 'ANDROID';
      String osVersion = 'Unknown';
      String appVersion = '1.0.0';

      if (kIsWeb) {
        final webInfo = await _deviceInfo.webBrowserInfo;
        deviceId = deviceId.isNotEmpty ? deviceId : 'web_${webInfo.userAgent.hashCode.abs()}';
        platform = 'WEB';
        osVersion = webInfo.platform ?? 'Web';
      } else if (defaultTargetPlatform == TargetPlatform.android) {
        final androidInfo = await _deviceInfo.androidInfo;
        deviceId = deviceId.isNotEmpty ? deviceId : (androidInfo.id.isNotEmpty ? androidInfo.id : 'android_${androidInfo.model}');
        platform = 'ANDROID';
        osVersion = 'Android ${androidInfo.version.release} (SDK ${androidInfo.version.sdkInt})';
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        final iosInfo = await _deviceInfo.iosInfo;
        deviceId = deviceId.isNotEmpty ? deviceId : (iosInfo.identifierForVendor ?? 'ios_${iosInfo.model}');
        platform = 'IOS';
        osVersion = '${iosInfo.systemName} ${iosInfo.systemVersion}';
      }

      // Retrieve live Firebase Cloud Messaging push token
      try {
        final fcmToken = await FirebaseMessaging.instance.getToken();
        if (fcmToken != null && fcmToken.isNotEmpty) {
          pushToken = fcmToken;
          await prefs.setString(_prefKeyPushToken, pushToken);
        }
      } catch (e) {
        debugPrint('⚠️ [FirebaseMessaging] getToken: $e');
      }

      // If no push token is present yet, assign a persistent device-bound token
      // so backend push dispatch has a valid target registered for this device.
      if (pushToken.isEmpty) {
        pushToken = 'ebic_device_token_${deviceId.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_')}';
        await prefs.setString(_prefKeyPushToken, pushToken);
      }

      await prefs.setString(_prefKeyDeviceId, deviceId);
      _cachedDeviceId = deviceId;

      final payload = {
        'deviceId': deviceId,
        'platform': platform,
        'pushToken': pushToken,
        'appVersion': appVersion,
        'osVersion': osVersion,
      };

      final res = await _api.post(
        ApiEndpoints.notificationDevices,
        body: payload,
        requiresAuth: true,
      );

      if (res.success) {
        debugPrint('🔔 [Notifications] Device registered successfully: $deviceId ($platform)');
        return true;
      } else {
        debugPrint('⚠️ [Notifications] Device registration failed: ${res.message}');
        return false;
      }
    } catch (e) {
      debugPrint('⚠️ [Notifications] Error registering device: $e');
      return false;
    }
  }

  /// Deactivates current device upon logout.
  Future<void> unregisterCurrentDevice() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final deviceId = _cachedDeviceId ?? prefs.getString(_prefKeyDeviceId);
      if (deviceId != null && deviceId.isNotEmpty) {
        await _api.delete(
          ApiEndpoints.notificationDevice(deviceId),
          requiresAuth: true,
        );
      }
    } catch (_) {}
  }
}
