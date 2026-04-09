import 'package:base_network/error_handling/error_exception.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mosl_network/network/extentions.dart';
import 'package:mosl_network/network/models/Base/BaseResponse.pb.dart' as base;
import 'package:mosl_network/network/models/google/protobuf/any.pb.dart';
import 'package:mosl_network/network/models/json_message_response.dart';
import 'package:mosl_network/network/models/no_response.dart';

void main() {
  group('ResponseExtension.handleResponse', () {
    test('returns unpacked protobuf data', () {
      final payload = base.MessageResponse(message: 'hello');
      final wrapped = base.BaseResponse(data: Any.pack(payload));
      final response = Response<List<int>>(
        requestOptions: RequestOptions(path: '/proto'),
        data: wrapped.writeToBuffer(),
      );

      final result = response.handleResponse(base.MessageResponse());

      expect(result, isA<base.MessageResponse>());
      expect(result.message, 'hello');
    });

    test('returns base response when base response requested', () {
      final wrapped = base.BaseResponse(error: base.ApiError(errorCode: '1'));
      final response = Response<List<int>>(
        requestOptions: RequestOptions(path: '/proto'),
        data: wrapped.writeToBuffer(),
      );

      final result = response.handleResponse(base.BaseResponse());

      expect(result, isA<base.BaseResponse>());
      expect(result.error.errorCode, '1');
    });

    test('throws mapped error for protobuf error payload', () {
      final wrapped = base.BaseResponse(
        error: base.ApiError(
          errorCode: '401',
          errorMessage: 'denied',
          category: base.ErrorCategory.BadRequest,
        ),
      );
      final response = Response<List<int>>(
        requestOptions: RequestOptions(path: '/proto'),
        data: wrapped.writeToBuffer(),
      );

      expect(
        () => response.handleResponse(base.MessageResponse()),
        throwsA(isA<ErrorException>()),
      );
    });

    test('returns no response marker directly', () {
      final response = Response<Map<String, dynamic>>(
        requestOptions: RequestOptions(path: '/download'),
        data: <String, dynamic>{},
      );

      final result = response.handleResponse(NoResponse());

      expect(result, isA<NoResponse>());
    });

    test('parses json message response success payload', () {
      final response = Response<Map<String, dynamic>>(
        requestOptions: RequestOptions(path: '/json'),
        data: {
          'message': 'ok',
          'status': 'Success',
          'data': {'message': 'inner'},
        },
      );

      final result = response.handleResponse(MessageResponse());

      expect(result, isA<MessageResponse>());
      expect(result.message, 'ok');
      expect(result.dataMessage, 'inner');
    });

    test('parses aws message response from outer message', () {
      final response = Response<Map<String, dynamic>>(
        requestOptions: RequestOptions(path: '/json'),
        data: {'message': 'uploaded', 'status': true, 'data': {'ignored': true}},
      );

      final result = response.handleResponse(AwsMessageResponse());

      expect(result.dataMessage, 'uploaded');
      expect(result.status, isTrue);
    });

    test('throws no data when json message data is empty', () {
      final response = Response<Map<String, dynamic>>(
        requestOptions: RequestOptions(path: '/json'),
        data: {'message': 'ok', 'status': 'Success', 'data': ''},
      );

      expect(
        () => response.handleResponse(MessageResponse()),
        throwsA(isA<ErrorException>()),
      );
    });

    test('throws mapped json api error for failure status', () {
      final response = Response<Map<String, dynamic>>(
        requestOptions: RequestOptions(path: '/json'),
        data: {
          'status': 'Failure',
          'error': {
            'errorMessage': 'bad',
            'localisedErrorMessage': 'bad',
            'errorCategory': 'BadRequest',
            'errorCode': 400,
            'identifier': 'BAD',
          },
        },
      );

      expect(
        () => response.handleResponse(MessageResponse()),
        throwsA(isA<ErrorException>()),
      );
    });

    test('returns raw json map for unknown payload shape', () {
      final response = Response<Map<String, dynamic>>(
        requestOptions: RequestOptions(path: '/json'),
        data: {'unexpected': true},
      );

      final result = response.handleResponse(<String, dynamic>{});

      expect(result, {'unexpected': true});
    });
  });
}
