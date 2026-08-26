// lib/services/audio/playback_service.dart

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import '../../data/models/playable_track.dart';
import '../../data/models/radio_model.dart';

/// Synthetic track representation for client devices listening to an HTTP stream
class HotspotStreamTrack implements PlayableTrack {
  @override
  final String trackId;
  @override
  final String title;
  @override
  final String subtitle;
  @override
  final String playUrl;

  HotspotStreamTrack({
    required this.trackId,
    required this.title,
    required this.subtitle,
    required this.playUrl,
  });

  @override
  String? get artworkUrl => null;

  @override
  String get hexCode => '1DB954'; // Accent theme color
}

class PlaybackService extends ChangeNotifier {
  final AudioPlayer _player = AudioPlayer();

  List<PlayableTrack> _queue = [];
  int _currentIndex = -1;
  int _playRequestId = 0;

  PlaybackService() {
    _player.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) {
        notifyListeners();
      }
    });
  }

  bool get isCompleted => _player.processingState == ProcessingState.completed;
  AudioPlayer get player => _player;
  PlayableTrack? get currentSong =>
      _currentIndex >= 0 && _currentIndex < _queue.length ? _queue[_currentIndex] : null;

  bool get hasNext => _currentIndex >= 0 && _currentIndex < _queue.length - 1;
  bool get hasPrevious => _currentIndex > 0;

  void clearQueue() {
    _queue = [];
    _currentIndex = -1;
    _player.stop();
    notifyListeners();
  }

  /// Load and play an HTTP stream from the Host
  /// Load and play an HTTP stream from the Host
  Future<void> playStreamTrack({
    required String streamUrl,
    required String trackId,
    required String title,
    required String subtitle,
  }) async {
    // 1. Update state SYNCHRONOUSLY so all UI widgets update title immediately
    final streamTrack = HotspotStreamTrack(
      trackId: trackId,
      title: title,
      subtitle: subtitle,
      playUrl: streamUrl,
    );

    _queue = [streamTrack];
    _currentIndex = 0;
    final requestId = ++_playRequestId;
    notifyListeners(); // UI rebuilds instantly with the new song metadata

    // 2. Perform async audio player operations safely
    try {
      await _player.stop();
      if (requestId != _playRequestId) return;
      await _player.setUrl(streamUrl);
      if (requestId != _playRequestId) return;
      _startPlayback();
    } catch (e) {
      if (requestId != _playRequestId) return;
      rethrow;
    }
  }

  Future<void> playSong(PlayableTrack song, {List<PlayableTrack>? queue}) async {
    // 1. Synchronous state update
    if (queue != null) {
      _queue = queue;
      _currentIndex = _queue.indexWhere((s) => s.trackId == song.trackId);
    } else if (_queue.isEmpty || !_queue.any((s) => s.trackId == song.trackId)) {
      _queue = [song];
      _currentIndex = 0;
    } else {
      _currentIndex = _queue.indexWhere((s) => s.trackId == song.trackId);
    }

    final requestId = ++_playRequestId;
    notifyListeners(); // Instant UI update

    // 2. Async player operations
    try {
      await _player.stop();
      if (requestId != _playRequestId) return;
      await _player.setUrl(song.playUrl);
      if (requestId != _playRequestId) return;
      _startPlayback();
    } catch (e) {
      if (requestId != _playRequestId) return;
      rethrow;
    }
  }

  Future<void> playNext() async {
    if (!hasNext) return;
    _currentIndex++;
    final requestId = ++_playRequestId;
    notifyListeners();
    await _player.stop();
    if (requestId != _playRequestId) return;
    await _player.setUrl(_queue[_currentIndex].playUrl);
    if (requestId != _playRequestId) return;
    _startPlayback();
  }

  Future<void> playPrevious() async {
    if (!hasPrevious) return;
    _currentIndex--;
    final requestId = ++_playRequestId;
    notifyListeners();
    await _player.stop();
    if (requestId != _playRequestId) return;
    await _player.setUrl(_queue[_currentIndex].playUrl);
    if (requestId != _playRequestId) return;
    _startPlayback();
  }

  /// Starts playback WITHOUT awaiting completion.
  ///
  /// just_audio's [AudioPlayer.play] returns a Future that only completes when
  /// playback is paused, stopped, or the track ends — NOT when it starts.
  /// Awaiting it would suspend the caller for the entire track, deferring any
  /// work that runs afterwards (broadcasting a new track to a room, clearing a
  /// re-entrancy guard, etc.). So we fire it and forget it, logging errors.
  void _startPlayback() {
    unawaited(_player.play().catchError((Object e) {
      debugPrint('PlaybackService: play() failed: $e');
    }));
  }

  Future<void> pause() async {
    await _player.pause();
    notifyListeners();
  }

  Future<void> resume() async {
    // Guard against a stale RESUME arriving before any track is loaded (e.g. a
    // client that just joined and cleared its queue). Without this the player
    // could replay whatever source was last loaded. See clearQueue().
    if (currentSong == null) return;
    _startPlayback();
    notifyListeners();
  }

  Future<void> togglePlayPause() async {
    if (_player.playing) {
      await pause();
    } else {
      await resume();
    }
  }

  Future<void> seek(Duration position) => _player.seek(position);

  Stream<Duration> get positionStream => _player.positionStream;
  Stream<Duration?> get durationStream => _player.durationStream;
  Stream<PlayerState> get playerStateStream => _player.playerStateStream;


  Future<void> playRadioStation(RadioStation station) async {
    final radioTrack = HotspotStreamTrack(
      trackId: station.stationUuid,
      title: station.name,
      subtitle: 'Live Radio • ${station.tags}',
      playUrl: station.streamUrl,
    );

    await playSong(radioTrack);
  }

  bool get isPlaying => _player.playing;

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }
}