import '../datasources/remote/auth_api.dart';
import '../datasources/remote/bdapps_api.dart';
import '../models/user_model.dart';
import '../../services/auth/token_storage_service.dart';

class AuthRepository {
  final AuthApi api;
  final BdappsApi bdapps;
  final TokenStorageService tokenStorage;

  AuthRepository(this.api, this.bdapps, this.tokenStorage);

  // --- OTP / subscription flow ----------------------------------------------

  /// Step one. Asks the telco whether this number already pays.
  ///
  /// A REGISTERED number with an existing account comes back with a session
  /// already minted, so the OTP is skipped entirely — OTPs cost money and BDApps
  /// caps the retries. When that happens the tokens are stored here so the caller
  /// only has to look at [SubscriptionCheckResult.canSignInDirectly].
  Future<SubscriptionCheckResult> checkSubscription(String phone) async {
    final result = await bdapps.checkSubscription(phone);
    if (result.canSignInDirectly) {
      await tokenStorage.saveTokens(
        accessToken: result.accessToken!,
        refreshToken: result.refreshToken!,
      );
      await tokenStorage.savePhoneNumber(phone);
    }
    return result;
  }

  Future<OtpSendResult> sendOtp(String phone) => bdapps.sendOtp(phone);

  /// Step two. [username] is only used when this number has no account yet;
  /// sending it alongside the code is what keeps a verified user from ever
  /// existing without a display name.
  Future<OtpVerifyResult> verifyOtp({
    required String phone,
    required String otp,
    required String referenceNo,
    String? username,
  }) async {
    final result = await bdapps.verifyOtp(
      phone: phone,
      otp: otp,
      referenceNo: referenceNo,
      username: username,
    );

    if (result.success && result.hasTokens) {
      await tokenStorage.saveTokens(
        accessToken: result.accessToken!,
        refreshToken: result.refreshToken!,
      );
      await tokenStorage.savePhoneNumber(phone);
      if (username != null && username.trim().isNotEmpty) {
        await tokenStorage.saveUsername(username.trim());
      }
    }
    return result;
  }

  /// Cancels the telco subscription, then drops the local session.
  ///
  /// Order matters: if the PHP call fails we keep the tokens, because a user who
  /// is still being billed must not be locked out of the app.
  Future<bool> unsubscribe() async {
    final phone = await tokenStorage.getPhoneNumber();
    if (phone == null || phone.isEmpty) return false;

    final ok = await bdapps.unsubscribe(phone);
    if (ok) await tokenStorage.clearTokens();
    return ok;
  }

  // --- legacy password flow -------------------------------------------------
  // Kept working for testing and for accounts created before OTP. Not reachable
  // from the UI: AuthGate routes to the phone screen.

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
    final user = UserModel.fromJson(data);
    // Keep the cache aligned with the server. The username is read by the
    // hotspot party name and shown to other room participants, and the phone
    // number is what unsubscribe needs.
    await tokenStorage.saveUsername(user.username);
    await tokenStorage.savePhoneNumber(user.phoneNumber);
    return user;
  }

  Future<bool> isLoggedIn() => tokenStorage.hasTokens();

  Future<void> logout() => tokenStorage.clearTokens();
}
