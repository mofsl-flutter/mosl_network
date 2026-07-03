import 'dart:convert';

import 'package:base_network/error_handling/error_constant.dart';
import 'package:base_network/error_handling/error_exception.dart';
import 'package:base_network/helper/misc.dart';
import 'package:base_network/models/api_constants.dart';
import 'package:base_network/models/api_enums.dart';
import 'package:base_network/models/api_error.dart';
import 'package:base_network/models/base_options.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

String _tokenWithExp(int exp, {int? iat}) {
  final header = base64Url.encode(utf8.encode('{"alg":"none"}'));
  final payload = base64Url.encode(
    utf8.encode(jsonEncode({'exp': exp, 'iat': iat ?? exp - 100})),
  );
  return '$header.$payload.signature';
}

void main() {
  group('api enums and constants', () {
    test('http methods map to expected names', () {
      expect(HttpMethod.get.name, 'get');
      expect(HttpMethod.download.name, 'download');
      expect(ApiVersion.v3_0.number, '3.0');
      expect(ApiConstants.timeoutDuration, const Duration(seconds: 15));
    });

    test('error constants stay stable', () {
      expect(ErrorConstant.noDataAvailable, 'No Data Available');
      expect(ErrorConstant.apiErrorSomethingWentWrong, contains('something went wrong'));
    });
  });

  group('misc jwt helpers', () {
    test('valid refresh token returns true', () {
      final now = getTimeStampInSeconds();
      final token = _tokenWithExp(now + 120);

      expect(isRefreshTokenValid(token), isTrue);
      expect(getJWTTokenRemainingValidity(token, isAccessToken: false), greaterThan(0));
    });

    test('expired or malformed refresh token returns false', () {
      final now = getTimeStampInSeconds();
      final expiredToken = _tokenWithExp(now + 10);

      expect(isRefreshTokenValid(expiredToken), isFalse);
      expect(isRefreshTokenValid('bad-token'), isFalse);
    });
  });

  group('api error mapping', () {
    test('getEndUrl extracts api suffix', () {
      final uri = Uri.parse('https://host.example.com/root/api/Login/Token');

      expect(ApiCallError.getEndUrl(uri), 'Login/Token');
    });

    test('callFailureDIO returns unauthorized for rise or 401', () {
      final response = Response(
        requestOptions: RequestOptions(path: '/x', headers: {'XApiKey': 'key'}),
        statusCode: 400,
      );

      final error = ApiCallError.callFailureDIO(
        response,
        Uri.parse('https://host.example.com/root/api/Login/Token'),
      );

      expect(error, isA<UnauthorizedCallFailure>());
    });

    test('api failure equality and request cancelled exception work', () {
      expect(const ApiFailure('oops', 1), const ApiFailure('oops', 1));
      expect(const DioRequestCancelledException().toString(), 'DioRequestCancelledException');
      expect(Http2Retry(), isA<Exception>());
    });
  });

  group('base options and errors', () {
    test('base dio options accept standard request', () {
      final options = BaseDioOptions<Map<String, dynamic>>(
        url: '/test',
        request: {'a': 1},
        requestType: HttpMethod.post,
      );

      expect(options.url, '/test');
      expect(options.requestType, HttpMethod.post);
      expect(options.baseOptions.responseType, ResponseType.bytes);
    });

    test('download and upload assertions are enforced', () {
      expect(
        () => BaseDioOptions<Object>(url: '/d', requestType: HttpMethod.download),
        throwsA(isA<AssertionError>()),
      );
      expect(
        () => BaseDioOptions<Object>(url: '/u', requestType: HttpMethod.upload, request: Object()),
        throwsA(isA<AssertionError>()),
      );
    });

    test('error exception copyWith overrides selected fields', () {
      const original = ErrorException(key: 'k', message: 'm');
      final updated = original.copyWith(statusCode: 401, actualError: 'boom');

      expect(updated.key, 'k');
      expect(updated.message, 'm');
      expect(updated.statusCode, 401);
      expect(updated.actualError, 'boom');
    });
  });
}
