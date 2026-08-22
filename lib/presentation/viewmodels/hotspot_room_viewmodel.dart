import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../data/models/local_song_model.dart';
import '../../services/audio/playback_service.dart';
import '../../services/streaming/local_stream_client_service.dart';
import '../../services/streaming/local_stream_host_service.dart';

enum HotspotRoomMode { none, host, client }

class HotspotRoomViewModel extends ChangeNotifier {
  final LocalStreamHostService hostService;
  final LocalStreamClientService clientService;
  final PlaybackService playbackService;

  HotspotRoomMode _mode = HotspotRoomMode.none;
  DiscoveredHost? _connectedHost;
  Timer? _syncTimer;
  bool _isSwitchingTrack = false;

  HotspotRoomViewModel({
    required this.hostService,
    required this.clientService,
    required this.playbackService,
  }) {
    _setupClientCallbacks();
  }

  HotspotRoomMode get mode => _mode;
  bool get isHost => _mode == HotspotRoomMode.host;
  bool get isClient => _mode == HotspotRoomMode.client;
  DiscoveredHost? get connectedHost => _connectedHost;
  LocalStreamHostService get hostServicePublic => hostService;
  LocalStreamClientService get clientServicePublic => clientService;

  // --- HOST ACTIONS ---

  Future<void> startHosting() async {
    debugPrint('[HotspotVM] startHosting() called');
    await clientService.disconnect();
    await clientService.stopDiscovery();
   // playbackService.clearQueue();
    await hostService.startHost();
    _mode = HotspotRoomMode.host;

    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(seconds: 6), (_) {
      if (isHost && playbackService.isPlaying) {
        debugPrint(
          '[HotspotVM] Periodic sync -> position: ${playbackService.player.position.inMilliseconds}ms',
        );
        hostService.broadcastPlayState(
          true,
          playbackService.player.position.inMilliseconds,
        );
      }
    });

    debugPrint('[HotspotVM] Hosting started successfully');
    notifyListeners();
  }

  Future<void> playLocalSongAsHost(LocalSongModel song) async {
    debugPrint(
      '[HotspotVM] playLocalSongAsHost() called -> title: ${song.title}, uri: ${song.uri}',
    );
    if (!isHost || _isSwitchingTrack) {
      debugPrint(
        '[HotspotVM] Ignored playLocalSongAsHost -> isHost: $isHost, _isSwitchingTrack: $_isSwitchingTrack',
      );
      return;
    }
    _isSwitchingTrack = true;
    try {
      if (song.uri.isEmpty || song.uri.startsWith('http')) {
        debugPrint('[HotspotVM] Error: Non-local song URI: ${song.uri}');
        throw Exception('Only local downloaded audio files can be shared in a Hotspot party.');
      }
      await playbackService.pause();
      await playbackService.playSong(song, queue: [song]);
      hostService.setTrack(
        filePath: song.uri,
        trackId: song.trackId,
        title: song.title,
        artist: song.subtitle,
      );
      debugPrint('[HotspotVM] Track broadcast complete for: ${song.title}');
      notifyListeners();
    } finally {
      _isSwitchingTrack = false;
    }
  }

  Future<void> hostTogglePlayPause() async {
    if (!isHost) return;
    debugPrint('[HotspotVM] hostTogglePlayPause() called');
    await playbackService.togglePlayPause();
    debugPrint(
      '[HotspotVM] Broadcasting play/pause state -> isPlaying: ${playbackService.isPlaying}',
    );
    hostService.broadcastPlayState(
      playbackService.isPlaying,
      playbackService.player.position.inMilliseconds,
    );
  }

  Future<void> hostSeek(Duration position) async {
    if (!isHost) return;
    debugPrint('[HotspotVM] hostSeek() called -> position: ${position.inMilliseconds}ms');
    await playbackService.seek(position);
    hostService.broadcastSeek(position.inMilliseconds);
  }

  // --- CLIENT ACTIONS ---

  void startDiscovery() {
    debugPrint('[HotspotVM] startDiscovery() called');
    clientService.startDiscovery();
  }

  Future<void> joinParty(DiscoveredHost host) async {
    debugPrint(
      '[HotspotVM] joinParty() called -> host: ${host.name} (${host.hostIp}:${host.port})',
    );
    await hostService.stopHost();
    playbackService.clearQueue();
    await clientService.connectToHost(host.hostIp, port: host.port);
    _connectedHost = host;
    _mode = HotspotRoomMode.client;
    debugPrint('[HotspotVM] Joined party successfully as client');
    notifyListeners();
  }

  void _setupClientCallbacks() {
    clientService.onSyncTrack = (streamUrl, trackId, title, artist, positionMs, isPlaying) async {
      debugPrint(
        '[HotspotClientCallback] onSyncTrack -> title: $title, pos: ${positionMs}ms, isPlaying: $isPlaying',
      );
      if (!isClient) return;
      await playbackService.playStreamTrack(
        streamUrl: streamUrl,
        trackId: trackId,
        title: title,
        subtitle: artist,
      );
      if (positionMs > 0) {
        await playbackService.seek(Duration(milliseconds: positionMs));
      }
      if (!isPlaying) {
        await playbackService.pause();
      }
      notifyListeners();
    };

    clientService.onPause = () {
      debugPrint('[HotspotClientCallback] onPause received');
      if (isClient) {
        playbackService.pause();
        notifyListeners();
      }
    };

    clientService.onResume = () {
      debugPrint('[HotspotClientCallback] onResume received');
      if (isClient) {
        playbackService.resume();
        notifyListeners();
      }
    };

    clientService.onSeek = (positionMs) {
      debugPrint('[HotspotClientCallback] onSeek received -> pos: ${positionMs}ms');
      if (isClient) playbackService.seek(Duration(milliseconds: positionMs));
    };
  }

  Future<void> leaveRoom() async {
    debugPrint('[HotspotVM] leaveRoom() called');
    _syncTimer?.cancel();
    _syncTimer = null;

    if (isHost) {
      debugPrint('[HotspotVM] Stopping host service...');
      await hostService.stopHost();
    } else if (isClient) {
      debugPrint('[HotspotVM] Disconnecting client service and stopping discovery...');
      await clientService.disconnect();
      await clientService.stopDiscovery();
    }

    try {
      await playbackService.pause();
    } catch (_) {}

    _mode = HotspotRoomMode.none;
    _connectedHost = null;
    debugPrint('[HotspotVM] Left room successfully');
    notifyListeners();
  }

  @override
  void dispose() {
    debugPrint('[HotspotVM] dispose() called');
    _syncTimer?.cancel();
    super.dispose();
  }
}