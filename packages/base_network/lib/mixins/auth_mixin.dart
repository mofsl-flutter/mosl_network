import 'dart:collection';

import 'package:base_network/models/api_error.dart';

mixin AuthMixin {
  Future<bool>  newTokenFound(final UnauthorizedException failure);

  String get accessToken;

  int refreshAuthCount = 0;

  String getKey(final Uri uri) {
    return ApiCallError.getEndUrl(uri);
  }

  bool shouldReplaceToken(final Uri baseUrl) {
    final String endPath = getKey(baseUrl);
    return _401UrlsMap.keys.contains(endPath);
  }

  // ignore: non_constant_identifier_names
  final HashMap<String, int> _401UrlsMap = HashMap<String, int>();

  void reduce401Url(final Uri uri) {
    final String endPath = getKey(uri);
    if (_401UrlsMap.containsKey(endPath)) {
      _401UrlsMap[endPath] = _401UrlsMap[endPath]! - 1;
      if (_401UrlsMap[endPath] == 0) {
        _401UrlsMap.remove(endPath);
      }
    }
  }

  void add401Url(
    final String endPath,
  ) {
    _401UrlsMap[endPath] = (_401UrlsMap[endPath] ?? 0) + 1;
  }
}
