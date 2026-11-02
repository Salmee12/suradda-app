import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/models/local_song_model.dart';
import '../../data/models/song_model.dart';
// SongSearchField arrives through this export — importing song_api.dart here as
// well would name the same declaration twice for no benefit.
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

  /// What the Cloud tab renders. Either the whole catalogue or the current
  /// server-side search result — never a client-side filter of some older list.
  List<SongModel> cloudSongs = [];
  List<LocalSongModel> localSongs = [];
  bool isLoading = false;
  bool isLoadingLocal = false;
  String? errorMessage;
  String? localErrorMessage;

  // --- Cloud search ---------------------------------------------------------
  //
  // The catalogue is paged and lives in Postgres, so a search has to be a query
  // parameter: filtering whatever happened to be loaded would hide every match
  // the app had not paged in yet, which is exactly the bug this replaces.

  /// The last unfiltered catalogue. Kept so clearing the search box is instant
  /// instead of another round trip, and so a failed search can fall back to
  /// something real rather than an empty screen.
  List<SongModel> _catalogue = [];

  String _searchQuery = '';
  SongSearchField _searchField = SongSearchField.all;

  /// True while a search request is in flight. Distinct from [isLoading] so the
  /// tab can keep showing the previous results under a thin progress bar
  /// instead of blanking to a spinner on every keystroke.
  bool _isSearching = false;

  /// Surfaced separately from [errorMessage]: a failed search should not wipe
  /// the catalogue view or claim the whole tab is broken.
  String? _searchError;

  Timer? _debounce;

  /// How long the user has to stop typing before a request goes out. Long
  /// enough to collapse a typed word into one call, short enough to feel live.
  static const _debounceDelay = Duration(milliseconds: 400);

  /// Monotonic id for search requests. Only the newest may write results —
  /// without this a slow response for "ra" can land after "rafi" and leave the
  /// list showing results for a query the box no longer contains.
  int _searchRequestId = 0;

  String get searchQuery => _searchQuery;
  SongSearchField get searchField => _searchField;
  bool get isSearching => _isSearching;
  String? get searchError => _searchError;

  /// True when the list on screen is a filtered result set, not the catalogue.
  bool get isSearchActive => _searchQuery.isNotEmpty;

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

  /// Loads the full catalogue. Used on first open and by the Retry button.
  Future<void> loadCloudSongs() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      final songs = await songRepository.getAllCloudSongs();
      if (_disposed) return; // NEW — bail before touching state/notifyListeners
      _catalogue = songs;
      // A search may have been started while this was in flight; if so it owns
      // the list and must not be overwritten by the full catalogue.
      if (_searchQuery.isEmpty) cloudSongs = songs;
    } catch (e) {
      if (_disposed) return; // NEW
      errorMessage = 'Failed to load songs. Please try again.';
    }
    isLoading = false;
    if (!_disposed) notifyListeners(); // NEW guard
  }

  // same pattern for loadLocalSongs() — add the `if (_disposed) return;` checks
  // after the await, before touching state or calling notifyListeners()

  /// Called on every keystroke. Debounced, so typing a word is one request.
  void setSearchQuery(String value) {
    final next = value.trim();
    if (next == _searchQuery) return;
    _searchQuery = next;
    _searchError = null;

    _debounce?.cancel();

    if (next.isEmpty) {
      // Restore what we already have rather than waiting out the debounce —
      // clearing the box should feel immediate.
      _searchRequestId++; // invalidate any in-flight search
      _isSearching = false;
      cloudSongs = _catalogue;
      notifyListeners();
      // Nothing cached to restore — the first load must have failed or not
      // finished. Refetch rather than leave the tab empty with no search term.
      if (_catalogue.isEmpty) unawaited(loadCloudSongs());
      return;
    }

    notifyListeners(); // chips/hint update immediately, request follows
    _debounce = Timer(_debounceDelay, () => _runSearch(next));
  }

  /// Switching Title/Artist re-runs the active search straight away — it is a
  /// deliberate tap, not typing, so it should not wait for a debounce.
  Future<void> setSearchField(SongSearchField field) async {
    if (field == _searchField) return;
    _searchField = field;
    _debounce?.cancel();
    if (_searchQuery.isEmpty) {
      notifyListeners();
      return;
    }
    await _runSearch(_searchQuery);
  }

  Future<void> _runSearch(String query) async {
    final requestId = ++_searchRequestId;
    _isSearching = true;
    notifyListeners();

    try {
      final results = await songRepository.getCloudSongs(
        query: query,
        field: _searchField,
      );
      // A newer search has already started; this answer is about a query the
      // user has moved on from.
      if (_disposed || requestId != _searchRequestId) return;
      cloudSongs = results;
      _searchError = null;
    } catch (e) {
      if (_disposed || requestId != _searchRequestId) return;
      // Hold on to the previous results: showing "couldn't search" over the
      // last good list beats replacing it with nothing.
      _searchError = 'Could not search right now. Check your connection.';
    }

    _isSearching = false;
    if (!_disposed) notifyListeners();
  }

  /// Retry button for a failed search.
  Future<void> retrySearch() async {
    if (_searchQuery.isEmpty) return;
    _debounce?.cancel();
    await _runSearch(_searchQuery);
  }

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
    // A pending debounce firing after disposal would call the repository and
    // then try to notify a dead listener.
    _debounce?.cancel();
    _debounce = null;
    super.dispose();
  }
}
