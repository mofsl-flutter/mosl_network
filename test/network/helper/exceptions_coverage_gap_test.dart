import 'package:base_network/error_handling/error_constant.dart';
import 'package:base_network/models/api_error.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mosl_network/network/helper/exceptions.dart';
import 'package:mosl_network/network/models/Base/BaseResponse.pb.dart' as base;
import 'package:mosl_network/network/models/json_message_response.dart';

void main() {
  group('getErrorFromException2 — coverage gaps', () {
    // ---- ApiCallFailure (not ApiCallFailureDIO) path ----
    test('ApiCallFailure maps to generic error message', () {
      final dioResponse = Response<dynamic>(
        requestOptions: RequestOptions(path: '/test'),
        statusCode: 503,
      );
      final error = getErrorFromException2(ApiCallFailure(dioResponse));

      expect(error.key, '503');
      expect(error.message, ErrorConstant.apiErrorSomethingWentWrong);
    });

    // ---- ApiError (protobuf) second branch (after all other checks) ----
    test('protobuf ApiError after ErrorCategoryEnum maps to ApiFailure wrapper', () {
      final apiError =
          base.ApiError(errorCode: '404', errorMessage: 'Not Found');
      final error = getErrorFromException2(ApiException(apiError));

      expect(error.message, ErrorConstant.apiErrorSomethingWentWrong);
    });

    // ---- DioException — rise path with "error" key in data ----
    test('DioException with rise header and error key maps error details', () {
      final dioError = DioException(
        requestOptions: RequestOptions(
          path: '/rise/api/data',
          headers: {'XApiKey': 'rise-key'},
        ),
        response: Response<dynamic>(
          requestOptions: RequestOptions(
            path: '/rise/api/data',
            headers: {'XApiKey': 'rise-key'},
          ),
          statusCode: 400,
          data: {
            'error': {
              'errorMessage': 'Rise error',
              'localisedErrorMessage': 'Rise error',
              'errorCategory': 'BadRequest',
              'errorCode': 400,
              'identifier': 'RISE_ERR',
            },
          },
        ),
        type: DioExceptionType.badResponse,
      );

      final error = getErrorFromException2(dioError);

      expect(error.key, 'RISE_ERR');
      expect(error.message, 'Rise error');
    });

    // ---- DioException — rise path with "error" key and NoData category ----
    test('DioException rise with NoData category returns noData exception', () {
      final dioError = DioException(
        requestOptions: RequestOptions(
          path: '/rise/api/data',
          headers: {'XApiKey': 'key'},
        ),
        response: Response<dynamic>(
          requestOptions: RequestOptions(
            path: '/rise/api/data',
            headers: {'XApiKey': 'key'},
          ),
          statusCode: 404,
          data: {
            'error': {
              'errorMessage': 'No data found',
              'localisedErrorMessage': 'No data found',
              'errorCategory': 'NoData',
              'errorCode': 404,
              'identifier': null,
            },
          },
        ),
        type: DioExceptionType.badResponse,
      );

      final error = getErrorFromException2(dioError);

      expect(error.message, ErrorConstant.noDataAvailable);
    });

    // ---- DioException — rise path, data is String (empty map fallback) ----
    test('DioException rise with string data falls through to generic', () {
      final dioError = DioException(
        requestOptions: RequestOptions(
          path: '/rise/api/data',
          headers: {'XApiKey': 'key'},
        ),
        response: Response<dynamic>(
          requestOptions: RequestOptions(
            path: '/rise/api/data',
            headers: {'XApiKey': 'key'},
          ),
          statusCode: 500,
          data: 'internal server error',
        ),
        type: DioExceptionType.connectionError,
      );

      final error = getErrorFromException2(dioError);

      // Falls to generic DioException unknown/connectionError handler
      expect(error.message, ErrorConstant.apiErrorSomethingWentWrong);
    });

    // ---- DioException — sendTimeout ----
    test('DioException sendTimeout maps to ApiTimeout', () {
      final dioError = DioException(
        requestOptions: RequestOptions(path: '/test'),
        type: DioExceptionType.sendTimeout,
      );

      final error = getErrorFromException2(dioError);

      expect(error.key, 'ApiTimeout');
    });

    // ---- DioException — receiveTimeout ----
    test('DioException receiveTimeout maps to ApiTimeout', () {
      final dioError = DioException(
        requestOptions: RequestOptions(path: '/test'),
        type: DioExceptionType.receiveTimeout,
      );

      final error = getErrorFromException2(dioError);

      expect(error.key, 'ApiTimeout');
    });

    // ---- DioException — badCertificate without rise header ----
    test('DioException badCertificate without rise header maps to generic', () {
      final dioError = DioException(
        requestOptions: RequestOptions(path: '/secure'),
        type: DioExceptionType.badCertificate,
      );

      final error = getErrorFromException2(dioError);

      expect(error.message, ErrorConstant.apiErrorSomethingWentWrong);
    });

    // ---- DioException — cancel type ----
    test('DioException cancel type maps to generic error', () {
      final dioError = DioException(
        requestOptions: RequestOptions(path: '/test'),
        type: DioExceptionType.cancel,
      );

      final error = getErrorFromException2(dioError);

      expect(error.message, ErrorConstant.apiErrorSomethingWentWrong);
    });

    // ---- Unknown error with "No" in message ----
    test('unknown error with "No" in message maps to noDataAvailable', () {
      final error = getErrorFromException2('No records found', key: 'search');

      expect(error.message, ErrorConstant.noDataAvailable);
    });

    // ---- Unknown error without "No" ----
    test('unknown error without "No" maps to somethingWentWrong', () {
      final error = getErrorFromException2('Something broke', key: 'test');

      expect(error.message, ErrorConstant.apiErrorSomethingWentWrong);
      expect(error.key, 'test');
    });

    // ---- Cache-enabled flag propagation ----
    test('isCacheEnabled flag is forwarded to ErrorException', () {
      final error = getErrorFromException2(
        const ApiFailure('fail', 503),
        isCacheEnabled: true,
      );

      expect(error.isCacheEnable, isTrue);
    });

    // ---- JsonApiError with null identifier uses errorCode as key ----
    test('JsonApiError with null identifier uses errorCode as key', () {
      final error = getErrorFromException2(
        JsonApiError.fromJson({
          'errorMessage': 'Validation failed',
          'localisedErrorMessage': 'Validation failed',
          'errorCategory': 'Validation',
          'errorCode': 422,
          'identifier': null,
        }),
      );

      expect(error.key, '422');
      expect(error.message, 'Validation failed');
    });

    // ---- ErrorCategoryEnum.valueOf — all branches ----
    test('ErrorCategoryEnum.valueOf covers all known string values', () {
      expect(ErrorCategoryEnum.valueOf('Unknown'), ErrorCategoryEnum.unknown);
      expect(ErrorCategoryEnum.valueOf(0), ErrorCategoryEnum.unknown);
      expect(ErrorCategoryEnum.valueOf('BadRequest'), ErrorCategoryEnum.badRequest);
      expect(ErrorCategoryEnum.valueOf(1), ErrorCategoryEnum.badRequest);
      expect(ErrorCategoryEnum.valueOf('Validation'), ErrorCategoryEnum.validation);
      expect(ErrorCategoryEnum.valueOf(2), ErrorCategoryEnum.validation);
      expect(ErrorCategoryEnum.valueOf('Unauthorized'), ErrorCategoryEnum.unauthorized);
      expect(ErrorCategoryEnum.valueOf(3), ErrorCategoryEnum.unauthorized);
      expect(ErrorCategoryEnum.valueOf('NoData'), ErrorCategoryEnum.noData);
      expect(ErrorCategoryEnum.valueOf(4), ErrorCategoryEnum.noData);
      expect(ErrorCategoryEnum.valueOf('ServerError'), ErrorCategoryEnum.serverError);
      expect(ErrorCategoryEnum.valueOf(5), ErrorCategoryEnum.serverError);
      // Default fallback
      expect(ErrorCategoryEnum.valueOf('AnythingElse'), ErrorCategoryEnum.unknown);
    });

    // ---- ErrorCategoryEnum boolean properties ----
    test('ErrorCategoryEnum boolean helpers return expected values', () {
      expect(ErrorCategoryEnum.unknown.isUnknown, isTrue);
      expect(ErrorCategoryEnum.badRequest.isBadRequest, isTrue);
      expect(ErrorCategoryEnum.validation.isValidation, isTrue);
      expect(ErrorCategoryEnum.unauthorized.isUnauthorized, isTrue);
      expect(ErrorCategoryEnum.noData.isNoData, isTrue);
      expect(ErrorCategoryEnum.serverError.isServerError, isTrue);

      expect(ErrorCategoryEnum.unknown.isNoData, isFalse);
    });
  });
}
