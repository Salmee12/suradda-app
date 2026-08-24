import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import '../../data/models/radio_model.dart';
import '../../services/streaming/radio_service.dart';


class RadioViewModel extends ChangeNotifier {
  final RadioService _radioService = RadioService();
  final AudioPlayer _radioPlayer = AudioPlayer();

  List<RadioStation> _stations = [];
  int _currentIndex = 0;
  bool _isLoading = false;
  bool _isPowerOn = false;
  bool _isBuffering = false;

  RadioViewModel() {
    _init();
  }

  List<RadioStation> get stations => _stations;
  int get currentIndex => _currentIndex;
  bool get isLoading => _isLoading;
  bool get isPowerOn => _isPowerOn;
  bool get isBuffering => _isBuffering;

  RadioStation? get currentStation =>
      _stations.isNotEmpty && _currentIndex < _stations.length
          ? _stations[_currentIndex]
          : null;

  void _init() {
    _radioPlayer.playerStateStream.listen((state) {
      _isBuffering = state.processingState == ProcessingState.buffering ||
          state.processingState == ProcessingState.loading;
      notifyListeners();
    });
    fetchStations();
  }

  Future<void> fetchStations() async {
    _isLoading = true;
    notifyListeners();

    _stations = await _radioService.fetchTopStations(limit: 30);
    _isLoading = false;
    notifyListeners();
  }

  Future<void> togglePower() async {
    if (currentStation == null) return;

    if (_isPowerOn) {
      await _radioPlayer.stop();
      _isPowerOn = false;
    } else {
      _isPowerOn = true;
      notifyListeners();
      await _playCurrentStation();
    }
    notifyListeners();
  }

  Future<void> nextStation() async {
    if (_stations.isEmpty) return;
    _currentIndex = (_currentIndex + 1) % _stations.length;
    notifyListeners();

    if (_isPowerOn) {
      await _playCurrentStation();
    }
  }

  Future<void> previousStation() async {
    if (_stations.isEmpty) return;
    _currentIndex = (_currentIndex - 1 + _stations.length) % _stations.length;
    notifyListeners();

    if (_isPowerOn) {
      await _playCurrentStation();
    }
  }

  Future<void> _playCurrentStation() async {
    final station = currentStation;
    if (station == null) return;

    try {
      await _radioPlayer.stop();
      await _radioPlayer.setUrl(station.streamUrl);
      await _radioPlayer.play();
    } catch (e) {
      debugPrint('[RadioVM] Error playing station stream: $e');
      _isPowerOn = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _radioPlayer.dispose();
    super.dispose();
  }
}