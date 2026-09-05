import 'dart:async';

/// Why the session stopped being usable.
enum AuthEvent {
  /// A 401 was met with a refresh that also failed, so the tokens have been
  /// cleared. The user has to sign in again.
  sessionExpired,

  /// A 403 came back from a subscription-gated route: the credentials are still
  /// valid, the subscription is not. The tokens stay put so the app can keep
  /// reading /auth/me and offer a resubscribe path.
  subscriptionLapsed,
}

/// One-way channel from [AuthInterceptor] to [AuthViewModel].
///
/// The interceptor is built inside [DioClient], which is constructed before any
/// view model exists, so it cannot hold a reference to one — and a view model
/// that imported the interceptor would close the loop the other way. A bus in
/// the middle lets the network layer report "this session is finished" without
/// either side knowing about the other.
class AuthEventBus {
  final _controller = StreamController<AuthEvent>.broadcast();

  Stream<AuthEvent> get stream => _controller.stream;

  void emit(AuthEvent event) {
    if (!_controller.isClosed) _controller.add(event);
  }

  void dispose() => _controller.close();
}
