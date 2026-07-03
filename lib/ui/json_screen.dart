import 'package:base_network/error_handling/error_exception.dart';
import 'package:base_network/models/api_enums.dart' show HttpMethod;
import 'package:flutter/material.dart';
import 'package:mosl_network/network/dio_impl.dart' show DioImpl;
import 'package:mosl_network/network/helper/api_request_builder.dart'
    show ApiIdentifier, ApiRequestBuilder;
import 'package:mosl_network/network/models/fund_details_model.dart';
import 'package:mosl_network/network/models/json_message_response.dart';
import 'package:mosl_network/network/models/story_banner_model.dart';

class JsonScreen extends StatelessWidget {
  final HttpMethod method;

  static const routeName = '/json';

  const JsonScreen({super.key, required this.method});

  Future<JsonMessageResponse> _fetchData() async {
    if (method == HttpMethod.get) {
      final request = ApiRequestBuilder()
          .apiIdentifier(ApiIdentifier.rise)
          .apiKey('v33tmau6aUePbWgCa9O5K1PVJJR7KpmG')
          .url(
            'cmsapi/api/UserEngagementContent?contenttype=mflandingpagebanner&id=0',
          )
          .build();
      return DioImpl().callApiWithDioClient(
        request,
        StoryBannerModel.initial(),
      );
    } else {
      final Map<String, dynamic> body = {
        'currentPageNumber': 1,
        'pageSize': 35,
        'type': 'mst_collectionsv1',
        'id': '',
        'fromdate': '',
        'todate': '',
      };
      final request = ApiRequestBuilder()
          .apiIdentifier(ApiIdentifier.rise)
          .requestType(HttpMethod.post)
          .cacheCallback((value) {})
          .apiKey('A1K6V8N8u0+JNZJLbPUwHw==')
          .url('master/Master/GetDatabyType')
          .request(body)
          .build();
      return DioImpl()
          .callApiWithDioClient(
        request,
        SchemeDetailsModel.initial(),
      )
          .onError<ErrorException>((error, _) {
        throw error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(method.name)),
      body: Center(
        child: FutureBuilder<JsonMessageResponse>(
          future: _fetchData(),
          builder: (
            BuildContext context,
            AsyncSnapshot<JsonMessageResponse> snapshot,
          ) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const CircularProgressIndicator();
            } else if (snapshot.hasError) {
              return Text('Error: ${snapshot.error}');
            } else if (snapshot.hasData) {
              return Text('Data: ${snapshot.data!.toJson}');
            } else {
              return const Text('No data available');
            }
          },
        ),
      ),
    );
  }
}
