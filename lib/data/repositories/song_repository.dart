import '../datasources/remote/song_api.dart';
import '../models/song_model.dart';

class SongRepository {
  final SongApi api;
  SongRepository(this.api);

  Future<List<SongModel>> getCloudSongs() => api.listSongs();
}