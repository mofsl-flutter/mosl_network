import 'dart:async';

import 'package:base_network/base_dio_client.dart';
import 'package:base_network/helper/network_file_logger.dart';
import 'package:base_network/models/network_interceptor_model.dart';
import 'package:dio/dio.dart';

class NetworkLoggerInterceptor extends Interceptor {
  static final NetworkLoggerInterceptor _instance = NetworkLoggerInterceptor._internal();
  factory NetworkLoggerInterceptor() => _instance;
  NetworkLoggerInterceptor._internal();

  final List<IntercepterResponseModel> networkLogs = [];
  final Map<int, DateTime> _startTimes = <int, DateTime>{};

  @override
  void onRequest(final RequestOptions options, final RequestInterceptorHandler handler) {
    _startTimes[options.hashCode] = DateTime.now();
    handler.next(options);
  }

  @override
  void onResponse(final Response<dynamic> response, final ResponseInterceptorHandler handler) {
    _logResponse(response);
    handler.next(response);
  }

  @override
  void onError(final DioException err, final ErrorInterceptorHandler handler) {
    if (err.response != null) {
      _logResponse(err.response!);
    }
    handler.next(err);
  }

  Map<String, String> getQueryParamsFromUrl(final String url) {
    final Uri uri = Uri.parse(url);
    return uri.queryParameters;
  }

  void _logResponse(final Response<dynamic> response) {
    final DateTime? startTime = _startTimes.remove(response.requestOptions.hashCode);
    final Duration duration = startTime != null ? DateTime.now().difference(startTime) : Duration.zero;

    final IntercepterResponseModel model = IntercepterResponseModel(
      createdAt: getFormatedDate(DateTime.now()),
      method: response.requestOptions.method,
      origin: response.requestOptions.uri.origin,
      query: response.requestOptions.uri.path,
      queryParam: response.requestOptions.queryParameters.isEmpty
          ? getQueryParamsFromUrl(response.requestOptions.uri.toString()).toString()
          : response.requestOptions.queryParameters.toString(),
      responseHeader: _formatHeaders(response.headers),
      // responseBody: _parseResponseBody(response.data),
      responseStatusCode: response.statusCode.toString(),
      responseStatusMessage: response.statusMessage ?? '',
      responseSize: _getResponseSize(response),
      requestHashCode: response.requestOptions.hashCode.toString(),
      responseTime: '${duration.inMilliseconds}ms',
      accept: response.requestOptions.headers['Accept'],
      contentType: response.requestOptions.headers['Content-Type'],
      xApiVersion: response.requestOptions.headers['X-Api-Version'],
      userAgent: response.requestOptions.headers['User-Agent'],
      authorization: response.requestOptions.headers['Authorization'],
    );

    networkLogs.add(model);
    _saveToFile(model);
  }

  String _formatHeaders(final Headers headers) {
    return headers.toString().replaceAll('\n', ', ');
  }

  String _getResponseSize(final Response<dynamic> response) {
    final String? contentLength = response.headers.value('content-length');
    if (contentLength != null) return '${contentLength}B';
    return '${response.data.toString().length}B';
  }

  void _saveToFile(final IntercepterResponseModel model) {
    final String logEntry = '''
    [NETWORK] Method: ${model.method}
    URL: ${model.origin}${model.query}
    Status: ${model.responseStatusCode}
    Duration: ${model.responseTime}
    Request Headers: ${{
      'Accept': model.accept,
      'Content-Type': model.contentType,
      'X-Api-Version': model.xApiVersion,
      'Authorization': model.authorization?.isNotEmpty ?? false ? '*****' : 'None'
    }}
    Response Headers: ${model.responseHeader}
  ''';

    unawaited(FileLogger().writeLog(logEntry, level: _getLogLevel(model.responseStatusCode)));
  }

  String _getLogLevel(final String statusCode) {
    final int code = int.tryParse(statusCode) ?? 500;
    if (code >= 500) return 'ERROR';
    if (code >= 400) return 'WARNING';
    return 'INFO';
  }

  void clearLogs() {
    networkLogs.clear();
  }
}
