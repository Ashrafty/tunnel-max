import 'dart:async';
import 'dart:convert';

import 'package:logger/logger.dart';

import '../models/singbox_error.dart';
import '../models/app_error.dart';
import 'logs_service.dart';

/// Service responsible for reporting and categorizing sing-box errors
/// 
/// This service provides comprehensive error reporting functionality including:
/// - Error severity classification and reporting
/// - Error pattern analysis and categorization
/// - Integration with logging and diagnostic systems
/// - Error recovery strategy recommendations
class SingboxErrorReporter {
  final LogsService _logsService;
  final Logger _logger;

  // Error tracking and analytics
  final List<SingboxError> _recentSingboxErrors = [];
  final Map<SingboxErrorCode, int> _errorFrequency = {};
  final Map<SingboxOperation, int> _operationFailures = {};
  final StreamController<SingboxError> _errorReportController = StreamController<SingboxError>.broadcast();

  // Configuration
  static const int _maxRecentErrors = 100;
  static const Duration _errorAnalysisWindow = Duration(hours: 1);

  SingboxErrorReporter({
    required LogsService logsService,
    Logger? logger,
  })  : _logsService = logsService,
        _logger = logger ?? Logger();

  /// Stream of sing-box errors for monitoring and analytics
  Stream<SingboxError> get errorReportStream => _errorReportController.stream;

  /// List of recent sing-box errors
  List<SingboxError> get recentSingboxErrors => List.unmodifiable(_recentSingboxErrors);

  /// Reports a sing-box error with comprehensive logging and analysis
  Future<void> reportError(SingboxError error) async {
    try {
      // Add to recent errors tracking
      _addToRecentErrors(error);

      // Update error frequency statistics
      _updateErrorStatistics(error);

      // Log the error with appropriate severity
      await _logSingboxError(error);

      // Perform error analysis
      await _analyzeErrorPatterns(error);

      // Emit error to stream for external monitoring
      _errorReportController.add(error);

      _logger.d('Sing-box error reported successfully: ${error.id}');
    } catch (e) {
      _logger.e('Failed to report sing-box error: $e');
      rethrow;
    }
  }

  /// Analyzes error patterns and provides insights
  Future<Map<String, dynamic>> analyzeErrorPatterns() async {
    final now = DateTime.now();
    final analysisWindow = now.subtract(_errorAnalysisWindow);
    
    final recentErrors = _recentSingboxErrors
        .where((error) => error.timestamp.isAfter(analysisWindow))
        .toList();

    final analysis = <String, dynamic>{
      'total_errors': recentErrors.length,
      'error_rate': _calculateErrorRate(recentErrors),
      'most_common_errors': _getMostCommonErrors(recentErrors),
      'operation_failure_rates': _getOperationFailureRates(recentErrors),
      'protocol_error_distribution': _getProtocolErrorDistribution(recentErrors),
      'severity_distribution': _getSeverityDistribution(recentErrors),
      'recovery_success_rate': _calculateRecoverySuccessRate(recentErrors),
      'recommendations': _generateRecommendations(recentErrors),
    };

    await _logsService.writeLog('INFO', 'Error pattern analysis completed: ${json.encode(analysis)}');
    return analysis;
  }

  /// Gets error statistics for a specific operation
  Map<String, dynamic> getOperationErrorStats(SingboxOperation operation) {
    final operationErrors = _recentSingboxErrors
        .where((error) => error.operation == operation)
        .toList();

    return {
      'operation': operation.toString(),
      'total_errors': operationErrors.length,
      'error_codes': _getErrorCodeDistribution(operationErrors),
      'average_severity': _calculateAverageSeverity(operationErrors),
      'most_recent_error': operationErrors.isNotEmpty 
          ? operationErrors.first.timestamp.toIso8601String()
          : null,
    };
  }

  /// Gets error statistics for a specific protocol
  Map<String, dynamic> getProtocolErrorStats(String protocol) {
    final protocolErrors = _recentSingboxErrors
        .where((error) => error.protocol == protocol)
        .toList();

    return {
      'protocol': protocol,
      'total_errors': protocolErrors.length,
      'error_codes': _getErrorCodeDistribution(protocolErrors),
      'common_endpoints': _getCommonFailedEndpoints(protocolErrors),
      'success_rate': _calculateProtocolSuccessRate(protocol),
    };
  }

  /// Generates a diagnostic report for troubleshooting
  Future<Map<String, dynamic>> generateDiagnosticReport() async {
    final report = <String, dynamic>{
      'timestamp': DateTime.now().toIso8601String(),
      'error_summary': {
        'total_tracked_errors': _recentSingboxErrors.length,
        'error_frequency': _errorFrequency,
        'operation_failures': _operationFailures,
      },
      'recent_critical_errors': _recentSingboxErrors
          .where((error) => error.severity == ErrorSeverity.critical)
          .take(10)
          .map((error) => _errorToMap(error))
          .toList(),
      'error_patterns': await analyzeErrorPatterns(),
      'system_health': _assessSystemHealth(),
      'recommendations': _generateSystemRecommendations(),
    };

    await _logsService.writeLog('INFO', 'Diagnostic report generated');
    return report;
  }

  /// Clears error tracking data
  void clearErrorData() {
    _recentSingboxErrors.clear();
    _errorFrequency.clear();
    _operationFailures.clear();
    _logger.d('Sing-box error data cleared');
  }

  /// Disposes of the service and releases resources
  void dispose() {
    _errorReportController.close();
    clearErrorData();
  }

  // Private helper methods

  void _addToRecentErrors(SingboxError error) {
    _recentSingboxErrors.insert(0, error);
    
    // Keep only the most recent errors
    if (_recentSingboxErrors.length > _maxRecentErrors) {
      _recentSingboxErrors.removeRange(_maxRecentErrors, _recentSingboxErrors.length);
    }
  }

  void _updateErrorStatistics(SingboxError error) {
    // Update error frequency
    _errorFrequency[error.singboxErrorCode] = 
        (_errorFrequency[error.singboxErrorCode] ?? 0) + 1;

    // Update operation failure count
    _operationFailures[error.operation] = 
        (_operationFailures[error.operation] ?? 0) + 1;
  }

  Future<void> _logSingboxError(SingboxError error) async {
    final logLevel = _mapSeverityToLogLevel(error.severity);
    final logMessage = _formatErrorLogMessage(error);
    
    await _logsService.writeLog(logLevel, logMessage);

    // Also log to console with appropriate level
    switch (error.severity) {
      case ErrorSeverity.critical:
        _logger.f('CRITICAL SING-BOX ERROR [${error.id}]: ${error.technicalMessage}');
        break;
      case ErrorSeverity.high:
        _logger.e('SING-BOX ERROR [${error.id}]: ${error.technicalMessage}');
        break;
      case ErrorSeverity.medium:
        _logger.w('SING-BOX WARNING [${error.id}]: ${error.technicalMessage}');
        break;
      case ErrorSeverity.low:
        _logger.i('SING-BOX INFO [${error.id}]: ${error.technicalMessage}');
        break;
    }
  }

  String _formatErrorLogMessage(SingboxError error) {
    final buffer = StringBuffer();
    buffer.writeln('SING-BOX ERROR REPORT [${error.id}]');
    buffer.writeln('Code: ${error.singboxErrorCode}');
    buffer.writeln('Operation: ${error.operation}');
    buffer.writeln('Severity: ${error.severity}');
    buffer.writeln('Category: ${error.category}');
    buffer.writeln('User Message: ${error.userMessage}');
    buffer.writeln('Technical Message: ${error.technicalMessage}');
    
    if (error.protocol != null) {
      buffer.writeln('Protocol: ${error.protocol}');
    }
    
    if (error.serverEndpoint != null) {
      buffer.writeln('Server: ${error.serverEndpoint}');
    }
    
    if (error.nativeErrorMessage != null) {
      buffer.writeln('Native Error: ${error.nativeErrorMessage}');
    }
    
    if (error.context != null && error.context!.isNotEmpty) {
      buffer.writeln('Context: ${json.encode(error.context)}');
    }
    
    if (error.recoveryActions != null && error.recoveryActions!.isNotEmpty) {
      buffer.writeln('Recovery Actions: ${error.recoveryActions!.join(', ')}');
    }
    
    buffer.writeln('Timestamp: ${error.timestamp.toIso8601String()}');
    
    return buffer.toString();
  }

  Future<void> _analyzeErrorPatterns(SingboxError error) async {
    // Check for error cascades (multiple related errors in short time)
    final recentSimilarErrors = _recentSingboxErrors
        .where((e) => 
            e.singboxErrorCode == error.singboxErrorCode &&
            e.timestamp.isAfter(DateTime.now().subtract(const Duration(minutes: 5))))
        .length;

    if (recentSimilarErrors > 3) {
      await _logsService.writeLog('WARN', 
          'Error cascade detected: ${error.singboxErrorCode} occurred $recentSimilarErrors times in 5 minutes');
    }

    // Check for critical operation failures
    if (error.severity == ErrorSeverity.critical && 
        (error.operation == SingboxOperation.initialization || 
         error.operation == SingboxOperation.connection)) {
      await _logsService.writeLog('FATAL', 
          'Critical operation failure: ${error.operation} failed with ${error.singboxErrorCode}');
    }
  }

  double _calculateErrorRate(List<SingboxError> errors) {
    if (errors.isEmpty) return 0.0;
    
    final timeSpan = _errorAnalysisWindow.inMinutes;
    return errors.length / timeSpan; // Errors per minute
  }

  List<Map<String, dynamic>> _getMostCommonErrors(List<SingboxError> errors) {
    final errorCounts = <SingboxErrorCode, int>{};
    
    for (final error in errors) {
      errorCounts[error.singboxErrorCode] = 
          (errorCounts[error.singboxErrorCode] ?? 0) + 1;
    }
    
    final sortedErrors = errorCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    return sortedErrors.take(5).map((entry) => {
      'error_code': entry.key.toString(),
      'count': entry.value,
      'percentage': (entry.value / errors.length * 100).toStringAsFixed(1),
    }).toList();
  }

  Map<String, double> _getOperationFailureRates(List<SingboxError> errors) {
    final operationCounts = <SingboxOperation, int>{};
    
    for (final error in errors) {
      operationCounts[error.operation] = 
          (operationCounts[error.operation] ?? 0) + 1;
    }
    
    final totalErrors = errors.length;
    return operationCounts.map((operation, count) => 
        MapEntry(operation.toString(), count / totalErrors * 100));
  }

  Map<String, int> _getProtocolErrorDistribution(List<SingboxError> errors) {
    final protocolCounts = <String, int>{};
    
    for (final error in errors) {
      if (error.protocol != null) {
        protocolCounts[error.protocol!] = 
            (protocolCounts[error.protocol!] ?? 0) + 1;
      }
    }
    
    return protocolCounts;
  }

  Map<String, int> _getSeverityDistribution(List<SingboxError> errors) {
    final severityCounts = <String, int>{};
    
    for (final error in errors) {
      final severity = error.severity.toString().split('.').last;
      severityCounts[severity] = (severityCounts[severity] ?? 0) + 1;
    }
    
    return severityCounts;
  }

  double _calculateRecoverySuccessRate(List<SingboxError> errors) {
    final retryableErrors = errors.where((error) => error.isRetryable).length;
    if (retryableErrors == 0) return 0.0;
    
    // This is a simplified calculation - in a real implementation,
    // you would track actual retry attempts and their outcomes
    return retryableErrors / errors.length * 100;
  }

  List<String> _generateRecommendations(List<SingboxError> errors) {
    final recommendations = <String>[];
    
    // Check for common patterns and generate recommendations
    final configErrors = errors.where((e) => 
        e.category == ErrorCategory.configuration).length;
    if (configErrors > errors.length * 0.3) {
      recommendations.add('High configuration error rate detected. Review server configurations.');
    }
    
    final networkErrors = errors.where((e) => 
        e.category == ErrorCategory.network).length;
    if (networkErrors > errors.length * 0.4) {
      recommendations.add('High network error rate detected. Check network connectivity and server availability.');
    }
    
    final permissionErrors = errors.where((e) => 
        e.category == ErrorCategory.permission).length;
    if (permissionErrors > 0) {
      recommendations.add('Permission errors detected. Ensure VPN permissions are granted.');
    }
    
    final criticalErrors = errors.where((e) => 
        e.severity == ErrorSeverity.critical).length;
    if (criticalErrors > 0) {
      recommendations.add('Critical errors detected. Consider restarting the application or device.');
    }
    
    return recommendations;
  }

  Map<String, int> _getErrorCodeDistribution(List<SingboxError> errors) {
    final codeCounts = <String, int>{};
    
    for (final error in errors) {
      final code = error.singboxErrorCode.toString();
      codeCounts[code] = (codeCounts[code] ?? 0) + 1;
    }
    
    return codeCounts;
  }

  double _calculateAverageSeverity(List<SingboxError> errors) {
    if (errors.isEmpty) return 0.0;
    
    final severityValues = errors.map((error) {
      switch (error.severity) {
        case ErrorSeverity.low:
          return 1.0;
        case ErrorSeverity.medium:
          return 2.0;
        case ErrorSeverity.high:
          return 3.0;
        case ErrorSeverity.critical:
          return 4.0;
      }
    }).toList();
    
    return severityValues.reduce((a, b) => a + b) / severityValues.length;
  }

  List<String> _getCommonFailedEndpoints(List<SingboxError> errors) {
    final endpointCounts = <String, int>{};
    
    for (final error in errors) {
      if (error.serverEndpoint != null) {
        endpointCounts[error.serverEndpoint!] = 
            (endpointCounts[error.serverEndpoint!] ?? 0) + 1;
      }
    }
    
    final sortedEndpoints = endpointCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    return sortedEndpoints.take(5).map((entry) => entry.key).toList();
  }

  double _calculateProtocolSuccessRate(String protocol) {
    // This would require tracking successful connections as well
    // For now, return a placeholder calculation
    final protocolErrors = _recentSingboxErrors
        .where((error) => error.protocol == protocol)
        .length;
    
    // Simplified calculation - in reality you'd track total attempts
    return protocolErrors > 0 ? 50.0 : 100.0;
  }

  Map<String, dynamic> _errorToMap(SingboxError error) {
    return {
      'id': error.id,
      'code': error.singboxErrorCode.toString(),
      'operation': error.operation.toString(),
      'severity': error.severity.toString(),
      'category': error.category.toString(),
      'user_message': error.userMessage,
      'technical_message': error.technicalMessage,
      'protocol': error.protocol,
      'server_endpoint': error.serverEndpoint,
      'timestamp': error.timestamp.toIso8601String(),
      'is_retryable': error.isRetryable,
    };
  }

  Map<String, dynamic> _assessSystemHealth() {
    final now = DateTime.now();
    final oneHourAgo = now.subtract(const Duration(hours: 1));
    
    final recentErrors = _recentSingboxErrors
        .where((error) => error.timestamp.isAfter(oneHourAgo))
        .toList();
    
    final criticalErrors = recentErrors
        .where((error) => error.severity == ErrorSeverity.critical)
        .length;
    
    final highErrors = recentErrors
        .where((error) => error.severity == ErrorSeverity.high)
        .length;
    
    String healthStatus;
    if (criticalErrors > 0) {
      healthStatus = 'critical';
    } else if (highErrors > 5) {
      healthStatus = 'degraded';
    } else if (recentErrors.length > 10) {
      healthStatus = 'warning';
    } else {
      healthStatus = 'healthy';
    }
    
    return {
      'status': healthStatus,
      'recent_errors': recentErrors.length,
      'critical_errors': criticalErrors,
      'high_errors': highErrors,
      'error_rate': _calculateErrorRate(recentErrors),
    };
  }

  List<String> _generateSystemRecommendations() {
    final health = _assessSystemHealth();
    final recommendations = <String>[];
    
    switch (health['status']) {
      case 'critical':
        recommendations.addAll([
          'Immediate attention required - critical errors detected',
          'Consider restarting the application',
          'Check system resources and permissions',
          'Review recent configuration changes',
        ]);
        break;
      case 'degraded':
        recommendations.addAll([
          'System performance is degraded',
          'Monitor error patterns closely',
          'Consider switching to backup servers',
          'Review network connectivity',
        ]);
        break;
      case 'warning':
        recommendations.addAll([
          'Elevated error rate detected',
          'Monitor system closely',
          'Review recent changes',
        ]);
        break;
      case 'healthy':
        recommendations.add('System is operating normally');
        break;
    }
    
    return recommendations;
  }

  String _mapSeverityToLogLevel(ErrorSeverity severity) {
    switch (severity) {
      case ErrorSeverity.critical:
        return 'FATAL';
      case ErrorSeverity.high:
        return 'ERROR';
      case ErrorSeverity.medium:
        return 'WARN';
      case ErrorSeverity.low:
        return 'INFO';
    }
  }
}