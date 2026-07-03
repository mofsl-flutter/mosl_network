import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mosl_network/network/helper/preferences.dart';
import 'package:mosl_network/shared_preference/shared_preferences_provider.dart';
import 'package:mosl_network/ui/download_screen.dart';
import 'package:mosl_network/ui/json_screen.dart';
import 'package:mosl_network/ui/proto_screen.dart';
import 'package:mosl_network/ui/upload_screen.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:base_network/models/api_enums.dart';
import 'package:permission_handler_platform_interface/permission_handler_platform_interface.dart';

class _FakePathProvider extends PathProviderPlatform {
  _FakePathProvider(this.basePath);

  final String basePath;

  @override
  Future<String?> getApplicationDocumentsPath() async => basePath;
}

class _FakePermissionHandler extends PermissionHandlerPlatform {
  _FakePermissionHandler(this.status);

  final PermissionStatus status;

  @override
  Future<Map<Permission, PermissionStatus>> requestPermissions(List<Permission> permissions) async {
    return {for (final permission in permissions) permission: status};
  }

  @override
  Future<PermissionStatus> checkPermissionStatus(Permission permission) async => status;
}

void main() {
  late Directory tempDir;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await SharedPreferencesProvider.init();
    Preferences.init(token: 'token', userAgent: 'agent', refreshToken: 'refresh');
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('mosl_ui_');
    PathProviderPlatform.instance = _FakePathProvider(tempDir.path);
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  testWidgets('JsonScreen shows loading then error when Dio is not initialized', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: JsonScreen(method: HttpMethod.get)));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.textContaining('Error:'), findsOneWidget);
  });

  testWidgets('ProtoScreen shows loading then error when Dio is not initialized', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ProtoScreen(method: HttpMethod.post)));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.textContaining('Error:'), findsOneWidget);
  });

  testWidgets('DownloadScreen shows error snackbar when download setup fails', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: DownloadScreen(downloadUrl: 'https://example.com/file.pdf')),
    );

    await tester.tap(find.text('Start Download'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Download failed:'), findsOneWidget);
  });

  testWidgets('UploadScreen shows permission denied snackbar', (tester) async {
    PermissionHandlerPlatform.instance = _FakePermissionHandler(PermissionStatus.denied);

    await tester.pumpWidget(const MaterialApp(home: CameraUploadScreen()));
    await tester.tap(find.text('Capture & Upload'));
    await tester.pumpAndSettle();

    expect(find.text('Camera permission denied'), findsOneWidget);
    expect(find.text('No image captured'), findsOneWidget);
  });
}
