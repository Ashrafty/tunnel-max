import 'dart:io';
import 'dart:convert';
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';

/// Logging levels for sing-box operations
enum SingboxLogLevel {
  trace,
  debug,
  info,
  warn,
  error,
  fatal,
}

/// Log entry for sing-box operations
class SingboxLogEntry {
  final DateTime timestamp;
  final SingboxLogLevel level;
  final String source;
  final String message;
  final Map<String, dynamic>? metadata;
  final String? stackTrace;

  SingboxLogEntry({
    required this.timestamp,
    required this.level,
    required this.source,
    required this.message,
    this.metadata,
    this.stackTrace,
  });

  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'level': level.name,
      'source': source,
      'message': message,
      'metadata': metadata,
      'stackTrace': stackTrace,
    };
  }

  factory SingboxLogEntry.fromJson(Map<String, dynamic> json) {
    return SingboxLogEntry(
      timestamp: DateTime.parse(json['timestamp']),
      level: SingboxLogLevel.values.firstWhere(
        (e) => e.name == json['level'],
        orElse: () => SingboxLogLevel.info,
      ),
      source: json['source'],
      message: json['message'],
      metadata: json['metadata'],
      stackTrace: json['stackTrace'],
    );
  }

  @override
  String toString() {
    final buffer = StringBuffer();
    buffer.write('[${timestamp.toIso8601String()}] ');
    buffer.write('[${level.name.toUpperCase()}] ');
    buffer.write('[$source] ');
    buffer.write(message);
    
    if (metadata != null && metadata!.isNotEmpty) {
      buffer.write(' | Metadata: ${jsonEncode(metadata)}');
    }
    
    if (stackTrace != null) {
      buffer.write('\nStack trace: $stackTrace');
    }
    
    return buffer.toString();
  }
}

/// Comprehensive logging and debugging infrastructure for sing-box operations
class SingboxLogger {
  static SingboxLogger? _instance;
  static SingboxLogger get instance => _instance ??= SingboxLogger._();

  final Logger _logger;
  final List<SingboxLogEntry> _logBuffer = [];
  final int _maxBufferSize = 1000;
  bool _debugMode = false;
  bool _verboseLogging = false;
  bool _fileLoggingEnabled = false;
  File? _logFile;

  SingboxLogger._() : _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 2,
      errorMethodCount: 8,
      lineLength: 120,
      colors: true,
      printEmojis: true,
      dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
    ),
  );

  /// Initialize the logger with configuration
  Future<void> initialize({
    bool debugMode = false,
    bool verboseLogging = false,
    bool fileLoggingEnabled = false,
  }) async {
    _debugMode = debugMode;
    _verboseLogging = verboseLogging;
    _fileLoggingEnabled = fileLoggingEnabled;

    if (_fileLoggingEnabled) {
      await _initializeFileLogging();
    }

    log(
      SingboxLogLevel.info,
      'SingboxLogger',
      'Logger initialized',
      metadata: {
        'debugMode': _debugMode,
        'verboseLogging': _verboseLogging,
        'fileLoggingEnabled': _fileLoggingEnabled,
      },
    );
  }

  /// Enable or disable debug mode
  void setDebugMode(bool enabled) {
    _debugMode = enabled;
    log(
      SingboxLogLevel.info,
      'SingboxLogger',
      'Debug mode ${enabled ? "enabled" : "disabled"}',
    );
  }

  /// Enable or disable verbose logging
  void setVerboseLogging(bool enabled) {
    _verboseLogging = enabled;
    log(
      SingboxLogLevel.info,
      'SingboxLogger',
      'Verbose logging ${enabled ? "enabled" : "disabled"}',
    );
  }

  /// Enable or disable file logging
  Future<void> setFileLogging(bool enabled) async {
    _fileLoggingEnabled = enabled;
    if (enabled && _logFile == null) {
      await _initializeFileLogging();
    }
    log(
      SingboxLogLevel.info,
      'SingboxLogger',
      'File logging ${enabled ? "enabled" : "disabled"}',
    );
  }

  /// Log a message with specified level and source
  void log(
    SingboxLogLevel level,
    String source,
    String message, {
    Map<String, dynamic>? metadata,
    String? stackTrace,
  }) {
    final entry = SingboxLogEntry(
      timestamp: DateTime.now(),
      level: level,
      source: source,
      message: message,
      metadata: metadata,
      stackTrace: stackTrace,
    );

    // Add to buffer
    _addToBuffer(entry);

    // Log to console based on level and settings
    if (_shouldLogToConsole(level)) {
      _logToConsole(entry);
    }

    // Log to file if enabled
    if (_fileLoggingEnabled) {
      _logToFile(entry);
    }
  }

  /// Log trace level message
  void trace(String source, String message, {Map<String, dynamic>? metadata}) {
    if (_verboseLogging) {
      log(SingboxLogLevel.trace, source, message, metadata: metadata);
    }
  }

  /// Log debug level message
  void debug(String source, String message, {Map<String, dynamic>? metadata}) {
    if (_debugMode || _verboseLogging) {
      log(SingboxLogLevel.debug, source, message, metadata: metadata);
    }
  }

  /// Log info level message
  void info(String source, String message, {Map<String, dynamic>? metadata}) {
    log(SingboxLogLevel.info, source, message, metadata: metadata);
  }

  /// Log warning level message
  void warn(String source, String message, {Map<String, dynamic>? metadata}) {
    log(SingboxLogLevel.warn, source, message, metadata: metadata);
  }

  /// Log error level message
  void error(
    String source,
    String message, {
    Map<String, dynamic>? metadata,
    dynamic error,
    StackTrace? stackTrace,
  }) {
    log(
      SingboxLogLevel.error,
      source,
      message,
      metadata: {
        ...?metadata,
        if (error != null) 'error': error.toString(),
      },
      stackTrace: stackTrace?.toString(),
    );
  }

  /// Log fatal level message
  void fatal(
    String source,
    String message, {
    Map<String, dynamic>? metadata,
    dynamic error,
    StackTrace? stackTrace,
  }) {
    log(
      SingboxLogLevel.fatal,
      source,
      message,
      metadata: {
        ...?metadata,
        if (error != null) 'error': error.toString(),
      },
      stackTrace: stackTrace?.toString(),
    );
  }

  /// Log operation timing
  void logOperationTiming(
    String source,
    String operation,
    Duration duration, {
    bool success = true,
    Map<String, dynamic>? metadata,
  }) {
    log(
      success ? SingboxLogLevel.info : SingboxLogLevel.warn,
      source,
      'Operation "$operation" ${success ? "completed" : "failed"} in ${duration.inMilliseconds}ms',
      metadata: {
        'operation': operation,
        'duration_ms': duration.inMilliseconds,
        'success': success,
        ...?metadata,
      },
    );
  }

  /// Log configuration validation
  void logConfigurationValidation(
    String source,
    String protocol,
    bool isValid, {
    List<String>? errors,
    Map<String, dynamic>? configMetadata,
  }) {
    log(
      isValid ? SingboxLogLevel.info : SingboxLogLevel.error,
      source,
      'Configuration validation ${isValid ? "PASSED" : "FAILED"} for protocol $protocol',
      metadata: {
        'protocol': protocol,
        'isValid': isValid,
        'errors': errors,
        'configMetadata': configMetadata,
      },
    );
  }

  /// Log process lifecycle events
  void logProcessLifecycle(
    String source,
    String event,
    String message, {
    Map<String, dynamic>? processInfo,
  }) {
    log(
      SingboxLogLevel.info,
      source,
      'Process lifecycle: $event - $message',
      metadata: {
        'event': event,
        'processInfo': processInfo,
      },
    );
  }

  /// Log native sing-box output
  void logNativeOutput(
    String source,
    String output, {
    String nativeSource = 'singbox-native',
  }) {
    if (!_debugMode && !_verboseLogging) return;

    final lines = output.split('\n');
    for (final line in lines) {
      if (line.trim().isNotEmpty) {
        log(
          SingboxLogLevel.debug,
          source,
          'Native[$nativeSource]: $line',
          metadata: {
            'nativeSource': nativeSource,
            'rawOutput': line,
          },
        );
      }
    }
  }

  /// Get recent log entries
  List<SingboxLogEntry> getRecentLogs({
    int? limit,
    SingboxLogLevel? minLevel,
    String? source,
  }) {
    var logs = List<SingboxLogEntry>.from(_logBuffer);

    // Filter by source if specified
    if (source != null) {
      logs = logs.where((entry) => entry.source == source).toList();
    }

    // Filter by minimum level if specified
    if (minLevel != null) {
      final minLevelIndex = SingboxLogLevel.values.indexOf(minLevel);
      logs = logs.where((entry) {
        final entryLevelIndex = SingboxLogLevel.values.indexOf(entry.level);
        return entryLevelIndex >= minLevelIndex;
      }).toList();
    }

    // Sort by timestamp (newest first)
    logs.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    // Apply limit if specified
    if (limit != null && logs.length > limit) {
      logs = logs.take(limit).toList();
    }

    return logs;
  }

  /// Get error history
  List<SingboxLogEntry> getErrorHistory({int? limit}) {
    return getRecentLogs(
      limit: limit,
      minLevel: SingboxLogLevel.error,
    );
  }

  /// Clear log buffer
  void clearLogs() {
    _logBuffer.clear();
    log(SingboxLogLevel.info, 'SingboxLogger', 'Log buffer cleared');
  }

  /// Generate diagnostic report
  Map<String, dynamic> generateDiagnosticReport() {
    final now = DateTime.now();
    final errorCount = _logBuffer.where((e) => e.level == SingboxLogLevel.error).length;
    final warnCount = _logBuffer.where((e) => e.level == SingboxLogLevel.warn).length;

    return {
      'timestamp': now.toIso8601String(),
      'configuration': {
        'debugMode': _debugMode,
        'verboseLogging': _verboseLogging,
        'fileLoggingEnabled': _fileLoggingEnabled,
        'logFilePath': _logFile?.path,
      },
      'statistics': {
        'totalLogEntries': _logBuffer.length,
        'errorCount': errorCount,
        'warningCount': warnCount,
        'bufferSize': _maxBufferSize,
      },
      'recentErrors': getErrorHistory(limit: 10).map((e) => e.toJson()).toList(),
      'logSources': _getLogSources(),
    };
  }

  /// Export logs to JSON format
  Future<String> exportLogsAsJson({
    int? limit,
    SingboxLogLevel? minLevel,
  }) async {
    final logs = getRecentLogs(limit: limit, minLevel: minLevel);
    final exportData = {
      'exportTimestamp': DateTime.now().toIso8601String(),
      'totalEntries': logs.length,
      'configuration': {
        'debugMode': _debugMode,
        'verboseLogging': _verboseLogging,
      },
      'logs': logs.map((e) => e.toJson()).toList(),
    };

    return jsonEncode(exportData);
  }

  /// Export logs to file
  Future<File?> exportLogsToFile({
    String? fileName,
    int? limit,
    SingboxLogLevel? minLevel,
  }) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
      final file = File('${directory.path}/${fileName ?? "singbox_logs_$timestamp"}.json');

      final jsonData = await exportLogsAsJson(limit: limit, minLevel: minLevel);
      await file.writeAsString(jsonData);

      log(
        SingboxLogLevel.info,
        'SingboxLogger',
        'Logs exported to file: ${file.path}',
        metadata: {'filePath': file.path, 'entriesCount': limit},
      );

      return file;
    } catch (e, stackTrace) {
      error(
        'SingboxLogger',
        'Failed to export logs to file',
        error: e,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  // Private methods

  Future<void> _initializeFileLogging() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final logsDir = Directory('${directory.path}/singbox_logs');
      if (!await logsDir.exists()) {
        await logsDir.create(recursive: true);
      }

      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
      _logFile = File('${logsDir.path}/singbox_$timestamp.log');
    } catch (e) {
      _logger.e('Failed to initialize file logging: $e');
    }
  }

  void _addToBuffer(SingboxLogEntry entry) {
    _logBuffer.add(entry);
    if (_logBuffer.length > _maxBufferSize) {
      _logBuffer.removeAt(0);
    }
  }

  bool _shouldLogToConsole(SingboxLogLevel level) {
    switch (level) {
      case SingboxLogLevel.trace:
        return _verboseLogging;
      case SingboxLogLevel.debug:
        return _debugMode || _verboseLogging;
      case SingboxLogLevel.info:
      case SingboxLogLevel.warn:
      case SingboxLogLevel.error:
      case SingboxLogLevel.fatal:
        return true;
    }
  }

  void _logToConsole(SingboxLogEntry entry) {
    switch (entry.level) {
      case SingboxLogLevel.trace:
      case SingboxLogLevel.debug:
        _logger.d(entry.toString());
        break;
      case SingboxLogLevel.info:
        _logger.i(entry.toString());
        break;
      case SingboxLogLevel.warn:
        _logger.w(entry.toString());
        break;
      case SingboxLogLevel.error:
        _logger.e(entry.toString());
        break;
      case SingboxLogLevel.fatal:
        _logger.f(entry.toString());
        break;
    }
  }

  void _logToFile(SingboxLogEntry entry) {
    if (_logFile == null) return;

    try {
      _logFile!.writeAsStringSync(
        '${entry.toString()}\n',
        mode: FileMode.append,
      );
    } catch (e) {
      // Avoid infinite recursion by not logging this error
      _logger.e('Failed to write to log file: $e');
    }
  }

  List<String> _getLogSources() {
    final sources = <String>{};
    for (final entry in _logBuffer) {
      sources.add(entry.source);
    }
    return sources.toList()..sort();
  }
}

/// Extension methods for easier logging
extension SingboxLoggerExtension on Object {
  void logTrace(String message, {Map<String, dynamic>? metadata}) {
    SingboxLogger.instance.trace(runtimeType.toString(), message, metadata: metadata);
  }

  void logDebug(String message, {Map<String, dynamic>? metadata}) {
    SingboxLogger.instance.debug(runtimeType.toString(), message, metadata: metadata);
  }

  void logInfo(String message, {Map<String, dynamic>? metadata}) {
    SingboxLogger.instance.info(runtimeType.toString(), message, metadata: metadata);
  }

  void logWarn(String message, {Map<String, dynamic>? metadata}) {
    SingboxLogger.instance.warn(runtimeType.toString(), message, metadata: metadata);
  }

  void logError(
    String message, {
    Map<String, dynamic>? metadata,
    dynamic error,
    StackTrace? stackTrace,
  }) {
    SingboxLogger.instance.error(
      runtimeType.toString(),
      message,
      metadata: metadata,
      error: error,
      stackTrace: stackTrace,
    );
  }

  void logFatal(
    String message, {
    Map<String, dynamic>? metadata,
    dynamic error,
    StackTrace? stackTrace,
  }) {
    SingboxLogger.instance.fatal(
      runtimeType.toString(),
      message,
      metadata: metadata,
      error: error,
      stackTrace: stackTrace,
    );
  }
}