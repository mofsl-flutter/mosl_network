import 'package:base_network/helper/network_log_interceptor.dart';
import 'package:base_network/mixins/auth_mixin.dart';
import 'package:base_network/mixins/misc_mixin.dart';
import 'package:base_network/models/api_enums.dart';
import 'package:base_network/models/api_error.dart';
import 'package:base_network/models/base_options.dart';
import "package:dio/dio.dart";
import 'package:dio_brotli_transformer/dio_brotli_transformer.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:firebase_performance_dio/firebase_performance_dio.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:retry/retry.dart';
import 'package:datadog_dio/datadog_dio.dart';
import 'package:datadog_flutter_plugin/datadog_flutter_plugin.dart';
import 'mixins/network_mixin.dart';

abstract class BaseDioClient with NetworkMixin, AuthMixin, MiscMixin {
  BaseDioClient() {
    final List<Interceptor> interceptorList = [
      NetworkLoggerInterceptor(),
      DioFirebasePerformanceInterceptor(
        requestUrlBuilder: (RequestOptions options) => options.uri.toString(),
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
          logPrint: (Object o) {
            if (o is String) {
              if (o.startsWith(' Authorization:')) {
                printLongString(o);
              } else {
                debugPrint(
                  o,
                );
              }
            }
          },
        ),
      ]);
    }
    _dio = Dio()
      ..addDatadogInterceptor(DatadogSdk.instance)
      ..httpClientAdapter = getHttp2Adapter
      ..interceptors.addAll(interceptorList)
      ..transformer = DioBrotliTransformer();
    _dio.interceptors.removeImplyContentTypeInterceptor();
  }

  late final Dio _dio;
  final bool _isDebug = kDebugMode;

  void addBaseInterceptors(final List<Interceptor> listInterceptors,
      [final bool shouldClear = true]) {
    if (shouldClear) {
      _dio.interceptors.clear();
    }
    _dio.interceptors.addAll(listInterceptors);
  }

  void updateCacheManager(final Interceptor interceptor) {
    _dio.interceptors.removeWhere((Interceptor e) => e.runtimeType == DioCacheInterceptor);
    _dio.interceptors.add(interceptor);
  }

  @protected
  Future<Response<dynamic>> callApiWithDio(
      {required final BaseDioOptions baseOptions,
      final bool isCacheAvailable = false,
      required final Map<String, String> header}) async {
    final Uri baseUrl = Uri.parse(baseOptions.url);
    const RetryOptions retry = RetryOptions(maxAttempts: 2);
    return await retry.retry(() async {
      _getDio(baseUrl.host);
      if (!await checkConnectivity && !isCacheAvailable) {
        // ignore: only_throw_errors
        throw noInternetException;
      } else {
        if (shouldReplaceToken(baseUrl)) {
          reduce401Url(baseUrl);
          header['Authorization'] = 'Bearer $accessToken';
        }
        _dio.options = baseOptions.baseOptions;
        _dio.options.headers = header;
        _dio.options.responseType = baseOptions.baseOptions.responseType;
        onRequestSubmit();
        final String url = baseOptions.url;
        final CancelToken? cancelToken = baseOptions.cancelToken;
        try {
          switch (baseOptions.requestType) {
            case HttpMethod.get:
              final Response<dynamic> res = await _dio.get(url, cancelToken: cancelToken);
              return res;
            case HttpMethod.post:
              final Response<dynamic> res =
                  await _dio.post(url, data: baseOptions.request, cancelToken: cancelToken);
              return res;
            case HttpMethod.download:
              final String? savePath = baseOptions.savePath; // absolute file path to save

              final Response<dynamic> res = await _dio.download(
                url,
                savePath,
                cancelToken: cancelToken,
                onReceiveProgress: baseOptions.onReceiveProgress,
              );
              return res;
            case HttpMethod.upload:
              final Response<dynamic> uploadRes = await _dio.post(
                url,
                data: baseOptions.request,
                cancelToken: cancelToken,
              );
              return uploadRes;
          }
        } on DioException catch (e) {
          final int? statusCode = e.response != null ? e.response?.statusCode : -1;

          onErrorOccurred(e, baseOptions.rawRequest);
          if (CancelToken.isCancel(e)) {
            throw const DioRequestCancelledException();
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
            final ApiCallError callFailure = ApiCallError.callFailureDIO(
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
            } else if (callFailure is ReAuthRequired) {
              // ignore: only_throw_errors
              throw ReAuthRequired(callFailure.endUrl, callFailure.challenge);
            } else if (callFailure is SessionExpired) {
              // Rethrow the classified instance rather than rebuilding it, so
              // fields such as the credential-expiry message cannot be dropped.
              // ignore: only_throw_errors
              throw callFailure;
            }
          }
          rethrow;
        } finally {}
      }
    }, retryIf: (final Exception e) async {
      if (e is Http2Retry) {
        return true;
      } else if (e is UnauthorizedException) {
        final bool tokenUpdated = await newTokenFound(e);
        if (tokenUpdated) {
          add401Url(
            e.data.endUrl,
          );
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

  void _getDio(final String host) {
    _dio.httpClientAdapter = getHttpAdapter(host);
  }

  void callCleverTap(final String s, final Map<String, String> map);

  void printLongString(final String text, {final int chunkSize = 1020}) {
    final RegExp pattern = RegExp('.{1,$chunkSize}', dotAll: true);
    for (final RegExpMatch match in pattern.allMatches(text)) {
      debugPrint(match.group(0));
    }
  }
}

String getFormatedDate(final DateTime date) {
  return DateFormat('dd-MM-yyyy HH:mm:ss.SSS a').format(date);
}
