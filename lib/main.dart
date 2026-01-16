import 'package:base_network/models/api_enums.dart' show HttpMethod;
import 'package:flutter/material.dart';
import 'package:mosl_network/network/dio_cache_manager.dart' show CacheManager;
import 'package:mosl_network/network/dio_impl.dart';
import 'package:mosl_network/network/helper/preferences.dart';
import 'package:mosl_network/network/helper/token_renewal.dart'
    show TokenRenewalHelper;
import 'package:mosl_network/shared_preference/shared_preferences_provider.dart';
import 'package:mosl_network/ui/download_screen.dart' show DownloadScreen;
import 'package:mosl_network/ui/json_screen.dart';
import 'package:mosl_network/ui/proto_screen.dart' show ProtoScreen;
import 'package:mosl_network/ui/upload_screen.dart' show CameraUploadScreen, FileUploadScreen;

final futureList = Future.value([
  SharedPreferencesProvider.init(),
  CacheManager().init(),
]);

final Set<String> skipAccessTokenCheckApis = {
  'Login/RenewSession',
  'Login/Token',
};

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Wait for all async initializations
    await Future.wait([
      SharedPreferencesProvider.init(),
      CacheManager().init(),
    ]);

    Preferences.init(
      token: 'eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.eyJfaWQiOiIwSE5ES01RTjNRNkg5OjAwMDAwMDAxIiwidW5pcXVlX25hbWUiOiJBQTAyMCIsInJvbGUiOiJUIiwiYXBwaWQiOiI3Mzc4ODdmNi1kODkxLTQ2NTgtODk0YS0xMDg5YmJjNTU5MTQiLCJmbGFncyI6IjE2IiwicGludGtuIjoicGFUbXNVRnJ6Yk5zYy9VeUNPTzFTRFpZRWxBd21jdDZ6Zm5RWWN6c2ZCVDVIN3EzTi93VlZjUFFLVC95enMwNSIsInVjaWQiOiI0OTk3NjY1IiwidXNlcm1hc3RlcmlkIjoiMTA4NDI1MCIsIlVzZXJJZCI6IiIsIm1vYmlsZSI6IjgxMDQ5NTE1MzQiLCJ1c2FjY291bnRpZCI6IiIsInVzYWNjb3VudG5vIjoiIiwidXNlcXVpdHljbGllbnRpZCI6IiIsIm5hbWUiOiJST0hJVCBTSElWS1VNQVIgR1VQVEEiLCJlbWFpbGlkIjoiU0hJVktVTUFSR1VQVEE2M0BHTUFJTC5DT00iLCJjbGllbnR0eXBlIjoiSU5EIiwiSCI6IiIsIk5BIjoiIiwiYWlvIjoiIiwibmJmIjoxNzUxNTQ0OTcxLCJleHAiOjE3NTE1NTk2NzEsImlhdCI6MTc1MTU0NTI3MSwiaXNzIjoibG9naW5fYXBpIiwiYXVkIjoidHJhZGluZ19hcGlzIn0.YGIDu6lEcH099MWNwX0mQ-ul4G8Pb8zAco-chkiQZuPjjQL2b-rt6jt4_QRwJUfdDO2sDhv6PW4TvRpO_Ep_ChEFomQYpHPUicCBSGnlJfScd5kTmwR6VAOwuozUJex2tbqNVqGTn2w7ZhlDj0huT9JfKhMgzzu1DgSqU8vMNSuxHSP-PMt9SJixBLsI9qdR7usB9QaWCtRtRxO4T4ldiPGIASwiokAtPQzEPwkb2HZz8sT5EK-UgTQH7meO_5FXWFMH0280ZoMPKarzJKx3FGKCRbfWeob-XCuvVMoYihKvQen4L-zLxeZT8t9Sy7jmBfHg2FGRWeivF5-XrcjCAA',
      userAgent: 'Android/14/SuperApp/6.0.28(UAT-27)_6025/IN/737887f6-d891-4658-894a-1089bbc55914',
      refreshToken: 'refressh',//'eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.eyJfaWQiOiIwSE5ES01RTjNQQzBTOjAwMDAwMDAxIiwidW5pcXVlX25hbWUiOiJBQTAyMCIsInJvbGUiOiJUIiwiYXBwaWQiOiJkNzA0ZTZiYS02OTI1LTQzMDItODlhYi04OWM4YTYxNmE4MjciLCJmbGFncyI6IjE2IiwicGludGtuIjoiZzU2Qnp1b0ovc0NnZ2d1aDNTZWRrUTA2OXBKYTNERXN5TDFQVkl3REZROGsyMmdLQlpOMDNCdTlSU0UvQXgxayIsInVjaWQiOiI0OTk3NjY1IiwidXNlcm1hc3RlcmlkIjoiMTA4NDI1MCIsIlVzZXJJZCI6IiIsIm1vYmlsZSI6IjgxMDQ5NTE1MzQiLCJ1c2FjY291bnRpZCI6IiIsInVzYWNjb3VudG5vIjoiIiwidXNlcXVpdHljbGllbnRpZCI6IiIsIm5hbWUiOiJST0hJVCBTSElWS1VNQVIgR1VQVEEiLCJlbWFpbGlkIjoiU0hJVktVTUFSR1VQVEE2M0BHTUFJTC5DT00iLCJjbGllbnR0eXBlIjoiSU5EIiwiSCI6IiIsIk5BIjoiIiwiYWlvIjoiIiwibmJmIjoxNzUxMDQ1MDU1LCJleHAiOjE3NTI0Mjc3NTUsImlhdCI6MTc1MTA0NTM1NSwiaXNzIjoibG9naW5fYXBpIiwiYXVkIjoidG9rZW5fYXBpIn0.STr5NBK68FD4Xc-XUetbguzaVWpQCxl1XukZc6iaBhpchiHcv0gVIaPBeGYL9rpuYYI1OB5S-MoDhX9FsjHut57nG89nVmZgUh9RdbPqMDHMGT_wPHBlyA-pzrmjOEsn1eF17MhEwzxenpeRFppKNKUI0VqZBoV-m3ap5HDmA-uIY2DF_yqJwhQ25sD32AF2IlKG6pjwl4BhyEBCwuzRyL4MY2Yxxxfjy6RS8htLRxYDhogqzjqi5Guo84SPtthJGvWoZrOKjGqM_7_k3voFiCAT0-Fljb86WCJBpBU7keF5t9m0N_ejPDzNfPqHXaYTPhlzV6Ct_BWOAsyNyS8ldw',
    );

    DioImpl.init(
      cacheManager: CacheManager(),
      tokenManager: TokenRenewalHelper(),
      urlsShouldNotFire401: skipAccessTokenCheckApis,
    );

    runApp(const MyApp());
  } catch (error, stackTrace) {
    debugPrint("Error during initialization: $error");
    debugPrintStack(stackTrace: stackTrace);
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
      onGenerateRoute: (RouteSettings settings) {
        switch (settings.name) {
          case ProtoScreen.routeName:
            final args = settings.arguments as HttpMethod;
            return MaterialPageRoute(
              builder: (context) => ProtoScreen(method: args),
            );
          case DownloadScreen.routeName:
            final args = settings.arguments as String;
            return MaterialPageRoute(
              builder: (context) => DownloadScreen(downloadUrl: args),
            );
          case JsonScreen.routeName:
            final args = settings.arguments as HttpMethod;
            return MaterialPageRoute(
              builder: (context) => JsonScreen(method: args),
            );
          case CameraUploadScreen.routeName:
            return MaterialPageRoute(
              builder: (context) => const CameraUploadScreen(),
            );
          default:
            return MaterialPageRoute(
              builder:
                  (context) => const Scaffold(
                    body: Center(child: Text('Unknown route')),
                  ),
            );
        }
      },
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  @override
  Widget build(BuildContext context) {
    return ApiButtonGrid();
  }
}

class ApiButtonGrid extends StatelessWidget {
  final List<String> buttonLabels = [
    'Get Proto',
    'Post Proto',
    'Get Json',
    'Post Json',
    'Upload File',
    'Download File',
  ];

  ApiButtonGrid({super.key});

  void _handleNavigation(String label, BuildContext context) {
    switch (label) {
      case 'Get Proto':
      case 'Post Proto':
        Navigator.pushNamed(
          context,
          ProtoScreen.routeName,
          arguments: label == 'Get Proto' ? HttpMethod.get : HttpMethod.post,
        );
        break;
      case 'Get Json':
      case 'Post Json':
        Navigator.pushNamed(
          context,
          JsonScreen.routeName,
          arguments: label == 'Get Json' ? HttpMethod.get : HttpMethod.post,
        );
        break;
      case 'Upload File':
        Navigator.pushNamed(
          context,
          CameraUploadScreen.routeName,
        );
        break;
      case 'Download File':
        Navigator.pushNamed(
          context,
          DownloadScreen.routeName,
          arguments: 'https://link.testfile.org/PDF10MB',
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('API Actions')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: GridView.count(
          crossAxisCount: 2,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          children:
              buttonLabels.map((label) {
                return ElevatedButton(
                  onPressed: () => _handleNavigation(label, context),
                  child: Text(label, textAlign: TextAlign.center),
                );
              }).toList(),
        ),
      ),
    );
  }
}
