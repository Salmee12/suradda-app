class UserModel {
  final String id;
  final String username;
  final String email;
  final String phoneNumber;
  final bool isSubscribed;

  UserModel({
    required this.id,
    required this.username,
    required this.email,
    required this.phoneNumber,
    required this.isSubscribed,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'],
      username: json['username'],
      email: json['email'],
      phoneNumber: json['phone_number'],
      isSubscribed: json['is_subscribed'],
    );
  }
}