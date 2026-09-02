import '../datasources/remote/auth_api.dart';
import '../models/user_model.dart';
import '../../services/auth/token_storage_service.dart';

class AuthRepository {
  final AuthApi api;
  final TokenStorageService tokenStorage;

  AuthRepository(this.api, this.tokenStorage);

  Future<void> register({
    required String username,
    required String email,
    required String phoneNumber,
    required String password,
  }) async {
    await api.register(
      username: username,
      email: email,
      phoneNumber: phoneNumber,
      password: password,
    ); // no try/catch here — let AuthViewModel handle it
  }

  Future<void> login({required String username, required String password}) async {
    final data = await api.login(username: username, password: password);
    await tokenStorage.saveTokens(
      accessToken: data['access_token'],
      refreshToken: data['refresh_token'],
    );
    await tokenStorage.saveUsername(username);
  }

  Future<UserModel> getCurrentUser() async {
    final data = await api.getMe();
    return UserModel.fromJson(data);
  }

  Future<bool> isLoggedIn() => tokenStorage.hasTokens();

  Future<void> logout() => tokenStorage.clearTokens();
}