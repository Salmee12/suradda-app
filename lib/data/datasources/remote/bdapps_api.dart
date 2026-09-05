import 'dart:convert';

import 'package:dio/dio.dart';

import '../../../core/constants/api_constants.dart';

/// Client for the PHP tier on cPanel, which owns the BDApps credentials and the
/// whitelisted IP.
///
/// Built on its own [Dio] on purpose. The locator's instance carries
/// [AuthInterceptor], which would attach a bearer token that does not exist yet
/// and, on the 401 that follows, try to refresh against a server these routes
/// know nothing about.
///
/// Timeouts here are unusually long, and have to be. The worst realistic path
/// through `verify_otp.php` is a BDApps call (up to 30s) plus a Render cold start
/// (30–60s) plus one retry. Giving up earlier than the server does is the one
/// failure that loses a token which was actually issued.
class BdappsApi {
  final Dio _dio;

  BdappsApi({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              baseUrl: ApiConstants.phpBaseUrl,
              connectTimeout: const Duration(seconds: 20),
              // Never throw on a status code — PHP reports business failures as
              // 200 with success:false, and a cPanel 500 carries an HTML body
              // that is more useful logged than thrown.
              validateStatus: (_) => true,
              contentType: Headers.formUrlEncodedContentType,
            ));

  /// Is this number subscribed, and can we sign it in without an OTP?
  ///
  /// `mint_token=1` asks PHP to trade a REGISTERED verdict for a session via
  /// `/internal/issue-token`. The token is minted server-side because the shared
  /// secret lives there; the app only ever receives the result.
  Future<SubscriptionCheckResult> checkSubscription(String phone) async {
    final data = await _post(
      'check_subscription.php',
      {'user_mobile': _toLocal(phone), 'mint_token': '1'},
      // Can chain into a token mint, so it inherits Render's cold-start risk.
      timeout: const Duration(seconds: 90),
    );
    return SubscriptionCheckResult.fromJson(data);
  }

  Future<OtpSendResult> sendOtp(String phone) async {
    final data = await _post(
      'send_otp.php',
      {'user_mobile': _toLocal(phone)},
      timeout: const Duration(seconds: 45),
    );
    return OtpSendResult.fromJson(data);
  }

  /// [username] is only read when this number has no account yet. Sending it
  /// with the OTP is what stops an authenticated-but-nameless user existing even
  /// briefly.
  ///
  /// The `Otp` key is capitalised because that is what `verify_otp.php` reads.
  /// Sending `otp` silently verifies an empty string.
  Future<OtpVerifyResult> verifyOtp({
    required String phone,
    required String otp,
    required String referenceNo,
    String? username,
  }) async {
    final data = await _post(
      'verify_otp.php',
      {
        'user_mobile': _toLocal(phone),
        'Otp': otp,
        'referenceNo': referenceNo,
        if (username != null && username.trim().isNotEmpty)
          'username': username.trim(),
      },
      timeout: const Duration(seconds: 110),
    );
    return OtpVerifyResult.fromJson(data);
  }

  Future<bool> unsubscribe(String phone) async {
    final data = await _post(
      'unsubscribe.php',
      {'user_mobile': _toLocal(phone)},
      timeout: const Duration(seconds: 45),
    );
    return data['success'] == true;
  }

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, String> body, {
    required Duration timeout,
  }) async {
    final Response response;
    try {
      response = await _dio.post(
        path,
        data: body,
        options: Options(receiveTimeout: timeout, sendTimeout: timeout),
      );
    } on DioException catch (e) {
      throw BdappsException(_networkMessage(e));
    }

    final parsed = _decode(response.data);
    if (parsed == null) {
      // cPanel serves an HTML error page when a script dies or times out, and a
      // stray PHP notice can prepend warning text to otherwise-valid JSON.
      throw BdappsException(
        response.statusCode == 200
            ? 'The server sent an unexpected response. Please try again.'
            : 'The server is unavailable right now (${response.statusCode}). Please try again.',
      );
    }
    return parsed;
  }

  /// Tolerates the three shapes cPanel actually produces: a decoded map, a JSON
  /// string, and JSON with leading PHP output before the first `{`.
  Map<String, dynamic>? _decode(dynamic raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is! String) return null;

    final start = raw.indexOf('{');
    if (start < 0) return null;
    try {
      final decoded = jsonDecode(raw.substring(start));
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  String _networkMessage(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'The server took too long to respond. Please try again.';
      case DioExceptionType.connectionError:
        return 'No connection. Check your internet and try again.';
      default:
        return 'Something went wrong reaching the server. Please try again.';
    }
  }

  /// `+8801712345678` -> `01712345678`. The PHP scripts normalise their input,
  /// but they were written around the 11-digit local form.
  String _toLocal(String phone) {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('880')) return '0${digits.substring(3)}';
    if (digits.startsWith('88') && digits.length == 12) {
      return '0${digits.substring(2)}';
    }
    return digits;
  }
}

class BdappsException implements Exception {
  final String message;
  BdappsException(this.message);
  @override
  String toString() => message;
}

class SubscriptionCheckResult {
  final bool success;
  final bool subscribed;
  final bool hasAccount;
  final String? accessToken;
  final String? refreshToken;

  /// The number was REGISTERED with an existing account, but minting the session
  /// failed. Treated as "fall through to the OTP flow" rather than an error.
  final bool tokenError;
  final String? message;

  SubscriptionCheckResult({
    required this.success,
    required this.subscribed,
    required this.hasAccount,
    this.accessToken,
    this.refreshToken,
    this.tokenError = false,
    this.message,
  });

  bool get canSignInDirectly =>
      subscribed &&
      hasAccount &&
      (accessToken?.isNotEmpty ?? false) &&
      (refreshToken?.isNotEmpty ?? false);

  factory SubscriptionCheckResult.fromJson(Map<String, dynamic> json) {
    return SubscriptionCheckResult(
      success: json['success'] == true,
      subscribed: _bool(json['subscribed']) ?? _registered(json),
      hasAccount: _bool(json['has_account']) ?? false,
      accessToken: json['access_token'] as String?,
      refreshToken: json['refresh_token'] as String?,
      tokenError: _bool(json['token_error']) ?? false,
      message: json['message'] as String?,
    );
  }

  static bool _registered(Map<String, dynamic> json) {
    final status = (json['subscriptionStatus'] ?? json['status']) as String?;
    return status?.trim().toUpperCase() == 'REGISTERED';
  }
}

class OtpSendResult {
  final bool success;
  final String? referenceNo;
  final String? message;

  OtpSendResult({required this.success, this.referenceNo, this.message});

  factory OtpSendResult.fromJson(Map<String, dynamic> json) {
    final ref = (json['referenceNo'] as String?)?.trim();
    return OtpSendResult(
      // A success with no referenceNo is unusable — there is nothing to verify
      // against — so it is not a success as far as the app is concerned.
      success: json['success'] == true && (ref?.isNotEmpty ?? false),
      referenceNo: ref,
      message: (json['message'] ?? json['statusDetail']) as String?,
    );
  }
}

class OtpVerifyResult {
  /// BDApps accepted the OTP. Note this is true even when [tokenError] is set:
  /// the code was spent either way, which is exactly why that case needs its own
  /// signal instead of being folded into failure.
  final bool success;
  final bool tokenError;
  final String? accessToken;
  final String? refreshToken;
  final bool isNewUser;
  final bool isSubscribed;
  final String? message;

  OtpVerifyResult({
    required this.success,
    this.tokenError = false,
    this.accessToken,
    this.refreshToken,
    this.isNewUser = false,
    this.isSubscribed = false,
    this.message,
  });

  bool get hasTokens =>
      (accessToken?.isNotEmpty ?? false) && (refreshToken?.isNotEmpty ?? false);

  factory OtpVerifyResult.fromJson(Map<String, dynamic> json) {
    return OtpVerifyResult(
      success: json['success'] == true,
      tokenError: _bool(json['token_error']) ?? false,
      accessToken: json['access_token'] as String?,
      refreshToken: json['refresh_token'] as String?,
      isNewUser: _bool(json['is_new_user']) ?? false,
      isSubscribed: _bool(json['is_subscribed']) ?? false,
      message: (json['message'] ?? json['statusDetail']) as String?,
    );
  }
}

/// PHP's booleans arrive as `true`, `"true"`, `1` or `"1"` depending on which
/// script wrote them and whether they came from a JSON re-encode.
bool? _bool(dynamic value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    final v = value.trim().toLowerCase();
    if (v == 'true' || v == '1') return true;
    if (v == 'false' || v == '0') return false;
  }
  return null;
}
