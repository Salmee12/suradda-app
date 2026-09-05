import 'dart:async';

import 'package:flutter/material.dart';
import '../../core/network/auth_event_bus.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/models/user_model.dart';

enum AuthStatus {
  unknown,
  authenticated,

  /// Signed in, but the subscription is not active. Distinct from
  /// [unauthenticated] because the tokens are still good: the app can read
  /// /auth/me and offer a resubscribe path instead of dumping the user back at
  /// the phone screen with no explanation.
  subscriptionExpired,
  unauthenticated,
}

/// Where the user is in the OTP flow.
enum OtpStage {
  /// Entering a phone number.
  phone,

  /// An OTP was sent and we are waiting for the code.
  code,
}

class AuthViewModel extends ChangeNotifier {
  final AuthRepository repository;
  StreamSubscription<AuthEvent>? _eventSub;

  AuthViewModel(this.repository, AuthEventBus events) {
    _eventSub = events.stream.listen(_onAuthEvent);
    _checkAuthStatus();
  }

  AuthStatus status = AuthStatus.unknown;
  UserModel? currentUser;
  String? errorMessage;
  bool isLoading = false;

  // --- OTP flow state -------------------------------------------------------
  // Held on the view model rather than passed between routes because the OTP
  // screen needs the referenceNo that the phone screen received, and this is a
  // locator singleton precisely so that value survives the navigation.

  OtpStage otpStage = OtpStage.phone;
  String? phoneNumber;
  String? _referenceNo;

  /// Whether the OTP screen should ask for a display name. True for a number with
  /// no account yet — the name has to arrive with the code so the row is complete
  /// on first insert. Defaults to true when we could not find out, which is
  /// harmless: the backend ignores the name for an existing user.
  bool needsUsername = true;

  /// Set when BDApps accepted the code but the session could not be minted. The
  /// OTP is spent, so the only way forward is a fresh one.
  bool tokenErrorOnLastVerify = false;

  @override
  void dispose() {
    _eventSub?.cancel();
    super.dispose();
  }

  void _onAuthEvent(AuthEvent event) {
    switch (event) {
      case AuthEvent.subscriptionLapsed:
        // Keep currentUser: the resubscribe screen shows the number, and the
        // tokens still work for everything that is not gated.
        if (status == AuthStatus.authenticated) {
          status = AuthStatus.subscriptionExpired;
          notifyListeners();
        }
      case AuthEvent.sessionExpired:
        currentUser = null;
        status = AuthStatus.unauthenticated;
        _resetOtpFlow();
        notifyListeners();
    }
  }

  Future<void> _checkAuthStatus() async {
    if (!await repository.isLoggedIn()) {
      status = AuthStatus.unauthenticated;
      notifyListeners();
      return;
    }

    // Previously this trusted the mere presence of a token, which left
    // currentUser null on every warm start — the hotspot party name and the
    // username shown to other room participants both read it — and admitted
    // users whose subscription had since lapsed.
    try {
      currentUser = await repository.getCurrentUser();
      status = currentUser!.isSubscribed
          ? AuthStatus.authenticated
          : AuthStatus.subscriptionExpired;
    } catch (_) {
      // Offline, or Render is cold. The tokens are still there and the
      // interceptor will emit sessionExpired if they turn out to be dead, so
      // letting the user in beats blocking them at a spinner over a flaky
      // network. A 403 en route here arrives as subscriptionLapsed.
      status = AuthStatus.authenticated;
    }
    notifyListeners();
  }

  /// Re-reads /auth/me. Used by the resubscribe screen to find out whether a
  /// subscription taken out elsewhere has landed yet.
  Future<void> refreshUser() async {
    isLoading = true;
    notifyListeners();
    try {
      currentUser = await repository.getCurrentUser();
      status = currentUser!.isSubscribed
          ? AuthStatus.authenticated
          : AuthStatus.subscriptionExpired;
      errorMessage = null;
    } catch (e) {
      errorMessage = _clean(e);
    }
    isLoading = false;
    notifyListeners();
  }

  // --- step one: phone number ----------------------------------------------

  /// Checks the subscription and, unless the telco signs the user straight in,
  /// sends an OTP.
  ///
  /// Returns true when the caller should move to the OTP screen. A direct
  /// sign-in returns false and has already flipped [status] — the OTP is skipped
  /// because codes cost money and BDApps limits the attempts.
  Future<bool> submitPhoneNumber(String e164Phone) async {
    isLoading = true;
    errorMessage = null;
    tokenErrorOnLastVerify = false;
    notifyListeners();

    try {
      final check = await repository.checkSubscription(e164Phone);

      if (check.canSignInDirectly) {
        phoneNumber = e164Phone;
        await _completeSignIn(isSubscribedHint: true);
        isLoading = false;
        notifyListeners();
        return false;
      }

      final otp = await repository.sendOtp(e164Phone);
      if (!otp.success) {
        errorMessage = otp.message ?? 'Could not send the code. Please try again.';
        isLoading = false;
        notifyListeners();
        return false;
      }

      phoneNumber = e164Phone;
      _referenceNo = otp.referenceNo;
      // A REGISTERED number that PHP could not mint a token for still has an
      // account, so it does not need a name.
      needsUsername = !(check.hasAccount || check.tokenError);
      otpStage = OtpStage.code;
      isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      errorMessage = _clean(e);
      isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // --- step two: the code ---------------------------------------------------

  Future<bool> submitOtp({required String otp, String? username}) async {
    final phone = phoneNumber;
    final reference = _referenceNo;
    if (phone == null || reference == null) {
      errorMessage = 'Your session expired. Please enter your number again.';
      _resetOtpFlow();
      notifyListeners();
      return false;
    }

    isLoading = true;
    errorMessage = null;
    tokenErrorOnLastVerify = false;
    notifyListeners();

    try {
      final result = await repository.verifyOtp(
        phone: phone,
        otp: otp,
        referenceNo: reference,
        username: username,
      );

      if (!result.success) {
        errorMessage = result.message ?? 'That code was not accepted. Please try again.';
        isLoading = false;
        notifyListeners();
        return false;
      }

      if (!result.hasTokens) {
        // Verified, but no session. The code is already spent, so there is
        // nothing to retry with — the user has to start over with a new one.
        tokenErrorOnLastVerify = true;
        errorMessage = 'Your number was verified, but we could not sign you in. '
            'Please request a new code.';
        _resetOtpFlow();
        isLoading = false;
        notifyListeners();
        return false;
      }

      await _completeSignIn(isSubscribedHint: result.isSubscribed);
      isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      errorMessage = _clean(e);
      isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Tokens are stored by this point. Fill in the profile and pick a status.
  Future<void> _completeSignIn({required bool isSubscribedHint}) async {
    try {
      currentUser = await repository.getCurrentUser();
      status = currentUser!.isSubscribed
          ? AuthStatus.authenticated
          : AuthStatus.subscriptionExpired;
    } catch (_) {
      // Render just minted the token, so this rarely fires — but if it does, the
      // verify response already told us what BDApps thinks, and /auth/me will be
      // retried on the next warm start.
      status = isSubscribedHint
          ? AuthStatus.authenticated
          : AuthStatus.subscriptionExpired;
    }
    _resetOtpFlow();
  }

  void restartOtpFlow() {
    _resetOtpFlow();
    errorMessage = null;
    notifyListeners();
  }

  void _resetOtpFlow() {
    otpStage = OtpStage.phone;
    _referenceNo = null;
    needsUsername = true;
  }

  // --- leaving ---------------------------------------------------------------

  Future<void> logout() async {
    await repository.logout();
    currentUser = null;
    status = AuthStatus.unauthenticated;
    _resetOtpFlow();
    notifyListeners();
  }

  /// Cancels the telco subscription and signs out.
  ///
  /// On failure the session is deliberately left intact: a user who is still
  /// being charged must not end up locked out of what they are paying for.
  Future<bool> unsubscribe() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      final ok = await repository.unsubscribe();
      if (ok) {
        currentUser = null;
        status = AuthStatus.unauthenticated;
        _resetOtpFlow();
      } else {
        errorMessage = 'Could not cancel your subscription. Please try again.';
      }
      isLoading = false;
      notifyListeners();
      return ok;
    } catch (e) {
      errorMessage = _clean(e);
      isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // --- legacy password flow -------------------------------------------------

  Future<bool> register({
    required String username,
    required String email,
    required String phoneNumber,
    required String password,
  }) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      await repository.register(
        username: username,
        email: email,
        phoneNumber: phoneNumber,
        password: password,
      );
      isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      errorMessage = _clean(e);
      isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> login({required String username, required String password}) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      await repository.login(username: username, password: password);
      await _completeSignIn(isSubscribedHint: false);
      isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      errorMessage = _clean(e);
      isLoading = false;
      notifyListeners();
      return false;
    }
  }

  String _clean(Object e) => e.toString().replaceFirst('Exception: ', '');
}
