import 'package:base_network/error_handling/error_constant.dart';
import 'package:base_network/error_handling/error_exception.dart';
import 'package:base_network/models/api_error.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mosl_network/network/helper/exceptions.dart';
import 'package:mosl_network/network/helper/preferences.dart';
import 'package:mosl_network/network/helper/preferences_base.dart';
import 'package:mosl_network/network/models/Base/BaseResponse.pb.dart' as base;
import 'package:mosl_network/network/models/json_message_response.dart';
import 'package:mosl_network/shared_preference/shared_preferences_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:typed_data';

class _BinaryPreferenceHarness extends BinaryPreference {
  _BinaryPreferenceHarness(String key)
      : super(SharedPreferencesProvider.instance, key);
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await SharedPreferencesProvider.init();
  });

  setUp(() async {
    await Preferences().accessToken.delete();
    await Preferences().refreshToken.delete();
    await Preferences().userAgent.delete();
    await Preferences().primaryUrlWorking.delete();
    await Preferences().currentUrlIndex.delete();
  });

  group('preferences', () {
    test('preferences init writes and reads values', () {
      Preferences.init(
        token: 'token-1',
        userAgent: 'agent-1',
        refreshToken: 'refresh-1',
      );

      expect(Preferences().accessToken.get(), 'token-1');
      expect(Preferences().userAgent.get(), 'agent-1');
      expect(Preferences().refreshToken.get(), 'refresh-1');
    });

    test('primitive preference wrappers return defaults', () async {
      final stringPref = StringPreference('missing-string');
      final intPref = IntPreference('missing-int');
      final boolPref = BooleanPreference('missing-bool');

      expect(stringPref.getOrDefault(def: 'fallback'), 'fallback');
      expect(intPref.getOrDefault(def: 9), 9);
      expect(boolPref.getOrDefault(def: true), isTrue);

      await stringPref.set('value');
      await intPref.set(5);
      await boolPref.set(false);

      expect(stringPref.get(), 'value');
      expect(intPref.get(), 5);
      expect(boolPref.get(), isFalse);
    });

    test('map list secure and binary preferences support read write delete', () async {
      final mapPref = MapPreference(SharedPreferencesProvider.instance, 'map-key');
      final listPref = StringListPreference(SharedPreferencesProvider.instance, 'list-key');
      final securePref = SecureStringPreference('secure-key');
      final binaryPref = _BinaryPreferenceHarness('binary-key');

      expect(mapPref.isNotSet, isTrue);
      expect(listPref.getOrDefault(), isEmpty);

      await mapPref.set({'a': 1});
      await listPref.set(['x', 'y']);
      await securePref.set('secret');
      await binaryPref.setBinary(Uint8List.fromList([1, 2, 3]));

      expect(mapPref.isSet, isTrue);
      expect(mapPref.get(), {'a': 1});
      expect(listPref.get(), ['x', 'y']);
      expect(securePref.get(), 'secret');
      expect(binaryPref.getBinary(), Uint8List.fromList([1, 2, 3]));

      await mapPref.delete();
      expect(mapPref.isNotSet, isTrue);
    });

    test('shared preferences provider exposes initialized singleton', () {
      expect(SharedPreferencesProvider.isInitiated, isTrue);
      expect(SharedPreferencesProvider.instance, isNotNull);
    });
  });

  group('exception mapping', () {
    test('json api error is converted to ErrorException', () {
      final error = getErrorFromException2(
        JsonApiError.fromJson({
          'errorMessage': 'Bad request',
          'localisedErrorMessage': 'Bad request',
          'errorCategory': 'BadRequest',
          'errorCode': 400,
          'identifier': 'BAD_REQ',
        }),
      );

      expect(error.key, 'BAD_REQ');
      expect(error.message, 'Bad request');
    });

    test('api failure is converted to ErrorException', () {
      final error = getErrorFromException2(const ApiFailure('boom', 500));

      expect(error.key, '500');
      expect(error.message, 'boom');
    });

    test('maps timeout and explicit error objects', () {
      expect(getErrorFromException2(const ApiTimeout()).key, 'ApiTimeout');
      expect(
        getErrorFromException2(const ErrorException(key: 'k', message: 'm')).message,
        ErrorConstant.apiErrorSomethingWentWrong,
      );
      expect(
        getErrorFromException2(
          ApiException(base.ApiError(errorCode: '1', errorMessage: 'oops')),
        ).message,
        ErrorConstant.apiErrorSomethingWentWrong,
      );
    });

    test('no internet string returns offline message', () {
      final error = getErrorFromException2(noInternetConnection);

      expect(error.key, noInternetConnection);
      expect(error.message, "You're offline! Check your internet connection.");
    });

    test('dio 401 maps status code', () {
      final dioError = DioException(
        requestOptions: RequestOptions(path: '/test'),
        response: Response(
          requestOptions: RequestOptions(path: '/test'),
          statusCode: 401,
        ),
        type: DioExceptionType.badResponse,
      );

      final error = getErrorFromException2(dioError);

      expect(error.statusCode, 401);
      expect(error.message, ErrorConstant.apiErrorSomethingWentWrong);
    });

    test('dio timeout maps to timeout error', () {
      final dioError = DioException(
        requestOptions: RequestOptions(path: '/test'),
        type: DioExceptionType.connectionTimeout,
      );

      final error = getErrorFromException2(dioError);

      expect(error.key, 'ApiTimeout');
    });

    test('common dart errors map to generic error message', () {
      dynamic value = 1;
      late Object typeError;
      try {
        (value as String).length;
      } catch (error) {
        typeError = error;
      }

      expect(
        getErrorFromException2(ArgumentError('bad')).message,
        ErrorConstant.apiErrorSomethingWentWrong,
      );
      expect(
        getErrorFromException2(UnimplementedError()).message,
        ErrorConstant.apiErrorSomethingWentWrong,
      );
      expect(
        getErrorFromException2(typeError).message,
        ErrorConstant.apiErrorSomethingWentWrong,
      );
    });

    test('error exception factories keep expected defaults', () {
      expect(ErrorException.noData().message, ErrorConstant.noDataAvailable);
      expect(ErrorException.somethingWentWrong().message, ErrorConstant.apiErrorSomethingWentWrong);
      expect(ErrorException.networkTimeout().key, 'networkTimeout');
      expect(
        ErrorException.noData().getNoInternetException.message,
        "You're offline. Please check your Wi-Fi or mobile \ndata and try again.",
      );
    });
  });
}
