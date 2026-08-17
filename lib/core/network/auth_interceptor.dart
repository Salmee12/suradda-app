import 'package:dio/dio.dart';
import '../../services/auth/token_storage_service.dart';

class AuthInterceptor extends Interceptor {
  final Dio dio;
  final TokenStorageService tokenStorage;

  AuthInterceptor(this.dio, this.tokenStorage);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    final token = await tokenStorage.getAccessToken();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode == 401) {
      final refreshToken = await tokenStorage.getRefreshToken();
      if (refreshToken != null && refreshToken.isNotEmpty) {
        try {
          final refreshDio = Dio(BaseOptions(baseUrl: dio.options.baseUrl));
          final response = await refreshDio.post('/auth/refresh', data: {
            'refresh_token': refreshToken,
          });

          final newAccess = response.data['access_token'];
          final newRefresh = response.data['refresh_token'];
          await tokenStorage.saveTokens(accessToken: newAccess, refreshToken: newRefresh);

          // Retry the original request cleanly
          final opts = err.requestOptions;
          opts.headers['Authorization'] = 'Bearer $newAccess';

          final clonedResponse = await dio.request(
            opts.path,
            options: Options(
              method: opts.method,
              headers: opts.headers,
              contentType: opts.contentType,
            ),
            data: opts.data,
            queryParameters: opts.queryParameters,
          );

          return handler.resolve(clonedResponse);
        } catch (_) {
          await tokenStorage.clearTokens();
        }
      }
    }
    handler.next(err);
  }
}