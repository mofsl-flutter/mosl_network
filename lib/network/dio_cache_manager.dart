import 'package:base_network/models/api_enums.dart';
import 'package:dio/dio.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:dio_cache_interceptor_hive_store/dio_cache_interceptor_hive_store.dart';
import 'package:flutter/material.dart';
import 'package:mosl_network/network/extentions.dart';
import 'package:path_provider/path_provider.dart';

final dioOptions = BaseOptions(
  connectTimeout: const Duration(seconds: 20),
  receiveTimeout: const Duration(seconds: 20),
  responseType: ResponseType.bytes,
);

class CacheManager {
  CacheManager._();

  static final CacheManager _instance = CacheManager._();
  late HiveCacheStore _cacheStore;

  factory CacheManager() {
    return _instance;
  }

  Future<void> init() async {
    final dir = await getTemporaryDirectory();
    _cacheStore = HiveCacheStore(dir.path);
  }

  Future<bool> isExist(String key) async {
    key = splitIfPossible(key);
    return _cacheStore.exists(key);
  }

  Future<CacheResponse?> get(String key) async {
    key = splitIfPossible(key);
    return _cacheStore.get(key);
  }

  Future<T?> getActualRes<T extends Object>({
    required String key,
    HttpMethod method = HttpMethod.get,
    required T runtimeType,
  }) async {
    key = splitIfPossible(key);
    final cachedRes = await _cacheStore.get(key);
    final response = cachedRes?.toResponse(
      _getReqOption(key, method),
      fromNetwork: false,
    );
    return response?.handleResponse<T>(runtimeType, isFromCache: true);
  }

  RequestOptions _getReqOption(String path, HttpMethod method) {
    // ignore: invalid_use_of_internal_member
    return DioMixin.checkOptions(
      method.name.toUpperCase(),
      Options(
        receiveTimeout: const Duration(seconds: 20),
        responseType: ResponseType.bytes,
      ),
    ).compose(dioOptions, path);
  }

  CacheOptions getCacheOptions(
    bool isForcedCacheEnable,
    bool checkConnectivity,
    Duration? maxStale,
  ) {
    return CacheOptions(
      store: _cacheStore,
      policy:
          isForcedCacheEnable
              ? CachePolicy.refreshForceCache
              : CachePolicy.request,
      maxStale: isForcedCacheEnable ? const Duration(hours: 12) : maxStale,
      hitCacheOnErrorExcept: checkConnectivity ? null : [],
      priority: CachePriority.normal,
      cipher: null,
      keyBuilder: (request) {
        var url = request.uri.toString();
        url = splitIfPossible(url);
        debugPrint("The new request url is test $url");
        return url;
      },
      allowPostMethod: false,
    );
  }

  Future<void> clearCacheOnLogout() async {
    try {
      await _cacheStore.clean();
    } catch (e) {
      debugPrint('Error clearing cache on logout: $e');
    }
  }

  Future<void> clearCacheOnAppUpdate() async {
    try {
      await _cacheStore.clean();
    } catch (e) {
      debugPrint('Error clearing cache on logout: $e');
    }
  }

  String splitIfPossible(String url) {
    if (url.contains(".com")) {
      url = url.split(".com")[1];
    }
    return url;
  }

  Future<void> delete(String homeDataSecUrl) async {
    final url = splitIfPossible(homeDataSecUrl);
    debugPrint("Does it exist ${await isExist(url)} $url");
    return _cacheStore.delete(url);
  }
}
