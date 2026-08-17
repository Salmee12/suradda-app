import '../datasources/remote/room_api.dart';
import '../models/room_model.dart';

class RoomRepository {
  final RoomApi api;
  RoomRepository(this.api);

  Future<RoomModel> createRoom() => api.createRoom();
  Future<RoomModel> joinRoom(String code) => api.joinRoom(code);
  Future<RoomModel> getRoom(String roomId) => api.getRoom(roomId);
  Future<void> leaveRoom(String roomId) => api.leaveRoom(roomId);
}