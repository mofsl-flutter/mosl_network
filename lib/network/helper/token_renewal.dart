import 'dart:async';

import 'package:base_network/auth/base_token_renewal_helper.dart';
import 'package:base_network/helper/misc.dart' show isRefreshTokenValid;
import 'package:base_network/models/api_enums.dart';
import 'package:mosl_network/network/data/token_renewal_repository.dart' show TokenRenewalRepository;
import 'package:mosl_network/network/helper/preferences.dart';

class TokenRenewalHelper extends BaseTokenManager {
  static final TokenRenewalHelper _singleton =
      TokenRenewalHelper._internal();
  late final TokenRenewalRepository _mPinTokenRenewalRepository;

  factory TokenRenewalHelper() {
    return _singleton;
  }

  TokenRenewalHelper._internal() {
    _mPinTokenRenewalRepository = TokenRenewalRepository();
  }


  Future<String> get _refreshTokenApiCall =>  _mPinTokenRenewalRepository.refreshToken();

  Future<SilentLoginStatus> get _silentLoginApiCall => _mPinTokenRenewalRepository.silentAuth();

  @override
  Future<String> renewToken() {

    return _refreshTokenApiCall;
  }

  @override
  Future<SilentLoginStatus> callSilentLogin(bool isForce) {

    return _silentLoginApiCall;
  }

  @override
  void handleSilentLoginFailure() {
    //Todo showDialog and logout ;
  }

  @override
  //Todo the case is very specific to MPin, so we are returning false here.
  bool get shouldCallRefreshToken =>false;

  @override
  void writeLogs(String title, String message) {}

  @override
  bool get isTokenValid => isRefreshTokenValid(Preferences().refreshToken.getOrDefault());
}
