import 'package:base_network/helper/network_log_interceptor.dart';
import 'package:base_network/mixins/auth_mixin.dart';
import 'package:base_network/mixins/misc_mixin.dart';
import 'package:base_network/models/api_enums.dart';
import 'package:base_network/models/api_error.dart';
import 'package:base_network/models/base_options.dart';
import 'package:base_network/sentry_service.dart';
import "package:dio/dio.dart";
import 'package:dio_brotli_transformer/dio_brotli_transformer.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:firebase_performance_dio/firebase_performance_dio.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:retry/retry.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'mixins/network_mixin.dart';

abstract class BaseDioClient with NetworkMixin, AuthMixin, MiscMixin {
  late final Dio _dio;
  final bool _isDebug = kDebugMode;

  BaseDioClient() {
    final interceptorList = [
      NetworkLoggerInterceptor(),
      DioFirebasePerformanceInterceptor(
        requestUrlBuilder: (options) => options.uri.toString(),
      ),
    ];
    if (_isDebug) {
      interceptorList.addAll([
        LogInterceptor(
          request: true,
          responseHeader: true,
          responseBody: true,
          requestBody: true,
          requestHeader: true,
          error: true,
          logPrint: (o) {
            if (o is String) {
              if (o.startsWith(' Authorization:')) {
                printLongString(o);
              } else {
                debugPrint(
                  o.toString(),
                );
              }
            }
          },
        ),
      ]);
    }
    _dio = Dio()
      ..httpClientAdapter = getHttp2Adapter
      ..interceptors.addAll(interceptorList)
      ..transformer = DioBrotliTransformer();
    _dio.interceptors.removeImplyContentTypeInterceptor();
  }

  void addBaseInterceptors(List<Interceptor> listInterceptors,
      [bool shouldClear = true]) {
    if (shouldClear) {
      _dio.interceptors.clear();
    }
    _dio.interceptors.addAll(listInterceptors);
  }

  void updateCacheManager(Interceptor interceptor) {
    _dio.interceptors.removeWhere((e) => e.runtimeType == DioCacheInterceptor);
    _dio.interceptors.add(interceptor);
  }

  @protected
  Future<Response<dynamic>> callApiWithDio(
      {required BaseDioOptions baseOptions,
      bool isCacheAvailable = false,
      required Map<String, String> header}) async {
    final baseUrl = Uri.parse(baseOptions.url);
    const retry = RetryOptions(maxAttempts: 2);
    return await retry.retry(() async {
      _getDio(baseUrl.host);
      if (!await checkConnectivity && !isCacheAvailable) {
        throw noInternetException;
      } else {
        if (shouldReplaceToken(baseUrl)) {
          reduce401Url(baseUrl);
          header['Authorization'] = 'Bearer $accessToken';
        }
        final sentryService =
            SentryService(shouldStartSentry: !_isDebug && isSentrySupported);
        sentryService.startTransaction(
            baseOptions.url, getRequest(baseOptions.rawRequest));
        _dio.options = baseOptions.baseOptions;
        _dio.options.headers = header;
        _dio.options.responseType = baseOptions.baseOptions.responseType;
        onRequestSubmit();
        final url = baseOptions.url;
        final cancelToken = baseOptions.cancelToken;
        try {
          switch (baseOptions.requestType) {
            case HttpMethod.get:
              final res = await _dio.get(url, cancelToken: cancelToken);
              sentryService.setStatus(
                const SpanStatus.ok(),
              );
              return res;
            case HttpMethod.post:
              final res = await _dio.post(url,
                  data: baseOptions.request, cancelToken: cancelToken);
              sentryService.setStatus(
                const SpanStatus.ok(),
              );
              return res;
            case HttpMethod.download:
              final savePath =
                  baseOptions.savePath; // absolute file path to save

              final res = await _dio.download(
                url,
                savePath,
                cancelToken: cancelToken,
                onReceiveProgress: baseOptions.onReceiveProgress, // optional
              );
              sentryService.setStatus(const SpanStatus.ok());
              return res;
            case HttpMethod.upload:
              final uploadRes = await _dio.post(
                url,
                data: baseOptions.request,
                cancelToken: cancelToken,
              );
              sentryService.setStatus(const SpanStatus.ok());
              return uploadRes;
          }
        } on DioException catch (e) {
          final statusCode = e.response != null ? e.response?.statusCode : -1;
          sentryService.captureException(e, statusCode!);
          onErrorOccurred(e, baseOptions.rawRequest);
          if (CancelToken.isCancel(e)) {
            throw DioRequestCancelledException();
          }
          if (e.type == DioExceptionType.connectionError ||
              e.type == DioExceptionType.connectionTimeout) {
            throw BaseUrlFailedException(
              e.requestOptions.uri.toString(),
            );
          }
          if (e.error.toString().toLowerCase().contains("http/2")) {
            throw Http2Retry();
          }
          if (e.response != null && e.response!.statusCode == 401) {
            final callFailure = ApiCallError.callFailureDIO(
              e.response!,
              e.response!.realUri,
            );
            callCleverTap("API_FAILED", {
              "api failed":
                  "Base URL:${e.requestOptions.path} Unauthorized Error , Error Msg: $callFailure Token : ${e.requestOptions.headers["Authorization"]}"
            });
            if (callFailure is UnauthorizedCallFailure) {
              if (shouldFireUnAuthorized(callFailure.endUrl)) {
                throw UnauthorizedException(callFailure);
              }
            } else if (callFailure is SessionExpired) {
              throw SessionExpired(callFailure.endUrl, callFailure.challenge);
            }
          }
          rethrow;
        } finally {
          sentryService.finish();
        }
      }
    }, retryIf: (e) async {
      if (e is Http2Retry) {
        return true;
      } else if (e is UnauthorizedException) {
        final tokenUpdated = await newTokenFound;
        if (tokenUpdated) {
          add401Url(e.data.endUrl,);
        }
        return tokenUpdated;
      }
      if (e is BaseUrlFailedException) {
        handleFallbackUrl(Uri.parse(e.message));
        return true;
      }
      return false;
    });
  }

  void _getDio(String host) {
    _dio.httpClientAdapter = getHttpAdapter(host);
  }

  void callCleverTap(String s, Map<String, String> map);

  void printLongString(String text, {int chunkSize = 1020}) {
    final pattern = RegExp('.{1,$chunkSize}', dotAll: true);
    for (final match in pattern.allMatches(text)) {
      debugPrint(match.group(0));
    }
  }
}

String getFormatedDate(DateTime date) {
  return DateFormat('dd-MM-yyyy HH:mm:ss.SSS a').format(date);
}
