import 'dart:async';

import 'package:logger/logger.dart';

import '../models/singbox_error.dart';
import '../models/app_error.dart';
import 'singbox_error_mapper.dart';
import 'singbox_error_reporter.dart';
import 'singbox_error_categorizer.dart';
import 'error_handler_service.dart';
import 'logs_service.dart';

/// Comprehensive integration service for sing-box error handling
/// 
/// This service provides a unified interface for all sing-box error handling
/// operations including mapping, categorization, reporting, and recovery.
/// It integrates with the existing error handling infrastructure while
/// providing sing-box specific functionality.
class SingboxErrorIntegrationService {
  final ErrorHandlerService _errorHandlerService;
  final SingboxErrorReporter _errorReporter;
  final LogsService _logsService;
  final Logger _logger;

  // Error tracking and correlation
  final List<SingboxError> _errorHistory = [];
  final Map<String, int> _errorRecurrenceCount = {};
  final StreamController<SingboxError> _processedErrorController = 
      StreamController<SingboxError>.broadcast();

  // Configuration
  static const int _maxErrorHistory = 200;
  static const Duration _recurrenceWindow = Duration(minutes: 10);

  SingboxErrorIntegrationService({
    required ErrorHandlerService errorHandlerService,
    required LogsService logsService,
    Logger? logger,
  })  : _errorHandlerService = errorHandlerService,
        _errorReporter = SingboxErrorReporter(logsService: logsService, logger: logger),
        _logsService = logsService,
        _logger = logger ?? Logger();

  /// Stream of processed sing-box errors
  Stream<SingboxError> get processedErrorStream => _processedErrorController.stream;

  /// Processes a native sing-box error and returns a structured SingboxError
  Future<SingboxError> processNativeError({
    required String nativeErrorMessage,
    String? nativeErrorCode,
    SingboxOperation? operation,
    String? protocol,
    String? serverEndpoint,
    Map<String, dynamic>? singboxConfig,
    Map<String, dynamic>? context,
    String? stackTrace,
    bool showNotification = true,
  }) async {
    try {
      // Map the native error to a structured SingboxError
      final mappedError = SingboxErrorMapper.mapNativeError(
        nativeErrorMessage: nativeErrorMessage,
        nativeErrorCode: nativeErrorCode,
        operation: operation,
        protocol: protocol,
        serverEndpoint: serverEndpoint,
        singboxConfig: singboxConfig,
        context: context,
        stackTrace: stackTrace,
      );

      // Process the error through the integration pipeline
      return await _processError(mappedError, showNotification: showNotification);
    } catch (e) {
      _logger.e('Failed to process native sing-box error: $e');
      
      // Create a fallback error
      final fallbackError = SingboxErrorFactory.unknownError(
        technicalMessage: 'Error processing native error: $e',
        nativeErrorMessage: nativeErrorMessage,
        operation: operation,
        protocol: protocol,
        serverEndpoint: serverEndpoint,
        context: context,
        stackTrace: stackTrace,
      );
      
      return await _processError(fallbackError, showNotification: showNotification);
    }
  }

  /// Processes a platform channel error and returns a structured SingboxError
  Future<SingboxError> processPlatformChannelError({
    required String errorCode,
    required String errorMessage,
    String? errorDetails,
    SingboxOperation? operation,
    String? protocol,
    String? serverEndpoint,
    Map<String, dynamic>? context,
    String? stackTrace,
    bool showNotification = true,
  }) async {
    try {
      final mappedError = SingboxErrorMapper.mapPlatformChannelError(
        errorCode: errorCode,
        errorMessage: errorMessage,
        errorDetails: errorDetails,
        operation: operation,
        protocol: protocol,
        serverEndpoint: serverEndpoint,
        context: context,
        stackTrace: stackTrace,
      );

      return await _processError(mappedError, showNotification: showNotification);
    } catch (e) {
      _logger.e('Failed to process platform channel error: $e');
      rethrow;
    }
  }

  /// Processes a Dart exception and returns a structured SingboxError
  Future<SingboxError> processDartException({
    required Exception exception,
    SingboxOperation? operation,
    String? protocol,
    String? serverEndpoint,
    Map<String, dynamic>? context,
    String? stackTrace,
    bool showNotification = true,
  }) async {
    try {
      final mappedError = SingboxErrorMapper.mapDartException(
        exception: exception,
        operation: operation,
        protocol: protocol,
        serverEndpoint: serverEndpoint,
        context: context,
        stackTrace: stackTrace,
      );

      return await _processError(mappedError, showNotification: showNotification);
    } catch (e) {
      _logger.e('Failed to process Dart exception: $e');
      rethrow;
    }
  }

  /// Creates and processes a categorized sing-box error
  Future<SingboxError> createCategorizedError({
    required SingboxErrorCode singboxErrorCode,
    required SingboxOperation operation,
    required String technicalMessage,
    String? userMessage,
    String? nativeErrorMessage,
    String? protocol,
    String? serverEndpoint,
    Map<String, dynamic>? singboxConfig,
    Map<String, dynamic>? context,
    String? stackTrace,
    bool showNotification = true,
  }) async {
    try {
      // Check if this is a recurring error
      final isRecurring = _isRecurringError(singboxErrorCode, operation);
      
      // Create the categorized error
      final categorizedError = SingboxErrorFactory.createCategorizedError(
        singboxErrorCode: singboxErrorCode,
        operation: operation,
        technicalMessage: technicalMessage,
        userMessage: userMessage,
        nativeErrorMessage: nativeErrorMessage,
        protocol: protocol,
        serverEndpoint: serverEndpoint,
        singboxConfig: singboxConfig,
        context: context,
        stackTrace: stackTrace,
        isRecurring: isRecurring,
      );

      return await _processError(categorizedError, showNotification: showNotification);
    } catch (e) {
      _logger.e('Failed to create categorized error: $e');
      rethrow;
    }
  }

  /// Analyzes error patterns and provides insights
  Future<Map<String, dynamic>> analyzeErrorPatterns() async {
    try {
      // Get analysis from the reporter
      final reporterAnalysis = await _errorReporter.analyzeErrorPatterns();
      
      // Add correlation analysis
      final correlationAnalysis = SingboxErrorCategorizer.analyzeErrorCorrelation(_errorHistory);
      
      // Combine analyses
      final combinedAnalysis = <String, dynamic>{
        ...reporterAnalysis,
        'correlation_analysis': correlationAnalysis,
        'error_history_size': _errorHistory.length,
        'recurrence_patterns': _analyzeRecurrencePatterns(),
        'system_health_assessment': _assessSystemHealth(),
      };

      await _logsService.writeLog('INFO', 'Error pattern analysis completed');
      return combinedAnalysis;
    } catch (e) {
      _logger.e('Failed to analyze error patterns: $e');
      rethrow;
    }
  }

  /// Gets comprehensive error statistics
  Map<String, dynamic> getErrorStatistics() {
    return {
      'total_processed_errors': _errorHistory.length,
      'recent_error_rate': _calculateRecentErrorRate(),
      'recurrence_statistics': _getRecurrenceStatistics(),
      'category_distribution': _getCategoryDistribution(),
      'severity_distribution': _getSeverityDistribution(),
      'operation_failure_rates': _getOperationFailureRates(),
      'protocol_error_rates': _getProtocolErrorRates(),
      'recovery_success_estimates': _getRecoverySuccessEstimates(),
    };
  }

  /// Generates a comprehensive diagnostic report
  Future<Map<String, dynamic>> generateDiagnosticReport() async {
    try {
      final reporterDiagnostics = await _errorReporter.generateDiagnosticReport();
      final errorAnalysis = await analyzeErrorPatterns();
      
      return {
        'timestamp': DateTime.now().toIso8601String(),
        'service_statistics': getErrorStatistics(),
        'error_analysis': errorAnalysis,
        'reporter_diagnostics': reporterDiagnostics,
        'integration_health': _assessIntegrationHealth(),
        'recommendations': _generateSystemRecommendations(),
      };
    } catch (e) {
      _logger.e('Failed to generate diagnostic report: $e');
      rethrow;
    }
  }

  /// Clears all error tracking data
  void clearErrorData() {
    _errorHistory.clear();
    _errorRecurrenceCount.clear();
    _errorReporter.clearErrorData();
    _logger.d('All error tracking data cleared');
  }

  /// Disposes of the service and releases resources
  void dispose() {
    _processedErrorController.close();
    _errorReporter.dispose();
    clearErrorData();
  }

  // Private helper methods

  Future<SingboxError> _processError(SingboxError error, {bool showNotification = true}) async {
    try {
      // Add to error history
      _addToErrorHistory(error);
      
      // Update recurrence tracking
      _updateRecurrenceTracking(error);
      
      // Report the error
      await _errorReporter.reportError(error);
      
      // Handle through the general error handler
      await _errorHandlerService.handleError(error, showNotification: showNotification);
      
      // Emit to processed error stream
      _processedErrorController.add(error);
      
      _logger.d('Sing-box error processed successfully: ${error.id}');
      return error;
    } catch (e) {
      _logger.e('Failed to process sing-box error: $e');
      rethrow;
    }
  }

  void _addToErrorHistory(SingboxError error) {
    _errorHistory.insert(0, error);
    
    // Keep only the most recent errors
    if (_errorHistory.length > _maxErrorHistory) {
      _errorHistory.removeRange(_maxErrorHistory, _errorHistory.length);
    }
  }

  void _updateRecurrenceTracking(SingboxError error) {
    final errorKey = '${error.singboxErrorCode}_${error.operation}';
    _errorRecurrenceCount[errorKey] = (_errorRecurrenceCount[errorKey] ?? 0) + 1;
  }

  bool _isRecurringError(SingboxErrorCode errorCode, SingboxOperation operation) {
    final errorKey = '${errorCode}_${operation}';
    final count = _errorRecurrenceCount[errorKey] ?? 0;
    
    // Check if we've seen this error recently
    final recentOccurrences = _errorHistory
        .where((error) => 
            error.singboxErrorCode == errorCode &&
            error.operation == operation &&
            error.timestamp.isAfter(DateTime.now().subtract(_recurrenceWindow)))
        .length;
    
    return count > 1 || recentOccurrences > 1;
  }

  Map<String, dynamic> _analyzeRecurrencePatterns() {
    final patterns = <String, dynamic>{};
    
    for (final entry in _errorRecurrenceCount.entries) {
      if (entry.value > 2) {
        final parts = entry.key.split('_');
        if (parts.length >= 2) {
          patterns[entry.key] = {
            'error_code': parts[0],
            'operation': parts[1],
            'occurrence_count': entry.value,
            'severity': 'high_recurrence',
          };
        }
      }
    }
    
    return {
      'recurring_errors': patterns,
      'total_recurring_patterns': patterns.length,
      'recurrence_rate': patterns.length / _errorHistory.length,
    };
  }

  Map<String, dynamic> _assessSystemHealth() {
    final now = DateTime.now();
    final oneHourAgo = now.subtract(const Duration(hours: 1));
    
    final recentErrors = _errorHistory
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
      'error_rate_per_hour': recentErrors.length,
    };
  }

  Map<String, dynamic> _assessIntegrationHealth() {
    return {
      'error_history_size': _errorHistory.length,
      'recurrence_tracking_entries': _errorRecurrenceCount.length,
      'memory_usage_estimate': _estimateMemoryUsage(),
      'processing_efficiency': _calculateProcessingEfficiency(),
    };
  }

  List<String> _generateSystemRecommendations() {
    final health = _assessSystemHealth();
    final recommendations = <String>[];
    
    switch (health['status']) {
      case 'critical':
        recommendations.addAll([
          'Immediate attention required - critical errors detected',
          'Consider restarting the sing-box core',
          'Review system resources and permissions',
          'Check for configuration issues',
        ]);
        break;
      case 'degraded':
        recommendations.addAll([
          'System performance is degraded',
          'Monitor error patterns closely',
          'Consider switching to backup configurations',
          'Review network connectivity',
        ]);
        break;
      case 'warning':
        recommendations.addAll([
          'Elevated error rate detected',
          'Monitor system closely',
          'Review recent configuration changes',
        ]);
        break;
      case 'healthy':
        recommendations.add('System is operating normally');
        break;
    }
    
    // Add recurrence-based recommendations
    final recurrenceAnalysis = _analyzeRecurrencePatterns();
    if (recurrenceAnalysis['total_recurring_patterns'] > 0) {
      recommendations.add('Recurring error patterns detected - investigate root causes');
    }
    
    return recommendations;
  }

  double _calculateRecentErrorRate() {
    final now = DateTime.now();
    final oneHourAgo = now.subtract(const Duration(hours: 1));
    
    final recentErrors = _errorHistory
        .where((error) => error.timestamp.isAfter(oneHourAgo))
        .length;
    
    return recentErrors / 60.0; // Errors per minute
  }

  Map<String, int> _getRecurrenceStatistics() {
    final stats = <String, int>{};
    
    for (final entry in _errorRecurrenceCount.entries) {
      final parts = entry.key.split('_');
      if (parts.isNotEmpty) {
        final errorCode = parts[0];
        stats[errorCode] = (stats[errorCode] ?? 0) + entry.value;
      }
    }
    
    return stats;
  }

  Map<String, int> _getCategoryDistribution() {
    final distribution = <String, int>{};
    
    for (final error in _errorHistory) {
      final category = error.category.toString().split('.').last;
      distribution[category] = (distribution[category] ?? 0) + 1;
    }
    
    return distribution;
  }

  Map<String, int> _getSeverityDistribution() {
    final distribution = <String, int>{};
    
    for (final error in _errorHistory) {
      final severity = error.severity.toString().split('.').last;
      distribution[severity] = (distribution[severity] ?? 0) + 1;
    }
    
    return distribution;
  }

  Map<String, double> _getOperationFailureRates() {
    final operationCounts = <SingboxOperation, int>{};
    
    for (final error in _errorHistory) {
      operationCounts[error.operation] = (operationCounts[error.operation] ?? 0) + 1;
    }
    
    final totalErrors = _errorHistory.length;
    return operationCounts.map((operation, count) => 
        MapEntry(operation.toString(), count / totalErrors * 100));
  }

  Map<String, double> _getProtocolErrorRates() {
    final protocolCounts = <String, int>{};
    
    for (final error in _errorHistory) {
      if (error.protocol != null) {
        protocolCounts[error.protocol!] = (protocolCounts[error.protocol!] ?? 0) + 1;
      }
    }
    
    final totalProtocolErrors = protocolCounts.values.fold(0, (sum, count) => sum + count);
    if (totalProtocolErrors == 0) return {};
    
    return protocolCounts.map((protocol, count) => 
        MapEntry(protocol, count / totalProtocolErrors * 100));
  }

  Map<String, double> _getRecoverySuccessEstimates() {
    final retryableErrors = _errorHistory.where((error) => error.isRetryable).length;
    final totalErrors = _errorHistory.length;
    
    if (totalErrors == 0) return {};
    
    return {
      'retryable_error_rate': retryableErrors / totalErrors * 100,
      'estimated_recovery_rate': retryableErrors > 0 ? 75.0 : 0.0, // Placeholder calculation
    };
  }

  int _estimateMemoryUsage() {
    // Rough estimate of memory usage in bytes
    const avgErrorSize = 2048; // Estimated average size per error object
    return _errorHistory.length * avgErrorSize + 
           _errorRecurrenceCount.length * 64; // Estimated size per recurrence entry
  }

  double _calculateProcessingEfficiency() {
    // Simple efficiency metric based on error processing success
    // In a real implementation, this would track actual processing times and success rates
    return _errorHistory.isNotEmpty ? 95.0 : 100.0; // Placeholder calculation
  }
}