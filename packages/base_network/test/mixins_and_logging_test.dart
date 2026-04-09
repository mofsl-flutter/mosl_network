import 'dart:async';
import 'dart:io';

import 'package:base_network/auth/base_token_renewal_helper.dart';
import 'package:base_network/helper/network_file_logger.dart';
import 'package:base_network/helper/network_log_interceptor.dart';
import 'package:base_network/mixins/auth_mixin.dart';
import 'package:base_network/mixins/misc_mixin.dart';
import 'package:base_network/mixins/network_mixin.dart';
import 'package:base_network/models/api_enums.dart';
import 'package:base_network/models/api_error.dart';
import 'package:base_network/models/network_interceptor_model.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

class _FakePathProvider extends PathProviderPlatform {
  _FakePathProvider(this.basePath);

  final String basePath;

  @override
  Future<String?> getApplicationDocumentsPath() async => basePath;
}

class _TrackingRequestHandler extends RequestInterceptorHandler {
  bool forwarded = false;

  @override
  void next(RequestOptions requestOptions) {
    forwarded = true;
  }
}

class _TrackingErrorHandler extends ErrorInterceptorHandler {
  bool forwarded = false;

  @override
  void next(DioException error) {
    forwarded = true;
  }
}

class _AuthHarness with AuthMixin {
  @override
  String get accessToken => 'token';

  @override
  Future<bool> newTokenFound(UnauthorizedException failure) async => true;
}

class _MiscHarness with MiscMixin {
  @override
  Object get noInternetException => 'offline';

  @override
  void handleFallbackUrl(Uri uri) {}

  @override
  void onErrorOccurred(DioException e, Object? request) {}

  @override
  void onRequestSubmit() {}

  @override
  bool shouldFireUnAuthorized(String endUrl) => true;
}

class _NetworkHarness with NetworkMixin {
  @override
  Future<bool> get checkConnectivity async => true;
}

class _TokenManagerHarness extends BaseTokenManager {
  _TokenManagerHarness({
    required this.renew,
    required this.silent,
    required this.tokenValid,
  });

  final Future<String> Function() renew;
  final Future<SilentLoginStatus> Function(bool) silent;
  final bool tokenValid;
  final bool refreshNeeded = false;
  int renewCalls = 0;
  int silentCalls = 0;
  int failureCalls = 0;
  final List<String> logs = [];

  @override
  Future<SilentLoginStatus> callSilentLogin(bool isForce) {
    silentCalls++;
    return silent(isForce);
  }

  @override
  void handleSilentLoginFailure() {
    failureCalls++;
  }

  @override
  bool get isTokenValid => tokenValid;

  @override
  Future<String> renewToken() {
    renewCalls++;
    return renew();
  }

  @override
  bool get shouldCallRefreshToken => refreshNeeded;

  @override
  void writeLogs(String title, String message) {
    logs.add('$title:$message');
  }
}

void main() {
  late Directory tempDir;
  late Directory logDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('base_network_test_');
    logDir = Directory('${tempDir.path}/logs')..createSync(recursive: true);
    PathProviderPlatform.instance = _FakePathProvider(logDir.path);
  });

  tearDownAll(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('mixins', () {
    test('auth mixin tracks and consumes 401 urls', () {
      final auth = _AuthHarness();
      final uri = Uri.parse('https://host/root/api/Login/Token');

      expect(auth.shouldReplaceToken(uri), isFalse);
      auth.add401Url('Login/Token');
      expect(auth.shouldReplaceToken(uri), isTrue);
      auth.reduce401Url(uri);
      expect(auth.shouldReplaceToken(uri), isFalse);
    });

    test('misc mixin stringifies requests', () {
      final misc = _MiscHarness();

      expect(misc.getRequest('abc'), 'abc');
      expect(misc.getRequest({'a': 1}), '{a: 1}');
    });

    test('network mixin stores adapters and falls back', () {
      final network = _NetworkHarness();

      final adapter = network.getHttpAdapter('example.com');
      expect(adapter, isNotNull);

      network.addEntryInMapWithIoAdapter('example.com');
      expect(network.getHttpAdapter('example.com'), isNotNull);
      expect(network.ioHttpAdapter, isNotNull);
      expect(network.getHttp2Adapter, isNotNull);
    });
  });

  group('base token manager', () {
    test('deduplicates concurrent token renewal calls', () async {
      final completer = Completer<String>();
      final manager = _TokenManagerHarness(
        renew: () => completer.future,
        silent: (_) async => SilentLoginStatus.failed,
        tokenValid: true,
      );

      final future1 = manager.newAccessToken();
      final future2 = manager.newAccessToken();
      completer.complete('new-token');

      expect(await future1, isTrue);
      expect(await future2, isTrue);
      expect(manager.renewCalls, 1);
    });

    test('falls back to silent login on renew 401 style failure', () async {
      final manager = _TokenManagerHarness(
        renew: () async => throw const ApiFailure('fail', 401),
        silent: (_) async => SilentLoginStatus.success,
        tokenValid: false,
      );

      expect(await manager.newAccessToken(), isTrue);
      expect(manager.silentCalls, 1);
    });

    test('refreshTokenIfNeeded triggers silent login when needed', () async {
      final manager = _TokenManagerHarness(
        renew: () async => 'ok',
        silent: (_) async => SilentLoginStatus.failed,
        tokenValid: false,
      );

      manager.refreshTokenIfNeeded();
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(manager.silentCalls, 1);
      expect(manager.failureCalls, 1);
    });
  });

  group('file logger and network logger', () {
    test('file logger writes, reads and clears logs', () async {
      final logger = FileLogger();

      await logger.writeLog('hello', level: 'INFO');
      await logger.writeLog('world', level: 'ERROR');

      final logs = await logger.readLogs(maxLines: 10);
      final path = await logger.currentLogPath;

      expect(logs.join('\n'), contains('hello'));
      expect(logs.join('\n'), contains('world'));
      expect(path, contains('network_log'));

      await logger.clearLogs();
      expect(await logger.readLogs(maxLines: 10), isEmpty);
    });

    test('network logger captures response and error logs', () async {
      final interceptor = NetworkLoggerInterceptor();
      interceptor.clearLogs();

      final requestOptions = RequestOptions(
        path: 'https://example.com/api?q=1',
        method: 'GET',
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'X-Api-Version': '1.0',
          'User-Agent': 'agent',
          'Authorization': 'Bearer token',
        },
      );

      final requestHandler = _TrackingRequestHandler();
      interceptor.onRequest(requestOptions, requestHandler);
      interceptor.onResponse(
        Response(
          requestOptions: requestOptions,
          headers: Headers.fromMap({'content-length': ['3']}),
          statusCode: 200,
          statusMessage: 'OK',
          data: 'abc',
        ),
        ResponseInterceptorHandler(),
      );

      final errorHandler = _TrackingErrorHandler();
      interceptor.onError(
        DioException(
          requestOptions: requestOptions,
          response: Response(
            requestOptions: requestOptions,
            headers: Headers.fromMap({'h': ['v']}),
            statusCode: 500,
            statusMessage: 'ERR',
            data: 'error',
          ),
          type: DioExceptionType.badResponse,
        ),
        errorHandler,
      );

      expect(interceptor.getQueryParamsFromUrl('https://example.com/a?x=1'), {'x': '1'});
      expect(interceptor.networkLogs.length, 2);
      expect(interceptor.networkLogs.first.responseStatusCode, '200');
      expect(requestHandler.forwarded, isTrue);
      expect(errorHandler.forwarded, isTrue);

      interceptor.clearLogs();
      expect(interceptor.networkLogs, isEmpty);
    });
  });

  test('network interceptor response model serializes to json', () {
    final model = IntercepterResponseModel(
      createdAt: 'now',
      responseHeader: 'h',
      responseStatusCode: '200',
      responseStatusMessage: 'OK',
      responseSize: '10B',
      requestHashCode: '123',
      method: 'GET',
      origin: 'https://example.com',
      query: '/a',
      queryParam: '{x: 1}',
    );

    final json = model.toJson();

    expect(json['createdAt'], 'now');
    expect(json['method'], 'GET');
    expect(json['query'], '/a');
    expect(json['responseStatusCode'], '200');
  });
}
