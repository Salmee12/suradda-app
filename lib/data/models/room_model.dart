class RoomModel {
  final String id;
  final String code;
  final String hostId;
  final String? currentSongId;
  final int currentPositionMs;
  final bool isPlaying;
  final bool isActive;
  final int participantCount;

  RoomModel({
    required this.id,
    required this.code,
    required this.hostId,
    required this.currentSongId,
    required this.currentPositionMs,
    required this.isPlaying,
    required this.isActive,
    required this.participantCount,
  });

  factory RoomModel.fromJson(Map<String, dynamic> json) {
    return RoomModel(
      id: json['id'],
      code: json['code'],
      hostId: json['host_id'],
      currentSongId: json['current_song_id'],
      currentPositionMs: json['current_position_ms'] ?? 0,
      isPlaying: json['is_playing'] ?? false,
      isActive: json['is_active'] ?? true,
      participantCount: json['participant_count'] ?? 0,
    );
  }

  RoomModel copyWith({
    String? currentSongId,
    int? currentPositionMs,
    bool? isPlaying,
    int? participantCount,
  }) {
    return RoomModel(
      id: id,
      code: code,
      hostId: hostId,
      currentSongId: currentSongId ?? this.currentSongId,
      currentPositionMs: currentPositionMs ?? this.currentPositionMs,
      isPlaying: isPlaying ?? this.isPlaying,
      isActive: isActive,
      participantCount: participantCount ?? this.participantCount,
    );
  }
}