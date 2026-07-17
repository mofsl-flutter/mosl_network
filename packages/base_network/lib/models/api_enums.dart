import 'package:firebase_performance/firebase_performance.dart' as fire_perf;

enum HttpMethod {
  get,
  post,
  upload,
  download;
}

extension HttpMethodExtension on HttpMethod {
  fire_perf.HttpMethod get toFireBaseHttpMethod {
    switch (this) {
      case HttpMethod.get:
        return fire_perf.HttpMethod.Get;
      case HttpMethod.post:
        return fire_perf.HttpMethod.Post;
      case HttpMethod.upload:
        return fire_perf.HttpMethod.Post;
      case HttpMethod.download:
        return fire_perf.HttpMethod.Get;
    }
  }
}

enum ApiVersion {
  v1_0,
  v1_1,
  v1_2,
  v2_0,
  v3_0;

  String get number {
    switch (this) {
      case ApiVersion.v1_0:
        return '1.0';
      case ApiVersion.v1_1:
        return '1.1';
      case ApiVersion.v1_2:
        return '1.2';
      case ApiVersion.v2_0:
        return '2.0';
      case ApiVersion.v3_0:
        return '3.0';
    }
  }
}

enum SilentLoginStatus { notCalled, success, failed, logout }
