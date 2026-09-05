import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenStorageService {
  final _storage = const FlutterSecureStorage();

  static const _accessKey = 'access_token';
  static const _refreshKey = 'refresh_token';
  static const _usernameKey = 'username';
  static const _phoneKey = 'phone_number';

  Future<void> saveTokens({required String accessToken, required String refreshToken}) async {
    await _storage.write(key: _accessKey, value: accessToken);
    await _storage.write(key: _refreshKey, value: refreshToken);
  }

  Future<String?> getAccessToken() => _storage.read(key: _accessKey);
  Future<String?> getRefreshToken() => _storage.read(key: _refreshKey);

  Future<void> saveUsername(String username) => _storage.write(key: _usernameKey, value: username);
  Future<String?> getUsername() => _storage.read(key: _usernameKey);

  /// Kept so unsubscribe and the resubscribe screen have a number to work with
  /// without another round trip. Stored in the same secure store as the tokens
  /// and cleared with them.
  Future<void> savePhoneNumber(String phone) => _storage.write(key: _phoneKey, value: phone);
  Future<String?> getPhoneNumber() => _storage.read(key: _phoneKey);

  Future<void> clearTokens() async {
    await _storage.delete(key: _accessKey);
    await _storage.delete(key: _refreshKey);
    await _storage.delete(key: _usernameKey);
    await _storage.delete(key: _phoneKey);
  }

  Future<bool> hasTokens() async {
    final token = await getAccessToken();
    return token != null;
  }
}
