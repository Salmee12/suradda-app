import 'package:dio/dio.dart';

class AuthApi {
  final Dio dio;
  AuthApi(this.dio);

  Future<Map<String, dynamic>> register({
    required String username,
    required String email,
    required String phoneNumber,
    required String password,
  }) async {
    final response = await dio.post('/auth/register', data: {
      'username': username,
      'email': email,
      'phone_number': phoneNumber,
      'password': password,
    });
    return response.data;
  }

  Future<Map<String, dynamic>> login({
    required String username,
    required String password,
  }) async {
    final response = await dio.post('/auth/login', data: {
      'username': username,
      'password': password,
    });
    return response.data;
  }

  Future<Map<String, dynamic>> getMe() async {
    final response = await dio.get('/auth/me');
    return response.data;
  }
}