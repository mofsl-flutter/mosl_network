import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mosl_network/network/dio_cache_manager.dart';
import 'package:mosl_network/network/helper/api_header_builder.dart';
import 'package:mosl_network/network/helper/preferences.dart';
import 'package:mosl_network/network/helper/token_renewal.dart';
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

class _TrackingErrorHandler extends ErrorInterceptorHandler {
  bool forwarded = false;

  @override
  void next(DioException error) {
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
      token: 'test-token',
      userAgent: 'test-agent',
      refreshToken: 'refresh-token',
    );
    tempDir = await Directory.systemTemp.createTemp('mosl_misc_test_');
    final cacheDir = Directory('${tempDir.path}/cache')
      ..createSync(recursive: true);
    PathProviderPlatform.instance = _FakePathProvider(cacheDir.path);
  });

  tearDownAll(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  // -------------------------------------------------------------------------
  // SharedPreferencesProvider
  // -------------------------------------------------------------------------
  group('SharedPreferencesProvider', () {
    test('isInitiated is true after init', () {
      expect(SharedPreferencesProvider.isInitiated, isTrue);
    });

    test('instance returns the SharedPreferences singleton', () {
      final instance = SharedPreferencesProvider.instance;
      expect(instance, isNotNull);
    });

    test('calling init a second time is a no-op', () async {
      // init is already called in setUpAll; calling again should not throw
      await SharedPreferencesProvider.init();
      expect(SharedPreferencesProvider.isInitiated, isTrue);
    });
  });

  // -------------------------------------------------------------------------
  // CacheManager — coverage gaps (isExist, getActualRes)
  // -------------------------------------------------------------------------
  group('CacheManager extended', () {
    test('isExist returns false for unknown key after init', () async {
      final manager = CacheManager();
      await manager.init();

      final exists = await manager.isExist('https://example.com/api/unknown');
      expect(exists, isFalse);
    });

    test('get returns null for unknown key', () async {
      final manager = CacheManager();
      await manager.init();

      final result = await manager.get('https://example.com/api/unknown');
      expect(result, isNull);
    });

    test('getActualRes returns null for unknown key', () async {
      final manager = CacheManager();
      await manager.init();

      final result = await manager.getActualRes(
        key: 'https://example.com/api/missing',
        runtimeType: <String, dynamic>{},
      );
      expect(result, isNull);
    });

    test('getCacheOptions with connectivity false sets empty hitCacheOnErrorExcept', () async {
      final manager = CacheManager();
      await manager.init();

      final opts = manager.getCacheOptions(false, false, const Duration(hours: 2));
      // hitCacheOnErrorExcept should be empty list when checkConnectivity is false
      expect(opts.hitCacheOnErrorExcept, isEmpty);
    });

    test('getCacheOptions keyBuilder strips .com prefix', () async {
      final manager = CacheManager();
      await manager.init();

      final opts = manager.getCacheOptions(false, true, const Duration(hours: 1));
      // Test keyBuilder through a fake RequestOptions
      final key = opts.keyBuilder(RequestOptions(
        path: 'https://example.com/api/data',
      ));
      expect(key, startsWith('/'));
      expect(key, contains('/api/data'));
    });
  });

  // -------------------------------------------------------------------------
  // ApiInterceptor — onError fallback path
  // -------------------------------------------------------------------------
  group('ApiInterceptor onError', () {
    // The connection-error path tries to index fallBackSchemaHost which is
    // intentionally always empty in this implementation.
    // We verify that non-connection errors are forwarded, and that the
    // fallback map is empty by default.
    test('error with badResponse type is forwarded', () {
      final interceptor = ApiInterceptor();
      interceptor.setHeaders(
        const JsonApiHeader(
          xApiKey: null,
          xApiVersion: '1.0',
          userAgent: 'agent',
          isTokenRequired: false,
        ),
      );

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

    test('error with unknown type is forwarded', () {
      final interceptor = ApiInterceptor();
      interceptor.setHeaders(
        const JsonApiHeader(
          xApiKey: null,
          xApiVersion: '1.0',
          userAgent: 'agent',
          isTokenRequired: false,
        ),
      );

      final errorHandler = _TrackingErrorHandler();
      interceptor.onError(
        DioException(
          requestOptions: RequestOptions(path: 'https://example.com/test'),
          type: DioExceptionType.unknown,
        ),
        errorHandler,
      );

      expect(errorHandler.forwarded, isTrue);
    });

    test('fallBackSchemaHost returns empty map by default', () {
      final interceptor = ApiInterceptor();
      expect(interceptor.fallBackSchemaHost, isEmpty);
    });

    test('setHeaders updates headers field', () {
      final interceptor = ApiInterceptor();
      const header = JsonApiHeader(
        xApiKey: 'some-key',
        xApiVersion: '2.0',
        userAgent: 'my-agent',
        isTokenRequired: true,
      );
      interceptor.setHeaders(header);
      // Accessing the header through toJson to confirm it was stored
      expect(interceptor.headers.toJson['X-Api-Version'], '2.0');
    });
  });

  // -------------------------------------------------------------------------
  // TokenRenewalHelper — singleton and basic property access
  // -------------------------------------------------------------------------
  group('TokenRenewalHelper', () {
    test('singleton returns the same instance', () {
      final a = TokenRenewalHelper();
      final b = TokenRenewalHelper();
      expect(identical(a, b), isTrue);
    });

    test('shouldCallRefreshToken is always false', () {
      expect(TokenRenewalHelper().shouldCallRefreshToken, isFalse);
    });

    test('isTokenValid reflects refresh token validity', () {
      // With a valid refresh token set
      Preferences.init(
        token: 'access-token',
        userAgent: 'agent',
        refreshToken: _buildValidRefreshToken(),
      );
      expect(TokenRenewalHelper().isTokenValid, isTrue);
    });

    test('isTokenValid returns false for empty refresh token', () {
      // Delete the refresh token so getOrDefault returns empty string
      Preferences().refreshToken.delete();
      // isRefreshTokenValid('') returns false
      expect(TokenRenewalHelper().isTokenValid, isFalse);
    });
  });
}

// Builds a minimal valid JWT that expires ~30 minutes from now
String _buildValidRefreshToken() {
  final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  final exp = now + 1800; // 30 min from now — beyond tokenSyncBufferTime (60s)
  final header = base64Url.encode(utf8.encode('{"alg":"none"}'));
  final payload = base64Url.encode(utf8.encode('{"exp":$exp,"iat":${now - 100}}'));
  return '$header.$payload.sig';
}
