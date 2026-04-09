import 'dart:io';

import 'package:base_network/models/api_enums.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mosl_network/network/helper/preferences.dart';
import 'package:mosl_network/shared_preference/shared_preferences_provider.dart';
import 'package:mosl_network/ui/download_screen.dart';
import 'package:mosl_network/ui/json_screen.dart';
import 'package:mosl_network/ui/proto_screen.dart';
import 'package:mosl_network/ui/upload_screen.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:permission_handler_platform_interface/permission_handler_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  Future<Map<Permission, PermissionStatus>> requestPermissions(
    List<Permission> permissions,
  ) async {
    return {for (final p in permissions) p: status};
  }

  @override
  Future<PermissionStatus> checkPermissionStatus(Permission permission) async =>
      status;
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
    tempDir = await Directory.systemTemp.createTemp('mosl_ui_gap_');
    PathProviderPlatform.instance = _FakePathProvider(tempDir.path);
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  // ---------------------------------------------------------------------------
  // JsonScreen
  // ---------------------------------------------------------------------------
  group('JsonScreen', () {
    testWidgets('GET — shows loading indicator initially', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: JsonScreen(method: HttpMethod.get)),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('GET — shows error after Dio not initialized', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: JsonScreen(method: HttpMethod.get)),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Error:'), findsOneWidget);
    });

    testWidgets('POST — shows loading indicator initially', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: JsonScreen(method: HttpMethod.post)),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('POST — shows error after Dio not initialized', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: JsonScreen(method: HttpMethod.post)),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Error:'), findsOneWidget);
    });

    testWidgets('displays method name in AppBar', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: JsonScreen(method: HttpMethod.get)),
      );
      expect(find.text(HttpMethod.get.name), findsOneWidget);
    });

    testWidgets('POST method AppBar shows post name', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: JsonScreen(method: HttpMethod.post)),
      );
      expect(find.text(HttpMethod.post.name), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------
  // ProtoScreen
  // ---------------------------------------------------------------------------
  group('ProtoScreen', () {
    testWidgets('POST — shows loading then error when Dio not initialized', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: ProtoScreen(method: HttpMethod.post)),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.pumpAndSettle();
      expect(find.textContaining('Error:'), findsOneWidget);
    });

    testWidgets('GET — shows loading then error when Dio not initialized', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: ProtoScreen(method: HttpMethod.get)),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.pumpAndSettle();
      expect(find.textContaining('Error:'), findsOneWidget);
    });

    testWidgets('AppBar shows method name for get', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: ProtoScreen(method: HttpMethod.get)),
      );
      expect(find.text(HttpMethod.get.name), findsOneWidget);
    });

    testWidgets('AppBar shows method name for post', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: ProtoScreen(method: HttpMethod.post)),
      );
      expect(find.text(HttpMethod.post.name), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------
  // DownloadScreen
  // ---------------------------------------------------------------------------
  group('DownloadScreen', () {
    testWidgets('renders Download File button', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: DownloadScreen(downloadUrl: 'https://example.com/file.pdf'),
        ),
      );
      expect(find.text('Start Download'), findsOneWidget);
      expect(find.text('Download File'), findsOneWidget);
    });

    testWidgets('shows error snackbar when download fails (Dio not init)', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: DownloadScreen(downloadUrl: 'https://example.com/file.pdf'),
        ),
      );
      await tester.tap(find.text('Start Download'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Download failed:'), findsOneWidget);
    });

    testWidgets('routeName is correct', (tester) async {
      expect(DownloadScreen.routeName, '/download');
    });
  });

  // ---------------------------------------------------------------------------
  // CameraUploadScreen (UploadScreen)
  // ---------------------------------------------------------------------------
  group('CameraUploadScreen', () {
    testWidgets('renders initial UI elements', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: CameraUploadScreen()));

      expect(find.text('Camera Capture & Upload'), findsOneWidget);
      expect(find.text('No image captured'), findsOneWidget);
      expect(find.text('Capture & Upload'), findsOneWidget);
    });

    testWidgets('permission denied shows snackbar', (tester) async {
      PermissionHandlerPlatform.instance =
          _FakePermissionHandler(PermissionStatus.denied);

      await tester.pumpWidget(const MaterialApp(home: CameraUploadScreen()));
      await tester.tap(find.text('Capture & Upload'));
      await tester.pumpAndSettle();

      expect(find.text('Camera permission denied'), findsOneWidget);
    });

    testWidgets('routeName is correct', (tester) async {
      expect(CameraUploadScreen.routeName, '/upload');
    });
  });
}
