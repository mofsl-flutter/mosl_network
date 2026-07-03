import 'package:base_network/models/api_enums.dart' show HttpMethod;
import 'package:flutter/material.dart';
import 'package:mosl_network/network/dio_impl.dart';
import 'package:mosl_network/network/helper/api_request_builder.dart'
    show ApiIdentifier, ApiRequestBuilder;
import 'package:mosl_network/network/helper/constants.dart' show Constants;
import 'package:mosl_network/network/models/Login/AuthRequest.pb.dart'
    show GeneratePasswordRequestV2, GeneratePasswordResponseV2;
import 'package:mosl_network/network/models/Quote/QuoteModels.pb.dart'
    show PlaceOrderData2;
import 'package:protobuf/protobuf.dart';

class ProtoScreen extends StatelessWidget {
  final HttpMethod method;

  const ProtoScreen({super.key, required this.method});

  static const routeName = '/proto';

  Future<GeneratedMessage> _fetchData() async {
    if (method == HttpMethod.get) {
      final request =
          ApiRequestBuilder()
              .apiIdentifier(ApiIdentifier.trader)
              .url('api/Quote/PlaceOrderData?scripCode=532667&exchange=1')
              .apiVersion(Constants.apiV2_1)
              .build();
      return DioImpl().callApiWithDioClient(request, PlaceOrderData2());
    } else {
      final body = GeneratePasswordRequestV2(input: 'AA020');
      final request =
          ApiRequestBuilder()
              .apiIdentifier(ApiIdentifier.trader)
              .requestType(HttpMethod.post)
              .url('api/Login/GeneratePassword')
              .isTokenRequired(false)
              .request(body)
              .apiVersion(Constants.apiV1_1)
              .build();
      return DioImpl().callApiWithDioClient(
        request,
        GeneratePasswordResponseV2(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(method.name)),
      body: Center(
        child: FutureBuilder<GeneratedMessage>(
          future: _fetchData(),
          builder: (
            BuildContext context,
            AsyncSnapshot<GeneratedMessage> snapshot,
          ) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const CircularProgressIndicator();
            } else if (snapshot.hasError) {
              return Text('Error: ${snapshot.error}');
            } else if (snapshot.hasData) {
              return Text('Data: ${snapshot.data!.writeToJson()}');
            } else {
              return const Text('No data available');
            }
          },
        ),
      ),
    );
  }
}
