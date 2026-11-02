import 'package:dio/dio.dart';
import '../../models/song_model.dart';

/// Which column the search term is matched against.
///
/// `all` lets the user find a track by typing a name without first deciding
/// whether it is the title or the artist. The UI's Title/Artist chips map to
/// the other two.
enum SongSearchField {
  all('all'),
  title('title'),
  artist('artist');

  const SongSearchField(this.wireValue);

  /// The value the backend's `field` query parameter expects.
  final String wireValue;
}

class SongApi {
  final Dio dio;
  SongApi(this.dio);

  /// Fetches the catalogue, optionally filtered server-side.
  ///
  /// [query] is trimmed before being sent, and a blank one is omitted entirely
  /// so that "clear the search box" is the same request as "open the tab" — no
  /// special case, and no wasted round trip on an empty term.
  ///
  /// The params are only added when they differ from the server's defaults, so
  /// the unfiltered call still goes out as a bare `GET /songs/list` and stays
  /// byte-identical to what older builds sent.
  Future<List<SongModel>> listSongs({
    String? query,
    SongSearchField field = SongSearchField.all,
    int? limit,
    int offset = 0,
  }) async {
    final term = query?.trim() ?? '';
    final params = <String, dynamic>{
      if (term.isNotEmpty) 'q': term,
      if (term.isNotEmpty && field != SongSearchField.all) 'field': field.wireValue,
      if (limit != null) 'limit': limit,
      if (offset > 0) 'offset': offset,
    };

    final response = await dio.get(
      '/songs/list',
      queryParameters: params.isEmpty ? null : params,
    );
    final data = response.data;
    // The route has always returned a bare array. The list check is a guard
    // rather than defensiveness for its own sake: an error page or a changed
    // response envelope would otherwise surface as a confusing cast error deep
    // inside the map below instead of a clear failure here.
    if (data is! List) {
      throw FormatException(
        'Expected a JSON array from /songs/list, got ${data.runtimeType}',
      );
    }
    return data.map((json) => SongModel.fromJson(json)).toList();
  }
}
