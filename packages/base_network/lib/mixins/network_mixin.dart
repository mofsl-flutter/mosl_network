import 'dart:collection';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:dio_http2_adapter/dio_http2_adapter.dart';
import 'package:flutter/foundation.dart';

mixin NetworkMixin {
  final HashMap<String, HttpClientAdapter> _mapNetworkAdapter = HashMap<String, HttpClientAdapter>();

  void addEntryInMap(final String hostName, [final HttpClientAdapter? adapter]) {
    final HttpClientAdapter? valueAdapter = _mapNetworkAdapter[hostName];
    if (valueAdapter == null) {
      _mapNetworkAdapter[hostName] = adapter ?? getHttp2Adapter;
    } else {
      _mapNetworkAdapter[hostName] = adapter ?? valueAdapter;
    }
  }

  Future<bool> get checkConnectivity;

  Duration get _idealTimeOut => const Duration(seconds: 200);

  HttpClientAdapter getHttpAdapter(final String hostName) {
    final HttpClientAdapter? entry = _mapNetworkAdapter[hostName];
    if (entry == null) {
      _mapNetworkAdapter[hostName] = getHttp2Adapter;
    }
    return _mapNetworkAdapter[hostName]!;
  }

  HttpClientAdapter get getHttp2Adapter =>
      Http2Adapter(ConnectionManager(idleTimeout: _idealTimeOut),
          fallbackAdapter: ioHttpAdapter, onNotSupported: (
        final RequestOptions options,
        final Stream<Uint8List>? requestStream,
        final Future<void>? cancelFuture,
        final DioH2NotSupportedException exception,
      ) {
        final String entry = _mapNetworkAdapter.keys.firstWhere(
          (final String element) => element.contains(_getBaseUrl(options)),
          orElse: () => '',
        );
        if (entry.isEmpty) {
          addEntryInMapWithIoAdapter(entry);
        }
        return ioHttpAdapter.fetch(options, requestStream, cancelFuture);
      });

  String _getBaseUrl(final RequestOptions options) {
    if (options.baseUrl.isNotEmpty) {
      return options.baseUrl;
    } else {
      return Uri.parse(options.path).host;
    }
  }

  HttpClientAdapter get ioHttpAdapter => IOHttpClientAdapter()
    ..createHttpClient = () {
      return HttpClient()..idleTimeout = _idealTimeOut;
    };

  void addEntryInMapWithIoAdapter(
    final String hostName,
  ) {
    addEntryInMap(hostName, ioHttpAdapter);
  }
}
