
import 'package:base_network/models/api_enums.dart';
import 'package:flutter/material.dart';
import 'package:mosl_network/network/dio_impl.dart';
import 'package:mosl_network/network/helper/api_request_builder.dart';
import 'package:mosl_network/network/models/no_response.dart';
import 'package:path_provider/path_provider.dart';

class DownloadScreen extends StatefulWidget {
  final String downloadUrl;

  const DownloadScreen({super.key, required this.downloadUrl});

  static const routeName = '/download';

  @override
  State<DownloadScreen> createState() => _DownloadScreenState();
}

class _DownloadScreenState extends State<DownloadScreen> {
  double _progress = 0;
  Future<void> _downloadFile(String url) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final filePath = '${directory.path}/${url.split('/').last}';

      StateSetter? dialogSetState;
      _progress = 0.0;

      if (!mounted) return;
      _showDownloadDialog(context, (setter) => dialogSetState = setter);

      final request = ApiRequestBuilder()
          .url(url)
          .savePath(filePath)
          .requestType(HttpMethod.download)
          .onReceiveProgress((count, total) {
        if (total > 0 && dialogSetState != null) {
          final value = count / total;
          dialogSetState!(() {
            _progress = value;
          });
        }
      })
          .build();

      await DioImpl().callApiWithDioClient(request, NoResponse());

      if (mounted) {
        Navigator.of(context).pop(); // Close progress dialog
        _showSuccessSnackBar(filePath);
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // Close progress dialog
        _showErrorSnackBar(e.toString());
      }
    }
  }

  void _showDownloadDialog(BuildContext context, Function(StateSetter) onBuilderReady) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setState) {
            onBuilderReady(setState); // Expose setState to outer scope
            return AlertDialog(
              title: const Text('Downloading...'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  LinearProgressIndicator(value: _progress),
                  const SizedBox(height: 16),
                  Text('${(_progress * 100).toStringAsFixed(0)}%'),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showSuccessSnackBar(String path) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Download complete: $path'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showErrorSnackBar(String error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Download failed: $error'),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Download File')),
      body: Center(
        child: ElevatedButton(
          onPressed: () => _downloadFile(widget.downloadUrl),
          child: const Text('Start Download'),
        ),
      ),
    );
  }
}
