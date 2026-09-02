import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:bonsoir/bonsoir.dart';
import 'package:flutter/foundation.dart';

class LocalStreamHostService extends ChangeNotifier {
  HttpServer? _server;
  BonsoirBroadcast? _broadcast;
  final List<WebSocket> _sockets = [];

  String? _currentFilePath;
  String? _currentTrackId;
  String? _currentTitle;
  String? _currentArtist;
  bool _isPlaying = false;
  int _currentPositionMs = 0;
  int _streamVersion = 0;

  bool get isHosting => _server != null;
  int get connectedClientsCount => _sockets.length;
  String? get currentTitle => _currentTitle;
  String? get currentArtist => _currentArtist;
  bool get isPlaying => _isPlaying;
  int get currentPositionMs => _currentPositionMs;

  Future<void> startHost({int port = 8090, String partyName = 'Suradda Hotspot Party'}) async {
    if (_server != null) return;

    _server = await HttpServer.bind(InternetAddress.anyIPv4, port);
    debugPrint('Host server listening on port $port');

    _server!.listen((HttpRequest request) {
      if (request.uri.path == '/stream') {
        _handleAudioStream(request);
      } else if (request.uri.path == '/control') {
        _handleWebSocketControl(request);
      } else {
        request.response.statusCode = HttpStatus.notFound;
        request.response.close();
      }
    });

    try {
      final service = BonsoirService(
        name: partyName,
        type: '_suradda._tcp',
        port: port,
      );
      _broadcast = BonsoirBroadcast(service: service);
      await _broadcast!.initialize();
      await _broadcast!.start();
    } catch (e) {
      debugPrint('Bonsoir broadcast error: $e');
    }
    notifyListeners();
  }

  void _handleAudioStream(HttpRequest request) async {
    if (_currentFilePath == null) {
      request.response.statusCode = HttpStatus.notFound;
      request.response.close();
      return;
    }
    final file = File(_currentFilePath!);
    if (!file.existsSync()) {
      request.response.statusCode = HttpStatus.notFound;
      request.response.close();
      return;
    }
    final fileLength = await file.length();
    request.response.headers.contentType = ContentType('audio', 'mpeg');
    request.response.headers.add('Accept-Ranges', 'bytes');
    try {
      final rangeHeader = request.headers.value('range');
      if (rangeHeader != null && rangeHeader.startsWith('bytes=')) {
        final parts = rangeHeader.substring(6).split('-');
        final start = int.parse(parts[0]);
        final end = parts.length > 1 && parts[1].isNotEmpty ? int.parse(parts[1]) : fileLength - 1;
        request.response.statusCode = HttpStatus.partialContent;
        request.response.headers.add('Content-Range', 'bytes $start-$end/$fileLength');
        request.response.contentLength = end - start + 1;
        await file.openRead(start, end + 1).pipe(request.response);
      } else {
        request.response.contentLength = fileLength;
        await file.openRead().pipe(request.response);
      }
    } catch (e) {
      debugPrint('Stream piping closed by client: $e');
    }
  }

  Future<void> stopHost() async {
    for (final socket in List.from(_sockets)) {
      try {
        await socket.close();
      } catch (_) {}
    }
    _sockets.clear();
    try {
      await _broadcast?.stop();
    } catch (_) {}
    _broadcast = null;
    try {
      await _server?.close(force: true);
    } catch (_) {}
    _server = null;
    _currentFilePath = null;
    _currentTrackId = null;
    _currentTitle = null;
    _currentArtist = null;
    _isPlaying = false;
    _currentPositionMs = 0;
    notifyListeners();
  }

  void _handleWebSocketControl(HttpRequest request) async {
    if (WebSocketTransformer.isUpgradeRequest(request)) {
      final socket = await WebSocketTransformer.upgrade(request);
      _sockets.add(socket);
      // Protocol-level keepalive so a listener whose phone leaves the network is
      // dropped from the count instead of lingering as a half-open socket.
      socket.pingInterval = const Duration(seconds: 30);
      notifyListeners(); // NEW — reflect the new listener count immediately

      if (_currentTrackId != null) {
        socket.add(jsonEncode({
          'action': 'SYNC_TRACK',
          'trackId': _currentTrackId,
          'title': _currentTitle,
          'artist': _currentArtist,
          'positionMs': _currentPositionMs,
          'isPlaying': _isPlaying,
          'streamVersion': _streamVersion, // NEW
        }));
      }

      socket.listen(
            (data) {},
        onDone: () {
          _sockets.remove(socket);
          notifyListeners(); // NEW
        },
        onError: (_) {
          _sockets.remove(socket);
          notifyListeners(); // NEW
        },
      );
    }
  }

  void setTrack({
    required String filePath,
    required String trackId,
    required String title,
    required String artist,
  }) {
    _currentFilePath = filePath;
    _currentTrackId = trackId;
    _currentTitle = title;
    _currentArtist = artist;
    _isPlaying = true;
    _currentPositionMs = 0;
    _streamVersion++; // NEW — forces a genuinely different URL every track change
    notifyListeners(); // NEW

    _broadcastMessage({
      'action': 'SYNC_TRACK',
      'trackId': _currentTrackId,
      'title': _currentTitle,
      'artist': _currentArtist,
      'positionMs': 0,
      'isPlaying': true,
      'streamVersion': _streamVersion, // NEW
    });
  }

  void broadcastPlayState(bool isPlaying, int positionMs) {
    _isPlaying = isPlaying;
    _currentPositionMs = positionMs;
    notifyListeners(); // NEW
    _broadcastMessage({'action': isPlaying ? 'RESUME' : 'PAUSE', 'positionMs': positionMs});
  }

  void broadcastSeek(int positionMs) {
    _currentPositionMs = positionMs;
    notifyListeners(); // NEW
    _broadcastMessage({'action': 'SEEK', 'positionMs': positionMs});
  }

  void _broadcastMessage(Map<String, dynamic> data) {
    final payload = jsonEncode(data);
    for (final socket in List.from(_sockets)) {
      try {
        socket.add(payload);
      } catch (e) {
        _sockets.remove(socket);
      }
    }
  }
}