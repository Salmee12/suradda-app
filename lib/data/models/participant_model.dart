class ParticipantModel {
  final String userId;
  final String username;

  ParticipantModel({required this.userId, required this.username});

  factory ParticipantModel.fromJson(Map<String, dynamic> json) {
    return ParticipantModel(
      userId: json['user_id'],
      username: json['username'],
    );
  }
}