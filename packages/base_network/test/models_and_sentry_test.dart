import 'dart:convert';

import 'package:base_network/base_dio_client.dart';
import 'package:base_network/helper/misc.dart';
import 'package:base_network/models/api_constants.dart';
import 'package:base_network/models/api_enums.dart';
import 'package:base_network/models/api_error.dart';
import 'package:base_network/models/base_options.dart';
import 'package:base_network/models/network_interceptor_model.dart';
import 'package:base_network/sentry_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart' show SpanStatus;

// ---------------------------------------------------------------------------
// JWT helper
// ---------------------------------------------------------------------------
String _buildToken(int exp, {int? iat}) {
  final header = base64Url.encode(utf8.encode('{"alg":"none"}'));
  final payload = base64Url.encode(
    utf8.encode(jsonEncode({'exp': exp, 'iat': iat ?? exp - 200})),
  );
  return '$header.$payload.sig';
}

void main() {
  // -------------------------------------------------------------------------
  // ApiVersion.number — all branches
  // -------------------------------------------------------------------------
  group('ApiVersion.number', () {
    test('covers all declared versions', () {
      expect(ApiVersion.v1_0.number, '1.0');
      expect(ApiVersion.v1_1.number, '1.1');
      expect(ApiVersion.v1_2.number, '1.2');
      expect(ApiVersion.v2_0.number, '2.0');
      expect(ApiVersion.v3_0.number, '3.0');
    });
  });

  // -------------------------------------------------------------------------
  // HttpMethodExtension.toFireBaseHttpMethod
  // -------------------------------------------------------------------------
  group('HttpMethodExtension', () {
    test('get and download map to Firebase Get', () {
      expect(HttpMethod.get.toFireBaseHttpMethod.name, 'Get');
      expect(HttpMethod.download.toFireBaseHttpMethod.name, 'Get');
    });

    test('post and upload map to Firebase Post', () {
      expect(HttpMethod.post.toFireBaseHttpMethod.name, 'Post');
      expect(HttpMethod.upload.toFireBaseHttpMethod.name, 'Post');
    });
  });

  // -------------------------------------------------------------------------
  // SilentLoginStatus enum values
  // -------------------------------------------------------------------------
  group('SilentLoginStatus', () {
    test('all values are distinct', () {
      const values = SilentLoginStatus.values;
      expect(values.toSet().length, values.length);
      expect(values, contains(SilentLoginStatus.success));
      expect(values, contains(SilentLoginStatus.failed));
      expect(values, contains(SilentLoginStatus.logout));
      expect(values, contains(SilentLoginStatus.notCalled));
    });
  });

  // -------------------------------------------------------------------------
  // ApiConstants
  // -------------------------------------------------------------------------
  group('ApiConstants', () {
    test('timeoutDuration is 15 seconds', () {
      expect(ApiConstants.timeoutDuration, const Duration(seconds: 15));
    });

    test('challenge strings are stable', () {
      expect(ApiConstants.bearerChallenge, 'Bearer');
      expect(ApiConstants.reLoginRequiredChallenge, 'ReLoginRequired');
      expect(ApiConstants.nonFrequentUserReLoginRequired, 'ReLoginRequired');
    });
  });

  // -------------------------------------------------------------------------
  // ApiCallError subclasses — toString and equality
  // -------------------------------------------------------------------------
  group('ApiCallError subclasses', () {
    test('ApiTimeout toString returns "ApiTimeout"', () {
      expect(ApiCallError.timeout().toString(), 'ApiTimeout');
    });

    test('ApiFailure equality and hashCode', () {
      const a = ApiFailure('err', 500);
      const b = ApiFailure('err', 500);
      const c = ApiFailure('err', 400);

      expect(a, b);
      expect(a == c, isFalse);
      expect(a.hashCode, b.hashCode);
      expect(a.hashCode == c.hashCode, isFalse);
      expect(a.toString(), 'err');
    });

    test('SessionExpired toString contains endUrl', () {
      final s = SessionExpired('Login/Token', 'challenge');
      expect(s.toString(), contains('Login/Token'));
      expect(s.toString(), contains('challenge'));
    });

    test('UnauthorizedCallFailure toString includes api and challenge', () {
      final u = UnauthorizedCallFailure('Login/Token', 'Bearer abc');
      expect(u.toString(), contains('Login/Token'));
      expect(u.toString(), contains('Bearer abc'));
    });

    test('NonFrequentSessionExpiredCallFailure toString has endUrl', () {
      final n = NonFrequentSessionExpiredCallFailure('path', 'challenge', 'session-msg');
      expect(n.toString(), contains('path'));
      expect(n.message, 'session-msg');
    });

    test('NonFrequentUserSessionOut toString contains endUrl', () {
      final n = NonFrequentUserSessionOut('path', 'some message');
      expect(n.toString(), contains('path'));
      expect(n.message, 'some message');
    });

    test('Http2Retry is an Exception', () {
      expect(Http2Retry(), isA<Exception>());
    });

    test('DioRequestCancelledException equality and hashCode', () {
      const a = DioRequestCancelledException();
      const b = DioRequestCancelledException();
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a.toString(), 'DioRequestCancelledException');
      // operator< always returns false
      expect(a < b, isFalse);
    });

    test('UnauthorizedException wraps UnauthorizedCallFailure', () {
      final u = UnauthorizedCallFailure('Login/Token', 'challenge');
      final e = UnauthorizedException(u);
      expect(e.data, same(u));
    });

    test('ApiCallFailure toString shows status code', () {
      final resp = Response<dynamic>(
        requestOptions: RequestOptions(path: '/x'),
        statusCode: 404,
      );
      expect(ApiCallFailure(resp).toString(), contains('404'));
    });

    test('ApiCallFailureDIO toString shows status code', () {
      final resp = Response<dynamic>(
        requestOptions: RequestOptions(path: '/x'),
        statusCode: 500,
      );
      expect(ApiCallFailureDIO(resp).toString(), contains('500'));
    });

    test('BaseUrlFailedException stores message', () {
      final e = BaseUrlFailedException('https://host.example.com');
      expect(e.message, 'https://host.example.com');
    });
  });

  // -------------------------------------------------------------------------
  // ApiCallError.callFailureDIO — various challenge combinations
  // -------------------------------------------------------------------------
  group('ApiCallError.callFailureDIO challenge paths', () {
    test('bearer challenge without reLoginRequired returns UnauthorizedCallFailure', () {
      final response = Response<dynamic>(
        requestOptions: RequestOptions(path: '/x'),
        statusCode: 401,
        headers: Headers.fromMap({
          'www-authenticate': ['Bearer realm="test"'],
        }),
      );
      final error = ApiCallError.callFailureDIO(
        response,
        Uri.parse('https://host.example.com/root/api/Login/Token'),
      );
      expect(error, isA<UnauthorizedCallFailure>());
    });

    test('reLoginRequired challenge without session out returns SessionExpired', () {
      final response = Response<dynamic>(
        requestOptions: RequestOptions(path: '/x'),
        statusCode: 401,
        headers: Headers.fromMap({
          'www-authenticate': ['Bearer realm="test", ReLoginRequired'],
        }),
      );
      final error = ApiCallError.callFailureDIO(
        response,
        Uri.parse('https://host.example.com/root/api/Login/Token'),
      );
      expect(error, isA<SessionExpired>());
    });

    test('reLoginRequired with WWW-Authenticate-SessionOutMsg returns NonFrequentSessionExpiredCallFailure', () {
      final response = Response<dynamic>(
        requestOptions: RequestOptions(path: '/x'),
        statusCode: 401,
        headers: Headers.fromMap({
          'www-authenticate': ['Bearer realm="test", ReLoginRequired'],
          'www-authenticate-sessionoutmsg': ['You have been inactive'],
        }),
      );
      final error = ApiCallError.callFailureDIO(
        response,
        Uri.parse('https://host.example.com/root/api/Login/Token'),
      );
      expect(error, isA<NonFrequentSessionExpiredCallFailure>());
    });

    test('401 status without headers returns UnauthorizedCallFailure', () {
      final response = Response<dynamic>(
        requestOptions: RequestOptions(path: '/x'),
        statusCode: 401,
      );
      final error = ApiCallError.callFailureDIO(
        response,
        Uri.parse('https://host.example.com/root/api/Login/Token'),
      );
      expect(error, isA<UnauthorizedCallFailure>());
    });

    test('non-401 without challenge returns ApiCallFailureDIO', () {
      final response = Response<dynamic>(
        requestOptions: RequestOptions(path: '/x'),
        statusCode: 403,
      );
      final error = ApiCallError.callFailureDIO(
        response,
        Uri.parse('https://host.example.com/root/api/Login/Token'),
      );
      expect(error, isA<ApiCallFailureDIO>());
    });
  });

  // -------------------------------------------------------------------------
  // misc.dart helpers
  // -------------------------------------------------------------------------
  group('misc helpers', () {
    test('getTimeStampInSeconds returns reasonable epoch', () {
      final ts = getTimeStampInSeconds();
      // Should be in the range of a year 2024+ Unix timestamp
      expect(ts, greaterThan(1700000000));
    });

    test('getJWTTokenRemainingValidity returns -1 for missing exp/iat', () {
      final header = base64Url.encode(utf8.encode('{"alg":"none"}'));
      final payload = base64Url.encode(utf8.encode('{"sub":"user"}'));
      final token = '$header.$payload.sig';

      expect(getJWTTokenRemainingValidity(token, isAccessToken: true), -1);
    });

    test('getJWTTokenRemainingValidity is positive for a far-future token', () {
      final now = getTimeStampInSeconds();
      final token = _buildToken(now + 3600);
      // Should be > 0 (far future minus buffer time)
      expect(getJWTTokenRemainingValidity(token, isAccessToken: true), greaterThan(0));
    });

    test('isRefreshTokenValid returns false for malformed token', () {
      expect(isRefreshTokenValid('not.valid'), isFalse);
      expect(isRefreshTokenValid(''), isFalse);
    });
  });

  // -------------------------------------------------------------------------
  // BaseDioOptions — responseType override
  // -------------------------------------------------------------------------
  group('BaseDioOptions', () {
    test('responseType override is applied when provided', () {
      final options = BaseDioOptions<Object>(
        url: '/test',
        responseType: ResponseType.json,
      );
      expect(options.baseOptions.responseType, ResponseType.json);
    });

    test('default responseType is bytes when not overridden', () {
      final options = BaseDioOptions<Object>(url: '/test');
      expect(options.baseOptions.responseType, ResponseType.bytes);
    });

    test('download request is valid with savePath', () {
      final options = BaseDioOptions<Object>(
        url: '/file',
        requestType: HttpMethod.download,
        savePath: '/tmp/file.pdf',
      );
      expect(options.savePath, '/tmp/file.pdf');
      expect(options.requestType, HttpMethod.download);
    });

    test('upload request is valid with FormData', () {
      final formData = FormData.fromMap({'key': 'value'});
      final options = BaseDioOptions<FormData>(
        url: '/upload',
        requestType: HttpMethod.upload,
        request: formData,
      );
      expect(options.requestType, HttpMethod.upload);
    });
  });

  // -------------------------------------------------------------------------
  // getFormatedDate
  // -------------------------------------------------------------------------
  group('getFormatedDate', () {
    test('formats date using expected pattern', () {
      final dt = DateTime(2024, 1, 15, 10, 30, 45, 123);
      final result = getFormatedDate(dt);
      expect(result, '15-01-2024 10:30:45.123 AM');
    });
  });

  // -------------------------------------------------------------------------
  // IntercepterResponseModel — null optional fields
  // -------------------------------------------------------------------------
  group('IntercepterResponseModel with nulls', () {
    test('toJson includes null optional fields as null', () {
      final model = IntercepterResponseModel(
        createdAt: 'ts',
        responseHeader: 'h',
        responseStatusCode: '200',
        responseStatusMessage: 'OK',
        responseSize: '0B',
        requestHashCode: '0',
      );
      final json = model.toJson();
      expect(json['method'], isNull);
      expect(json['origin'], isNull);
      expect(json['query'], isNull);
      expect(json['responseTime'], isNull);
      expect(json['authorization'], isNull);
    });
  });

  // -------------------------------------------------------------------------
  // SentryService — shouldStartSentry = false (safe no-op paths)
  // -------------------------------------------------------------------------
  group('SentryService with shouldStartSentry=false', () {
    late SentryService sut;

    setUp(() {
      sut = SentryService(shouldStartSentry: false);
    });

    test('addBreadcrumb is a no-op and completes', () async {
      await expectLater(
        sut.addBreadcrumb({'key': 'value'}),
        completes,
      );
    });

    test('finish is a no-op and completes', () async {
      await expectLater(sut.finish(), completes);
    });

    test('startTransaction returns null', () async {
      final span = await sut.startTransaction('name', 'op');
      expect(span, isNull);
    });

    test('captureException does not throw', () {
      expect(() => sut.captureException(Exception('test'), 500), returnsNormally);
    });

    test('setStatus does not throw', () {
      expect(() => sut.setStatus(const SpanStatus.internalError()), returnsNormally);
    });

    test('startChildTransaction does not throw', () {
      expect(
        () => sut.startChildTransaction('child', 'op'),
        returnsNormally,
      );
    });
  });
}
