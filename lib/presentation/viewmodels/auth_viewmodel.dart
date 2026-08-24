import 'package:flutter/material.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/models/user_model.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthViewModel extends ChangeNotifier {
  final AuthRepository repository;

  AuthViewModel(this.repository) {
    _checkAuthStatus();
  }

  AuthStatus status = AuthStatus.unknown;
  UserModel? currentUser;
  String? errorMessage;
  bool isLoading = false;

  Future<void> _checkAuthStatus() async {
    final loggedIn = await repository.isLoggedIn();
    status = loggedIn ? AuthStatus.authenticated : AuthStatus.unauthenticated;
    notifyListeners();
  }

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
      errorMessage = e.toString().replaceFirst('Exception: ', ''); // CHANGED
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
      currentUser = await repository.getCurrentUser();
      status = AuthStatus.authenticated;
      isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      errorMessage =  e.toString().replaceFirst('Exception: ', '');
      isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    await repository.logout();
    currentUser = null;
    status = AuthStatus.unauthenticated;
    notifyListeners();
  }
}