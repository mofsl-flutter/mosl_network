import 'dart:io';
import 'package:base_network/helper/network_file_logger.dart';
import 'package:base_network/helper/network_log_interceptor.dart';
import 'package:base_network/models/network_interceptor_model.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';

class NetworkLogsScreen extends StatefulWidget {
  const NetworkLogsScreen({super.key});

  @override
  NetworkLogsScreenState createState() => NetworkLogsScreenState();
}

class NetworkLogsScreenState extends State<NetworkLogsScreen> {
  final NetworkLoggerInterceptor logger = NetworkLoggerInterceptor();
  bool _isSharing = false;

  Future<void> _shareLogs() async {
    setState(() => _isSharing = true);
    try {
      final Directory tempDir = await getTemporaryDirectory();
      final File exportFile = File('${tempDir.path}/network_logs_export.txt');

      // Get all logs from FileLogger
      final List<String> logs = await FileLogger().readLogs(maxLines: 10000);

      if (logs.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No logs available to share')),
        );
        return;
      }

      // Write logs to temporary file
      await exportFile.writeAsString(logs.join('\n'));

      // Share the file
      if (!mounted) return;
      await Share.shareXFiles(
        <XFile>[XFile(exportFile.path)],
        text: 'Network Logs Export',
        subject: 'Network Logs from ${DateTime.now().toLocal()}',
        sharePositionOrigin: Rect.fromPoints(
          Offset.zero,
          Offset(MediaQuery.of(context).size.width, MediaQuery.of(context).size.height),
        ),
      );
    } on Exception catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sharing logs: $e')),
      );
    } finally {
      setState(() => _isSharing = false);
    }
  }

  @override
  Widget build(final BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Network Logs'),
        actions: <Widget>[
          IconButton(
            icon: _isSharing
                ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator())
                : const Icon(Icons.share),
            onPressed: _isSharing ? null : _shareLogs,
            tooltip: 'Export Logs',
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () {
              logger.clearLogs();
              setState(() {});
            },
          ),
        ],
      ),
      body: ListView.builder(
        itemCount: logger.networkLogs.length,
        itemBuilder: (final BuildContext context, final int index) {
          final IntercepterResponseModel log = logger.networkLogs.reversed.toList()[index];
          return _NetworkLogItem(log: log);
        },
      ),
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<NetworkLoggerInterceptor>('logger', logger));
  }
}

class _NetworkLogItem extends StatelessWidget {
  const _NetworkLogItem({required this.log});

  final IntercepterResponseModel log;

  @override
  Widget build(final BuildContext context) {
    return ExpansionTile(
      title: Text(
        '${log.method} ${log.origin}${log.query}',
        style: TextStyle(
          color: _statusColor(log.responseStatusCode),
        ),
      ),
      subtitle: Text('Status: ${log.responseStatusCode} - ${log.responseTime}'),
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _buildInfoRow('Time', log.createdAt),
              _buildInfoRow('Status', '${log.responseStatusCode} ${log.responseStatusMessage}'),
              _buildInfoRow("Query Params", log.queryParam ?? ''),
              _buildInfoRow('Duration', log.responseTime ?? 'N/A'),
              _buildInfoRow('Size', log.responseSize),
              _buildInfoRow('Headers', log.responseHeader),
              _buildInfoRow('Request Headers', '''
                Accept: ${log.accept}
                Content-Type: ${log.contentType}
                X-Api-Version: ${log.xApiVersion}
                Authorization: ${log.authorization?.isNotEmpty ?? false ? '*****' : 'None'}
              '''),
              // _buildInfoRow('Response Body', log.responseBody.toString()),
            ],
          ),
        ),
      ],
    );
  }

  Color _statusColor(final String statusCode) {
    final int code = int.tryParse(statusCode) ?? 500;
    if (code >= 200 && code < 300) return Colors.green;
    if (code >= 300 && code < 400) return Colors.orange;
    return Colors.red;
  }

  Widget _buildInfoRow(final String title, final String content) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Text(
            content,
            style: const TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<IntercepterResponseModel>('log', log));
  }
}
