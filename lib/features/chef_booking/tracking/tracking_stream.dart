import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../../core/api/api_endpoints.dart';
import '../../../core/config/app_config.dart';
import '../../../core/storage/token_storage.dart';

/// Live tracking events for one booking over Server-Sent Events
/// (GET /chef-bookings/:id/tracking/stream): chef location, ETA and status
/// changes the moment the backend receives them, instead of waiting for the
/// next poll. Reconnects with backoff; the screen keeps a slow poll as a
/// safety net, so a dropped stream never freezes the map.
///
/// Not used on web — browsers' fetch buffers the whole response, so the
/// screen falls back to polling there.
class TrackingStream {
  TrackingStream(this.bookingId);

  final String bookingId;
  final _controller = StreamController<Map<String, dynamic>>.broadcast();
  http.Client? _client;
  StreamSubscription<String>? _lines;
  Timer? _retry;
  Timer? _watchdog;
  int _attempt = 0;
  bool _closed = false;

  /// True while the stream is open and heartbeats are arriving.
  final ValueNotifier<bool> connected = ValueNotifier(false);

  Stream<Map<String, dynamic>> get events => _controller.stream;

  static bool get supported => !kIsWeb;

  void start() {
    if (!supported || _closed) return;
    _connect();
  }

  Future<void> _connect() async {
    _cleanupConnection();
    final token = await TokenStorage.getAccessToken();
    if (_closed || token == null) return;

    final base = AppConfig.apiBaseUrl.trim().replaceAll(RegExp(r'/+$'), '');
    final uri = Uri.parse('$base${ApiEndpoints.chefBookingTracking(bookingId)}/stream');
    final client = http.Client();
    _client = client;
    try {
      final request = http.Request('GET', uri)
        ..headers['Authorization'] = 'Bearer $token'
        ..headers['Accept'] = 'text/event-stream'
        ..headers['Cache-Control'] = 'no-cache';
      final response = await client.send(request);
      if (response.statusCode != 200) {
        throw Exception('stream HTTP ${response.statusCode}');
      }
      _attempt = 0;
      connected.value = true;
      _armWatchdog();

      final buffer = StringBuffer();
      _lines = response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(
        (line) {
          if (line.startsWith('data:')) {
            buffer.write(line.substring(5).trimLeft());
          } else if (line.isEmpty && buffer.isNotEmpty) {
            _emit(buffer.toString());
            buffer.clear();
          }
        },
        onError: (_) => _scheduleReconnect(),
        onDone: _scheduleReconnect,
        cancelOnError: true,
      );
    } catch (_) {
      _scheduleReconnect();
    }
  }

  void _emit(String raw) {
    _armWatchdog();
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return;
      var event = Map<String, dynamic>.from(decoded);
      // Tolerate a response envelope ({success, data: {...}}) around the event.
      if (event['event'] == null && event['data'] is Map) {
        event = Map<String, dynamic>.from(event['data'] as Map);
      }
      if (event['event'] == 'heartbeat') return;
      _controller.add(event);
    } catch (_) {
      // Malformed frame — ignore; the next one (or the poll) resyncs.
    }
  }

  /// Server heartbeats every 15 s; silence for 40 s means the connection died
  /// without closing (common on mobile network switches).
  void _armWatchdog() {
    _watchdog?.cancel();
    _watchdog = Timer(const Duration(seconds: 40), _scheduleReconnect);
  }

  void _scheduleReconnect() {
    connected.value = false;
    _cleanupConnection();
    if (_closed) return;
    _attempt++;
    final seconds = [2, 4, 8, 15, 30][(_attempt - 1).clamp(0, 4)];
    _retry?.cancel();
    _retry = Timer(Duration(seconds: seconds), _connect);
  }

  void _cleanupConnection() {
    _watchdog?.cancel();
    _lines?.cancel();
    _lines = null;
    _client?.close();
    _client = null;
  }

  void dispose() {
    _closed = true;
    _retry?.cancel();
    _cleanupConnection();
    connected.dispose();
    _controller.close();
  }
}
