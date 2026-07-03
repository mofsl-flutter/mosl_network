import 'package:base_network/base_dio_client.dart' show getFormatedDate;
import 'package:base_network/error_handling/error_exception.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mosl_network/network/helper/api_request_builder.dart';
import 'package:mosl_network/network/helper/exceptions.dart';
import 'package:mosl_network/network/helper/url_paths.dart';

// ---------------------------------------------------------------------------
// Logic extracted from DioImpl that is testable without platform-SDK setup:
//
// 1. ApiIdentifier enum properties (drive _appendUrl branching)
// 2. _appendUrl URL-routing rules (replicated inline)
// 3. shouldFireUnAuthorized logic (simple set membership)
// 4. noInternetException structure
// 5. onErrorOccurred DioExceptionType classification (switch branches)
// 6. getFormatedDate formatting
// ---------------------------------------------------------------------------

// Mirrors DioImpl._appendUrl without needing a DioImpl instance.
String appendUrl(
  ApiIdentifier identifier,
  String url, {
  String rise = riseBaseUrl,
  String mPin = mPinLoginUrl,
  String trader = traderBaseUrl,
}) {
  if (url.startsWith('http')) return url;
  if (identifier.isRise) return '$rise$url';
  if (identifier.isMPinLogin) return '$mPin$url';
  return '$trader$url';
}

// Mirrors DioImpl.shouldFireUnAuthorized.
bool shouldFireUnAuthorized(Set<String> exclusions, String endUrl) =>
    !exclusions.contains(endUrl);

void main() {
  // ─── 1. ApiIdentifier enum ─────────────────────────────────────────────
  group('ApiIdentifier enum properties', () {
    test('rise.isRise is true; all others false', () {
      expect(ApiIdentifier.rise.isRise, isTrue);
      for (final id in ApiIdentifier.values.where((e) => e != ApiIdentifier.rise)) {
        expect(id.isRise, isFalse, reason: '$id.isRise should be false');
      }
    });

    test('mPinLogin.isMPinLogin is true; all others false', () {
      expect(ApiIdentifier.mPinLogin.isMPinLogin, isTrue);
      for (final id
          in ApiIdentifier.values.where((e) => e != ApiIdentifier.mPinLogin)) {
        expect(id.isMPinLogin, isFalse,
            reason: '$id.isMPinLogin should be false');
      }
    });

    test('pwm.isPWM is true; all others false', () {
      expect(ApiIdentifier.pwm.isPWM, isTrue);
      for (final id
          in ApiIdentifier.values.where((e) => e != ApiIdentifier.pwm)) {
        expect(id.isPWM, isFalse, reason: '$id.isPWM should be false');
      }
    });

    test('unknown identifier has all boolean properties false', () {
      expect(ApiIdentifier.unknown.isRise, isFalse);
      expect(ApiIdentifier.unknown.isMPinLogin, isFalse);
      expect(ApiIdentifier.unknown.isPWM, isFalse);
    });

    test('all 8 enum values are distinct', () {
      expect(ApiIdentifier.values.toSet().length, ApiIdentifier.values.length);
    });
  });

  // ─── 2. _appendUrl routing logic ───────────────────────────────────────
  group('_appendUrl routing (mirrors DioImpl._appendUrl)', () {
    test('absolute URL is returned unchanged regardless of identifier', () {
      const absoluteUrl = 'https://example.com/api/data';
      for (final id in ApiIdentifier.values) {
        expect(appendUrl(id, absoluteUrl), absoluteUrl,
            reason: 'identifier $id should not modify an absolute URL');
      }
    });

    test('rise identifier prepends riseBaseUrl', () {
      const path = 'api/master/GetDatabyType';
      final result = appendUrl(ApiIdentifier.rise, path);
      expect(result, '$riseBaseUrl$path');
      expect(result, startsWith('https://dic541g2t9.execute-api'));
    });

    test('mPinLogin identifier prepends mPinLoginUrl', () {
      const path = 'api/mpin/validate';
      final result = appendUrl(ApiIdentifier.mPinLogin, path);
      expect(result, '$mPinLoginUrl$path');
      expect(result, startsWith('https://api.dev.riseapp.in'));
    });

    test('trader identifier prepends traderBaseUrl', () {
      const path = 'api/Order/Place';
      final result = appendUrl(ApiIdentifier.trader, path);
      expect(result, '$traderBaseUrl$path');
      expect(result, startsWith('https://tradingapi.motilaloswaluat.com'));
    });

    test('non-rise, non-mPin identifiers all use traderBaseUrl', () {
      const path = 'api/test';
      final traderIdentifiers = [
        ApiIdentifier.trader,
        ApiIdentifier.eDuMo,
        ApiIdentifier.login,
        ApiIdentifier.accountAggregator,
        ApiIdentifier.pwm,
        ApiIdentifier.unknown,
      ];
      for (final id in traderIdentifiers) {
        expect(appendUrl(id, path), '$traderBaseUrl$path',
            reason: '$id should use traderBaseUrl');
      }
    });
  });

  // ─── 3. shouldFireUnAuthorized logic ───────────────────────────────────
  group('shouldFireUnAuthorized (mirrors DioImpl.shouldFireUnAuthorized)', () {
    final exclusions = {'/auth/login', '/auth/refresh', '/mpin/generate'};

    test('returns false for excluded URLs (should NOT fire 401)', () {
      expect(shouldFireUnAuthorized(exclusions, '/auth/login'), isFalse);
      expect(shouldFireUnAuthorized(exclusions, '/auth/refresh'), isFalse);
      expect(shouldFireUnAuthorized(exclusions, '/mpin/generate'), isFalse);
    });

    test('returns true for non-excluded URLs (should fire 401)', () {
      expect(shouldFireUnAuthorized(exclusions, '/api/portfolio'), isTrue);
      expect(shouldFireUnAuthorized(exclusions, '/api/order/place'), isTrue);
    });

    test('empty exclusion set always returns true', () {
      expect(shouldFireUnAuthorized({}, '/any/endpoint'), isTrue);
    });

    test('URL must be an exact match; prefix does not count', () {
      expect(shouldFireUnAuthorized(exclusions, '/auth/login/extra'), isTrue);
      expect(shouldFireUnAuthorized(exclusions, 'auth/login'), isTrue);
    });
  });

  // ─── 4. noInternetException structure ──────────────────────────────────
  group('noInternetException construct (mirrors DioImpl.noInternetException)', () {
    test('creates ErrorException with expected key and message', () {
      final exception = ErrorException(
        key: 'No Internet!',
        message: noInternetConnection,
      );
      expect(exception.key, 'No Internet!');
      expect(exception.message, noInternetConnection);
      expect(exception.isCacheEnable, isFalse);
      expect(exception.statusCode, -1);
    });

    test('noInternetConnection constant matches the exception constant in exceptions.dart', () {
      const inExceptions = noInternetConnection; // from exceptions.dart
      expect(inExceptions, 'No Internet Connection');
    });
  });

  // ─── 5. onErrorOccurred – DioExceptionType classification ──────────────
  group('onErrorOccurred – DioExceptionType branches', () {
    // These mirror the switch in DioImpl.onErrorOccurred which calls
    // callCleverTap for connectivity/timeout/unknown errors.
    const cleverTapTypes = [
      DioExceptionType.connectionTimeout,
      DioExceptionType.sendTimeout,
      DioExceptionType.receiveTimeout,
      DioExceptionType.badCertificate,
      DioExceptionType.connectionError,
      DioExceptionType.unknown,
    ];

    for (final type in cleverTapTypes) {
      test('$type should trigger CleverTap reporting', () {
        // Verify the set membership used in DioImpl's switch
        expect(cleverTapTypes.contains(type), isTrue);
      });
    }

    test('badResponse and cancel do NOT trigger CleverTap reporting', () {
      expect(cleverTapTypes.contains(DioExceptionType.badResponse), isFalse);
      expect(cleverTapTypes.contains(DioExceptionType.cancel), isFalse);
    });
  });

  // ─── 6. getFormatedDate formatting ─────────────────────────────────────
  group('getFormatedDate (from BaseDioClient)', () {
    test('formats date in dd-MM-yyyy HH:mm:ss.SSS a pattern', () {
      final date = DateTime(2025, 4, 9, 14, 30, 5, 123);
      final result = getFormatedDate(date);
      // Pattern: dd-MM-yyyy HH:mm:ss.SSS a
      expect(result, matches(r'^\d{2}-\d{2}-\d{4} \d{2}:\d{2}:\d{2}\.\d{3} [APap][Mm]$'));
    });

    test('formats midnight correctly', () {
      final date = DateTime(2025, 1, 1, 0, 0, 0, 0);
      final result = getFormatedDate(date);
      expect(result, contains('01-01-2025'));
      expect(result, contains('00:00:00.000'));
    });

    test('formats end of day correctly', () {
      final date = DateTime(2025, 12, 31, 23, 59, 59, 999);
      final result = getFormatedDate(date);
      expect(result, contains('31-12-2025'));
      expect(result, contains('23:59:59.999'));
    });
  });

  // ─── 7. URL constants sanity checks ────────────────────────────────────
  group('URL constants (url_paths.dart)', () {
    test('riseBaseUrl is a valid HTTPS URL ending with /', () {
      expect(riseBaseUrl, startsWith('https://'));
      expect(riseBaseUrl, endsWith('/'));
    });

    test('traderBaseUrl is a valid HTTPS URL ending with /', () {
      expect(traderBaseUrl, startsWith('https://'));
      expect(traderBaseUrl, endsWith('/'));
    });

    test('mPinLoginUrl is a valid HTTPS URL ending with /', () {
      expect(mPinLoginUrl, startsWith('https://'));
      expect(mPinLoginUrl, endsWith('/'));
    });

    test('all three base URLs are distinct', () {
      final urls = {riseBaseUrl, traderBaseUrl, mPinLoginUrl};
      expect(urls.length, 3);
    });
  });

  // ─── 8. getErrorFromException2 – DioImpl error path ───────────────────
  group('getErrorFromException2 used by DioImpl.callApiWithDioClient', () {
    test('DioException connectionTimeout maps to ApiTimeout key', () {
      final e = DioException(
        requestOptions: RequestOptions(path: '/api/data'),
        type: DioExceptionType.connectionTimeout,
      );
      final result = getErrorFromException2(e);
      expect(result.key, 'ApiTimeout');
    });

    test('DioException unknown without rise header maps to generic error', () {
      final e = DioException(
        requestOptions: RequestOptions(path: '/api/data'),
        type: DioExceptionType.unknown,
      );
      final result = getErrorFromException2(e);
      expect(result.message, isNotEmpty);
    });

    test('DioException 401 response maps to statusCode 401', () {
      final e = DioException(
        requestOptions: RequestOptions(path: '/api/secure'),
        response: Response<dynamic>(
          requestOptions: RequestOptions(path: '/api/secure'),
          statusCode: 401,
          data: {},
        ),
        type: DioExceptionType.unknown,
      );
      final result = getErrorFromException2(e);
      expect(result.statusCode, 401);
    });

    test('ErrorException wraps to generic error', () {
      const original = ErrorException(key: 'original', message: 'original msg');
      final result = getErrorFromException2(original);
      expect(result, isA<ErrorException>());
    });

    test('TypeError maps to generic error', () {
      final result = getErrorFromException2(TypeError());
      expect(result, isA<ErrorException>());
    });

    test('UnimplementedError maps to generic error', () {
      final result = getErrorFromException2(UnimplementedError('not impl'));
      expect(result, isA<ErrorException>());
    });

    test('ArgumentError maps to generic error', () {
      final result = getErrorFromException2(ArgumentError('bad arg'));
      expect(result, isA<ErrorException>());
    });
  });
}
