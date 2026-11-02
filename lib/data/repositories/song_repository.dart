import '../datasources/remote/song_api.dart';
import '../models/song_model.dart';

// Re-exported so the presentation layer can name the search field without
// importing a datasource directly.
export '../datasources/remote/song_api.dart' show SongSearchField;

class SongRepository {
  final SongApi api;
  SongRepository(this.api);

  /// The whole catalogue, or one server-filtered page of it.
  ///
  /// Search is a query parameter rather than client-side filtering because the
  /// app only ever holds a page of the catalogue: filtering what happens to be
  /// loaded silently hides every matching track that wasn't.
  Future<List<SongModel>> getCloudSongs({
    String? query,
    SongSearchField field = SongSearchField.all,
    int? limit,
    int offset = 0,
  }) =>
      api.listSongs(query: query, field: field, limit: limit, offset: offset);

  /// Same, but for the online-party mirror path, which needs a song by id and
  /// has no interest in the search parameters. Kept as its own name so callers
  /// don't have to pass four defaulted arguments to say "everything".
  Future<List<SongModel>> getAllCloudSongs() => api.listSongs();
}
