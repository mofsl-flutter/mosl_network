import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

class LoggingInterceptor extends Interceptor {
  LoggingInterceptor({
    this.request = true,
    this.requestHeader = true,
    this.requestBody = false,
    this.responseHeader = true,
    this.responseBody = false,
    this.error = true,
  });

  /// Print request [Options]
  bool request;

  /// Print request header [Options.headers]
  bool requestHeader;

  /// Print request data [Options.data]
  bool requestBody;

  /// Print [Response.data]
  bool responseBody;

  /// Print [Response.headers]
  bool responseHeader;

  /// Print error message
  bool error;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    debugPrint('*** Request ***');
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (error) {
      debugPrint('*** DioException ***:');
      debugPrint('uri: ${err.requestOptions.uri}');
      debugPrint('$err');
      if (err.response != null) {
        _printResponse(err.response!);
      }
    }
    handler.next(err);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    debugPrint('*** Response ***');
    handler.next(response);
  }

  void _printResponse(Response response) {
    _printKV('uri', response.requestOptions.uri);
    if (responseHeader) {
      _printKV('statusCode', response.statusCode);
      if (response.isRedirect == true) {
        _printKV('redirect', response.realUri);
      }
      debugPrint('headers:');
      response.headers.forEach((key, v) => _printKV(' $key', v.join('\r\n\t')));
    }
    if (responseBody) {
      debugPrint('Response Text:');
      if(!kReleaseMode) {
        debugPrint(response.toString());
      }
    }
  }

  void _printKV(String key, Object? v) {
    debugPrint('$key: $v');
  }
}