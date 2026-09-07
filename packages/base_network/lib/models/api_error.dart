import 'dart:io';
import 'package:base_network/models/api_constants.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

const String authenticateHeaderMPin = 'x-amzn-Remapped-WWW-Authenticate';
const String credentialExpiredMsgHeader = 'x-credential-expired-msg';

abstract class ApiCallError {
  const ApiCallError();

  factory ApiCallError.timeout() => const ApiTimeout();

  factory ApiCallError.failure(final String error, final int statusCode) =>
      ApiFailure(error, statusCode);

  factory ApiCallError.callFailureDIO(final Response<dynamic> response, final Uri uri) {
    //Sample Path - TraderRevampAPI/api/Init
    final bool isFromRise = response.requestOptions.headers.containsKey("XApiKey");
    final String endUrl = getEndUrl(uri);
    final dynamic challenge = response.headers[HttpHeaders.wwwAuthenticateHeader] ??
        response.headers[authenticateHeaderMPin] ??
        '';

    if (challenge is List<String> && challenge.isNotEmpty) {
      if (challenge.any((String c) => c.contains(ApiConstants.reAuthRequiredChallenge))) {
        return ReAuthRequired(endUrl, challenge[0]);
      } else if (!(challenge.any((String challenge) =>
          challenge.contains(ApiConstants.reLoginRequiredChallenge)))) {
        // Raise a custom exception indicating that re-login is required
        return UnauthorizedCallFailure(endUrl, challenge[0]);
      } else if ((challenge.any((String challenge) =>
          challenge.contains(ApiConstants.reLoginRequiredChallenge)))) {
        final List<String>? nonFrequentUserSessionOut =
            response.headers['WWW-Authenticate-SessionOutMsg'] ??
                response.headers['www-authenticate-sessionoutmsg'];
        if (nonFrequentUserSessionOut != null &&
            nonFrequentUserSessionOut.isNotEmpty) {
          return NonFrequentSessionExpiredCallFailure(
              endUrl, challenge[0], nonFrequentUserSessionOut[0]);
        }
        // PIN/password expiry: the server sends the copy to show instead of
        // the generic session-expired message.
        final List<String>? credentialExpiredMsg =
            response.headers[credentialExpiredMsgHeader];
        final String? credentialMessage = credentialExpiredMsg != null &&
                credentialExpiredMsg.isNotEmpty &&
                credentialExpiredMsg.first.trim().isNotEmpty
            ? credentialExpiredMsg.first.trim()
            : null;
        return SessionExpired(endUrl, challenge[0], credentialMessage);
      }
    } else if (isFromRise || response.statusCode == 401) {
      return UnauthorizedCallFailure(endUrl, endUrl);
    }
    return ApiCallFailureDIO(response);
  }

  static String getEndUrl(final Uri uri) {
    final String endUrl = uri.path.substring(uri.path.indexOf('/api/') + 5);
    return endUrl;
  }
}

class ApiTimeout extends ApiCallError {
  const ApiTimeout();

  @override
  String toString() {
    return 'ApiTimeout';
  }
}

@immutable
class ApiFailure extends ApiCallError {
  const ApiFailure(this.error, this.errorCode);

  final String error;
  final int errorCode;

  @override
  bool operator ==(final Object other) =>
      identical(this, other) ||
      other is ApiFailure &&
          runtimeType == other.runtimeType &&
          error == other.error &&
          errorCode == other.errorCode;

  @override
  int get hashCode => error.hashCode ^ errorCode.hashCode;

  @override
  String toString() {
    return error;
  }
}

class SessionExpired extends ApiCallError {
  SessionExpired(this.endUrl, this.challenge, [this.message]);

  final String endUrl;
  final String challenge;

  /// Server-supplied copy from `X-Credential-Expired-Msg`; null when the
  /// header was absent or empty, in which case the generic message is shown.
  final String? message;

  @override
  String toString() {
    return 'SessionExpired{endUrl: $endUrl, challenge: $challenge, message: $message}';
  }
}

class ReAuthRequired extends ApiCallError {
  ReAuthRequired(this.endUrl, this.challenge);

  final String endUrl;
  final String challenge;

  @override
  String toString() => 'ReAuthRequired{endUrl: $endUrl, challenge: $challenge}';
}

class NonFrequentUserSessionOut extends ApiCallError {
  NonFrequentUserSessionOut(this.endUrl, this.message);

  final String endUrl;
  final String message;

  @override
  String toString() {
    return 'NonFrequentUserSessionOut{endUrl: $endUrl, message: $message}';
  }
}

//401:Bearer challenge or 401:Empty Challenge
class UnauthorizedCallFailure extends ApiCallError {
  UnauthorizedCallFailure(this.endUrl, this.challenge);

  final String endUrl;
  final String challenge;

  @override
  String toString() {
    return 'Api: $endUrl, 401 Challenge: $challenge';
  }
}

class NonFrequentSessionExpiredCallFailure extends UnauthorizedCallFailure {
  NonFrequentSessionExpiredCallFailure(
      super.endUrl, super.challenge, this.message);

  final String message;

  @override
  String toString() {
    return 'NonFrequentSessionExpiredCallFailure: $endUrl, 401 Challenge: $challenge';
  }
}

class Http2Retry implements Exception {}

@immutable
class DioRequestCancelledException implements Exception {
  const DioRequestCancelledException();

  @override
  String toString() {
    return 'DioRequestCancelledException';
  }

  @override
  bool operator ==(final Object other) =>
      identical(this, other) ||
      other is DioRequestCancelledException && runtimeType == other.runtimeType;

  @override
  int get hashCode => 0;

  bool operator <(final Object other) {
    return false;
  }
}

class UnauthorizedException implements Exception {
  UnauthorizedException(this.data);

  final UnauthorizedCallFailure data;
}

class NonFrequentUserSessionOutException implements Exception {
  NonFrequentUserSessionOutException(this.data);

  final NonFrequentUserSessionOut data;
}

class ApiCallFailure extends ApiCallError {
  ApiCallFailure(this.response);

  final Response<dynamic> response;

  @override
  String toString() {
    return 'Status Code: ${response.statusCode}';
  }
}

class ApiCallFailureDIO extends ApiCallError {
  ApiCallFailureDIO(this.response);

  final Response<dynamic> response;

  @override
  String toString() {
    return 'Status Code: ${response.statusCode}';
  }
}

class BaseUrlFailedException implements Exception {
  BaseUrlFailedException(
    this.message,
  );

  final String message;
}
