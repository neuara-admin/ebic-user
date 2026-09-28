import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../auth/session_manager.dart';
import '../config/app_config.dart';
import '../storage/token_storage.dart';

enum SocketConnectionState {
  connected,
  disconnected,
  reconnecting,
}

/// Event names the backend emits (see ebic-backend RealtimeGateway /
/// ConsultationEventsService / NotificationService).
class RealtimeEvents {
  static const consultationStatusChanged = 'consultation.status_changed';
  static const notificationCreated = 'notification.created';
}

class StandardSocketEnvelope {
  final String eventId;
  final String type;
  final int version;
  final String timestamp;
  final Map<String, dynamic> data;

  const StandardSocketEnvelope({
    required this.eventId,
    required this.type,
    required this.version,
    required this.timestamp,
    required this.data,
  });

  factory StandardSocketEnvelope.fromJson(Map<String, dynamic> json) {
    final rawVersion = json['version'];
    return StandardSocketEnvelope(
      eventId: json['eventId']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      version: rawVersion is num ? rawVersion.toInt() : int.tryParse(rawVersion?.toString() ?? '') ?? 1,
      timestamp: json['timestamp']?.toString() ?? DateTime.now().toIso8601String(),
      data: json['data'] is Map ? Map<String, dynamic>.from(json['data'] as Map) : {},
    );
  }
}

/// Live connection to the backend's socket.io gateway. The backend puts every
/// authenticated socket in its own `user:{id}` room, so there's nothing to
/// subscribe to — screens just listen to [envelopes] (or the filtered
/// streams) and refetch when something relevant changes.
///
/// Follows [SessionManager]: connects when a session becomes authenticated,
/// disconnects on logout/expiry. The auth token is read fresh on every
/// (re)connect, so a refreshed access token is picked up automatically.
class RealtimeService {
  static final RealtimeService _instance = RealtimeService._internal();
  factory RealtimeService() => _instance;
  RealtimeService._internal();

  final _envelopeController = StreamController<StandardSocketEnvelope>.broadcast();
  final _stateController = StreamController<SocketConnectionState>.broadcast();

  Stream<StandardSocketEnvelope> get envelopes => _envelopeController.stream;
  Stream<SocketConnectionState> get stateStream => _stateController.stream;

  Stream<StandardSocketEnvelope> get consultationUpdates =>
      envelopes.where((e) => e.type == RealtimeEvents.consultationStatusChanged);
  Stream<StandardSocketEnvelope> get notifications =>
      envelopes.where((e) => e.type == RealtimeEvents.notificationCreated);

  SocketConnectionState _state = SocketConnectionState.disconnected;
  SocketConnectionState get state => _state;
  bool get isConnected => _state == SocketConnectionState.connected;

  io.Socket? _socket;
  bool _boundToSession = false;
  final Set<String> _seenEventIds = <String>{};

  /// Call once at startup.
  void bindToSession() {
    if (_boundToSession) return;
    _boundToSession = true;
    final session = SessionManager();
    session.addListener(() => _syncWithSession(session.status));
    _syncWithSession(session.status);
  }

  void _syncWithSession(AuthSessionStatus status) {
    if (status == AuthSessionStatus.authenticated) {
      connect();
    } else if (status == AuthSessionStatus.unauthenticated ||
        status == AuthSessionStatus.expired ||
        status == AuthSessionStatus.loggingOut) {
      disconnect();
    }
  }

  /// The API base is `http(s)://host:port/v1`; socket.io is served at the
  /// server root (`/socket.io/`), not under `/v1`.
  String get _serverUrl => AppConfig.apiBaseUrl.trim().replaceAll(RegExp(r'/v1/?$'), '');

  void connect() {
    if (_socket != null) return;

    final socket = io.io(
      _serverUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setAuthFn((callback) {
            TokenStorage.getAccessToken().then((token) => callback({'token': token ?? ''}));
          })
          .enableReconnection()
          .setReconnectionDelay(2000)
          .setReconnectionDelayMax(15000)
          .disableAutoConnect()
          .enableForceNew()
          .build(),
    );

    socket.onConnect((_) => _setState(SocketConnectionState.connected));
    socket.onDisconnect((reason) {
      // The server disconnects a socket whose token failed verification;
      // socket.io won't retry that on its own, so retry once the token
      // (likely just refreshed by ApiClient) is available again.
      if (reason == 'io server disconnect' && _socket == socket) {
        Future.delayed(const Duration(seconds: 3), () {
          if (_socket == socket) socket.connect();
        });
      }
      _setState(SocketConnectionState.reconnecting);
    });
    socket.onConnectError((err) {
      debugPrint('⚠️ [Realtime] connect error: $err');
      _setState(SocketConnectionState.reconnecting);
    });
    // The gateway emits every event both under its own name and as
    // `realtime_event`; listening to the latter alone avoids duplicates.
    socket.on('realtime_event', _onEnvelope);

    _socket = socket;
    socket.connect();
  }

  void disconnect() {
    final socket = _socket;
    _socket = null;
    if (socket != null) {
      socket.dispose();
    }
    _seenEventIds.clear();
    _setState(SocketConnectionState.disconnected);
  }

  void _onEnvelope(dynamic raw) {
    if (raw is! Map) return;
    final envelope = StandardSocketEnvelope.fromJson(Map<String, dynamic>.from(raw));
    if (envelope.eventId.isNotEmpty) {
      if (!_seenEventIds.add(envelope.eventId)) return;
      if (_seenEventIds.length > 500) _seenEventIds.remove(_seenEventIds.first);
    }
    _envelopeController.add(envelope);
  }

  void _setState(SocketConnectionState next) {
    if (_state == next) return;
    _state = next;
    _stateController.add(next);
  }
}
