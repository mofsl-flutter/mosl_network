import 'package:base_network/models/api_enums.dart';
import 'package:base_network/models/base_options.dart';
import 'package:dio/dio.dart';
import 'package:mosl_network/network/helper/api_header_builder.dart';
import 'package:mosl_network/network/helper/header_base_options.dart'
    show HeaderBaseOptions;
import 'package:mosl_network/network/helper/preferences.dart';
import 'package:protobuf/protobuf.dart';

enum ApiIdentifier {
  rise,
  trader,
  eDuMo,
  login,
  accountAggregator,
  mPinLogin,
  pwm,
  unknown;

  bool get isPWM => this == pwm;

  bool get isRise => this == rise;

  bool get isMPinLogin => this == mPinLogin;
}

class ApiRequest<T extends Object> extends BaseDioOptions<T> {
  final String? specialToken;
  final bool isForcedCacheEnable;
  final bool isInternetAvailable;
  final bool isCacheAvailable;
  final String apiVersion;
  final ApiIdentifier apiIdentifier;
  final String? apiKey;
  final void Function(T cachedBaseResponse)? cacheCallback;
  final bool isTokenRequired;

  ApiRequest._({
    required super.url,
    required super.request,
    required super.rawRequest,
    required super.requestType,
    required super.cancelToken,
    required super.responseType,
    super.onReceiveProgress,
    super.savePath,
    this.specialToken,
    required this.isForcedCacheEnable,
    required this.isCacheAvailable,
    required this.isInternetAvailable,
    required this.apiVersion,
    required this.apiIdentifier,
    this.apiKey,
    this.cacheCallback,
    required this.isTokenRequired,
  });

  static ApiRequestBuilder<T> builder<T extends Object>() =>
      ApiRequestBuilder<T>();

  ApiRequest copyWith({String? url}) {
    return ApiRequest._(
      url: url ?? this.url,
      request: request,
      rawRequest: rawRequest,
      requestType: requestType,
      cancelToken: cancelToken,
      responseType: responseType,
      onReceiveProgress: onReceiveProgress,
      savePath: savePath,
      specialToken: specialToken,
      isForcedCacheEnable: isForcedCacheEnable,
      isInternetAvailable: isInternetAvailable,
      isCacheAvailable: isCacheAvailable,
      apiVersion: apiVersion,
      apiIdentifier: apiIdentifier,
      apiKey: apiKey,
      cacheCallback: cacheCallback == null
          ? null
          : (Object obj) => cacheCallback!(obj as T),
      isTokenRequired: isTokenRequired,
    );
  }

  String get userAgent => Preferences().userAgent.getOrDefault();

  HeaderBaseOptions get headers {
    if (apiIdentifier == ApiIdentifier.trader || apiIdentifier.isMPinLogin) {
      return ProtoApiHeader(
        xApiVersion: apiVersion,
        userAgent: userAgent,
        specialToken: specialToken,
        cacheCallback: null,
        isTokenRequired: isTokenRequired,
      );

    } else {
      return JsonApiHeader(
        xApiKey: apiKey,
        xApiVersion: apiVersion,
        userAgent: userAgent,
        specialToken: specialToken,
        cacheCallback: null,
        isTokenRequired: isTokenRequired,
      );
    }
  }
}

class ApiRequestBuilder<T extends Object> {
  String? _url;
  T? _request;
  T? _rawRequest;
  HttpMethod _requestType = HttpMethod.get;
  CancelToken? _cancelToken;
  ResponseType _responseType = ResponseType.bytes;
  ProgressCallback? _onReceiveProgress;
  String? _savePath;
  String? _specialToken;
  bool _isForcedCacheEnable = false;
  bool _isInternetAvailable = true;
  bool _isCacheAvailable = false;
  bool _isTokenRequired = true;
  String _apiVersion = '1.0';
  ApiIdentifier? _apiIdentifier = ApiIdentifier.unknown;
  String? _apiKey;
  void Function(T)? _cacheCallback;

  ApiRequestBuilder<T> url(String url) {
    _url = url;
    return this;
  }

  ApiRequestBuilder<T> request(T request) {
    _request = request;
    return this;
  }

  ApiRequestBuilder<T> rawRequest(T rawRequest) {
    _rawRequest = rawRequest;
    return this;
  }

  ApiRequestBuilder<T> requestType(HttpMethod method) {
    _requestType = method;
    return this;
  }

  ApiRequestBuilder<T> cancelToken(CancelToken token) {
    _cancelToken = token;
    return this;
  }

  ApiRequestBuilder<T> responseType(ResponseType type) {
    _responseType = type;
    return this;
  }

  ApiRequestBuilder<T> onReceiveProgress(ProgressCallback callback) {
    _onReceiveProgress = callback;
    return this;
  }

  ApiRequestBuilder<T> savePath(String path) {
    _savePath = path;
    return this;
  }

  ApiRequestBuilder<T> specialToken(String? token) {
    _specialToken = token;
    return this;
  }

  ApiRequestBuilder<T> forcedCache(bool val) {
    _isForcedCacheEnable = val;
    return this;
  }

  ApiRequestBuilder<T> internetAvailable(bool val) {
    _isInternetAvailable = val;
    return this;
  }

  ApiRequestBuilder<T> cacheAvailable(bool val) {
    _isCacheAvailable = val;
    return this;
  }

  ApiRequestBuilder<T> apiVersion(String version) {
    _apiVersion = version;
    return this;
  }

  ApiRequestBuilder<T> apiIdentifier(ApiIdentifier id) {
    _apiIdentifier = id;
    return this;
  }

  ApiRequestBuilder<T> isTokenRequired(bool isTokenRequired) {
    _isTokenRequired = isTokenRequired;
    return this;
  }

  ApiRequestBuilder<T> apiKey(String key) {
    _apiKey = key;
    return this;
  }

  ApiRequestBuilder<T> cacheCallback(void Function(T) callback) {
    _cacheCallback = callback;
    return this;
  }

  ApiRequest<T> build() {
    assert(_url != null, 'URL is required');
    assert(_apiVersion != null, 'API version is required');
    assert(_apiIdentifier != null, 'API Identifier is required');
    final responseType = ApiIdentifier.trader == _apiIdentifier || ApiIdentifier.mPinLogin == _apiIdentifier
        ? ResponseType.bytes
        : ResponseType.json;
    return ApiRequest._(
      url: _url!,
      request:
          _request is GeneratedMessage
              ? _request = (_request as GeneratedMessage).writeToBuffer() as T?
              : _request,
      rawRequest: _rawRequest,
      requestType: _requestType,
      cancelToken: _cancelToken,
      responseType: responseType,
      onReceiveProgress: _onReceiveProgress,
      savePath: _savePath,
      specialToken: _specialToken,
      isForcedCacheEnable: _isForcedCacheEnable,
      isCacheAvailable: _isCacheAvailable,
      isInternetAvailable: _isInternetAvailable,
      apiVersion: _apiVersion!,
      isTokenRequired: _isTokenRequired,
      apiIdentifier: _apiIdentifier!,
      apiKey: _apiKey,
      cacheCallback: _cacheCallback,
    );
  }
}
