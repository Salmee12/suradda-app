import 'package:dio/dio.dart';
import '../../models/song_model.dart';

class SongApi {
  final Dio dio;
  SongApi(this.dio);

  Future<List<SongModel>> listSongs() async {
    final response = await dio.get('/songs/list');
    final List data = response.data;
    return data.map((json) => SongModel.fromJson(json)).toList();
  }
}