import 'dart:collection';

import 'package:base_network/models/api_error.dart';

mixin AuthMixin {
  Future<bool> get newTokenFound;

  String get accessToken;

  int refreshAuthCount = 0;

  String getKey(Uri uri) {
    return ApiCallError.getEndUrl(uri);
  }

  bool shouldReplaceToken(Uri baseUrl) {
    final endPath = getKey(baseUrl);
    return _401UrlsMap.keys.contains(endPath);
  }

  final _401UrlsMap = HashMap<String, int>();

  void reduce401Url(Uri uri) {
    final endPath = getKey(uri);
    if (_401UrlsMap.containsKey(endPath)) {
      _401UrlsMap[endPath] = _401UrlsMap[endPath]! - 1;
      if (_401UrlsMap[endPath] == 0) {
        _401UrlsMap.remove(endPath);
      }
    }
  }

  void add401Url(
    String endPath,
  ) {
    _401UrlsMap[endPath] = (_401UrlsMap[endPath] ?? 0) + 1;
  }
}
