import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../data/models/participant_model.dart';
import '../../data/models/room_model.dart';
import '../../data/models/song_model.dart';
import '../../data/repositories/room_repository.dart';
import '../../data/repositories/song_repository.dart';
import '../../services/streaming/online_room_socket_service.dart';
import '../../services/audio/playback_service.dart';
import '../../services/auth/token_storage_service.dart';

class OnlineRoomViewModel extends ChangeNotifier {
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
      );

  RoomModel? room;
  bool _isHost = false;
  bool _isSelectingSong = false;
  List<ParticipantModel> participants = []; // NEW
  bool isLoading = false;
  String? errorMessage;
  Timer? _syncTimer;

  bool get isHost => _isHost;
  bool get isToggling => _isToggling; // add this getter
  PlaybackService get playbackServicePublic => playbackService;

  Future<void> createParty() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      room = await roomRepository.createRoom();
      _isHost = true;
      playbackService.clearQueue(); // party starts with a clean slate
      await _connectSocket();
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
      await _connectSocket();
    } catch (e, stack) {
      debugPrint('joinParty failed: $e\n$stack');
      errorMessage = 'Party not found. Check the code and try again.';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _connectSocket() async {
    final token = await tokenStorage.getAccessToken();
    if (token == null || token.isEmpty) {
      debugPrint('WS Connection Aborted: Access token is null or empty');
      errorMessage = 'Authentication error. Please log in again.';
      notifyListeners();
      return;
    }

    if (room == null) {
      debugPrint('WS Connection Aborted: Room object is null');
      return;
    }

    debugPrint('Connecting to WebSocket for Room ID: ${room!.id}');
    socketService.connect(
      roomId: room!.id,
      accessToken: token,
      onMessage: _handleMessage,
    );

    if (isHost) {
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
    if (!isHost || _isToggling) return; // guard against reentrant calls
    _isToggling = true;
    try {

      final positionMs = playbackService.player.position.inMilliseconds;
      final activeSongId = playbackService.currentSong?.trackId ?? room?.currentSongId ?? '';

      if (playbackService.isPlaying) {
        socketService.sendPlay(songId: activeSongId, positionMs: positionMs);
      } else {
        socketService.sendPause(positionMs: positionMs);
      }
      room = room?.copyWith(isPlaying: playbackService.isPlaying); // explicit, don't rely on notifyListeners timing alone
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
    notifyListeners();
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    socketService.disconnect();
    super.dispose();
  }
}