import 'dart:io';
import 'package:base_network/models/api_constants.dart';
import 'package:dio/dio.dart';


const authenticateHeaderMPin = 'x-amzn-Remapped-WWW-Authenticate';
abstract class ApiCallError {
  factory ApiCallError.timeout() => const ApiTimeout();

  factory ApiCallError.failure(String error, int statusCode) => ApiFailure(error, statusCode);


  static String getEndUrl(Uri uri) {
     final endUrl = uri.path.substring(uri.path.indexOf('/api/') + 5);
     return endUrl;
  }
  factory ApiCallError.callFailureDIO(Response response, Uri uri) {
    //Sample Path - TraderRevampAPI/api/Init
    final isFromRise = response.requestOptions.headers.containsKey("XApiKey");
    final endUrl = getEndUrl(uri);
    final challenge = response.headers[HttpHeaders.wwwAuthenticateHeader] ?? response.headers[authenticateHeaderMPin]  ?? '';
    final nonFrequentUserSessionOut = response.headers['WWW-Authenticate-SessionOutMsg'] ?? response.headers['www-authenticate-sessionoutmsg'];
    // Check for non-frequent user session out header
    if (nonFrequentUserSessionOut != null && nonFrequentUserSessionOut.isNotEmpty) {
      return NonFrequentUserSessionOut(endUrl, nonFrequentUserSessionOut.toString());
    }
    
    if (challenge is List<String> && challenge.isNotEmpty) {
      if (!(challenge
          .any((challenge) => challenge.contains(ApiConstants.reLoginRequiredChallenge)))) {
        // Raise a custom exception indicating that re-login is required
        return UnauthorizedCallFailure(endUrl, challenge[0]);
      }else if ((challenge
          .any((challenge) => challenge.contains(ApiConstants.reLoginRequiredChallenge)))){
        return SessionExpired(endUrl, challenge[0]);
      }
    }else if(isFromRise){
      return UnauthorizedCallFailure(endUrl, endUrl);
    }
    return ApiCallFailureDIO(response);
  }

  const ApiCallError();
}

class ApiTimeout extends ApiCallError {
  const ApiTimeout();

  @override
  String toString() {
    return 'ApiTimeout';
  }
}

class ApiFailure extends ApiCallError {
  final String error;
  final int errorCode;
  const ApiFailure(this.error, this.errorCode);

  @override
  bool operator ==(Object other) =>
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

class SessionExpired extends ApiCallError{
  final String endUrl;
  final String challenge;

  SessionExpired(this.endUrl, this.challenge);

  @override
  String toString() {
    return 'SessionExpired{endUrl: $endUrl, challenge: $challenge}';
  }
}

class NonFrequentUserSessionOut extends ApiCallError{
  final String endUrl;
  final String message;

  NonFrequentUserSessionOut(this.endUrl, this.message);

  @override
  String toString() {
    return 'NonFrequentUserSessionOut{endUrl: $endUrl, message: $message}';
  }
}

//401:Bearer challenge or 401:Empty Challenge
class UnauthorizedCallFailure extends ApiCallError {
  final String endUrl;
  final String challenge;

  UnauthorizedCallFailure(this.endUrl, this.challenge);

  @override
  String toString() {
    return 'Api: $endUrl, 401 Challenge: $challenge';
  }
}

class Http2Retry implements Exception {}

class DioRequestCancelledException implements Exception {
  DioRequestCancelledException();

  @override
  String toString() {
    return 'DioRequestCancelledException';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DioRequestCancelledException && runtimeType == other.runtimeType;

  @override
  int get hashCode => 0;

  @override 
  bool operator <(Object other) {
    return false;
  }
}

class UnauthorizedException implements Exception {
  final UnauthorizedCallFailure data;

  UnauthorizedException(this.data);
}

class NonFrequentUserSessionOutException implements Exception {
  final NonFrequentUserSessionOut data;

  NonFrequentUserSessionOutException(this.data);
}

class ApiCallFailure extends ApiCallError {
  final Response response;

  ApiCallFailure(this.response);

  @override
  String toString() {
    return 'Status Code: ${response.statusCode}';
  }
}

class ApiCallFailureDIO extends ApiCallError {
  final Response response;

  ApiCallFailureDIO(this.response);

  @override
  String toString() {
    return 'Status Code: ${response.statusCode}';
  }
}

class BaseUrlFailedException implements Exception {
  final String message;
  BaseUrlFailedException(this.message,);
}
