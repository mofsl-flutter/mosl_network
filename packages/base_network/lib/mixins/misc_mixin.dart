import 'package:dio/dio.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';
import 'package:protobuf/protobuf.dart';

mixin MiscMixin {
  void onRequestSubmit();

  bool shouldFireUnAuthorized(String endUrl);

  Object get noInternetException;

  void onErrorOccurred(DioException e,Object? request);

  String getRequest(Object? request) {
    if (request is String) {
      return request;
    } else if (request is GeneratedMessage) {
      return request.toProto3Json().toString();
    }
    return request.toString();
  }

}