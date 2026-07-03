
import 'package:base_network/models/api_enums.dart';
import "package:dio/dio.dart";

final BaseOptions baseDioOptions = BaseOptions(
  connectTimeout: const Duration(seconds: 20),
  receiveTimeout: const Duration(seconds: 20),
  responseType: ResponseType.bytes,
);

class BaseDioOptions<T extends Object> {
  BaseDioOptions({
    final BaseOptions? baseOptions,
    required this.url,
    this.request,
    this.rawRequest,
    this.requestType = HttpMethod.get,
    this.cancelToken,
    this.responseType,
    this.onReceiveProgress,
    this.savePath,
  }) {
    assert(
    requestType != HttpMethod.download || savePath != null,
    'Download requests must have a non-null savePath',
    );

// For upload: request must be FormData and not null
    assert(
    requestType != HttpMethod.upload || (request != null && request is FormData),
    'Upload requests must have a non-null FormData request body',
    );
    this.baseOptions = baseOptions ?? baseDioOptions;
    if (responseType != null) {
      this.baseOptions = this.baseOptions.copyWith(responseType: responseType);
    }
  }

  late BaseOptions baseOptions;
  final String url;
  final T? request;
  final T? rawRequest;
  final HttpMethod requestType;
  final CancelToken? cancelToken;
  final ResponseType? responseType;
  final ProgressCallback? onReceiveProgress;
  final String? savePath;
}