import 'package:flutter/foundation.dart';

import '../../data/models/local_song_model.dart';
import '../../data/models/song_model.dart';
import '../../data/repositories/song_repository.dart';
import '../../services/audio/local_audio_service.dart';
import '../../services/audio/playback_service.dart';

class LibraryViewModel extends ChangeNotifier {
  final SongRepository songRepository;
  final LocalAudioService localAudioService;
  final PlaybackService playbackService;

  LibraryViewModel(this.songRepository, this.localAudioService, this.playbackService);

  bool _disposed = false; // NEW

  List<SongModel> cloudSongs = [];
  List<LocalSongModel> localSongs = [];
  bool isLoading = false;
  bool isLoadingLocal = false;
  String? errorMessage;
  String? localErrorMessage;

  Future<void> loadLocalSongs() async {
    isLoadingLocal = true;
    localErrorMessage = null;
    notifyListeners();
    try {
      final local_Songs = await localAudioService.fetchLocalSongs();
      if (_disposed) return; // NEW — bail before touching state/notifyListeners
      localSongs = local_Songs;
    } catch (e) {
      if (_disposed) return; // NEW
      localErrorMessage = 'Permission denied or no local songs found.';
    }
    isLoadingLocal = false;
    if (!_disposed) notifyListeners();
  }

  Future<void> loadCloudSongs() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      final songs = await songRepository.getCloudSongs();
      if (_disposed) return; // NEW — bail before touching state/notifyListeners
      cloudSongs = songs;
    } catch (e) {
      if (_disposed) return; // NEW
      errorMessage = 'Failed to load songs. Please try again.';
    }
    isLoading = false;
    if (!_disposed) notifyListeners(); // NEW guard
  }

  // same pattern for loadLocalSongs() — add the `if (_disposed) return;` checks
  // after the await, before touching state or calling notifyListeners()

  Future<void> playSong(SongModel song) => playbackService.playSong(song, queue: cloudSongs);
  Future<void> playLocalSong(LocalSongModel song) => playbackService.playSong(song, queue: localSongs);

  @override
  void dispose() {
    _disposed = true; // NEW
    super.dispose();
  }
}