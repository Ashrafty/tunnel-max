import 'dart:io';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import 'singbox_logger.dart';

/// Diagnostic information categories
enum DiagnosticCategory {
  system,
  configuration,
  network,
  performance,
  errors,
  logs,
}

/// Diagnostic report entry
class DiagnosticEntry {
  final DiagnosticCategory category;
  final String key;
  final dynamic value;
  final DateTime timestamp;
  final String? description;

  DiagnosticEntry({
    required this.category,
    required this.key,
    required this.value,
    required this.timestamp,
    this.description,
  });

  Map<String, dynamic> toJson() {
    return {
      'category': category.name,
      'key': key,
      'value': value,
      'timestamp': timestamp.toIso8601String(),
      'description': description,
    };
  }
}

/// Comprehensive diagnostic service for sing-box operations
class SingboxDiagnosticService {
  static SingboxDiagnosticService? _instance;
  static SingboxDiagnosticService get instance => _instance ??= SingboxDiagnosticService._();

  final SingboxLogger _logger = SingboxLogger.instance;
  final List<DiagnosticEntry> _diagnosticEntries = [];
  final MethodChannel _platformChannel = const MethodChannel('com.tunnelmax.vpnclient/vpn');

  SingboxDiagnosticService._();

  /// Collect comprehensive diagnostic information
  Future<Map<String, dynamic>> collectDiagnosticReport() async {
    _logger.info('SingboxDiagnosticService', 'Starting diagnostic collection');

    final report = <String, dynamic>{
      'timestamp': DateTime.now().toIso8601String(),
      'version': await _getAppVersion(),
      'platform': Platform.operatingSystem,
      'system': await _collectSystemInfo(),
      'configuration': await _collectConfigurationInfo(),
      'network': await _collectNetworkInfo(),
      'performance': await _collectPerformanceInfo(),
      'errors': await _collectErrorInfo(),
      'logs': await _collectLogInfo(),
      'native': await _collectNativeDiagnostics(),
    };

    _logger.info(
      'SingboxDiagnosticService',
      'Diagnostic collection completed',
      metadata: {
        'reportSize': jsonEncode(report).length,
        'categories': report.keys.length,
      },
    );

    return report;
  }

  /// Export diagnostic report to file
  Future<File?> exportDiagnosticReport({String? fileName}) async {
    try {
      final report = await collectDiagnosticReport();
      final directory = await getApplicationDocumentsDirectory();
      
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
      final file = File('${directory.path}/${fileName ?? "singbox_diagnostic_$timestamp"}.json');

      final jsonData = const JsonEncoder.withIndent('  ').convert(report);
      await file.writeAsString(jsonData);

      _logger.info(
        'SingboxDiagnosticService',
        'Diagnostic report exported',
        metadata: {
          'filePath': file.path,
          'fileSize': jsonData.length,
        },
      );

      return file;
    } catch (e, stackTrace) {
      _logger.error(
        'SingboxDiagnosticService',
        'Failed to export diagnostic report',
        error: e,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  /// Add custom diagnostic entry
  void addDiagnosticEntry(DiagnosticEntry entry) {
    _diagnosticEntries.add(entry);
    
    // Keep only recent entries (last 100)
    if (_diagnosticEntries.length > 100) {
      _diagnosticEntries.removeAt(0);
    }
  }

  /// Log system event for diagnostics
  void logSystemEvent(
    String event,
    Map<String, dynamic> details, {
    DiagnosticCategory category = DiagnosticCategory.system,
  }) {
    addDiagnosticEntry(DiagnosticEntry(
      category: category,
      key: event,
      value: details,
      timestamp: DateTime.now(),
      description: 'System event: $event',
    ));

    _logger.info(
      'SingboxDiagnosticService',
      'System event logged: $event',
      metadata: details,
    );
  }

  /// Log configuration change for diagnostics
  void logConfigurationChange(
    String configType,
    Map<String, dynamic> oldConfig,
    Map<String, dynamic> newConfig,
  ) {
    addDiagnosticEntry(DiagnosticEntry(
      category: DiagnosticCategory.configuration,
      key: 'config_change_$configType',
      value: {
        'old': oldConfig,
        'new': newConfig,
        'changes': _findConfigChanges(oldConfig, newConfig),
      },
      timestamp: DateTime.now(),
      description: 'Configuration change: $configType',
    ));
  }

  /// Log network event for diagnostics
  void logNetworkEvent(
    String event,
    Map<String, dynamic> networkInfo,
  ) {
    addDiagnosticEntry(DiagnosticEntry(
      category: DiagnosticCategory.network,
      key: event,
      value: networkInfo,
      timestamp: DateTime.now(),
      description: 'Network event: $event',
    ));
  }

  /// Log performance metrics
  void logPerformanceMetrics(
    String operation,
    Duration duration,
    Map<String, dynamic> metrics,
  ) {
    addDiagnosticEntry(DiagnosticEntry(
      category: DiagnosticCategory.performance,
      key: 'perf_$operation',
      value: {
        'duration_ms': duration.inMilliseconds,
        'metrics': metrics,
      },
      timestamp: DateTime.now(),
      description: 'Performance metrics: $operation',
    ));
  }

  /// Clear diagnostic data
  void clearDiagnosticData() {
    _diagnosticEntries.clear();
    _logger.info('SingboxDiagnosticService', 'Diagnostic data cleared');
  }

  // Private methods for collecting diagnostic information

  Future<String> _getAppVersion() async {
    try {
      // This would typically come from package_info_plus or similar
      return '1.0.0'; // Placeholder
    } catch (e) {
      return 'unknown';
    }
  }

  Future<Map<String, dynamic>> _collectSystemInfo() async {
    try {
      return {
        'platform': Platform.operatingSystem,
        'platformVersion': Platform.operatingSystemVersion,
        'numberOfProcessors': Platform.numberOfProcessors,
        'pathSeparator': Platform.pathSeparator,
        'localeName': Platform.localeName,
        'environment': Platform.environment.keys.take(10).toList(), // Limited for privacy
        'executableArguments': Platform.executableArguments,
        'dartVersion': Platform.version,
      };
    } catch (e) {
      _logger.error('SingboxDiagnosticService', 'Failed to collect system info', error: e);
      return {'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> _collectConfigurationInfo() async {
    try {
      // Collect configuration-related diagnostic info
      return {
        'supportedProtocols': ['vless', 'vmess', 'trojan', 'shadowsocks'],
        'configurationHistory': _diagnosticEntries
            .where((e) => e.category == DiagnosticCategory.configuration)
            .take(10)
            .map((e) => e.toJson())
            .toList(),
        'lastConfigurationChange': _diagnosticEntries
            .where((e) => e.category == DiagnosticCategory.configuration)
            .isNotEmpty
            ? _diagnosticEntries
                .where((e) => e.category == DiagnosticCategory.configuration)
                .last
                .timestamp
                .toIso8601String()
            : null,
      };
    } catch (e) {
      _logger.error('SingboxDiagnosticService', 'Failed to collect configuration info', error: e);
      return {'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> _collectNetworkInfo() async {
    try {
      final networkEvents = _diagnosticEntries
          .where((e) => e.category == DiagnosticCategory.network)
          .take(20)
          .map((e) => e.toJson())
          .toList();

      return {
        'networkEvents': networkEvents,
        'lastNetworkEvent': networkEvents.isNotEmpty 
            ? networkEvents.last['timestamp'] 
            : null,
        'networkEventCount': networkEvents.length,
      };
    } catch (e) {
      _logger.error('SingboxDiagnosticService', 'Failed to collect network info', error: e);
      return {'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> _collectPerformanceInfo() async {
    try {
      final performanceEntries = _diagnosticEntries
          .where((e) => e.category == DiagnosticCategory.performance)
          .toList();

      final operationTimings = <String, List<int>>{};
      for (final entry in performanceEntries) {
        final operation = entry.key.replaceFirst('perf_', '');
        final duration = entry.value['duration_ms'] as int;
        
        operationTimings.putIfAbsent(operation, () => []).add(duration);
      }

      final performanceStats = <String, Map<String, dynamic>>{};
      for (final entry in operationTimings.entries) {
        final timings = entry.value;
        performanceStats[entry.key] = {
          'count': timings.length,
          'average': timings.reduce((a, b) => a + b) / timings.length,
          'min': timings.reduce((a, b) => a < b ? a : b),
          'max': timings.reduce((a, b) => a > b ? a : b),
        };
      }

      return {
        'operationStats': performanceStats,
        'recentPerformanceEvents': performanceEntries
            .take(10)
            .map((e) => e.toJson())
            .toList(),
      };
    } catch (e) {
      _logger.error('SingboxDiagnosticService', 'Failed to collect performance info', error: e);
      return {'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> _collectErrorInfo() async {
    try {
      final errorHistory = _logger.getErrorHistory();
      final recentErrors = errorHistory.take(20).toList();

      // Categorize errors
      final errorCategories = <String, int>{};
      for (final error in recentErrors) {
        final category = _categorizeError(error.message);
        errorCategories[category] = (errorCategories[category] ?? 0) + 1;
      }

      return {
        'totalErrors': errorHistory.length,
        'recentErrors': recentErrors,
        'errorCategories': errorCategories,
        'lastError': recentErrors.isNotEmpty ? recentErrors.first : null,
      };
    } catch (e) {
      _logger.error('SingboxDiagnosticService', 'Failed to collect error info', error: e);
      return {'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> _collectLogInfo() async {
    try {
      final recentLogs = _logger.getRecentLogs(limit: 50);
      
      final logLevels = <String, int>{};
      final logSources = <String, int>{};
      
      for (final log in recentLogs) {
        logLevels[log.level.name] = (logLevels[log.level.name] ?? 0) + 1;
        logSources[log.source] = (logSources[log.source] ?? 0) + 1;
      }

      return {
        'totalLogEntries': recentLogs.length,
        'logLevelDistribution': logLevels,
        'logSourceDistribution': logSources,
        'oldestLogEntry': recentLogs.isNotEmpty 
            ? recentLogs.last.timestamp.toIso8601String()
            : null,
        'newestLogEntry': recentLogs.isNotEmpty 
            ? recentLogs.first.timestamp.toIso8601String()
            : null,
      };
    } catch (e) {
      _logger.error('SingboxDiagnosticService', 'Failed to collect log info', error: e);
      return {'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> _collectNativeDiagnostics() async {
    try {
      // Collect native platform diagnostics
      final nativeDiagnostics = await _platformChannel.invokeMethod<Map<dynamic, dynamic>>('getDiagnostics');
      
      return Map<String, dynamic>.from(nativeDiagnostics ?? {});
    } catch (e) {
      _logger.error('SingboxDiagnosticService', 'Failed to collect native diagnostics', error: e);
      return {'error': e.toString(), 'available': false};
    }
  }

  List<String> _findConfigChanges(Map<String, dynamic> oldConfig, Map<String, dynamic> newConfig) {
    final changes = <String>[];
    
    // Simple change detection
    for (final key in {...oldConfig.keys, ...newConfig.keys}) {
      if (!oldConfig.containsKey(key)) {
        changes.add('Added: $key');
      } else if (!newConfig.containsKey(key)) {
        changes.add('Removed: $key');
      } else if (oldConfig[key] != newConfig[key]) {
        changes.add('Modified: $key');
      }
    }
    
    return changes;
  }

  String _categorizeError(String error) {
    final errorLower = error.toLowerCase();
    
    if (errorLower.contains('network') || errorLower.contains('connection')) {
      return 'network';
    } else if (errorLower.contains('config') || errorLower.contains('validation')) {
      return 'configuration';
    } else if (errorLower.contains('permission') || errorLower.contains('access')) {
      return 'permission';
    } else if (errorLower.contains('process') || errorLower.contains('native')) {
      return 'process';
    } else if (errorLower.contains('timeout') || errorLower.contains('performance')) {
      return 'performance';
    } else {
      return 'general';
    }
  }
}

/// Extension methods for easier diagnostic logging
extension DiagnosticLogging on Object {
  void logDiagnosticEvent(
    String event,
    Map<String, dynamic> details, {
    DiagnosticCategory category = DiagnosticCategory.system,
  }) {
    SingboxDiagnosticService.instance.logSystemEvent(event, details, category: category);
  }

  void logConfigChange(
    String configType,
    Map<String, dynamic> oldConfig,
    Map<String, dynamic> newConfig,
  ) {
    SingboxDiagnosticService.instance.logConfigurationChange(configType, oldConfig, newConfig);
  }

  void logNetworkEvent(String event, Map<String, dynamic> networkInfo) {
    SingboxDiagnosticService.instance.logNetworkEvent(event, networkInfo);
  }

  void logPerformanceMetrics(
    String operation,
    Duration duration,
    Map<String, dynamic> metrics,
  ) {
    SingboxDiagnosticService.instance.logPerformanceMetrics(operation, duration, metrics);
  }
}