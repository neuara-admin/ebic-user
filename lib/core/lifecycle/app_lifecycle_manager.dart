import 'package:flutter/material.dart';

/// Centralized lifecycle observer.
/// Adheres to Section 22 (App Lifecycle): handles Foreground, Background, Inactive,
/// and recovers pending payment/booking transactions upon returning to foreground.
class AppLifecycleManager with WidgetsBindingObserver {
  static final AppLifecycleManager _instance = AppLifecycleManager._internal();
  factory AppLifecycleManager() => _instance;
  AppLifecycleManager._internal();

  AppLifecycleState _currentState = AppLifecycleState.resumed;
  AppLifecycleState get currentState => _currentState;

  final List<VoidCallback> _onForegroundCallbacks = [];

  void initialize() {
    WidgetsBinding.instance.addObserver(this);
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
  }

  /// Register callback to verify state when app returns to foreground
  /// (e.g. during payment or in-progress booking).
  void registerForegroundRecovery(VoidCallback callback) {
    _onForegroundCallbacks.add(callback);
  }

  void unregisterForegroundRecovery(VoidCallback callback) {
    _onForegroundCallbacks.remove(callback);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _currentState = state;

    if (state == AppLifecycleState.resumed) {
      // Trigger recovery query callbacks (Section 22: "Query backend, Do not assume failure")
      for (final callback in List<VoidCallback>.from(_onForegroundCallbacks)) {
        callback();
      }
    }
  }
}
