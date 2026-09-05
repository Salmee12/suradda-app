class UserModel {
  final String id;
  final String username;

  /// Null for OTP subscribers, who never supply one. Only the legacy
  /// register/login path sets it.
  final String? email;
  final String phoneNumber;
  final bool isSubscribed;

  UserModel({
    required this.id,
    required this.username,
    this.email,
    required this.phoneNumber,
    required this.isSubscribed,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'],
      username: json['username'],
      email: json['email'] as String?,
      phoneNumber: json['phone_number'],
      isSubscribed: json['is_subscribed'],
    );
  }
}