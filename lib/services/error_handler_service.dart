import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:logger/logger.dart';

import '../models/app_error.dart';
import '../models/notification_data.dart';
import 'notification_service.dart';
import 'logs_service.dart';

/// Comprehensive error handling service
/// 
/// This service provides centralized error handling with:
/// - Error categorization and user-friendly message generation
/// - Automatic error logging and diagnostic information collection
/// - Integration with notification system for user feedback
/// - Error reporting and analytics
class ErrorHandlerService {
  final NotificationService _notificationService;
  final LogsService _logsService;
  final Logger _logger;

  // Error tracking
  final List<AppError> _recentErrors = [];
  final StreamController<AppError> _errorController = StreamController<AppError>.broadcast();
  
  // Configuration
  static const int _maxRecentErrors = 50;
  static const Duration _errorReportingThrottle = Duration(minutes: 1);
  final Map<String, DateTime> _lastReportedErrors = {};

  ErrorHandlerService({
    required NotificationService notificationService,
    required LogsService logsService,
    Logger? logger,
  })  : _notificationService = notificationService,
        _logsService = logsService,
        _logger = logger ?? Logger();

  /// Stream of errors for monitoring and analytics
  Stream<AppError> get errorStream => _errorController.stream;

  /// List of recent errors (up to [_maxRecentErrors])
  List<AppError> get recentErrors => List.unmodifiable(_recentErrors);

  /// Handles an exception and converts it to a structured error
  Future<AppError> handleException(
    dynamic exception, {
    StackTrace? stackTrace,
    String? context,
    Map<String, dynamic>? additionalData,
    bool showNotification = true,
  }) async {
    try {
      final appError = _convertExceptionToAppError(
        exception,
        stackTrace: stackTrace,
        context: context,
        additionalData: additionalData,
      );

      return await handleError(
        appError,
        showNotification: showNotification,
      );
    } catch (e) {
      // Fallback error handling
      _logger.e('Error in error handler: $e');
      final fallbackError = AppErrorFactory.systemError(
        technicalMessage: 'Error handler failure: $e',
        context: {'original_exception': exception.toString()},
      );
      
      await _logError(fallbackError);
      return fallbackError;
    }
  }

  /// Handles a structured AppError
  Future<AppError> handleError(
    AppError error, {
    bool showNotification = true,
  }) async {
    try {
      // Add to recent errors
      _addToRecentErrors(error);

      // Log the error
      await _logError(error);

      // Show notification if requested
      if (showNotification) {
        await _showErrorNotification(error);
      }

      // Report error if needed
      if (error.shouldReport && _shouldReportError(error)) {
        await _reportError(error);
      }

      // Emit error to stream
      _errorController.add(error);

      _logger.d('Error handled successfully: ${error.id}');
      return error;
    } catch (e) {
      _logger.e('Failed to handle error: $e');
      rethrow;
    }
  }

  /// Handles VPN-specific errors with appropriate categorization
  Future<AppError> handleVpnError(
    dynamic exception, {
    StackTrace? stackTrace,
    String? serverName,
    String? configurationId,
    bool showNotification = true,
  }) async {
    final context = <String, dynamic>{
      if (serverName != null) 'server_name': serverName,
      if (configurationId != null) 'configuration_id': configurationId,
    };

    final appError = _convertVpnExceptionToAppError(
      exception,
      stackTrace: stackTrace,
      context: context,
    );

    return await handleError(
      appError,
      showNotification: showNotification,
    );
  }

  /// Handles network-related errors
  Future<AppError> handleNetworkError(
    dynamic exception, {
    StackTrace? stackTrace,
    String? url,
    int? statusCode,
    bool showNotification = true,
  }) async {
    final context = <String, dynamic>{
      if (url != null) 'url': url,
      if (statusCode != null) 'status_code': statusCode,
    };

    final appError = _convertNetworkExceptionToAppError(
      exception,
      stackTrace: stackTrace,
      context: context,
    );

    return await handleError(
      appError,
      showNotification: showNotification,
    );
  }

  /// Clears recent errors
  void clearRecentErrors() {
    _recentErrors.clear();
    _logger.d('Recent errors cleared');
  }

  /// Gets error statistics
  Map<String, dynamic> getErrorStatistics() {
    final stats = <String, dynamic>{
      'total_errors': _recentErrors.length,
      'by_category': <String, int>{},
      'by_severity': <String, int>{},
      'recent_error_rate': _calculateRecentErrorRate(),
    };

    // Count by category
    for (final error in _recentErrors) {
      final category = error.category.toString().split('.').last;
      stats['by_category'][category] = (stats['by_category'][category] ?? 0) + 1;
    }

    // Count by severity
    for (final error in _recentErrors) {
      final severity = error.severity.toString().split('.').last;
      stats['by_severity'][severity] = (stats['by_severity'][severity] ?? 0) + 1;
    }

    return stats;
  }

  /// Disposes of the service and releases resources
  void dispose() {
    _errorController.close();
    _recentErrors.clear();
    _lastReportedErrors.clear();
  }

  // Private helper methods

  AppError _convertExceptionToAppError(
    dynamic exception, {
    StackTrace? stackTrace,
    String? context,
    Map<String, dynamic>? additionalData,
  }) {
    if (exception is AppError) {
      return exception;
    }

    // Handle common Flutter/Dart exceptions
    if (exception is SocketException) {
      return AppErrorFactory.networkError(
        technicalMessage: exception.message,
        errorCode: 'SOCKET_EXCEPTION',
        context: {
          'os_error': exception.osError?.toString(),
          'address': exception.address?.toString(),
          'port': exception.port?.toString(),
          if (context != null) 'context': context,
          ...?additionalData,
        },
        stackTrace: stackTrace?.toString(),
      );
    }

    if (exception is HttpException) {
      return AppErrorFactory.networkError(
        technicalMessage: exception.message,
        errorCode: 'HTTP_EXCEPTION',
        context: {
          'uri': exception.uri?.toString(),
          if (context != null) 'context': context,
          ...?additionalData,
        },
        stackTrace: stackTrace?.toString(),
      );
    }

    if (exception is FormatException) {
      return AppErrorFactory.configurationError(
        technicalMessage: exception.message,
        errorCode: 'FORMAT_EXCEPTION',
        context: {
          'source': exception.source?.toString(),
          'offset': exception.offset?.toString(),
          if (context != null) 'context': context,
          ...?additionalData,
        },
        stackTrace: stackTrace?.toString(),
      );
    }

    if (exception is ArgumentError) {
      return AppErrorFactory.configurationError(
        technicalMessage: exception.message ?? 'Invalid argument',
        errorCode: 'ARGUMENT_ERROR',
        context: {
          'invalid_value': exception.invalidValue?.toString(),
          'name': exception.name,
          if (context != null) 'context': context,
          ...?additionalData,
        },
        stackTrace: stackTrace?.toString(),
      );
    }

    if (exception is StateError) {
      return AppErrorFactory.systemError(
        technicalMessage: exception.message,
        errorCode: 'STATE_ERROR',
        context: {
          if (context != null) 'context': context,
          ...?additionalData,
        },
        stackTrace: stackTrace?.toString(),
      );
    }

    if (exception is TimeoutException) {
      return AppErrorFactory.networkError(
        technicalMessage: exception.message ?? 'Operation timed out',
        errorCode: 'TIMEOUT_EXCEPTION',
        context: {
          'duration': exception.duration?.toString(),
          if (context != null) 'context': context,
          ...?additionalData,
        },
        stackTrace: stackTrace?.toString(),
      );
    }

    // Handle platform-specific exceptions
    if (exception is PlatformException) {
      return _convertPlatformException(
        exception,
        context: context,
        additionalData: additionalData,
        stackTrace: stackTrace,
      );
    }

    // Generic exception handling
    return AppErrorFactory.unknownError(
      technicalMessage: exception.toString(),
      context: {
        'exception_type': exception.runtimeType.toString(),
        if (context != null) 'context': context,
        ...?additionalData,
      },
      stackTrace: stackTrace?.toString(),
    );
  }

  AppError _convertVpnExceptionToAppError(
    dynamic exception, {
    StackTrace? stackTrace,
    Map<String, dynamic>? context,
  }) {
    final exceptionString = exception.toString().toLowerCase();

    // Check for common VPN error patterns
    if (exceptionString.contains('permission') || exceptionString.contains('denied')) {
      return AppErrorFactory.permissionError(
        technicalMessage: exception.toString(),
        context: context,
        stackTrace: stackTrace?.toString(),
      );
    }

    if (exceptionString.contains('authentication') || exceptionString.contains('auth')) {
      return AppErrorFactory.authenticationError(
        technicalMessage: exception.toString(),
        context: context,
        stackTrace: stackTrace?.toString(),
      );
    }

    if (exceptionString.contains('timeout') || exceptionString.contains('unreachable')) {
      return AppErrorFactory.networkError(
        technicalMessage: exception.toString(),
        context: context,
        stackTrace: stackTrace?.toString(),
      );
    }

    if (exceptionString.contains('configuration') || exceptionString.contains('config')) {
      return AppErrorFactory.configurationError(
        technicalMessage: exception.toString(),
        context: context,
        stackTrace: stackTrace?.toString(),
      );
    }

    // Default to VPN connection error
    return AppErrorFactory.vpnConnectionError(
      technicalMessage: exception.toString(),
      context: context,
      stackTrace: stackTrace?.toString(),
    );
  }

  AppError _convertNetworkExceptionToAppError(
    dynamic exception, {
    StackTrace? stackTrace,
    Map<String, dynamic>? context,
  }) {
    return AppErrorFactory.networkError(
      technicalMessage: exception.toString(),
      context: context,
      stackTrace: stackTrace?.toString(),
    );
  }

  AppError _convertPlatformException(
    PlatformException exception, {
    String? context,
    Map<String, dynamic>? additionalData,
    StackTrace? stackTrace,
  }) {
    final code = exception.code.toLowerCase();
    final message = exception.message ?? 'Platform error occurred';

    if (code.contains('permission') || code.contains('denied')) {
      return AppErrorFactory.permissionError(
        technicalMessage: message,
        errorCode: exception.code,
        context: {
          'platform_details': exception.details?.toString(),
          if (context != null) 'context': context,
          ...?additionalData,
        },
        stackTrace: stackTrace?.toString(),
      );
    }

    if (code.contains('network') || code.contains('connection')) {
      return AppErrorFactory.networkError(
        technicalMessage: message,
        errorCode: exception.code,
        context: {
          'platform_details': exception.details?.toString(),
          if (context != null) 'context': context,
          ...?additionalData,
        },
        stackTrace: stackTrace?.toString(),
      );
    }

    return AppErrorFactory.platformError(
      technicalMessage: message,
      errorCode: exception.code,
      context: {
        'platform_details': exception.details?.toString(),
        if (context != null) 'context': context,
        ...?additionalData,
      },
      stackTrace: stackTrace?.toString(),
    );
  }

  void _addToRecentErrors(AppError error) {
    _recentErrors.insert(0, error);
    
    // Keep only the most recent errors
    if (_recentErrors.length > _maxRecentErrors) {
      _recentErrors.removeRange(_maxRecentErrors, _recentErrors.length);
    }
  }

  Future<void> _logError(AppError error) async {
    try {
      // Log to console/debug output
      switch (error.severity) {
        case ErrorSeverity.critical:
          _logger.f('CRITICAL ERROR [${error.id}]: ${error.technicalMessage}');
          break;
        case ErrorSeverity.high:
          _logger.e('ERROR [${error.id}]: ${error.technicalMessage}');
          break;
        case ErrorSeverity.medium:
          _logger.w('WARNING [${error.id}]: ${error.technicalMessage}');
          break;
        case ErrorSeverity.low:
          _logger.i('INFO [${error.id}]: ${error.technicalMessage}');
          break;
      }

      // Log to persistent storage
      final logMessage = '${error.technicalMessage} [ID: ${error.id}]';
      await _logsService.writeLog(_mapSeverityToLogLevel(error.severity), logMessage);
    } catch (e) {
      _logger.e('Failed to log error: $e');
    }
  }

  Future<void> _showErrorNotification(AppError error) async {
    try {
      // Don't show notifications for low severity errors
      if (error.severity == ErrorSeverity.low) {
        return;
      }

      final notification = _createNotificationFromError(error);
      await _notificationService.showNotification(notification);
    } catch (e) {
      _logger.e('Failed to show error notification: $e');
    }
  }

  NotificationData _createNotificationFromError(AppError error) {
    switch (error.category) {
      case ErrorCategory.network:
        return NotificationFactory.connectionError(
          errorMessage: error.userMessage,
          actionText: error.isRetryable ? 'Retry' : null,
          actionData: error.isRetryable ? {'error_id': error.id} : null,
        );
      
      case ErrorCategory.permission:
        return NotificationFactory.permissionRequired(
          permissionType: 'VPN',
        );
      
      case ErrorCategory.configuration:
        return NotificationFactory.genericError(
          title: 'Configuration Error',
          message: error.userMessage,
          actionText: 'Fix Configuration',
          actionData: {'error_id': error.id},
        );
      
      default:
        return NotificationFactory.genericError(
          title: 'Error',
          message: error.userMessage,
          actionText: error.isRetryable ? 'Retry' : null,
          actionData: error.isRetryable ? {'error_id': error.id} : null,
        );
    }
  }

  bool _shouldReportError(AppError error) {
    final errorKey = '${error.category}_${error.errorCode ?? 'unknown'}';
    final lastReported = _lastReportedErrors[errorKey];
    
    if (lastReported == null) {
      _lastReportedErrors[errorKey] = DateTime.now();
      return true;
    }
    
    final timeSinceLastReport = DateTime.now().difference(lastReported);
    if (timeSinceLastReport > _errorReportingThrottle) {
      _lastReportedErrors[errorKey] = DateTime.now();
      return true;
    }
    
    return false;
  }

  Future<void> _reportError(AppError error) async {
    try {
      // In a real implementation, this would send error reports to a service
      // For now, we'll just log that the error would be reported
      _logger.i('Error reported for analytics: ${error.id}');
      
      // You could integrate with services like:
      // - Firebase Crashlytics
      // - Sentry
      // - Custom analytics service
      
      await _logsService.writeLog('INFO', 'Error reported for analytics [ID: ${error.id}]');
    } catch (e) {
      _logger.e('Failed to report error: $e');
    }
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

  double _calculateRecentErrorRate() {
    if (_recentErrors.isEmpty) return 0.0;
    
    final now = DateTime.now();
    final oneHourAgo = now.subtract(const Duration(hours: 1));
    
    final recentErrorsCount = _recentErrors
        .where((error) => error.timestamp.isAfter(oneHourAgo))
        .length;
    
    return recentErrorsCount / 60.0; // Errors per minute
  }
}