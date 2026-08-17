import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import '../../data/models/playable_track.dart';
import '../../data/models/song_model.dart';

class PlaybackService extends ChangeNotifier {
  final AudioPlayer _player = AudioPlayer();

  List<PlayableTrack> _queue = [];
  int _currentIndex = -1;
  int _playRequestId = 0;

  PlaybackService() {
    _player.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) {
        notifyListeners(); // let UI know playback naturally ended
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
    notifyListeners();
  }

  Future<void> playSong(PlayableTrack song, {List<PlayableTrack>? queue}) async {
    await _player.pause();
    if (queue != null) {
      _queue = queue;
      _currentIndex = _queue.indexWhere((s) => s.trackId == song.trackId);
    } else if (_queue.isEmpty || !_queue.any((s) => s.trackId == song.trackId)) {
      _queue = [song];
      _currentIndex = 0;
    } else {
      _currentIndex = _queue.indexWhere((s) => s.trackId == song.trackId);
    }

    if (currentSong?.trackId == song.trackId && _player.playing) {
      return;
    }

    final requestId = ++_playRequestId;
    notifyListeners();

    try {
      await _player.pause(); // raw player call — does NOT bump _playRequestId itself
      if (requestId != _playRequestId) return;
      await _player.setUrl(song.playUrl);
      if (requestId != _playRequestId) return;
      await _player.play();
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
    await _player.pause();
    if (requestId != _playRequestId) return;
    await _player.setUrl(_queue[_currentIndex].playUrl);
    if (requestId != _playRequestId) return;
    await _player.play();
  }

  Future<void> playPrevious() async {
    if (!hasPrevious) return;
    _currentIndex--;
    final requestId = ++_playRequestId;
    notifyListeners();
    await _player.pause();
    if (requestId != _playRequestId) return;
    await _player.setUrl(_queue[_currentIndex].playUrl);
    if (requestId != _playRequestId) return;
    await _player.play();
  }

  /// Public pause — invalidates any in-flight load so its trailing
  /// play() call can't silently undo this pause.
  Future<void> pause() async {
    _playRequestId++; // NEW — this is the actual fix
    await _player.pause();
    notifyListeners();
  }



  /// Public resume — same invalidation, in case a stale load is
  /// still trying to act on the player.
  Future<void> resume() async {
    _playRequestId++; // NEW
    await _player.play();
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

  bool get isPlaying => _player.playing;

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }
}