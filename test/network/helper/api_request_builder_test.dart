import 'package:base_network/models/api_enums.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mosl_network/network/helper/api_request_builder.dart';
import 'package:mosl_network/network/helper/preferences.dart';
import 'package:mosl_network/network/models/Login/AuthRequest.pb.dart';
import 'package:mosl_network/shared_preference/shared_preferences_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await SharedPreferencesProvider.init();
    Preferences.init(
      token: 'token',
      userAgent: 'unit-test-agent',
      refreshToken: 'refresh',
    );
  });

  group('ApiRequestBuilder', () {
    test('uses bytes response type for trader APIs and serializes protobuf body', () {
      final body = GeneratePasswordRequestV2(input: 'AA020');

      final request = ApiRequestBuilder<Object>()
          .apiIdentifier(ApiIdentifier.trader)
          .apiVersion('2.1')
          .url('api/Login/GeneratePassword')
          .requestType(HttpMethod.post)
          .request(body)
          .build();

      expect(request.responseType, ResponseType.bytes);
      expect(request.requestType, HttpMethod.post);
      expect(request.request, body.writeToBuffer());
      expect(request.rawRequest, isNull);
    });

    test('uses json response type for rise APIs and copyWith only overrides url', () {
      final request = ApiRequestBuilder<Map<String, dynamic>>()
          .apiIdentifier(ApiIdentifier.rise)
          .apiKey('api-key')
          .url('master/Master/GetDatabyType')
          .requestType(HttpMethod.post)
          .request({'pageSize': 10})
          .forcedCache(true)
          .internetAvailable(false)
          .cacheAvailable(true)
          .specialToken('special-token')
          .isTokenRequired(false)
          .apiVersion('3.0')
          .build();

      final updated = request.copyWith(url: 'master/Master/GetData');

      expect(request.responseType, ResponseType.json);
      expect(updated.url, 'master/Master/GetData');
      expect(updated.request, {'pageSize': 10});
      expect(updated.apiKey, 'api-key');
      expect(updated.specialToken, 'special-token');
      expect(updated.isForcedCacheEnable, isTrue);
      expect(updated.isInternetAvailable, isFalse);
      expect(updated.isCacheAvailable, isTrue);
      expect(updated.isTokenRequired, isFalse);
    });

    test('builder preserves raw request and derived json headers', () {
      final cancelToken = CancelToken();
      final request = ApiRequestBuilder<Map<String, dynamic>>()
          .apiIdentifier(ApiIdentifier.rise)
          .url('master/path')
          .rawRequest({'raw': true})
          .request({'body': true})
          .cancelToken(cancelToken)
          .requestType(HttpMethod.post)
          .build();

      expect(request.rawRequest, {'raw': true});
      expect(request.cancelToken, same(cancelToken));
      expect(request.headers.toJson['User-Agent'], 'unit-test-agent');
      expect(request.headers.toJson['X-Api-Version'], '1.0');
    });

    test('builder uses proto headers for mPinLogin and trader identifiers', () {
      final traderRequest = ApiRequestBuilder<Object>()
          .apiIdentifier(ApiIdentifier.trader)
          .url('api/test')
          .build();
      final mPinRequest = ApiRequestBuilder<Object>()
          .apiIdentifier(ApiIdentifier.mPinLogin)
          .specialToken('special')
          .url('api/token')
          .build();

      expect(traderRequest.responseType, ResponseType.bytes);
      expect(traderRequest.headers.toJson.containsKey('XApiKey'), isFalse);
      expect(mPinRequest.headers.toJson['Authorization'], 'Bearer special');
      expect(mPinRequest.headers.toJson['Content-Type'], isNotNull);
    });
  });
}
