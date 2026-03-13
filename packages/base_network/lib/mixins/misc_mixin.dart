import 'package:dio/dio.dart';
import 'package:protobuf/protobuf.dart';

mixin MiscMixin {
  bool get isSentrySupported => false;

  void onRequestSubmit();

  bool shouldFireUnAuthorized(final String endUrl);

  Object get noInternetException;

  void onErrorOccurred(final DioException e, final Object? request);

  void handleFallbackUrl(final Uri uri);

  String getRequest(final Object? request) {
    if (request is String) {
      return request;
    } else if (request is GeneratedMessage) {
      return request.toProto3Json().toString();
    }
    return request.toString();
  }

}