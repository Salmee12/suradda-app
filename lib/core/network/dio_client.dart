import 'package:dio/dio.dart';
import '../constants/api_constants.dart';
import 'auth_interceptor.dart';
import '../../services/auth/token_storage_service.dart';

class DioClient {
  final Dio dio;

  DioClient(TokenStorageService tokenStorage)
      : dio = Dio(BaseOptions(baseUrl: ApiConstants.baseUrl)) {
    dio.interceptors.add(AuthInterceptor(dio, tokenStorage));
  }
}