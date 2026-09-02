import 'package:flutter/foundation.dart';

import '../../data/models/local_song_model.dart';
import '../../data/models/song_model.dart';
import '../../data/repositories/song_repository.dart';
import '../../services/audio/local_audio_service.dart';
import '../../services/audio/playback_service.dart';
import '../../services/download/song_download_service.dart';

class LibraryViewModel extends ChangeNotifier {
  final SongRepository songRepository;
  final LocalAudioService localAudioService;
  final PlaybackService playbackService;
  final SongDownloadService downloadService;

  LibraryViewModel(this.songRepository, this.localAudioService, this.playbackService, this.downloadService);

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
      final songs = await localAudioService.fetchLocalSongs();
      if (_disposed) return; // NEW — bail before touching state/notifyListeners
      localSongs = songs;
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

  // --- Cloud song downloads ---
  final Set<String> _downloadingIds = {};
  final Set<String> _downloadedIds = {};

  bool isDownloading(String id) => _downloadingIds.contains(id);
  bool isDownloaded(String id) => _downloadedIds.contains(id);

  Future<DownloadResult> downloadSong(SongModel song) async {
    if (_downloadingIds.contains(song.id)) {
      return const DownloadResult.failed('Already downloading');
    }
    if (_downloadedIds.contains(song.id)) {
      return const DownloadResult.ok();
    }
    _downloadingIds.add(song.id);
    if (!_disposed) notifyListeners();

    DownloadResult result;
    try {
      result = await downloadService.downloadSong(song);
    } catch (e) {
      result = DownloadResult.failed(e.toString());
    } finally {
      _downloadingIds.remove(song.id);
    }
    if (_disposed) return result;

    if (result.success) {
      _downloadedIds.add(song.id);
      // Surface the new file in the Local tab. Anything that goes wrong here is
      // a refresh problem, not a download problem — it must not turn a
      // successful download into a reported failure.
      try {
        await loadLocalSongs();
      } catch (e) {
        debugPrint('LibraryViewModel: local refresh after download failed -> $e');
      }
    }
    if (!_disposed) notifyListeners();
    return result;
  }

  @override
  void dispose() {
    _disposed = true; // NEW
    super.dispose();
  }
}