import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mosl_network/network/dio_cache_manager.dart';
import 'package:mosl_network/network/helper/api_header_builder.dart';
import 'package:mosl_network/network/helper/preferences.dart';
import 'package:mosl_network/network/interceptors/dio_api_interceptor.dart';
import 'package:mosl_network/network/interceptors/loging_interceptor.dart';
import 'package:mosl_network/shared_preference/shared_preferences_provider.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakePathProvider extends PathProviderPlatform {
  _FakePathProvider(this.basePath);

  final String basePath;

  @override
  Future<String?> getTemporaryPath() async => basePath;

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

class _TrackingResponseHandler extends ResponseInterceptorHandler {
  bool forwarded = false;

  @override
  void next(Response response) {
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

void main() {
  late Directory tempDir;
  late Directory cacheDir;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await SharedPreferencesProvider.init();
    Preferences.init(
      token: 'token',
      userAgent: 'agent',
      refreshToken: 'refresh',
    );
    tempDir = await Directory.systemTemp.createTemp('mosl_test_');
    cacheDir = Directory('${tempDir.path}/cache')..createSync(recursive: true);
    PathProviderPlatform.instance = _FakePathProvider(cacheDir.path);
  });

  tearDownAll(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('CacheManager', () {
    test('splitIfPossible trims .com prefix when present', () {
      final manager = CacheManager();

      expect(
        manager.splitIfPossible('https://example.com/api/data'),
        '/api/data',
      );
      expect(manager.splitIfPossible('/api/data'), '/api/data');
    });

    test('cache options reflect forced cache flag', () async {
      final manager = CacheManager();
      await manager.init();

      final forced = manager.getCacheOptions(true, false, const Duration(hours: 1));
      final regular = manager.getCacheOptions(false, true, const Duration(hours: 1));

      expect(forced.policy.name, contains('refreshForceCache'));
      expect(forced.maxStale, const Duration(hours: 12));
      expect(regular.policy.name, contains('request'));
      expect(regular.maxStale, const Duration(hours: 1));
    });

    test('clear and delete methods are safe when cache is initialized', () async {
      final manager = CacheManager();
      await manager.init();

      await manager.delete('https://example.com/missing');
      await manager.clearCacheOnLogout();
      await manager.clearCacheOnAppUpdate();

      expect(manager.splitIfPossible('https://x.com/a'), '/a');
    });
  });

  group('ApiInterceptor', () {
    test('onRequest passes through and onError handles non-fallback errors', () async {
      final interceptor = ApiInterceptor();
      interceptor.setHeaders(
        const JsonApiHeader(
          xApiKey: 'key',
          xApiVersion: '1.0',
          userAgent: 'agent',
          isTokenRequired: false,
        ),
      );

      final requestOptions = RequestOptions(path: 'https://example.com/test');
      final requestHandler = _TrackingRequestHandler();

      interceptor.onRequest(requestOptions, requestHandler);
      expect(requestHandler.forwarded, isTrue);

      final errorHandler = _TrackingErrorHandler();

      interceptor.onError(
        DioException(
          requestOptions: RequestOptions(path: 'https://example.com/test'),
          type: DioExceptionType.badResponse,
        ),
        errorHandler,
      );

      expect(errorHandler.forwarded, isTrue);
    });
  });

  group('LoggingInterceptor', () {
    test('request response and error are forwarded', () {
      final interceptor = LoggingInterceptor(responseBody: true);

      final requestHandler = _TrackingRequestHandler();
      interceptor.onRequest(
        RequestOptions(path: '/x'),
        requestHandler,
      );

      final responseHandler = _TrackingResponseHandler();
      interceptor.onResponse(
        Response(
          requestOptions: RequestOptions(path: '/x'),
          headers: Headers.fromMap({'content-length': ['3']}),
          data: 'abc',
        ),
        responseHandler,
      );

      final errorHandler = _TrackingErrorHandler();
      interceptor.onError(
        DioException(
          requestOptions: RequestOptions(path: '/x'),
          response: Response(
            requestOptions: RequestOptions(path: '/x'),
            headers: Headers.fromMap({'h': ['v']}),
            data: 'abc',
          ),
          type: DioExceptionType.badResponse,
        ),
        errorHandler,
      );

      expect(requestHandler.forwarded, isTrue);
      expect(responseHandler.forwarded, isTrue);
      expect(errorHandler.forwarded, isTrue);
    });
  });
}
