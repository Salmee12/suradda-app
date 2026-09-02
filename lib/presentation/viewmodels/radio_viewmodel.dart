import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import '../../data/models/radio_model.dart';
import '../../services/audio/playback_service.dart';
import '../../services/streaming/radio_service.dart';

/// Drives the Radio tab.
///
/// Registered as a locator singleton rather than created per page: the radio
/// keeps playing after you leave the tab, so its state has to outlive the
/// widget. A side effect is that the station list is fetched once and cached
/// instead of refetched on every visit.
class RadioViewModel extends ChangeNotifier {
  RadioViewModel(this._radioService, this._playback) {
    _init();
  }

  final RadioService _radioService;

  /// The app's single AudioPlayer, borrowed rather than duplicated.
  ///
  /// just_audio_background permits exactly one AudioPlayer per process and
  /// PlaybackService already owns it, so a player of our own would throw
  /// "supports only a single player instance" the moment it loaded a station.
  final PlaybackService _playback;

  StreamSubscription<PlayerState>? _stateSub;

  List<RadioStation> _stations = [];
  RadioRegion _region = RadioRegion.international;
  int _currentIndex = 0;
  bool _isLoading = false;
  bool _isBuffering = false;

  /// Guards notifies after disposal. Nothing disposes this VM in normal use,
  /// but a hot restart or `locator.reset()` can, and an in-flight fetch would
  /// still be running.
  bool _disposed = false;

  List<RadioStation> get stations => _stations;
  RadioRegion get region => _region;
  int get currentIndex => _currentIndex;
  bool get isLoading => _isLoading;
  bool get isBuffering => _isBuffering;

  /// Whether the shared player is currently tuned to a station.
  ///
  /// Derived rather than stored: anything else that takes the player — tapping
  /// a song, entering a party — switches the radio off as a side effect, and a
  /// stored flag would go stale and leave the badge reading LIVE over silence.
  bool get isPowerOn => _playback.isLiveRadio;

  RadioStation? get currentStation =>
      _stations.isNotEmpty && _currentIndex < _stations.length
          ? _stations[_currentIndex]
          : null;

  void _init() {
    _stateSub = _playback.playerStateStream.listen((state) {
      // Gated on isLiveRadio: a song buffering on the shared player is not the
      // radio connecting.
      final buffering = _playback.isLiveRadio &&
          (state.processingState == ProcessingState.buffering ||
              state.processingState == ProcessingState.loading);
      if (buffering == _isBuffering) return;
      _isBuffering = buffering;
      _notify();
    });
    // isPowerOn reads PlaybackService, so the badge only tracks reality if we
    // forward that service's notifications to our own listeners.
    _playback.addListener(_notify);
    fetchStations();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> fetchStations() async {
    _isLoading = true;
    _notify();

    final stations =
        await _radioService.fetchStations(region: _region, limit: 30);
    if (_disposed) return;

    _stations = stations;
    _isLoading = false;
    _notify();
  }

  /// Switches which country's stations are listed.
  ///
  /// Keeps the power state: a real radio doesn't switch off when you change
  /// band, it just plays whatever the new band is tuned to.
  Future<void> setRegion(RadioRegion region) async {
    if (region == _region) return;

    // Captured first — the stop below clears isPowerOn, which is derived from
    // the player.
    final wasOn = isPowerOn;
    _region = region;
    _currentIndex = 0;
    // Stop before refetching: the station playing belongs to the list we're
    // about to replace, and it must not keep streaming behind the new one.
    await _playback.stopLiveRadio();
    await fetchStations();
    if (_disposed) return;

    if (wasOn && currentStation != null) {
      await _playCurrentStation();
    }
  }

  Future<void> togglePower() async {
    if (currentStation == null) return;

    if (isPowerOn) {
      await _playback.stopLiveRadio();
    } else {
      await _playCurrentStation();
    }
  }

  Future<void> nextStation() async {
    if (_stations.isEmpty) return;
    _currentIndex = (_currentIndex + 1) % _stations.length;
    _notify();

    if (isPowerOn) {
      await _playCurrentStation();
    }
  }

  Future<void> previousStation() async {
    if (_stations.isEmpty) return;
    _currentIndex = (_currentIndex - 1 + _stations.length) % _stations.length;
    _notify();

    if (isPowerOn) {
      await _playCurrentStation();
    }
  }

  Future<void> _playCurrentStation() async {
    final station = currentStation;
    if (station == null) return;

    try {
      await _playback.playRadioStation(station);
    } catch (e) {
      debugPrint('[RadioVM] Error playing station stream: $e');
      // The player is left holding a source that will never produce audio;
      // clearing it drops isPowerOn back to false so the badge reads OFF and
      // the next power-on starts clean.
      await _playback.stopLiveRadio();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _stateSub?.cancel();
    _playback.removeListener(_notify);
    // No player disposal here — the player belongs to PlaybackService, which
    // outlives this VM.
    super.dispose();
  }
}
