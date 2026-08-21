import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:bonsoir/bonsoir.dart';
import 'package:flutter/foundation.dart';

class DiscoveredHost {
  final String name;
  final String hostIp;
  final int port;
  final BonsoirService bonsoirService;

  DiscoveredHost({
    required this.name,
    required this.hostIp,
    required this.port,
    required this.bonsoirService,
  });
}

class LocalStreamClientService {
  BonsoirDiscovery? _discovery;
  WebSocket? _controlSocket;
  StreamSubscription? _discoverySubscription;
  // Add this set at the top of your LocalStreamClientService class:
  final Set<String> _resolving = {};

  final StreamController<List<DiscoveredHost>> _discoveredHostsController =
  StreamController<List<DiscoveredHost>>.broadcast();
  final List<DiscoveredHost> _hosts = [];

  Stream<List<DiscoveredHost>> get discoveredHostsStream => _discoveredHostsController.stream;

  Function(String streamUrl, String trackId, String title, String artist, int positionMs, bool isPlaying)? onSyncTrack;
  Function()? onPause;
  Function()? onResume;
  Function(int positionMs)? onSeek;



  Future<void> startDiscovery() async {
    _hosts.clear();
    _resolving.clear();
    _discoveredHostsController.add([]);

    _discovery = BonsoirDiscovery(type: '_suradda._tcp');
    await _discovery!.initialize();

    _discoverySubscription = _discovery!.eventStream!.listen((event) {
      debugPrint('Bonsoir event: $event');

      switch (event) {
        case BonsoirDiscoveryServiceFoundEvent():
          final name = event.service.name;
          if (_resolving.add(name)) {
            // Resolve service to get IP and port
            event.service.resolve(_discovery!.serviceResolver);
          }
          break;

        case BonsoirDiscoveryServiceResolvedEvent():
          final service = event.service;
          final hostIp = service.host ?? service.attributes['host'] ?? service.name;

          final host = DiscoveredHost(
            name: service.name,
            hostIp: hostIp,
            port: service.port,
            bonsoirService: service,
          );

          _hosts.removeWhere((h) => h.name == service.name);
          _hosts.add(host);
          _discoveredHostsController.add(List.from(_hosts));
          break;

        case BonsoirDiscoveryServiceLostEvent():
          final name = event.service.name;
          _resolving.remove(name);
          _hosts.removeWhere((h) => h.name == name);
          _discoveredHostsController.add(List.from(_hosts));
          break;

        default:
          break;
      }
    });

    await _discovery!.start();
  }

  Future<void> connectToHost(String hostIp, {int port = 8090}) async {
    await disconnect();

    try {
      final wsUrl = 'ws://$hostIp:$port/control';
      _controlSocket = await WebSocket.connect(wsUrl);
      debugPrint('Connected to host WebSocket control: $wsUrl');

      _controlSocket!.listen((rawMessage) {
        final data = jsonDecode(rawMessage as String);
        final action = data['action'] as String?;

        switch (action) {
          case 'SYNC_TRACK':
            final version = data['streamVersion'] ?? DateTime.now().millisecondsSinceEpoch;
            final streamUrl = 'http://$hostIp:$port/stream?v=$version'; // NEW — cache-busting query param
            onSyncTrack?.call(
              streamUrl,
              data['trackId'] ?? '',
              data['title'] ?? 'Unknown',
              data['artist'] ?? 'Unknown',
              data['positionMs'] ?? 0,
              data['isPlaying'] ?? false,
            );
            break;
          case 'PAUSE':
            onPause?.call();
            break;
          case 'RESUME':
            onResume?.call();
            break;
          case 'SEEK':
            onSeek?.call(data['positionMs'] ?? 0);
            break;
        }
      }, onDone: () {
        debugPrint('Disconnected from host.');
      });
    } catch (e) {
      debugPrint('Failed to connect to host WebSocket: $e');
      rethrow;
    }
  }

  Future<void> stopDiscovery() async {
    await _discoverySubscription?.cancel();
    _discoverySubscription = null;

    try {
      await _discovery?.stop();
    } catch (e) {
      debugPrint('Safe ignore - Bonsoir discovery stop error: $e');
    }
    _discovery = null;
  }

  Future<void> disconnect() async {
    try {
      await _controlSocket?.close();
    } catch (_) {}
    _controlSocket = null;
  }

  void dispose() {
    stopDiscovery();
    disconnect();
    _discoveredHostsController.close();
  }
}