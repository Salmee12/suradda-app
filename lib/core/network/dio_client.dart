import 'package:dio/dio.dart';
import '../constants/api_constants.dart';
import 'auth_event_bus.dart';
import 'auth_interceptor.dart';
import '../../services/auth/token_storage_service.dart';

class DioClient {
  final Dio dio;

  DioClient(TokenStorageService tokenStorage, AuthEventBus events)
      : dio = Dio(BaseOptions(baseUrl: ApiConstants.baseUrl)) {
    dio.interceptors.add(AuthInterceptor(dio, tokenStorage, events));
  }
}
