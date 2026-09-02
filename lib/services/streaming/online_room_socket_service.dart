import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../core/constants/api_constants.dart';

/// Thin wrapper over the online-party WebSocket.
///
/// Every path that can end the connection — a close frame, a stream error, a
/// failed send, or a half-open link caught by the pong watchdog — funnels
/// through [_handleDrop], which fires the `onDisconnected` callback exactly
/// once. Without that callback the ViewModel keeps showing a party the user is
/// no longer in.
class OnlineRoomSocketService {
  static const _pingInterval = Duration(seconds: 25);
  static const _watchdogInterval = Duration(seconds: 10);

  /// How long the link may stay silent before we declare it dead. Comfortably
  /// larger than [_pingInterval] so one lost pong doesn't tear down a live
  /// socket.
  static const _silenceTimeout = Duration(seconds: 70);

  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  Timer? _pingTimer;
  Timer? _watchdogTimer;

  void Function()? _onDisconnected;
  bool _closingIntentionally = false;

  /// The watchdog only arms once the server has actually answered a ping. If the
  /// backend doesn't implement pong, an unconditional watchdog would kill a
  /// perfectly healthy socket every 70 seconds.
  bool _sawPong = false;
  DateTime _lastInbound = DateTime.now();

  bool get isConnected => _channel != null;

  /// Opens the socket and completes once the handshake has succeeded.
  /// Throws if the connection cannot be established.
  Future<void> connect({
    required String roomId,
    required String accessToken,
    required void Function(Map<String, dynamic>) onMessage,
    void Function()? onDisconnected,
  }) async {
    disconnect(); // Clean up any existing connection and timers first.

    final wsBase = ApiConstants.baseUrl
        .replaceFirst('https://', 'wss://')
        .replaceFirst('http://', 'ws://')
        .replaceFirst('/api/v1', '');

    final uri = Uri.parse('$wsBase/api/v1/ws/rooms/$roomId?token=$accessToken');
    debugPrint('Connecting to WS: $uri');

    final channel = WebSocketChannel.connect(uri);
    // `connect` is lazy; `ready` is what actually surfaces a handshake failure,
    // so the caller can tell a real connection from a dead one.
    await channel.ready;

    _channel = channel;
    _closingIntentionally = false;
    _sawPong = false;
    _lastInbound = DateTime.now();
    _onDisconnected = onDisconnected;

    _subscription = channel.stream.listen(
      (raw) {
        _lastInbound = DateTime.now();
        debugPrint('WS received: $raw');
        try {
          final data = jsonDecode(raw as String) as Map<String, dynamic>;
          if (data['type'] == 'pong') {
            _sawPong = true; // The watchdog is now trustworthy.
            return;
          }
          onMessage(data);
        } catch (e) {
          debugPrint('Error decoding WS message: $e');
        }
      },
      onError: (e) => _handleDrop('stream error: $e'),
      onDone: () => _handleDrop('closed by peer'),
      cancelOnError: true,
    );

    _startHeartbeat();
    debugPrint('WS connected to room $roomId');
  }

  void _startHeartbeat() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(_pingInterval, (_) => _send({'type': 'ping'}));

    _watchdogTimer?.cancel();
    _watchdogTimer = Timer.periodic(_watchdogInterval, (_) {
      if (!_sawPong) return;
      if (DateTime.now().difference(_lastInbound) > _silenceTimeout) {
        _handleDrop('no traffic for ${_silenceTimeout.inSeconds}s');
      }
    });
  }

  void sendPlay({required String songId, required int positionMs}) {
    _send({'type': 'play', 'song_id': songId, 'position_ms': positionMs});
  }

  void sendPause({required int positionMs}) {
    _send({'type': 'pause', 'position_ms': positionMs});
  }

  void sendSeek({required int positionMs}) {
    _send({'type': 'seek', 'position_ms': positionMs});
  }

  void sendSyncPosition({required int positionMs}) {
    _send({'type': 'sync_position', 'position_ms': positionMs});
  }

  void _send(Map<String, dynamic> message) {
    final channel = _channel;
    if (channel == null) {
      debugPrint('Dropping WS message "${message['type']}" — socket is closed');
      return;
    }
    try {
      channel.sink.add(jsonEncode(message));
    } catch (e) {
      // A send that throws means the socket is gone; don't fail silently.
      _handleDrop('send failed: $e');
    }
  }

  /// Tears the connection down and notifies the listener exactly once.
  void _handleDrop(String reason) {
    if (_channel == null) return; // Already torn down.
    debugPrint('WS dropped ($reason)');
    final notify = _closingIntentionally ? null : _onDisconnected;
    _teardown();
    notify?.call();
  }

  void _teardown() {
    _pingTimer?.cancel();
    _pingTimer = null;
    _watchdogTimer?.cancel();
    _watchdogTimer = null;
    _subscription?.cancel();
    _subscription = null;
    try {
      _channel?.sink.close();
    } catch (e) {
      debugPrint('Error closing WS sink: $e');
    }
    _channel = null;
    _onDisconnected = null;
  }

  /// Closes the socket on purpose. `onDisconnected` will NOT fire.
  void disconnect() {
    _closingIntentionally = true;
    _teardown();
  }
}
