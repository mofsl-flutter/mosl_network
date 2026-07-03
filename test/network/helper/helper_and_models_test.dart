import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mosl_network/network/helper/api_header_builder.dart';
import 'package:mosl_network/network/helper/constants.dart';
import 'package:mosl_network/network/helper/mutual_fund_api_request_params.dart';
import 'package:mosl_network/network/helper/preferences.dart';
import 'package:mosl_network/network/helper/url_paths.dart';
import 'package:mosl_network/network/models/fund_details_model.dart';
import 'package:mosl_network/network/models/json_message_response.dart';
import 'package:mosl_network/network/models/story_banner_model.dart';
import 'package:mosl_network/shared_preference/shared_preferences_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await SharedPreferencesProvider.init();
    Preferences.init(
      token: 'access-token',
      userAgent: 'test-agent',
      refreshToken: 'refresh-token',
    );
  });

  group('constants', () {
    test('network constants and urls are stable', () {
      expect(Constants.networkTimeOut, 20);
      expect(Constants.apiV4_3, '4.3');
      expect(Constants.contentTypeProtobuf, 'application/x-protobuf');
      expect(Constants.json, 'application/json');
      expect(riseBaseUrl, startsWith('https://'));
      expect(traderBaseUrl, contains('TradingApiV2'));
      expect(mPinLoginUrl, contains('riseapp.in'));
    });

    test('mutual fund request params expose expected keys', () {
      expect(MutualFundRequestParams.currentPageNumber, 'currentPageNumber');
      expect(MutualFundRequestParams.pageSize, 'pageSize');
      expect(MutualFundRequestParams.type, 'type');
      expect(MutualFundRequestParams.getDataByType, 'trans_vr_fund_details');
    });
  });

  group('headers', () {
    test('proto header includes auth and version', () {
      const header = ProtoApiHeader(
        xApiVersion: '2.1',
        userAgent: 'agent',
        isTokenRequired: true,
      );

      expect(header.toJson['Authorization'], 'Bearer access-token');
      expect(header.toJson['X-Api-Version'], '2.1');
      expect(header.toJson['User-Agent'], 'agent');
      expect(header.toJson['Content-Type'], Constants.contentTypeProtobuf);
    });

    test('json header omits auth when token is not required', () {
      const header = JsonApiHeader(
        xApiKey: 'key',
        xApiVersion: '3.0',
        userAgent: 'agent',
        isTokenRequired: false,
      );

      expect(header.toJson['XApiKey'], 'key');
      expect(header.toJson.containsKey('Authorization'), isFalse);
      expect(header.toJson['Content-Type'], Constants.json);
    });
  });

  group('json responses', () {
    test('api status parses bool and string values', () {
      expect(ApiStatus.fromStatus(true).isSuccess, isTrue);
      expect(ApiStatus.fromStatus('Failure').isFailure, isTrue);
      expect(() => ApiStatus.fromStatus('weird'), throwsA(isA<FlutterError>()));
    });

    test('message response reads nested string payload', () {
      final response = MessageResponse();

      response.fromJson({
        'status': 'Success',
        'message': 'ok',
        'data': {'message': 'nested-message'},
      });

      expect(response.status, isTrue);
      expect(response.message, 'ok');
      expect(response.dataMessage, 'nested-message');
    });

    test('aws response mirrors outer message', () {
      final response = AwsMessageResponse();

      response.fromJson({'status': true, 'message': 'uploaded'});

      expect(response.status, isTrue);
      expect(response.dataMessage, 'uploaded');
    });

    test('json api error maps categories and equality', () {
      final error = JsonApiError.fromJson({
        'errorMessage': 'No data',
        'localisedErrorMessage': 'No data',
        'errorCategory': 'NoData',
        'errorCode': 404,
        'identifier': 'NO_DATA',
      });

      expect(error.errorCategoryValue.isNoData, isTrue);
      expect(error.toJson['identifier'], 'NO_DATA');
      expect(
        error,
        JsonApiError.fromJson({
          'errorMessage': 'x',
          'localisedErrorMessage': 'x',
          'errorCategory': 'NoData',
          'errorCode': 404,
          'identifier': null,
        }),
      );
    });
  });

  group('models', () {
    test('story banner initial model can parse empty payload', () {
      final model = StoryBannerModel.initial();

      model.fromJson({
        'status': 'Success',
        'message': 'ok',
        'data': <Map<String, dynamic>>[],
      });

      expect(model.status, isTrue);
      expect(model.data, isEmpty);
      expect(model.toJson['data'], isEmpty);
    });

    test('scheme details request json uses expected defaults', () {
      final json = SchemeDetailsModel.requestJson('abc');

      expect(json[MutualFundRequestParams.currentPageNumber], 1);
      expect(json[MutualFundRequestParams.pageSize], 3);
      expect(json[MutualFundRequestParams.id], 'abc');
      expect(json[MutualFundRequestParams.type], MutualFundRequestParams.getDataByType);
    });

    test('scheme details initial model can parse empty list', () {
      final model = SchemeDetailsModel.initial();

      model.fromJson({
        'status': true,
        'message': 'ok',
        'data': <Map<String, dynamic>>[],
      });

      expect(model.status, isTrue);
      expect(model.data, isEmpty);
      expect(model.toJson['data'], isEmpty);
    });
  });
}
