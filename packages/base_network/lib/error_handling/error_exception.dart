import 'package:base_network/error_handling/error_constant.dart';

class ErrorException implements Exception {
  const ErrorException(
      {required this.key,
      required this.message,
      this.isCacheEnable = false,
      this.statusCode = -1,
      this.trace,
      this.actualError});

  factory ErrorException.noData() {
    return const ErrorException(key: "NoData", message: ErrorConstant.noDataAvailable);
  }

  factory ErrorException.somethingWentWrong() {
    return const ErrorException(
        key: "",
        message: ErrorConstant.apiErrorSomethingWentWrong);
  }

  factory ErrorException.networkTimeout() {
    return const ErrorException(
        key: "networkTimeout",
        message: "networkTimeout",
        );
  }

  final String key;
  final String message;
  final bool isCacheEnable;
  final int statusCode;
  final Object? actualError;
  final StackTrace? trace;

  ErrorException copyWith({
    final String? key,
    final String? message,
    final bool? isCacheEnable,
    final int? statusCode,
    final Object? actualError,
    final StackTrace? trace,
  }) {
    return ErrorException(
      key: key ?? this.key,
      message: message ?? this.message,
      isCacheEnable: isCacheEnable ?? this.isCacheEnable,
      statusCode: statusCode ?? this.statusCode,
      actualError: actualError ?? this.actualError,
      trace: trace ?? this.trace,
    );
  }

  @override
  String toString() {
    return message;
  }
}

extension ErrorExceptionExtension on ErrorException {
  ErrorException get getNoInternetException {
    const String internetConnectionOffline =
        "You're offline. Please check your Wi-Fi or mobile \ndata and try again.";
    return const ErrorException(
        key: "noInternetConnection", message: internetConnectionOffline);
  }
}
