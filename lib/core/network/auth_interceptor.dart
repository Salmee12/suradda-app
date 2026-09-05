import 'package:dio/dio.dart';
import 'auth_event_bus.dart';
import '../../services/auth/token_storage_service.dart';

class AuthInterceptor extends Interceptor {
  final Dio dio;
  final TokenStorageService tokenStorage;
  final AuthEventBus events;

  AuthInterceptor(this.dio, this.tokenStorage, this.events);

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
    // 403 is reserved by the API for exactly one thing: get_subscribed_user
    // refusing a valid token because the subscription is not active. Refreshing
    // would be pointless — the token is fine — and clearing the tokens would be
    // wrong, because the app still needs them to read /auth/me and show a
    // resubscribe screen. So: report it and let the error through.
    if (err.response?.statusCode == 403) {
      events.emit(AuthEvent.subscriptionLapsed);
      handler.next(err);
      return;
    }

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
          // Previously the tokens were dropped silently, leaving the user inside
          // the shell with every request failing until they killed the app.
          events.emit(AuthEvent.sessionExpired);
        }
      } else {
        // A 401 with nothing to refresh from is already a finished session.
        events.emit(AuthEvent.sessionExpired);
      }
    }
    handler.next(err);
  }
}
