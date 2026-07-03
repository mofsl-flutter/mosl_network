import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:base_network/models/api_enums.dart';
import 'package:mosl_network/main.dart';
import 'package:mosl_network/ui/download_screen.dart';
import 'package:mosl_network/ui/json_screen.dart';
import 'package:mosl_network/ui/proto_screen.dart';
import 'package:mosl_network/ui/upload_screen.dart';

void main() {
  testWidgets('MyApp shows API action grid on launch', (tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('API Actions'), findsOneWidget);
    expect(find.text('Get Proto'), findsOneWidget);
    expect(find.text('Post Proto'), findsOneWidget);
    expect(find.text('Get Json'), findsOneWidget);
    expect(find.text('Post Json'), findsOneWidget);

    await tester.drag(find.byType(GridView), const Offset(0, -300));
    await tester.pumpAndSettle();

    expect(find.text('Upload File'), findsOneWidget);
    expect(find.text('Download File'), findsOneWidget);
  });

  testWidgets('unknown route renders fallback screen', (tester) async {
    await tester.pumpWidget(const MyApp());

    final context = tester.element(find.text('API Actions'));
    Navigator.of(context).pushNamed('/missing');
    await tester.pumpAndSettle();

    expect(find.text('Unknown route'), findsOneWidget);
  });

  testWidgets('button taps navigate to expected screens', (tester) async {
    await tester.pumpWidget(const MyApp());

    await tester.tap(find.text('Get Proto'));
    await tester.pumpAndSettle();
    expect(find.byType(ProtoScreen), findsOneWidget);
    expect(find.text(HttpMethod.get.name), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.drag(find.byType(GridView), const Offset(0, -300));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Get Json'));
    await tester.pumpAndSettle();
    expect(find.byType(JsonScreen), findsOneWidget);
    expect(find.text(HttpMethod.get.name), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.drag(find.byType(GridView), const Offset(0, -300));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Upload File'));
    await tester.pumpAndSettle();
    expect(find.byType(CameraUploadScreen), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Download File'));
    await tester.pumpAndSettle();
    expect(find.byType(DownloadScreen), findsOneWidget);
  });
}
