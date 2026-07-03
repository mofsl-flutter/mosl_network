class IntercepterResponseModel {
  IntercepterResponseModel({
    required this.createdAt,
    required this.responseHeader,
    // required this.responseBody,
    required this.responseStatusCode,
    required this.responseStatusMessage,
    required this.responseSize,
    required this.requestHashCode,
    this.responseTime,
    this.origin,
    this.query,
    this.queryParam,
    this.method,
    this.accept,
    this.contentType,
    this.xApiVersion,
    this.userAgent,
    this.authorization,
  });

  final String createdAt;
  final String responseHeader;
  // final dynamic responseBody;
  final String responseStatusCode;
  final String responseStatusMessage;
  final String responseSize;
  final String requestHashCode;
  final String? responseTime;
  final String? origin;
  final String? query;
  final String? queryParam;
  final String? method;
  final String? accept;
  final String? contentType;
  final String? xApiVersion;
  final String? userAgent;
  final String? authorization;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'createdAt': createdAt,
      'method': method,
      'origin': origin,
      'query': query,
      'queryParam': queryParam,
      'responseHeader': responseHeader,
      // 'responseBody': responseBody,
      'responseStatusCode': responseStatusCode,
      'responseStatusMessage': responseStatusMessage,
      'responseSize': responseSize,
      'responseTime': responseTime,
      'accept': accept,
      'contentType': contentType,
      'xApiVersion': xApiVersion,
      'userAgent': userAgent,
      'authorization': authorization,
    };
  }
}
