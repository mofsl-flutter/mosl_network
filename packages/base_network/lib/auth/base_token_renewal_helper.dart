import 'dart:async';

import 'package:base_network/error_handling/error_exception.dart';
import 'package:base_network/models/api_constants.dart';
import 'package:base_network/models/api_enums.dart';
import 'package:base_network/models/api_error.dart';
import 'package:dio/dio.dart';

abstract class BaseTokenManager {
  Future<bool>? _renewAccessTokenFuture;

  Future<bool> newAccessToken() {
    return (_renewAccessTokenFuture ??= _getAccessToken()).whenComplete(_tokenUpdated);
  }

  void _tokenUpdated() {
    //FlutterLogs.logInfo("Trader", "Broadcast",'JwtTokenProvider: _tokenUpdated() called');
    writeLogs("Trader TokenUpdate", 'JwtTokenProvider: _tokenUpdated() called');

    //Set future to null after timeoutDuration, ensuring all API which may
    // receive 401 due to bad token have either completed or failed.
    // This prevents multiple token api call due to timing isssue.
    Timer(ApiConstants.timeoutDuration, () {
      _renewAccessTokenFuture = null;
    });
  }

/*
*
* should be returning access token(refreshed)
*
* */
  Future<String> renewToken();

  Future<SilentLoginStatus> callSilentLogin(final bool isForce);

  void handleSilentLoginFailure();

  void writeLogs(final String title, final String message);

  bool get isTokenValid;

  bool get shouldCallRefreshToken;

  Future<bool> _getAccessToken() {
    return renewToken().then((final String value) {
      return value.isNotEmpty;
    }).onError((final Object? error, final StackTrace stackTrace) async {
      writeLogs("Trader TokenReview", "renewToken api call failed: $error");
      if (!isTokenValid) {
        return await _getRefreshToken();
      }

      //Todo not effective case
      /*if (error is UnauthorizedCallFailure && error.refreshTokenExpired) {
        return await _getRefreshToken();
      }*/
      if (error is DioException) {
        final List<String>? challenge = error.response?.headers[authenticateHeaderMPin];
        if (challenge is List<String> && challenge.isNotEmpty) {
          writeLogs("Trader TokenReview", "renewToken api call failed: Getting token from _getAccessToken now getting renew session");
          if (!(challenge.any((final String challenge) =>
              challenge.contains(ApiConstants.reLoginRequiredChallenge)))) {
            return await _getRefreshToken();
          } else if ((challenge.any((final String challenge) =>
              challenge.contains(ApiConstants.reLoginRequiredChallenge)))) {
            writeLogs("Trader TokenReview", "renewToken api call failed: ReLoginRequired");
            return false;
          }
        }
      }
      if (error is ApiFailure && error.errorCode == 401) {
        return await _getRefreshToken();
      }
      if (error is ErrorException && error.statusCode == 401) {
        return await _getRefreshToken();
      }
      return false;
    });
  }

  void refreshTokenIfNeeded() {
    if (!isTokenValid || shouldCallRefreshToken) {
      unawaited(_getRefreshToken());
    }
  }

  Future<bool> _getRefreshToken() {
    return callSilentLogin(true).then((final SilentLoginStatus value) {
      if (value != SilentLoginStatus.success) {
        handleSilentLoginFailure();
      }
      return value == SilentLoginStatus.success;
    });
  }
}
