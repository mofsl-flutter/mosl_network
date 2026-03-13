import 'dart:convert' show base64Url, json, utf8;

import 'package:flutter/foundation.dart';

const int tokenSyncBufferTime = 60;

bool isRefreshTokenValid(final String refreshToken) {
  try {
    final int remainingValidity =
        getJWTTokenRemainingValidity(refreshToken, isAccessToken: false);
    return remainingValidity != -1 ? (remainingValidity > 0) : false;
  } on Exception {
    return false;
  }
}

int getJWTTokenRemainingValidity(final String token, {required final bool isAccessToken}) {
  final List<String> parts = token.split('.');
  final StringBuffer payload64Buffer = StringBuffer(parts.length > 1 ? parts[1] : '');
  while (payload64Buffer.length % 4 != 0) {
    payload64Buffer.write('=');
  }
  final Uint8List payloadData = base64Url.decode(payload64Buffer.toString());
  final String payload = utf8.decode(payloadData);
  final Map<String, dynamic> tokenDict = json.decode(payload);

  final int? expiry = tokenDict['exp'];
  final int? creationTime = tokenDict['iat'];

  if (expiry == null || creationTime == null) {
    return -1;
  }

  final int remainingValidity = expiry - getTimeStampInSeconds();

  return remainingValidity - tokenSyncBufferTime; // Buffer time for proactively refresh the token first to avoid getting a unauthorized access i.e 401
}

int getTimeStampInSeconds() {
  return DateTime.now().millisecondsSinceEpoch ~/ 1000;
}
