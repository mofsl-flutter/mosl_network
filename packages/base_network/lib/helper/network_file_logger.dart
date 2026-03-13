import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:synchronized/synchronized.dart';

class FileLogger {
  static final FileLogger _instance = FileLogger._internal();

  factory FileLogger() => _instance;

  FileLogger._internal();

  static const String _logFolder = 'network_logs';
  static const int _maxFileSize = 2 * 1024 * 1024; // 2MB
  static const int _maxFiles = 5; // Keep last 5 log files
  static const String _logPrefix = 'network_log';
  static const String _logExtension = '.txt';

  final Lock _lock = Lock();
  Directory? _logDirectory;
  RandomAccessFile? _currentFile;
  int _currentFileIndex = 0;

  Future<void> initialize() async {
    try {
      await _lock.synchronized(() async {
        if (_logDirectory != null) return;

        final Directory appDocDir = await getApplicationDocumentsDirectory();
        _logDirectory = Directory(path.join(appDocDir.path, _logFolder));

        if (!_logDirectory!.existsSync()) {
          await _logDirectory!.create(recursive: true);
        }

        await _rotateLogsIfNeeded();
        await _openNextFile();
      });
    } on Exception catch (exception) {
      debugPrint("VVK : No such file or directory $exception");
    }
  }

  Future<void> _rotateLogsIfNeeded() async {
    final List<File> files = await _logDirectory!
        .list()
        .where((final FileSystemEntity entity) => entity is File)
        .map((final FileSystemEntity entity) => entity as File)
        .toList();

    // Sort files by modified time
    files.sort((final File a, final File b) => b.statSync().modified.compareTo(a.statSync().modified));

    // Delete oldest files if over limit
    while (files.length >= _maxFiles) {
      await files.removeLast().delete();
    }
  }

  Future<void> _openNextFile() async {
    _currentFileIndex = await _getNextFileIndex();
    final String fileName = '$_logPrefix${_currentFileIndex.toString().padLeft(3, '0')}$_logExtension';
    final File file = File(path.join(_logDirectory!.path, fileName));

    _currentFile = await file.open(mode: FileMode.writeOnlyAppend);
  }

  Future<int> _getNextFileIndex() async {
    final List<FileSystemEntity> files = await _logDirectory!.list().toList();
    if (files.isEmpty) return 0;

    final File? lastFile = files
        .whereType<File>()
        .where((final File f) => f.path.endsWith(_logExtension))
        .fold<File?>(
            null,
            (final File? prev, final File element) =>
                prev == null || element.path.compareTo(prev.path) > 0 ? element : prev);

    return lastFile != null ? _extractFileNumber(lastFile.path) + 1 : 0;
  }

  int _extractFileNumber(final String? filePath) {
    if (filePath == null) return -1;
    final String fileName = path.basename(filePath);
    final RegExp regex = RegExp(r'(\d{3})' + _logExtension + r'$');
    final RegExpMatch? match = regex.firstMatch(fileName);
    return match != null ? int.parse(match.group(1)!) : -1;
  }

  Future<void> writeLog(final String message, {final String level = 'INFO'}) async {
    await initialize();
    await _lock.synchronized(() async {
      final String timestamp = DateTime.now().toIso8601String();
      final String logEntry = '[$timestamp][$level] $message\n';

      // Check current file size
      final int position = await _currentFile!.position();
      if (position + logEntry.length > _maxFileSize) {
        await _currentFile!.close();
        await _openNextFile();
        await _rotateLogsIfNeeded();
      }

      await _currentFile!.writeString(logEntry);
    });
  }

  Future<List<String>> readLogs({final int maxLines = 100}) async {
    await initialize();
    return await _lock.synchronized(() async {
      final List<File> files = await _logDirectory!
          .list()
          .where((final FileSystemEntity entity) => entity is File)
          .map((final FileSystemEntity entity) => entity as File)
          .toList();

      files.sort((final File a, final File b) => b.path.compareTo(a.path));

      final List<String> lines = <String>[];
      for (final File file in files) {
        final List<String> content = await file.readAsLines();
        lines.addAll(content.reversed);
        if (lines.length >= maxLines) break;
      }

      return lines.take(maxLines).toList().reversed.toList();
    });
  }

  Future<void> clearLogs() async {
    await initialize();
    await _lock.synchronized(() async {
      if (_logDirectory!.existsSync()) {
        await _logDirectory!.delete(recursive: true);
        await _logDirectory!.create();
        await _openNextFile();
      }
    });
  }

  Future<String> get currentLogPath async {
    await initialize();
    return path.join(_logDirectory!.path,
        '$_logPrefix${_currentFileIndex.toString().padLeft(3, '0')}$_logExtension');
  }
}
