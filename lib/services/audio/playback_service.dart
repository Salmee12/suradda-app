// lib/services/audio/playback_service.dart

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
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

  /// Optional remote image for the media notification. Hotspot streams have
  /// none; radio stations supply their station logo.
  final String? artwork;

  HotspotStreamTrack({
    required this.trackId,
    required this.title,
    required this.subtitle,
    required this.playUrl,
    this.artwork,
  });

  @override
  String? get artworkUrl => artwork;

  @override
  String get hexCode => '1DB954'; // Accent theme color
}

class PlaybackService extends ChangeNotifier {
  final AudioPlayer _player = AudioPlayer();

  List<PlayableTrack> _queue = [];
  int _currentIndex = -1;
  int _playRequestId = 0;
  bool _isLiveRadio = false;

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

  /// True while the loaded source is a live radio station rather than a song.
  ///
  /// The UI hides the MusicSlab — and with it MusicPlayerPage, which is only
  /// reachable by tapping the slab — on this flag. A stream reports no
  /// duration, so the progress bar, seek bar and skip arrows would all be
  /// meaningless; the radio is driven solely from the Radio tab's power button.
  bool get isLiveRadio => _isLiveRadio;

  void clearQueue() {
    _queue = [];
    _currentIndex = -1;
    _isLiveRadio = false;
    // Invalidate any load still in flight, or it would reach _startPlayback()
    // after this stop and resurrect the source we just dropped.
    _playRequestId++;
    _player.stop();
    notifyListeners();
  }

  /// Stops playback only when what's loaded is live radio; leaves music alone.
  ///
  /// Room entry calls this. The radio outlives the Radio tab now, so it can
  /// still be streaming when a party starts, and a party has no business
  /// broadcasting a radio station. Callers that want the queue emptied
  /// regardless use [clearQueue].
  Future<void> stopLiveRadio() async {
    if (!_isLiveRadio) return;
    _isLiveRadio = false;
    _queue = [];
    _currentIndex = -1;
    _playRequestId++;
    await _player.stop();
    notifyListeners();
  }

  /// Wraps a track in an [AudioSource] carrying the [MediaItem] tag that
  /// just_audio_background needs to populate the media notification.
  ///
  /// Every source MUST be tagged — an untagged one throws at load time — so all
  /// playback goes through here instead of calling `setUrl` directly.
  AudioSource _sourceFor(PlayableTrack track) {
    final art = track.artworkUrl;
    return AudioSource.uri(
      Uri.parse(track.playUrl),
      tag: MediaItem(
        // MediaItem.id must be non-empty; hotspot streams may not carry a
        // trackId, so fall back to the URL.
        id: track.trackId.isEmpty ? track.playUrl : track.trackId,
        title: track.title,
        artist: track.subtitle,
        artUri: (art != null && art.startsWith('http')) ? Uri.tryParse(art) : null,
      ),
    );
  }

  /// Load and play an HTTP stream from the Host
  Future<void> playStreamTrack({
    required String streamUrl,
    required String trackId,
    required String title,
    required String subtitle,
  }) async {
    await _playSingle(
      HotspotStreamTrack(
        trackId: trackId,
        title: title,
        subtitle: subtitle,
        playUrl: streamUrl,
      ),
      isLiveRadio: false,
    );
  }

  /// Replaces the queue with a single track and loads it.
  ///
  /// Shared by the hotspot-stream and radio paths, which both play exactly one
  /// source that isn't part of a library queue. State is updated synchronously
  /// before the notify, so every widget sees the new metadata — and
  /// [isLiveRadio] — on the same frame the load starts, with no window where
  /// the slab could flash a station it is supposed to hide.
  Future<void> _playSingle(
    PlayableTrack track, {
    required bool isLiveRadio,
  }) async {
    _isLiveRadio = isLiveRadio;
    _queue = [track];
    _currentIndex = 0;
    final requestId = ++_playRequestId;
    notifyListeners();

    try {
      await _player.stop();
      if (requestId != _playRequestId) return;
      await _player.setAudioSource(_sourceFor(track));
      if (requestId != _playRequestId) return;
      _startPlayback();
    } catch (e) {
      if (requestId != _playRequestId) return;
      rethrow;
    }
  }

  Future<void> playSong(PlayableTrack song, {List<PlayableTrack>? queue}) async {
    // 1. Synchronous state update
    _isLiveRadio = false;
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
      await _player.setAudioSource(_sourceFor(song));
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
    await _player.setAudioSource(_sourceFor(_queue[_currentIndex]));
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
    await _player.setAudioSource(_sourceFor(_queue[_currentIndex]));
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


  /// Tunes the shared player to [station].
  ///
  /// The radio cannot own an AudioPlayer of its own: just_audio_background
  /// permits exactly one per process and this service already holds it, so a
  /// second player throws "supports only a single player instance" as soon as
  /// it loads a URL. Sharing this one also gets the radio a media notification
  /// and background playback for free.
  Future<void> playRadioStation(RadioStation station) async {
    final tags = station.tags.trim();
    await _playSingle(
      HotspotStreamTrack(
        trackId: station.stationUuid,
        title: station.name,
        subtitle: tags.isEmpty ? 'Live Radio' : 'Live Radio • $tags',
        playUrl: station.streamUrl,
        artwork: station.favicon,
      ),
      isLiveRadio: true,
    );
  }

  bool get isPlaying => _player.playing;

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }
}