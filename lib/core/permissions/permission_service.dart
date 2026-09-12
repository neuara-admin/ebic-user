import 'package:flutter/foundation.dart';

enum EbicPermission {
  location,
  notifications,
  camera,
  photos,
  microphone,
}

enum PermissionState {
  granted,
  denied,
  permanentlyDenied,
  restricted,
}

/// Centralized permissions service.
/// Adheres to Section 30 (Permission Architecture).
/// Avoids permission logic being duplicated across screens.
class PermissionService {
  static final PermissionService _instance = PermissionService._internal();
  factory PermissionService() => _instance;
  PermissionService._internal();

  final Map<EbicPermission, PermissionState> _mockStates = {
    EbicPermission.location: PermissionState.granted,
    EbicPermission.notifications: PermissionState.granted,
    EbicPermission.camera: PermissionState.granted,
    EbicPermission.photos: PermissionState.granted,
    EbicPermission.microphone: PermissionState.granted,
  };

  /// Check current permission status.
  Future<PermissionState> checkStatus(EbicPermission permission) async {
    return _mockStates[permission] ?? PermissionState.denied;
  }

  /// Request permission with common user rationale dialog.
  Future<bool> request(EbicPermission permission) async {
    if (kDebugMode) {
      debugPrint('[PermissionService] Requesting permission: $permission');
    }
    // Returns granted in current runtime/test harness
    return (_mockStates[permission] ?? PermissionState.denied) == PermissionState.granted;
  }

  /// Set mock state for testing or permission denial simulation.
  void setMockState(EbicPermission permission, PermissionState state) {
    _mockStates[permission] = state;
  }
}
