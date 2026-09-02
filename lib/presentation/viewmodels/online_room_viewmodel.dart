import 'dart:async';
import 'package:flutter/widgets.dart';
import '../../data/models/participant_model.dart';
import '../../data/models/room_model.dart';
import '../../data/models/song_model.dart';
import '../../data/repositories/room_repository.dart';
import '../../data/repositories/song_repository.dart';
import '../../services/streaming/online_room_socket_service.dart';
import '../../services/audio/playback_service.dart';
import '../../services/auth/token_storage_service.dart';
import 'room_connection.dart';

class OnlineRoomViewModel extends ChangeNotifier with WidgetsBindingObserver {
  final RoomRepository roomRepository;
  final SongRepository songRepository;
  final OnlineRoomSocketService socketService;
  final PlaybackService playbackService;
  final TokenStorageService tokenStorage;

  OnlineRoomViewModel(
      this.roomRepository,
      this.songRepository,
      this.socketService,
      this.playbackService,
      this.tokenStorage,
      ) {
    // Backgrounding the app can silently kill the socket; resuming is our cue to
    // check and rejoin.
    WidgetsBinding.instance.addObserver(this);
  }

  RoomModel? room;
  bool _isHost = false;
  bool _isSelectingSong = false;
  List<ParticipantModel> participants = []; // NEW
  bool isLoading = false;
  String? errorMessage;
  Timer? _syncTimer;

  /// Live socket state. The UI reads this instead of assuming that a non-null
  /// [room] means the user is still in the party.
  RoomConnection connection = RoomConnection.idle;
  Timer? _retryTimer;
  int _retryAttempt = 0;
  static const _maxRetries = 4;

  bool get isHost => _isHost;
  bool get isToggling => _isToggling; // add this getter
  bool get isConnected => connection == RoomConnection.connected;
  PlaybackService get playbackServicePublic => playbackService;


  Future<void> createParty() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      room = await roomRepository.createRoom();
      _isHost = true;
      playbackService.clearQueue(); // party starts with a clean slate
      await _openSocket();
    } catch (e, stack) {
      debugPrint('createParty failed: $e\n$stack');
      errorMessage = 'Could not create party. Please try again.';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> joinParty(String code) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      room = await roomRepository.joinRoom(code.trim().toUpperCase());
      _isHost = false;
      // A joining client keeps its own song until the host's first sync, but
      // never its radio: the radio outlives the Radio tab, so it can still be
      // streaming as the party opens.
      await playbackService.stopLiveRadio();
      await _openSocket();
    } catch (e, stack) {
      debugPrint('joinParty failed: $e\n$stack');
      errorMessage = 'Party not found. Check the code and try again.';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// First connect after creating/joining. A failure here is reported, not
  /// retried silently — the user just pressed a button and deserves an answer.
  Future<void> _openSocket() async {
    final ok = await _connectSocket();
    if (!ok) {
      connection = RoomConnection.disconnected;
      errorMessage =
          'You are in the party but the live connection failed. Tap Reconnect.';
      notifyListeners();
    }
  }

  /// Opens the socket. Returns true only if it is genuinely connected.
  Future<bool> _connectSocket() async {
    final token = await tokenStorage.getAccessToken();
    if (token == null || token.isEmpty) {
      debugPrint('WS Connection Aborted: Access token is null or empty');
      errorMessage = 'Authentication error. Please log in again.';
      connection = RoomConnection.disconnected;
      notifyListeners();
      return false;
    }

    if (room == null) {
      debugPrint('WS Connection Aborted: Room object is null');
      return false;
    }

    connection = _retryAttempt == 0
        ? RoomConnection.connecting
        : RoomConnection.reconnecting;
    notifyListeners();

    debugPrint('Connecting to WebSocket for Room ID: ${room!.id}');
    try {
      await socketService.connect(
        roomId: room!.id,
        accessToken: token,
        onMessage: _handleMessage,
        onDisconnected: _handleSocketDrop,
      );
    } catch (e) {
      debugPrint('WS connect failed: $e');
      return false;
    }

    connection = RoomConnection.connected;
    _retryAttempt = 0;
    if (isHost) _startHostSyncTimer();
    notifyListeners();
    return true;
  }

  void _startHostSyncTimer() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(seconds: 6), (_) {
      if (playbackService.isPlaying) {

        final song = playbackService.currentSong;
        if (song != null && song.trackId != room?.currentSongId) {
          socketService.sendPlay(songId: song.trackId, positionMs: 0);
          room = room?.copyWith(currentSongId: song.trackId, isPlaying: true, currentPositionMs: 0);
          notifyListeners();
        }

        socketService.sendSyncPosition(
          positionMs: playbackService.player.position.inMilliseconds,
        );
      }
    });
  }

  /// The socket died on its own. Stop broadcasting into the void, tell the UI
  /// the truth, and start trying to get back in.
  void _handleSocketDrop() {
    if (room == null) return; // Already left; nothing to recover.
    debugPrint('Online party socket dropped — entering reconnect');
    _syncTimer?.cancel();
    _syncTimer = null;
    connection = RoomConnection.reconnecting;
    notifyListeners();
    _scheduleRetry();
  }

  void _scheduleRetry() {
    _retryTimer?.cancel();
    if (_retryAttempt >= _maxRetries) {
      debugPrint('Giving up on automatic reconnect after $_retryAttempt tries');
      connection = RoomConnection.disconnected;
      notifyListeners();
      return;
    }

    // 2s, 4s, 8s, 16s — long enough to ride out a lift or a WiFi handover
    // without hammering the server.
    final delay = Duration(seconds: 2 << _retryAttempt);
    _retryAttempt++;
    debugPrint('Retrying party socket in ${delay.inSeconds}s (attempt $_retryAttempt)');
    _retryTimer = Timer(delay, () async {
      if (room == null) return;
      final ok = await _connectSocket();
      if (!ok) _scheduleRetry();
    });
  }

  /// Manual "Reconnect" from the UI — tries immediately, then falls back to the
  /// automatic retry ladder.
  Future<void> retryConnection() async {
    if (room == null) return;
    _retryTimer?.cancel();
    _retryAttempt = 0;
    errorMessage = null;
    final ok = await _connectSocket();
    if (!ok) _scheduleRetry();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    if (room == null || connection == RoomConnection.connected) return;
    debugPrint('App resumed with a broken party socket — reconnecting');
    retryConnection();
  }

  void _handleMessage(Map<String, dynamic> data) {
    final type = data['type'];

    switch (type) {
      case 'play':
      case 'pause':
      case 'seek':
      case 'sync_position':
        final positionMs = data['position_ms'] as int?;
        final songId = data['song_id'] as String?;

        if (positionMs != null) {
          room = room?.copyWith(
            currentPositionMs: positionMs,
            currentSongId: songId ?? room?.currentSongId,
            isPlaying: type != 'pause',
          );
        }

        if (!isHost) {
          _mirrorPlayback(type, positionMs, songId);
        }
        notifyListeners();
        break;

      case 'participant_count':
        final count = data['count'] as int?;
        if (count != null) {
          room = room?.copyWith(participantCount: count);
          notifyListeners();
        }
        break;

      case 'participants': // NEW
        final list = data['participants'] as List<dynamic>?;
        final count = data['count'] as int?;
        if (list != null) {
          participants = list.map((p) => ParticipantModel.fromJson(p)).toList();
        }
        if (count != null) {
          room = room?.copyWith(participantCount: count);
        }
        notifyListeners();
        break;
    }
  }

  Future<void> _mirrorPlayback(String type, int? positionMs, String? songId) async {
    if (positionMs == null) return;

    // 1. If host changes or starts a new song, load it on the client player
    if (songId != null && songId.isNotEmpty && playbackService.currentSong?.trackId != songId) {
      try {
        final songs = await songRepository.getCloudSongs();
        final targetSong = songs.firstWhere(
              (s) => (s.id == songId || s.trackId == songId),
        );
        await playbackService.playSong(targetSong);
      } catch (e) {
        debugPrint('Failed to fetch/play mirrored track: $e');
        return; // Avoid seeking an unloaded player
      }
    }

    final currentPos = playbackService.player.position.inMilliseconds;
    final drift = (currentPos - positionMs).abs();

    // 2. Control audio player with a 1500ms threshold to prevent buffer crashes on Web & Mobile
    switch (type) {
      case 'play':
        if (drift > 1500) {
          await playbackService.seek(Duration(milliseconds: positionMs));
        }
        await playbackService.resume();
        break;

      case 'pause':
        await playbackService.pause();
        break;

      case 'seek':
        await playbackService.seek(Duration(milliseconds: positionMs));
        break;

      case 'sync_position':
        if (drift > 1500) {
          await playbackService.seek(Duration(milliseconds: positionMs));
        }
        break;
    }
  }

  Future<void> hostPlaySong(SongModel song, {List<SongModel>? queue}) async {
    if (!isHost || _isSelectingSong) return;
    _isSelectingSong = true;
    try {
      // 1. Tell listeners to pause immediately — don't let them keep playing the outgoing track
      /*socketService.sendPause(positionMs: playbackService.player.position.inMilliseconds);
      room = room?.copyWith(isPlaying: false);
      notifyListeners();*/

      await playbackService.playSong(song, queue: queue ?? [song]);

      // 3. Broadcast the new track once it's actually loaded and playing
      socketService.sendPlay(songId: song.id, positionMs: 0);
      room = room?.copyWith(currentSongId: song.id, isPlaying: true, currentPositionMs: 0);
      notifyListeners();
    } finally {
      _isSelectingSong = false;
    }
  }

  Future<void> hostPlayNext() async {
    if (!isHost || !playbackService.hasNext) return;
    await playbackService.pause(); // NEW
    await playbackService.playNext();
    final song = playbackService.currentSong;
    if (song == null) return;
    socketService.sendPlay(songId: song.trackId, positionMs: 0);
    room = room?.copyWith(currentSongId: song.trackId, isPlaying: true, currentPositionMs: 0);
    notifyListeners();
  }

  Future<void> hostPlayPrevious() async {
    if (!isHost || !playbackService.hasPrevious) return;
    await playbackService.pause(); // NEW
    await playbackService.playPrevious();
    final song = playbackService.currentSong;
    if (song == null) return;
    socketService.sendPlay(songId: song.trackId, positionMs: 0);
    room = room?.copyWith(currentSongId: song.trackId, isPlaying: true, currentPositionMs: 0);
    notifyListeners();
  }

  bool _isToggling = false; // NEW

  Future<void> hostTogglePlayPause() async {
    if (!isHost || _isToggling) return;
    _isToggling = true;
    try {
      await playbackService.togglePlayPause();

      final positionMs = playbackService.player.position.inMilliseconds;
      final activeSongId = playbackService.currentSong?.trackId ?? room?.currentSongId ?? '';

      if (playbackService.isPlaying) {
        socketService.sendPlay(songId: activeSongId, positionMs: positionMs);
      } else {
        socketService.sendPause(positionMs: positionMs);
      }
      room = room?.copyWith(isPlaying: playbackService.isPlaying);
      notifyListeners();
    } finally {
      _isToggling = false;
    }
  }

  /// Host-only: Seek to a position across the room.
  Future<void> hostSeek(Duration position) async {
    if (!isHost) return;
    await playbackService.seek(position);
    socketService.sendSeek(positionMs: position.inMilliseconds);
  }

  Future<void> leaveParty() async {
    _syncTimer?.cancel();
    _syncTimer = null;
    _retryTimer?.cancel();
    _retryTimer = null;
    _retryAttempt = 0;
    socketService.disconnect();
    if (room != null) {
      try {
        await roomRepository.leaveRoom(room!.id);
      } catch (e) {
        debugPrint('Error leaving room: $e');
      }
    }
    room = null;
    participants = [];
    connection = RoomConnection.idle;
    errorMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _syncTimer?.cancel();
    _retryTimer?.cancel();
    socketService.disconnect();
    super.dispose();
  }
}