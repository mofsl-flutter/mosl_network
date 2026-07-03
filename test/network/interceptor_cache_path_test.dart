import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mosl_network/network/dio_cache_manager.dart';
import 'package:mosl_network/network/helper/api_header_builder.dart';
import 'package:mosl_network/network/helper/preferences.dart';
import 'package:mosl_network/network/interceptors/dio_api_interceptor.dart';
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
  void next(RequestOptions options) {
    forwarded = true;
  }
}

void main() {
  late Directory tempDir;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await SharedPreferencesProvider.init();
    Preferences.init(
      token: 'token',
      userAgent: 'agent',
      refreshToken: 'refresh',
    );
    tempDir = await Directory.systemTemp.createTemp('mosl_interceptor_');
    final cacheDir = Directory('${tempDir.path}/cache')
      ..createSync(recursive: true);
    PathProviderPlatform.instance = _FakePathProvider(cacheDir.path);
    await CacheManager().init();
  });

  tearDownAll(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('ApiInterceptor — cache callback path', () {
    test('onRequest with non-null cacheCallback invokes cache lookup (cache miss)', () async {
      final interceptor = ApiInterceptor();
      bool callbackInvoked = false;

      interceptor.setHeaders(
        JsonApiHeader(
          xApiKey: 'key',
          xApiVersion: '1.0',
          userAgent: 'agent',
          isTokenRequired: false,
          cacheCallback: (response) {
            callbackInvoked = true;
          },
        ),
      );

      final requestOptions = RequestOptions(
        path: 'https://example.com/api/cache-test',
      );
      final handler = _TrackingRequestHandler();

      // Execute — cache entry does not exist so callback will not be called
      // but the code path (lines 29-31) will be exercised
      interceptor.onRequest(requestOptions, handler);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(handler.forwarded, isTrue);
      // cacheData is null (no cache entry), so callbackInvoked stays false
      expect(callbackInvoked, isFalse);
    });

    test('onRequest with null cacheCallback skips cache block', () async {
      final interceptor = ApiInterceptor();
      interceptor.setHeaders(
        const JsonApiHeader(
          xApiKey: null,
          xApiVersion: '2.0',
          userAgent: 'agent',
          isTokenRequired: false,
          cacheCallback: null,
        ),
      );

      final requestOptions = RequestOptions(path: 'https://example.com/api/no-cache');
      final handler = _TrackingRequestHandler();

      interceptor.onRequest(requestOptions, handler);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(handler.forwarded, isTrue);
    });
  });
}
