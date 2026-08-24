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
    try {
      final response = await dio.post('/auth/register', data: {
        'username': username,
        'email': email,
        'phone_number': phoneNumber,
        'password': password,
      });
      return response.data;
    } on DioException catch (e) {
      throw Exception(_extractErrorMessage(e));
    }
  }

  String _extractErrorMessage(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['detail'] != null) {
      final detail = data['detail'];
      if (detail is List) {
        // FastAPI validation errors — join all messages
        final messages = detail
            .map((d) => d is Map ? (d['msg']?.toString() ?? '') : d.toString())
            .where((m) => m.isNotEmpty)
            .toList();
        if (messages.isNotEmpty) return messages.join('\n');
      } else if (detail is String) {
        // Simple string detail, e.g. "Username or email already registered"
        return detail;
      }
    }
    return 'Registration failed. Please try again.';
  }
  Future<Map<String, dynamic>> login({
    required String username,
    required String password,
  }) async {
    try{ final response = await dio.post('/auth/login', data: {
      'username': username,
      'password': password,
    });
    return response.data;

    } on DioException catch (e) {
      throw Exception(_extractErrorMessage(e));
    }
  }

  Future<Map<String, dynamic>> getMe() async {
    final response = await dio.get('/auth/me');
    return response.data;
  }
}