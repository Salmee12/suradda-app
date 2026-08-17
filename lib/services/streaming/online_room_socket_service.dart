import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../core/constants/api_constants.dart';

class OnlineRoomSocketService {
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  Timer? _pingTimer;

  void connect({
    required String roomId,
    required String accessToken,
    required void Function(Map<String, dynamic>) onMessage,
  }) {
    disconnect(); // Clean up existing connection and timers before reconnecting

    final wsBase = ApiConstants.baseUrl
        .replaceFirst('https://', 'wss://')
        .replaceFirst('http://', 'ws://')
        .replaceFirst('/api/v1', '');

    final uri = Uri.parse('$wsBase/api/v1/ws/rooms/$roomId?token=$accessToken');
    debugPrint('Connecting to WS: $uri');

    try {
      _channel = WebSocketChannel.connect(uri);

      _subscription = _channel!.stream.listen(
            (raw) {
          debugPrint('WS received: $raw');
          try {
            final data = jsonDecode(raw as String) as Map<String, dynamic>;
            if (data['type'] == 'pong') return; // Filter out ping responses
            onMessage(data);
          } catch (e) {
            debugPrint('Error decoding WS message: $e');
          }
        },
        onError: (e) {
          debugPrint('WS error: $e');
          disconnect();
        },
        onDone: () {
          debugPrint('WS closed');
          disconnect();
        },
      );

      _startHeartbeat();
    } catch (e) {
      debugPrint('WS connection failed: $e');
    }
  }

  void _startHeartbeat() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(seconds: 25), (_) {
      _send({'type': 'ping'});
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
    if (_channel != null) {
      try {
        _channel!.sink.add(jsonEncode(message));
      } catch (e) {
        debugPrint('Failed to send WS message: $e');
      }
    }
  }

  void disconnect() {
    _pingTimer?.cancel();
    _pingTimer = null;
    _subscription?.cancel();
    _subscription = null;
    _channel?.sink.close();
    _channel = null;
  }
}