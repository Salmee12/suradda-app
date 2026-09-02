import 'dart:async';
import 'package:flutter/widgets.dart';
import '../../data/models/local_song_model.dart';
import '../../services/audio/playback_service.dart';
import '../../services/auth/token_storage_service.dart';
import '../../services/streaming/local_stream_client_service.dart';
import '../../services/streaming/local_stream_host_service.dart';
import 'room_connection.dart';

enum HotspotRoomMode { none, host, client }

class HotspotRoomViewModel extends ChangeNotifier with WidgetsBindingObserver {
  final LocalStreamHostService hostService;
  final LocalStreamClientService clientService;
  final PlaybackService playbackService;
  final TokenStorageService tokenStorage;

  HotspotRoomMode _mode = HotspotRoomMode.none;
  DiscoveredHost? _connectedHost;
  Timer? _syncTimer;
  bool _isSwitchingTrack = false;

  /// Live state of the client's control socket (hosts are "connected" for as
  /// long as their own server is up). The UI reads this instead of assuming
  /// that being in client mode means the host is still reachable.
  RoomConnection connection = RoomConnection.idle;
  Timer? _retryTimer;
  int _retryAttempt = 0;
  static const _maxRetries = 4;

  HotspotRoomViewModel({
    required this.hostService,
    required this.clientService,
    required this.playbackService,
    required this.tokenStorage,
  }) {
    _setupClientCallbacks();
    // Android suspends timers and sockets for backgrounded apps; resuming is our
    // cue to check whether we silently fell out of the party.
    WidgetsBinding.instance.addObserver(this);
  }

  HotspotRoomMode get mode => _mode;
  bool get isHost => _mode == HotspotRoomMode.host;
  bool get isClient => _mode == HotspotRoomMode.client;
  bool get isConnected => connection == RoomConnection.connected;
  DiscoveredHost? get connectedHost => _connectedHost;
  LocalStreamHostService get hostServicePublic => hostService;
  LocalStreamClientService get clientServicePublic => clientService;


  // --- HOST ACTIONS ---

  Future<void> startHosting() async {
    debugPrint('[HotspotVM] startHosting() called');
    await clientService.disconnect();
    await clientService.stopDiscovery();
    // Deliberately not clearQueue(): the host keeps whatever song they had
    // loaded. The radio is the exception — it now survives leaving the Radio
    // tab, and a party has no business streaming a station.
    await playbackService.stopLiveRadio();
    final username = await tokenStorage.getUsername();
    final partyName = (username != null && username.isNotEmpty)
        ? "$username's Hotspot Party"
        : 'Suradda Hotspot Party';
    await hostService.startHost(partyName: partyName);
    _mode = HotspotRoomMode.host;
    connection = RoomConnection.connected;

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

    // Flip mode BEFORE connecting so the very first SYNC_TRACK
    // (which the host sends the instant the socket upgrades) isn't
    // dropped by the isClient guard in onSyncTrack/onPause/onResume.
    _connectedHost = host;
    _mode = HotspotRoomMode.client;
    connection = RoomConnection.connecting;
    _retryAttempt = 0;
    notifyListeners();

    try {
      await clientService.connectToHost(host.hostIp, port: host.port);
      connection = RoomConnection.connected;
      notifyListeners();
      debugPrint('[HotspotVM] Joined party successfully as client');
    } catch (e) {
      _mode = HotspotRoomMode.none;
      _connectedHost = null;
      connection = RoomConnection.idle;
      notifyListeners();
      rethrow;
    }
  }

  /// The host's control socket went away without us asking. Tell the truth in
  /// the UI, stop the now-orphaned stream, and try to get back in.
  void _handleClientDrop() {
    debugPrint('[HotspotVM] Lost the host connection');
    connection = RoomConnection.reconnecting;
    // The audio came from the host's HTTP server, which is gone too. Pausing
    // stops the client from playing a stale buffer that can never resync.
    playbackService.pause();
    notifyListeners();
    _scheduleRejoin();
  }

  void _scheduleRejoin() {
    _retryTimer?.cancel();
    final host = _connectedHost;
    if (host == null || _retryAttempt >= _maxRetries) {
      debugPrint('[HotspotVM] Giving up on automatic rejoin');
      connection = RoomConnection.disconnected;
      notifyListeners();
      return;
    }

    // 2s, 4s, 8s, 16s — enough to survive a WiFi hiccup or the host briefly
    // backgrounding, without spinning.
    final delay = Duration(seconds: 2 << _retryAttempt);
    _retryAttempt++;
    debugPrint('[HotspotVM] Rejoining ${host.name} in ${delay.inSeconds}s (attempt $_retryAttempt)');
    _retryTimer = Timer(delay, () async {
      if (!isClient) return;
      try {
        await clientService.connectToHost(host.hostIp, port: host.port);
        // The host re-sends SYNC_TRACK the instant the socket upgrades, so the
        // current track and position come back on their own.
        connection = RoomConnection.connected;
        _retryAttempt = 0;
        notifyListeners();
        debugPrint('[HotspotVM] Rejoined ${host.name}');
      } catch (e) {
        debugPrint('[HotspotVM] Rejoin failed: $e');
        _scheduleRejoin();
      }
    });
  }

  /// Manual "Reconnect" from the UI — tries immediately, then falls back to the
  /// automatic retry ladder.
  Future<void> retryConnection() async {
    final host = _connectedHost;
    if (!isClient || host == null) return;
    _retryTimer?.cancel();
    _retryAttempt = 0;
    connection = RoomConnection.reconnecting;
    notifyListeners();
    try {
      await clientService.connectToHost(host.hostIp, port: host.port);
      connection = RoomConnection.connected;
      notifyListeners();
    } catch (e) {
      debugPrint('[HotspotVM] Manual reconnect failed: $e');
      _scheduleRejoin();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    if (!isClient || connection == RoomConnection.connected) return;
    debugPrint('[HotspotVM] App resumed with a broken host connection — reconnecting');
    retryConnection();
  }

  void _setupClientCallbacks() {
    clientService.onDisconnected = () {
      // Only meaningful while we believe we're a client; a stale callback after
      // leaving must not resurrect the room UI.
      if (!isClient) return;
      _handleClientDrop();
    };

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
    _retryTimer?.cancel();
    _retryTimer = null;
    _retryAttempt = 0;

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
    connection = RoomConnection.idle;
    debugPrint('[HotspotVM] Left room successfully');
    notifyListeners();
  }

  @override
  void dispose() {
    debugPrint('[HotspotVM] dispose() called');
    WidgetsBinding.instance.removeObserver(this);
    _syncTimer?.cancel();
    _retryTimer?.cancel();
    super.dispose();
  }
}