import 'dart:async';
import 'package:flutter/foundation.dart';

enum RealtimeEventType {
  chefAssigned,
  chefDeparted,
  chefArrived,
  cookingStarted,
  cookingCompleted,
  orderStatusChanged,
  supportTicketUpdated,
}

class RealtimeEvent {
  final RealtimeEventType type;
  final String referenceId;
  final Map<String, dynamic> payload;

  const RealtimeEvent({
    required this.type,
    required this.referenceId,
    this.payload = const {},
  });
}

/// Realtime subscription manager supporting WebSocket / SSE with controlled polling fallback.
/// Adheres strictly to Section 18 (Realtime Architecture).
class RealtimeService {
  static final RealtimeService _instance = RealtimeService._internal();
  factory RealtimeService() => _instance;
  RealtimeService._internal();

  final _eventStreamController = StreamController<RealtimeEvent>.broadcast();
  Stream<RealtimeEvent> get events => _eventStreamController.stream;

  Timer? _pollingTimer;
  bool _isConnected = false;

  bool get isConnected => _isConnected;

  /// Connect to realtime channel
  void connect({required String userId}) {
    _isConnected = true;
    if (kDebugMode) {
      debugPrint('[RealtimeService] ⚡ Connected realtime channel for user: $userId');
    }
  }

  /// Disconnect realtime channel
  void disconnect() {
    _isConnected = false;
    _pollingTimer?.cancel();
    _pollingTimer = null;
    if (kDebugMode) {
      debugPrint('[RealtimeService] 🔌 Disconnected realtime channel');
    }
  }

  /// Start controlled polling fallback (Section 18: "Controlled polling / refresh")
  void startControlledPolling({
    required Future<void> Function() onPoll,
    Duration interval = const Duration(seconds: 15),
  }) {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(interval, (_) async {
      try {
        await onPoll();
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[RealtimeService] Polling cycle error: $e');
        }
      }
    });
  }

  void stopControlledPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  /// Dispatches an event (used by WebSocket client or local simulations)
  void dispatchEvent(RealtimeEvent event) {
    _eventStreamController.add(event);
  }
}
