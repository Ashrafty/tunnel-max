import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:logger/logger.dart';

/// Service for managing application logs
class LogsService {
  static const String _logFileName = 'tunnel_max.log';
  static const int _maxLogFileSize = 5 * 1024 * 1024; // 5MB
  static const int _maxLogFiles = 3;
  
  final Logger _logger;
  File? _logFile;

  LogsService({Logger? logger}) : _logger = logger ?? Logger();

  /// Initializes the logs service and sets up log file
  Future<void> initialize() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final logsDir = Directory(path.join(appDir.path, 'logs'));
      
      if (!await logsDir.exists()) {
        await logsDir.create(recursive: true);
      }
      
      _logFile = File(path.join(logsDir.path, _logFileName));
      _logger.i('Logs service initialized: ${_logFile?.path}');
    } catch (e) {
      _logger.e('Failed to initialize logs service: $e');
    }
  }

  /// Writes a log entry to the log file
  Future<void> writeLog(String level, String message) async {
    if (_logFile == null) {
      await initialize();
    }
    
    try {
      final timestamp = DateTime.now().toIso8601String();
      final logEntry = '[$timestamp] [$level] $message\n';
      
      await _logFile!.writeAsString(logEntry, mode: FileMode.append);
      
      // Check if log rotation is needed
      await _rotateLogsIfNeeded();
    } catch (e) {
      _logger.e('Failed to write log: $e');
    }
  }

  /// Reads all log entries from the current log file
  Future<List<String>> readLogs() async {
    if (_logFile == null) {
      await initialize();
    }
    
    try {
      if (!await _logFile!.exists()) {
        return [];
      }
      
      final content = await _logFile!.readAsString();
      return content.split('\n').where((line) => line.isNotEmpty).toList();
    } catch (e) {
      _logger.e('Failed to read logs: $e');
      return [];
    }
  }

  /// Gets recent log entries (last N entries)
  Future<List<String>> getRecentLogs({int count = 100}) async {
    final allLogs = await readLogs();
    if (allLogs.length <= count) {
      return allLogs;
    }
    return allLogs.sublist(allLogs.length - count);
  }

  /// Clears all log files
  Future<void> clearLogs() async {
    try {
      if (_logFile != null && await _logFile!.exists()) {
        await _logFile!.delete();
      }
      
      // Also clear rotated log files
      final appDir = await getApplicationDocumentsDirectory();
      final logsDir = Directory(path.join(appDir.path, 'logs'));
      
      if (await logsDir.exists()) {
        await for (final file in logsDir.list()) {
          if (file is File && file.path.contains(_logFileName)) {
            await file.delete();
          }
        }
      }
      
      _logger.i('All logs cleared');
    } catch (e) {
      _logger.e('Failed to clear logs: $e');
    }
  }

  /// Exports logs to a shareable format
  Future<File?> exportLogs() async {
    try {
      final allLogs = await readLogs();
      if (allLogs.isEmpty) {
        return null;
      }
      
      final tempDir = await getTemporaryDirectory();
      final exportFile = File(path.join(tempDir.path, 'tunnel_max_logs_export.txt'));
      
      final exportContent = allLogs.join('\n');
      await exportFile.writeAsString(exportContent);
      
      _logger.i('Logs exported to: ${exportFile.path}');
      return exportFile;
    } catch (e) {
      _logger.e('Failed to export logs: $e');
      return null;
    }
  }

  /// Rotates log files if the current file is too large
  Future<void> _rotateLogsIfNeeded() async {
    if (_logFile == null || !await _logFile!.exists()) {
      return;
    }
    
    try {
      final fileSize = await _logFile!.length();
      if (fileSize > _maxLogFileSize) {
        await _rotateLogs();
      }
    } catch (e) {
      _logger.e('Failed to check log file size: $e');
    }
  }

  /// Rotates log files by renaming current file and creating a new one
  Future<void> _rotateLogs() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final logsDir = Directory(path.join(appDir.path, 'logs'));
      
      // Rotate existing files
      for (int i = _maxLogFiles - 1; i > 0; i--) {
        final oldFile = File(path.join(logsDir.path, '$_logFileName.$i'));
        final newFile = File(path.join(logsDir.path, '$_logFileName.${i + 1}'));
        
        if (await oldFile.exists()) {
          if (i == _maxLogFiles - 1) {
            await oldFile.delete(); // Delete oldest file
          } else {
            await oldFile.rename(newFile.path);
          }
        }
      }
      
      // Rename current log file
      if (_logFile != null && await _logFile!.exists()) {
        final rotatedFile = File(path.join(logsDir.path, '$_logFileName.1'));
        await _logFile!.rename(rotatedFile.path);
      }
      
      // Create new log file
      _logFile = File(path.join(logsDir.path, _logFileName));
      
      _logger.i('Log files rotated');
    } catch (e) {
      _logger.e('Failed to rotate logs: $e');
    }
  }
}