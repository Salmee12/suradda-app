import 'package:dio/dio.dart';
import '../../models/room_model.dart';

class RoomApi {
  final Dio dio;
  RoomApi(this.dio);

  Future<RoomModel> createRoom() async {
    final response = await dio.post('/rooms/create');
    return RoomModel.fromJson(response.data);
  }

  Future<RoomModel> joinRoom(String code) async {
    final response = await dio.post('/rooms/join', data: {'code': code});
    return RoomModel.fromJson(response.data);
  }

  Future<RoomModel> getRoom(String roomId) async {
    final response = await dio.get('/rooms/$roomId');
    return RoomModel.fromJson(response.data);
  }

  Future<void> leaveRoom(String roomId) async {
    await dio.post('/rooms/$roomId/leave');
  }
}