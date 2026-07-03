
import 'package:base_network/models/api_enums.dart';
import 'package:mosl_network/network/dio_impl.dart';
import 'package:mosl_network/network/helper/api_request_builder.dart';
import 'package:mosl_network/network/helper/preferences.dart';
import 'package:mosl_network/network/models/Login/AuthRequest.pb.dart' show TokenInfo, TokenResponse;

class TokenRenewalRepository {
  TokenRenewalRepository._();

  static final TokenRenewalRepository _instance = TokenRenewalRepository._();

  factory TokenRenewalRepository() {
    return _instance;
  }

  Future<String> refreshToken() async {
    final refreshToken = Preferences().refreshToken.getOrDefault();
    final request =
        ApiRequestBuilder()
            .apiIdentifier(ApiIdentifier.mPinLogin)
            .url("api/Login/Token")
            .requestType(HttpMethod.get)
            .specialToken(refreshToken)
            .build();

    return DioImpl().callApiWithDioClient(request, TokenResponse(), null).then((
      refreshTokenResponse,
    ) {
      final accessToken = refreshTokenResponse.accessToken;
      Preferences.init(
        token: refreshTokenResponse.accessToken,
        userAgent: Preferences().userAgent.getOrDefault(),
        refreshToken: refreshToken,
      );
      return accessToken;
    });
  }

  Future<SilentLoginStatus> silentAuth() async {
    final refreshToken = Preferences().refreshToken.getOrDefault();
    final request =
        ApiRequestBuilder()
            .apiIdentifier(ApiIdentifier.mPinLogin)
            .url("api/Login/RenewSession")
            .requestType(HttpMethod.get)
            .specialToken(refreshToken)
            .build();

    return DioImpl()
        .callApiWithDioClient(request, TokenInfo(), null)
        .then((refreshTokenResponse) {
          Preferences.init(
            token: refreshTokenResponse.accessToken,
            userAgent: Preferences().userAgent.getOrDefault(),
            refreshToken: refreshToken,
          );
          return SilentLoginStatus.success;
        })
        .onError((error, stackTrace) {
          return SilentLoginStatus.failed;
        });
  }
}
