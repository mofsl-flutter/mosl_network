import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mosl_network/network/helper/preferences.dart';
import 'package:mosl_network/network/helper/token_renewal.dart';
import 'package:mosl_network/shared_preference/shared_preferences_provider.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakePathProvider extends PathProviderPlatform {
  _FakePathProvider(this.basePath);
  final String basePath;

  @override
  Future<String?> getTemporaryPath() async => basePath;

  @override
  Future<String?> getApplicationDocumentsPath() async => basePath;
}

void main() {
  late Directory tempDir;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await SharedPreferencesProvider.init();
    Preferences.init(
      token: 'test-token',
      userAgent: 'test-agent',
      refreshToken: 'refresh-token',
    );
    tempDir = await Directory.systemTemp.createTemp('mosl_renewal_test_');
    PathProviderPlatform.instance = _FakePathProvider(tempDir.path);
  });

  tearDownAll(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('TokenRenewalHelper', () {
    test('singleton returns identical instance across calls', () {
      final a = TokenRenewalHelper();
      final b = TokenRenewalHelper();
      expect(identical(a, b), isTrue);
    });

    test('shouldCallRefreshToken is always false', () {
      expect(TokenRenewalHelper().shouldCallRefreshToken, isFalse);
    });

    test('handleSilentLoginFailure completes without throwing', () {
      expect(
        () => TokenRenewalHelper().handleSilentLoginFailure(),
        returnsNormally,
      );
    });

    test('writeLogs is a no-op and does not throw', () {
      expect(
        () => TokenRenewalHelper().writeLogs('title', 'message'),
        returnsNormally,
      );
    });

    test('isTokenValid reflects empty refresh token as false', () {
      Preferences().refreshToken.delete();
      expect(TokenRenewalHelper().isTokenValid, isFalse);
    });

    test('renewToken throws StateError when DioImpl is not initialized', () async {
      expect(
        () async => TokenRenewalHelper().renewToken(),
        throwsA(isA<Error>()),
      );
    });

    test('callSilentLogin throws StateError when DioImpl is not initialized', () async {
      expect(
        () async => TokenRenewalHelper().callSilentLogin(false),
        throwsA(isA<Error>()),
      );
    });
  });
}
