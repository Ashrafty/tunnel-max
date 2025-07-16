import 'package:json_annotation/json_annotation.dart';

part 'app_error.g.dart';

/// Enum representing different categories of errors in the application
enum ErrorCategory {
  @JsonValue('network')
  network,
  @JsonValue('configuration')
  configuration,
  @JsonValue('permission')
  permission,
  @JsonValue('platform')
  platform,
  @JsonValue('authentication')
  authentication,
  @JsonValue('system')
  system,
  @JsonValue('unknown')
  unknown,
}

/// Enum representing error severity levels
enum ErrorSeverity {
  @JsonValue('low')
  low,
  @JsonValue('medium')
  medium,
  @JsonValue('high')
  high,
  @JsonValue('critical')
  critical,
}

/// Comprehensive error model for the application
/// 
/// This class provides structured error information including:
/// - Error categorization and severity
/// - User-friendly messages and technical details
/// - Context information and recovery suggestions
/// - Timestamp and unique identifier for tracking
@JsonSerializable()
class AppError {
  /// Unique identifier for this error instance
  final String id;
  
  /// Error category for classification
  final ErrorCategory category;
  
  /// Severity level of the error
  final ErrorSeverity severity;
  
  /// User-friendly error message
  final String userMessage;
  
  /// Technical error message for debugging
  final String technicalMessage;
  
  /// Error code for programmatic handling
  final String? errorCode;
  
  /// Additional context information
  final Map<String, dynamic>? context;
  
  /// Suggested recovery actions for the user
  final List<String>? recoveryActions;
  
  /// Whether this error can be retried
  final bool isRetryable;
  
  /// Whether this error should be reported automatically
  final bool shouldReport;
  
  /// Timestamp when the error occurred
  final DateTime timestamp;
  
  /// Stack trace information (for debugging)
  final String? stackTrace;

  const AppError({
    required this.id,
    required this.category,
    required this.severity,
    required this.userMessage,
    required this.technicalMessage,
    this.errorCode,
    this.context,
    this.recoveryActions,
    this.isRetryable = false,
    this.shouldReport = true,
    required this.timestamp,
    this.stackTrace,
  });

  /// Creates an AppError from JSON map
  factory AppError.fromJson(Map<String, dynamic> json) =>
      _$AppErrorFromJson(json);

  /// Converts this AppError to JSON map
  Map<String, dynamic> toJson() => _$AppErrorToJson(this);

  /// Creates a copy of this error with updated fields
  AppError copyWith({
    String? id,
    ErrorCategory? category,
    ErrorSeverity? severity,
    String? userMessage,
    String? technicalMessage,
    String? errorCode,
    Map<String, dynamic>? context,
    List<String>? recoveryActions,
    bool? isRetryable,
    bool? shouldReport,
    DateTime? timestamp,
    String? stackTrace,
  }) {
    return AppError(
      id: id ?? this.id,
      category: category ?? this.category,
      severity: severity ?? this.severity,
      userMessage: userMessage ?? this.userMessage,
      technicalMessage: technicalMessage ?? this.technicalMessage,
      errorCode: errorCode ?? this.errorCode,
      context: context ?? this.context,
      recoveryActions: recoveryActions ?? this.recoveryActions,
      isRetryable: isRetryable ?? this.isRetryable,
      shouldReport: shouldReport ?? this.shouldReport,
      timestamp: timestamp ?? this.timestamp,
      stackTrace: stackTrace ?? this.stackTrace,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AppError &&
        other.id == id &&
        other.category == category &&
        other.severity == severity &&
        other.userMessage == userMessage &&
        other.technicalMessage == technicalMessage &&
        other.errorCode == errorCode &&
        other.isRetryable == isRetryable &&
        other.shouldReport == shouldReport &&
        other.timestamp == timestamp;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      category,
      severity,
      userMessage,
      technicalMessage,
      errorCode,
      isRetryable,
      shouldReport,
      timestamp,
    );
  }

  @override
  String toString() {
    return 'AppError(id: $id, category: $category, severity: $severity, '
           'userMessage: $userMessage, technicalMessage: $technicalMessage, '
           'errorCode: $errorCode, timestamp: $timestamp)';
  }
}

/// Factory class for creating common application errors
class AppErrorFactory {
  /// Creates a network connectivity error
  static AppError networkError({
    required String technicalMessage,
    String? errorCode,
    Map<String, dynamic>? context,
    String? stackTrace,
  }) {
    return AppError(
      id: _generateId(),
      category: ErrorCategory.network,
      severity: ErrorSeverity.high,
      userMessage: 'Network connection failed. Please check your internet connection and try again.',
      technicalMessage: technicalMessage,
      errorCode: errorCode,
      context: context,
      recoveryActions: [
        'Check your internet connection',
        'Try connecting to a different network',
        'Restart your router or modem',
        'Contact your internet service provider if the problem persists',
      ],
      isRetryable: true,
      timestamp: DateTime.now(),
      stackTrace: stackTrace,
    );
  }

  /// Creates a VPN connection error
  static AppError vpnConnectionError({
    required String technicalMessage,
    String? errorCode,
    Map<String, dynamic>? context,
    String? stackTrace,
  }) {
    return AppError(
      id: _generateId(),
      category: ErrorCategory.network,
      severity: ErrorSeverity.high,
      userMessage: 'Failed to establish VPN connection. Please check your server configuration and try again.',
      technicalMessage: technicalMessage,
      errorCode: errorCode,
      context: context,
      recoveryActions: [
        'Verify server configuration details',
        'Check if the VPN server is online',
        'Try connecting to a different server',
        'Check your firewall settings',
      ],
      isRetryable: true,
      timestamp: DateTime.now(),
      stackTrace: stackTrace,
    );
  }

  /// Creates a configuration validation error
  static AppError configurationError({
    required String technicalMessage,
    String? errorCode,
    Map<String, dynamic>? context,
    String? stackTrace,
  }) {
    return AppError(
      id: _generateId(),
      category: ErrorCategory.configuration,
      severity: ErrorSeverity.medium,
      userMessage: 'Invalid configuration detected. Please check your settings and try again.',
      technicalMessage: technicalMessage,
      errorCode: errorCode,
      context: context,
      recoveryActions: [
        'Review your configuration settings',
        'Import a valid configuration file',
        'Contact your VPN provider for correct settings',
      ],
      isRetryable: false,
      timestamp: DateTime.now(),
      stackTrace: stackTrace,
    );
  }

  /// Creates a permission error
  static AppError permissionError({
    required String technicalMessage,
    String? errorCode,
    Map<String, dynamic>? context,
    String? stackTrace,
  }) {
    return AppError(
      id: _generateId(),
      category: ErrorCategory.permission,
      severity: ErrorSeverity.critical,
      userMessage: 'Permission required to establish VPN connection. Please grant the necessary permissions.',
      technicalMessage: technicalMessage,
      errorCode: errorCode,
      context: context,
      recoveryActions: [
        'Grant VPN permission when prompted',
        'Check app permissions in system settings',
        'Restart the application after granting permissions',
      ],
      isRetryable: true,
      timestamp: DateTime.now(),
      stackTrace: stackTrace,
    );
  }

  /// Creates a platform-specific error
  static AppError platformError({
    required String technicalMessage,
    String? errorCode,
    Map<String, dynamic>? context,
    String? stackTrace,
  }) {
    return AppError(
      id: _generateId(),
      category: ErrorCategory.platform,
      severity: ErrorSeverity.high,
      userMessage: 'A system error occurred. Please try again or restart the application.',
      technicalMessage: technicalMessage,
      errorCode: errorCode,
      context: context,
      recoveryActions: [
        'Restart the application',
        'Restart your device',
        'Update the application to the latest version',
      ],
      isRetryable: true,
      timestamp: DateTime.now(),
      stackTrace: stackTrace,
    );
  }

  /// Creates an authentication error
  static AppError authenticationError({
    required String technicalMessage,
    String? errorCode,
    Map<String, dynamic>? context,
    String? stackTrace,
  }) {
    return AppError(
      id: _generateId(),
      category: ErrorCategory.authentication,
      severity: ErrorSeverity.high,
      userMessage: 'Authentication failed. Please check your credentials and try again.',
      technicalMessage: technicalMessage,
      errorCode: errorCode,
      context: context,
      recoveryActions: [
        'Verify your username and password',
        'Check if your account is active',
        'Contact your VPN provider for support',
      ],
      isRetryable: true,
      timestamp: DateTime.now(),
      stackTrace: stackTrace,
    );
  }

  /// Creates a generic system error
  static AppError systemError({
    required String technicalMessage,
    String? errorCode,
    Map<String, dynamic>? context,
    String? stackTrace,
  }) {
    return AppError(
      id: _generateId(),
      category: ErrorCategory.system,
      severity: ErrorSeverity.medium,
      userMessage: 'An unexpected error occurred. Please try again.',
      technicalMessage: technicalMessage,
      errorCode: errorCode,
      context: context,
      recoveryActions: [
        'Try the operation again',
        'Restart the application if the problem persists',
      ],
      isRetryable: true,
      timestamp: DateTime.now(),
      stackTrace: stackTrace,
    );
  }

  /// Creates an unknown error
  static AppError unknownError({
    required String technicalMessage,
    String? errorCode,
    Map<String, dynamic>? context,
    String? stackTrace,
  }) {
    return AppError(
      id: _generateId(),
      category: ErrorCategory.unknown,
      severity: ErrorSeverity.medium,
      userMessage: 'An unexpected error occurred. Please try again.',
      technicalMessage: technicalMessage,
      errorCode: errorCode,
      context: context,
      recoveryActions: [
        'Try the operation again',
        'Restart the application if the problem persists',
        'Contact support if the issue continues',
      ],
      isRetryable: true,
      timestamp: DateTime.now(),
      stackTrace: stackTrace,
    );
  }

  static String _generateId() {
    return DateTime.now().millisecondsSinceEpoch.toString();
  }
}