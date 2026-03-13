import 'dart:async';

import 'package:base_network/auth/base_token_renewal_helper.dart';
import 'package:base_network/base_dio_client.dart';
import 'package:base_network/error_handling/error_exception.dart'
    show ErrorException;
import 'package:base_network/models/api_error.dart';
import 'package:dio/dio.dart'
    show DioException, DioExceptionType, Interceptor, Response;
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:flutter/material.dart';
import 'package:mosl_network/network/dio_cache_manager.dart';
import 'package:mosl_network/network/extentions.dart';
import 'package:mosl_network/network/helper/api_request_builder.dart';
import 'package:mosl_network/network/helper/exceptions.dart';
import 'package:mosl_network/network/helper/preferences.dart';
import 'package:mosl_network/network/helper/url_paths.dart';
import 'package:mosl_network/network/interceptors/dio_api_interceptor.dart';
import 'package:mosl_network/network/interceptors/loging_interceptor.dart';
import 'package:protobuf/protobuf.dart';

class DioImpl extends BaseDioClient {
  static late final DioImpl _instance;
  final CacheManager _cacheManager;

  factory DioImpl() => _instance;

  final List<Interceptor> _interceptorList = [];

  late final BaseTokenManager _tokenManager;
  late final Set<String> _urlsShouldNotFire401;

  factory DioImpl.init({
    required CacheManager cacheManager,
    required BaseTokenManager tokenManager,
    required Set<String> urlsShouldNotFire401,
  }) {
    _instance = DioImpl._(cacheManager);
    _instance._tokenManager = tokenManager;
    _instance._urlsShouldNotFire401 = urlsShouldNotFire401;
    _instance
      .._interceptorList.clear()
      .._interceptorList.add(ApiInterceptor())
      .._interceptorList.add(LoggingInterceptor())
      .._interceptorList.add(
        DioCacheInterceptor(
          options: _instance._cacheManager.getCacheOptions(
            false,
            false,
            const Duration(hours: 12),
          ),
        ),
      );
    return _instance..addBaseInterceptors(_instance._interceptorList, false);
  }

  DioImpl._(this._cacheManager);

  Future<T> callApiWithDioClient<T extends Object>(
      ApiRequest apiRequest, T response,
      [Duration? maxStale]) async {
    final completer = Completer<T>();
    final bool fromRise = apiRequest.apiIdentifier.isRise;
    apiRequest = _appendUrl(fromRise, apiRequest);
    ApiInterceptor().setHeaders(apiRequest.headers);
    updateCacheManager(
      DioCacheInterceptor(
        options: _cacheManager.getCacheOptions(
          apiRequest.isForcedCacheEnable,
          apiRequest.isInternetAvailable,
          maxStale,
        ),
      ),
    );

    final isCacheAvailable =
        apiRequest.isForcedCacheEnable && apiRequest.isCacheAvailable;

    Response<dynamic>? baseResponse;
    try {
      baseResponse = await callApiWithDio(
        baseOptions: apiRequest,
        isCacheAvailable: isCacheAvailable,
        header: apiRequest.headers.toJson,
      );
    } catch (error) {
      if (isCacheAvailable) {
        CacheManager().delete(apiRequest.url);
      }

      if (error is SessionExpired) {
        //Todo need to add logger here
        // AppWriteLog.writeLog("Api service", "SessionExpired with the value ${error.toString()}");
        _handleReLogin();
      } else {
        completer.completeError(
          getErrorFromException2(error, isCacheEnabled: false),
        );
      }
    }
    if (baseResponse != null) {
      if (runtimeType is GeneratedMessage) {
        (runtimeType as GeneratedMessage).clear();
      }

      try {
        final finalResponse = (baseResponse)
            .handleResponse(response, isFromCache: isCacheAvailable);
        completer.complete(finalResponse);
      } catch (e) {
        debugPrintStack();
        if (e is ErrorException) {
          rethrow;
        } else {
          throw getErrorFromException2(e);
        }
      }
    }
    return completer.future;
  }

  @override
  Future<bool> newTokenFound(UnauthorizedException failure) async {
    bool respVal = await _tokenManager.newAccessToken();
    return respVal;
  }

  @override
  void onErrorOccurred(DioException e, Object? request) {
    var requestOptionsUrl = e.requestOptions.path;
    try {
      final headers = e.response!.headers.map;
      final List<String> userAgentSplit =
          ((headers['User-Agent'] ?? '') as String).split('/');
      final serverTimingData = headers['server-timing'] ?? '';
      requestOptionsUrl = e.requestOptions.path.replaceAll(',', '');
      writeLog("-,${e.requestOptions.method},"
          "${e.requestOptions.uri.origin} ,"
          "${e.requestOptions.path.replaceAll(',', '')},"
          "${e.response?.statusCode}, "
          " ${getFormatedDate(DateTime.now())}, - ,"
          " ${userAgentSplit.last}, ${userAgentSplit[0]},"
          "${userAgentSplit.length > 3 ? userAgentSplit[3] : ''},"
          "${userAgentSplit.length > 2 ? userAgentSplit[2] : ''},"
          "${e.requestOptions.headers['X-Api-Version'] ?? ''},"
          "${userAgentSplit[1]},$serverTimingData");
    } catch (e) {
      debugPrint(
        'Error Exception : $e',
      );
    }
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.badCertificate:
      case DioExceptionType.connectionError:
      case DioExceptionType.unknown:
        callCleverTap("API_FAILED", {
          "api failed":
              "Base URL:$requestOptionsUrl, Request: ${request.toString()},Error Msg: $e}"
        });
      default:
      //ignore this;
    }
  }

  @override
  bool shouldFireUnAuthorized(String endUrl) =>
      !_urlsShouldNotFire401.contains(endUrl);

  @override
  void onRequestSubmit() {}

  @override
  Object get noInternetException =>
      ErrorException(key: "No Internet!", message: noInternetConnection);

  @override
  Future<bool> get checkConnectivity => checkInternetConnectivity();

  @override
  String get accessToken => Preferences().accessToken.getOrDefault();

  @override
  bool get isSentrySupported => true;

  ApiRequest _appendUrl(bool fromRise, ApiRequest dioOptions) {
    final identifier = dioOptions.apiIdentifier;
    if (!dioOptions.url.startsWith("http")) {
      if (identifier.isRise) {
        dioOptions = dioOptions.copyWith(url: "$riseBaseUrl${dioOptions.url}");
      } else if (identifier.isMPinLogin) {
        dioOptions = dioOptions.copyWith(
          url: "$mPinLoginUrl${dioOptions.url}",
        );
      } else {
        dioOptions = dioOptions.copyWith(
          url: "$traderBaseUrl${dioOptions.url}",
        );
      }
    }
    return dioOptions;
  }

  void _handleReLogin() {
    _tokenManager.handleSilentLoginFailure();
  }

  @override
  void handleFallbackUrl(Uri uri) {}

  @override
  void callCleverTap(String s, Map<String, String> map) {}

  void writeLog(String message) {}
}
