import 'package:on_audio_query/on_audio_query.dart';
import '../../data/models/local_song_model.dart';
import '../../core/utils/permission_utils.dart';

class LocalAudioService {
  final OnAudioQuery _audioQuery = OnAudioQuery();

  Future<List<LocalSongModel>> fetchLocalSongs() async {
    final granted = await PermissionUtils.requestAudioPermission();
    if (!granted) {
      throw Exception('Storage/audio permission denied');
    }

    final songs = await _audioQuery.querySongs(
      sortType: SongSortType.TITLE,
      orderType: OrderType.ASC_OR_SMALLER,
      uriType: UriType.EXTERNAL,
      ignoreCase: true,
    );

    return songs.map((s) => LocalSongModel.fromQuerySong(s)).toList();
  }
}