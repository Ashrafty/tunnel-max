import 'package:json_annotation/json_annotation.dart';
import 'app_error.dart';

part 'singbox_error.g.dart';

/// Enum representing sing-box specific error codes
enum SingboxErrorCode {
  @JsonValue('SINGBOX_INIT_FAILED')
  initFailed,
  @JsonValue('SINGBOX_CONFIG_INVALID')
  configInvalid,
  @JsonValue('SINGBOX_START_FAILED')
  startFailed,
  @JsonValue('SINGBOX_STOP_FAILED')
  stopFailed,
  @JsonValue('SINGBOX_CONNECTION_FAILED')
  connectionFailed,
  @JsonValue('SINGBOX_PROTOCOL_ERROR')
  protocolError,
  @JsonValue('SINGBOX_AUTH_FAILED')
  authFailed,
  @JsonValue('SINGBOX_NETWORK_UNREACHABLE')
  networkUnreachable,
  @JsonValue('SINGBOX_TUN_SETUP_FAILED')
  tunSetupFailed,
  @JsonValue('SINGBOX_PERMISSION_DENIED')
  permissionDenied,
  @JsonValue('SINGBOX_LIBRARY_NOT_FOUND')
  libraryNotFound,
  @JsonValue('SINGBOX_PROCESS_CRASHED')
  processCrashed,
  @JsonValue('SINGBOX_STATS_UNAVAILABLE')
  statsUnavailable,
  @JsonValue('SINGBOX_TIMEOUT')
  timeout,
  @JsonValue('SINGBOX_UNKNOWN')
  unknown,
}

/// Enum representing sing-box operation types
enum SingboxOperation {
  @JsonValue('initialization')
  initialization,
  @JsonValue('configuration')
  configuration,
  @JsonValue('connection')
  connection,
  @JsonValue('statistics')
  statistics,
  @JsonValue('monitoring')
  monitoring,
  @JsonValue('cleanup')
  cleanup,
}

/// Specialized error class for sing-box related errors
/// 
/// This class extends the base AppError with sing-box specific information
/// including operation context, error codes, and recovery strategies.
@JsonSerializable()
class SingboxError extends AppError {
  /// The sing-box specific error code
  final SingboxErrorCode singboxErrorCode;
  
  /// The operation that was being performed when the error occurred
  final SingboxOperation operation;
  
  /// The sing-box configuration that was being used (if applicable)
  final Map<String, dynamic>? singboxConfig;
  
  /// The native error message from sing-box core
  final String? nativeErrorMessage;
  
  /// The protocol being used when the error occurred
  final String? protocol;
  
  /// The server endpoint that was being connected to
  final String? serverEndpoint;

  const SingboxError({
    required super.id,
    required super.category,
    required super.severity,
    required super.userMessage,
    required super.technicalMessage,
    super.errorCode,
    super.context,
    super.recoveryActions,
    super.isRetryable = false,
    super.shouldReport = true,
    required super.timestamp,
    super.stackTrace,
    required this.singboxErrorCode,
    required this.operation,
    this.singboxConfig,
    this.nativeErrorMessage,
    this.protocol,
    this.serverEndpoint,
  });

  /// Creates a SingboxError from JSON map
  factory SingboxError.fromJson(Map<String, dynamic> json) =>
      _$SingboxErrorFromJson(json);

  /// Converts this SingboxError to JSON map
  @override
  Map<String, dynamic> toJson() => _$SingboxErrorToJson(this);

  /// Creates a copy of this error with updated fields
  @override
  SingboxError copyWith({
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
    SingboxErrorCode? singboxErrorCode,
    SingboxOperation? operation,
    Map<String, dynamic>? singboxConfig,
    String? nativeErrorMessage,
    String? protocol,
    String? serverEndpoint,
  }) {
    return SingboxError(
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
      singboxErrorCode: singboxErrorCode ?? this.singboxErrorCode,
      operation: operation ?? this.operation,
      singboxConfig: singboxConfig ?? this.singboxConfig,
      nativeErrorMessage: nativeErrorMessage ?? this.nativeErrorMessage,
      protocol: protocol ?? this.protocol,
      serverEndpoint: serverEndpoint ?? this.serverEndpoint,
    );
  }

  @override
  String toString() {
    return 'SingboxError(id: $id, category: $category, severity: $severity, '
           'singboxErrorCode: $singboxErrorCode, operation: $operation, '
           'userMessage: $userMessage, technicalMessage: $technicalMessage, '
           'nativeErrorMessage: $nativeErrorMessage, protocol: $protocol, '
           'serverEndpoint: $serverEndpoint, timestamp: $timestamp)';
  }
}

/// Factory class for creating sing-box specific errors with proper categorization
class SingboxErrorFactory {
  
  /// Creates a SingboxError with automatic categorization and severity assessment
  static SingboxError createCategorizedError({
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
    bool isRecurring = false,
  }) {
    // Import the categorizer (this would be done at the top of the file in practice)
    // For now, we'll use basic categorization logic here
    
    final category = _categorizeError(singboxErrorCode, operation, nativeErrorMessage);
    final severity = _assessSeverity(singboxErrorCode, operation, isRecurring);
    final isRetryable = _determineRetryability(singboxErrorCode, nativeErrorMessage);
    final recoveryActions = _generateRecoveryActions(singboxErrorCode, operation, protocol);
    
    return SingboxError(
      id: _generateId(),
      category: category,
      severity: severity,
      userMessage: userMessage ?? _generateUserMessage(singboxErrorCode, category),
      technicalMessage: technicalMessage,
      errorCode: singboxErrorCode.toString().split('.').last.toUpperCase(),
      context: context,
      recoveryActions: recoveryActions,
      isRetryable: isRetryable,
      shouldReport: _shouldReport(singboxErrorCode, severity, operation),
      timestamp: DateTime.now(),
      stackTrace: stackTrace,
      singboxErrorCode: singboxErrorCode,
      operation: operation,
      singboxConfig: singboxConfig,
      nativeErrorMessage: nativeErrorMessage,
      protocol: protocol,
      serverEndpoint: serverEndpoint,
    );
  }

  // Helper methods for categorization
  static ErrorCategory _categorizeError(
    SingboxErrorCode errorCode,
    SingboxOperation operation,
    String? nativeErrorMessage,
  ) {
    switch (errorCode) {
      case SingboxErrorCode.initFailed:
      case SingboxErrorCode.libraryNotFound:
      case SingboxErrorCode.processCrashed:
      case SingboxErrorCode.statsUnavailable:
        return ErrorCategory.system;
      
      case SingboxErrorCode.configInvalid:
      case SingboxErrorCode.protocolError:
        return ErrorCategory.configuration;
      
      case SingboxErrorCode.connectionFailed:
      case SingboxErrorCode.networkUnreachable:
      case SingboxErrorCode.timeout:
        return ErrorCategory.network;
      
      case SingboxErrorCode.authFailed:
        return ErrorCategory.authentication;
      
      case SingboxErrorCode.permissionDenied:
      case SingboxErrorCode.tunSetupFailed:
        return ErrorCategory.permission;
      
      case SingboxErrorCode.startFailed:
      case SingboxErrorCode.stopFailed:
        return _categorizeOperationalError(operation, nativeErrorMessage);
      
      case SingboxErrorCode.unknown:
        return _categorizeUnknownError(nativeErrorMessage);
    }
  }

  static ErrorCategory _categorizeOperationalError(
    SingboxOperation operation,
    String? nativeErrorMessage,
  ) {
    if (nativeErrorMessage != null) {
      final message = nativeErrorMessage.toLowerCase();
      
      if (message.contains('permission') || message.contains('denied')) {
        return ErrorCategory.permission;
      }
      if (message.contains('network') || message.contains('connection')) {
        return ErrorCategory.network;
      }
      if (message.contains('config') || message.contains('invalid')) {
        return ErrorCategory.configuration;
      }
    }
    
    switch (operation) {
      case SingboxOperation.initialization:
        return ErrorCategory.system;
      case SingboxOperation.configuration:
        return ErrorCategory.configuration;
      case SingboxOperation.connection:
        return ErrorCategory.network;
      default:
        return ErrorCategory.system;
    }
  }

  static ErrorCategory _categorizeUnknownError(String? nativeErrorMessage) {
    if (nativeErrorMessage != null) {
      final message = nativeErrorMessage.toLowerCase();
      
      if (message.contains('network') || message.contains('connection')) {
        return ErrorCategory.network;
      }
      if (message.contains('config') || message.contains('invalid')) {
        return ErrorCategory.configuration;
      }
      if (message.contains('permission') || message.contains('denied')) {
        return ErrorCategory.permission;
      }
      if (message.contains('auth') || message.contains('login')) {
        return ErrorCategory.authentication;
      }
    }
    
    return ErrorCategory.unknown;
  }

  static ErrorSeverity _assessSeverity(
    SingboxErrorCode errorCode,
    SingboxOperation operation,
    bool isRecurring,
  ) {
    ErrorSeverity baseSeverity;
    
    switch (errorCode) {
      case SingboxErrorCode.initFailed:
      case SingboxErrorCode.libraryNotFound:
      case SingboxErrorCode.processCrashed:
      case SingboxErrorCode.permissionDenied:
      case SingboxErrorCode.tunSetupFailed:
        baseSeverity = ErrorSeverity.critical;
        break;
      
      case SingboxErrorCode.connectionFailed:
      case SingboxErrorCode.authFailed:
      case SingboxErrorCode.configInvalid:
      case SingboxErrorCode.startFailed:
      case SingboxErrorCode.stopFailed:
        baseSeverity = ErrorSeverity.high;
        break;
      
      case SingboxErrorCode.protocolError:
      case SingboxErrorCode.networkUnreachable:
      case SingboxErrorCode.timeout:
        baseSeverity = ErrorSeverity.medium;
        break;
      
      case SingboxErrorCode.statsUnavailable:
      case SingboxErrorCode.unknown:
        baseSeverity = ErrorSeverity.low;
        break;
    }
    
    // Adjust for critical operations
    if (operation == SingboxOperation.initialization || 
        operation == SingboxOperation.connection) {
      baseSeverity = _escalateSeverity(baseSeverity);
    }
    
    // Escalate recurring errors
    if (isRecurring) {
      baseSeverity = _escalateSeverity(baseSeverity);
    }
    
    return baseSeverity;
  }

  static ErrorSeverity _escalateSeverity(ErrorSeverity severity) {
    switch (severity) {
      case ErrorSeverity.low:
        return ErrorSeverity.medium;
      case ErrorSeverity.medium:
        return ErrorSeverity.high;
      case ErrorSeverity.high:
      case ErrorSeverity.critical:
        return ErrorSeverity.critical;
    }
  }

  static bool _determineRetryability(
    SingboxErrorCode errorCode,
    String? nativeErrorMessage,
  ) {
    switch (errorCode) {
      case SingboxErrorCode.configInvalid:
      case SingboxErrorCode.libraryNotFound:
      case SingboxErrorCode.permissionDenied:
        return false;
      
      case SingboxErrorCode.authFailed:
        return _isTemporaryAuthFailure(nativeErrorMessage);
      
      case SingboxErrorCode.protocolError:
        return _isRetryableProtocolError(nativeErrorMessage);
      
      default:
        return true;
    }
  }

  static bool _isTemporaryAuthFailure(String? nativeErrorMessage) {
    if (nativeErrorMessage == null) return true;
    
    final message = nativeErrorMessage.toLowerCase();
    return !(message.contains('invalid credentials') || 
             message.contains('account disabled') ||
             message.contains('subscription expired'));
  }

  static bool _isRetryableProtocolError(String? nativeErrorMessage) {
    if (nativeErrorMessage == null) return true;
    
    final message = nativeErrorMessage.toLowerCase();
    return !(message.contains('unsupported') || 
             message.contains('not implemented') ||
             message.contains('version mismatch'));
  }

  static List<String> _generateRecoveryActions(
    SingboxErrorCode errorCode,
    SingboxOperation operation,
    String? protocol,
  ) {
    final actions = <String>[];
    
    // Base actions for error code
    switch (errorCode) {
      case SingboxErrorCode.initFailed:
        actions.addAll([
          'Restart the application',
          'Check available system memory',
          'Verify app installation integrity',
        ]);
        break;
      
      case SingboxErrorCode.configInvalid:
        actions.addAll([
          'Verify server configuration details',
          'Check protocol-specific settings',
          'Import a valid configuration file',
        ]);
        break;
      
      case SingboxErrorCode.connectionFailed:
        actions.addAll([
          'Check internet connectivity',
          'Verify server is online',
          'Try a different server location',
        ]);
        break;
      
      case SingboxErrorCode.authFailed:
        actions.addAll([
          'Verify credentials are correct',
          'Check account status',
          'Contact service provider',
        ]);
        break;
      
      case SingboxErrorCode.permissionDenied:
        actions.addAll([
          'Grant VPN permission when prompted',
          'Check app permissions in settings',
          'Run as administrator if needed',
        ]);
        break;
      
      default:
        actions.addAll([
          'Try the operation again',
          'Restart the application if needed',
        ]);
    }
    
    // Add operation-specific actions
    switch (operation) {
      case SingboxOperation.initialization:
        actions.addAll([
          'Ensure sufficient system resources',
          'Check for conflicting VPN software',
        ]);
        break;
      
      case SingboxOperation.connection:
        actions.addAll([
          'Test with different protocols',
          'Check firewall settings',
        ]);
        break;
      
      default:
        break;
    }
    
    return actions.toSet().toList(); // Remove duplicates
  }

  static String _generateUserMessage(SingboxErrorCode errorCode, ErrorCategory category) {
    switch (errorCode) {
      case SingboxErrorCode.initFailed:
        return 'Failed to initialize VPN core. Please restart the application.';
      case SingboxErrorCode.configInvalid:
        return 'Invalid VPN configuration. Please check your server settings.';
      case SingboxErrorCode.connectionFailed:
        return 'Failed to connect to VPN server. Please check your connection and try again.';
      case SingboxErrorCode.authFailed:
        return 'Authentication failed. Please check your credentials.';
      case SingboxErrorCode.permissionDenied:
        return 'Permission required to establish VPN connection.';
      case SingboxErrorCode.libraryNotFound:
        return 'VPN core library is missing. Please reinstall the application.';
      case SingboxErrorCode.processCrashed:
        return 'VPN core has stopped unexpectedly. Attempting to restart.';
      case SingboxErrorCode.timeout:
        return 'Operation timed out. Please check your connection and try again.';
      default:
        return 'An unexpected error occurred. Please try again.';
    }
  }

  static bool _shouldReport(
    SingboxErrorCode errorCode,
    ErrorSeverity severity,
    SingboxOperation operation,
  ) {
    // Always report critical errors
    if (severity == ErrorSeverity.critical) return true;
    
    // Don't report statistics collection failures
    if (errorCode == SingboxErrorCode.statsUnavailable) return false;
    
    // Report initialization and connection failures
    if (operation == SingboxOperation.initialization || 
        operation == SingboxOperation.connection) {
      return severity != ErrorSeverity.low;
    }
    
    // Report high severity errors by default
    return severity == ErrorSeverity.high;
  }
  /// Creates an error for sing-box initialization failure
  static SingboxError initializationError({
    required String technicalMessage,
    String? nativeErrorMessage,
    Map<String, dynamic>? context,
    String? stackTrace,
  }) {
    return SingboxError(
      id: _generateId(),
      category: ErrorCategory.system,
      severity: ErrorSeverity.critical,
      userMessage: 'Failed to initialize VPN core. Please restart the application.',
      technicalMessage: technicalMessage,
      errorCode: 'SINGBOX_INIT_FAILED',
      context: context,
      recoveryActions: [
        'Restart the application',
        'Check if the device has sufficient memory',
        'Ensure the app has necessary permissions',
        'Reinstall the application if the problem persists',
      ],
      isRetryable: true,
      timestamp: DateTime.now(),
      stackTrace: stackTrace,
      singboxErrorCode: SingboxErrorCode.initFailed,
      operation: SingboxOperation.initialization,
      nativeErrorMessage: nativeErrorMessage,
    );
  }

  /// Creates an error for invalid sing-box configuration
  static SingboxError configurationError({
    required String technicalMessage,
    String? nativeErrorMessage,
    Map<String, dynamic>? singboxConfig,
    String? protocol,
    Map<String, dynamic>? context,
    String? stackTrace,
  }) {
    return SingboxError(
      id: _generateId(),
      category: ErrorCategory.configuration,
      severity: ErrorSeverity.high,
      userMessage: 'Invalid VPN configuration. Please check your server settings.',
      technicalMessage: technicalMessage,
      errorCode: 'SINGBOX_CONFIG_INVALID',
      context: context,
      recoveryActions: [
        'Verify server configuration details',
        'Check protocol-specific settings',
        'Import a valid configuration file',
        'Contact your VPN provider for correct settings',
      ],
      isRetryable: false,
      timestamp: DateTime.now(),
      stackTrace: stackTrace,
      singboxErrorCode: SingboxErrorCode.configInvalid,
      operation: SingboxOperation.configuration,
      singboxConfig: singboxConfig,
      nativeErrorMessage: nativeErrorMessage,
      protocol: protocol,
    );
  }

  /// Creates an error for sing-box connection failure
  static SingboxError connectionError({
    required String technicalMessage,
    String? nativeErrorMessage,
    String? protocol,
    String? serverEndpoint,
    Map<String, dynamic>? context,
    String? stackTrace,
  }) {
    return SingboxError(
      id: _generateId(),
      category: ErrorCategory.network,
      severity: ErrorSeverity.high,
      userMessage: 'Failed to connect to VPN server. Please check your connection and try again.',
      technicalMessage: technicalMessage,
      errorCode: 'SINGBOX_CONNECTION_FAILED',
      context: context,
      recoveryActions: [
        'Check your internet connection',
        'Verify server is online and accessible',
        'Try connecting to a different server',
        'Check firewall and antivirus settings',
      ],
      isRetryable: true,
      timestamp: DateTime.now(),
      stackTrace: stackTrace,
      singboxErrorCode: SingboxErrorCode.connectionFailed,
      operation: SingboxOperation.connection,
      nativeErrorMessage: nativeErrorMessage,
      protocol: protocol,
      serverEndpoint: serverEndpoint,
    );
  }

  /// Creates an error for authentication failure
  static SingboxError authenticationError({
    required String technicalMessage,
    String? nativeErrorMessage,
    String? protocol,
    String? serverEndpoint,
    Map<String, dynamic>? context,
    String? stackTrace,
  }) {
    return SingboxError(
      id: _generateId(),
      category: ErrorCategory.authentication,
      severity: ErrorSeverity.high,
      userMessage: 'Authentication failed. Please check your credentials.',
      technicalMessage: technicalMessage,
      errorCode: 'SINGBOX_AUTH_FAILED',
      context: context,
      recoveryActions: [
        'Verify your username and password',
        'Check if your account is active',
        'Ensure your subscription is valid',
        'Contact your VPN provider for support',
      ],
      isRetryable: true,
      timestamp: DateTime.now(),
      stackTrace: stackTrace,
      singboxErrorCode: SingboxErrorCode.authFailed,
      operation: SingboxOperation.connection,
      nativeErrorMessage: nativeErrorMessage,
      protocol: protocol,
      serverEndpoint: serverEndpoint,
    );
  }

  /// Creates an error for protocol-specific issues
  static SingboxError protocolError({
    required String technicalMessage,
    String? nativeErrorMessage,
    required String protocol,
    String? serverEndpoint,
    Map<String, dynamic>? context,
    String? stackTrace,
  }) {
    return SingboxError(
      id: _generateId(),
      category: ErrorCategory.configuration,
      severity: ErrorSeverity.medium,
      userMessage: 'Protocol error occurred. The server may not support this protocol.',
      technicalMessage: technicalMessage,
      errorCode: 'SINGBOX_PROTOCOL_ERROR',
      context: context,
      recoveryActions: [
        'Try a different protocol if available',
        'Check if the server supports $protocol',
        'Verify protocol-specific settings',
        'Contact your VPN provider for supported protocols',
      ],
      isRetryable: true,
      timestamp: DateTime.now(),
      stackTrace: stackTrace,
      singboxErrorCode: SingboxErrorCode.protocolError,
      operation: SingboxOperation.connection,
      nativeErrorMessage: nativeErrorMessage,
      protocol: protocol,
      serverEndpoint: serverEndpoint,
    );
  }

  /// Creates an error for TUN interface setup failure
  static SingboxError tunSetupError({
    required String technicalMessage,
    String? nativeErrorMessage,
    Map<String, dynamic>? context,
    String? stackTrace,
  }) {
    return SingboxError(
      id: _generateId(),
      category: ErrorCategory.platform,
      severity: ErrorSeverity.critical,
      userMessage: 'Failed to set up VPN interface. Please check permissions.',
      technicalMessage: technicalMessage,
      errorCode: 'SINGBOX_TUN_SETUP_FAILED',
      context: context,
      recoveryActions: [
        'Grant VPN permission when prompted',
        'Check app permissions in system settings',
        'Restart the application',
        'Restart your device if the problem persists',
      ],
      isRetryable: true,
      timestamp: DateTime.now(),
      stackTrace: stackTrace,
      singboxErrorCode: SingboxErrorCode.tunSetupFailed,
      operation: SingboxOperation.initialization,
      nativeErrorMessage: nativeErrorMessage,
    );
  }

  /// Creates an error for permission denied
  static SingboxError permissionError({
    required String technicalMessage,
    String? nativeErrorMessage,
    Map<String, dynamic>? context,
    String? stackTrace,
  }) {
    return SingboxError(
      id: _generateId(),
      category: ErrorCategory.permission,
      severity: ErrorSeverity.critical,
      userMessage: 'Permission required to establish VPN connection.',
      technicalMessage: technicalMessage,
      errorCode: 'SINGBOX_PERMISSION_DENIED',
      context: context,
      recoveryActions: [
        'Grant VPN permission when prompted',
        'Check app permissions in system settings',
        'Ensure the app is not restricted by device policies',
        'Restart the application after granting permissions',
      ],
      isRetryable: true,
      timestamp: DateTime.now(),
      stackTrace: stackTrace,
      singboxErrorCode: SingboxErrorCode.permissionDenied,
      operation: SingboxOperation.initialization,
      nativeErrorMessage: nativeErrorMessage,
    );
  }

  /// Creates an error for sing-box library not found
  static SingboxError libraryNotFoundError({
    required String technicalMessage,
    String? nativeErrorMessage,
    Map<String, dynamic>? context,
    String? stackTrace,
  }) {
    return SingboxError(
      id: _generateId(),
      category: ErrorCategory.system,
      severity: ErrorSeverity.critical,
      userMessage: 'VPN core library is missing. Please reinstall the application.',
      technicalMessage: technicalMessage,
      errorCode: 'SINGBOX_LIBRARY_NOT_FOUND',
      context: context,
      recoveryActions: [
        'Reinstall the application',
        'Download the app from official sources',
        'Check if the app installation is complete',
        'Contact support if the problem persists',
      ],
      isRetryable: false,
      timestamp: DateTime.now(),
      stackTrace: stackTrace,
      singboxErrorCode: SingboxErrorCode.libraryNotFound,
      operation: SingboxOperation.initialization,
      nativeErrorMessage: nativeErrorMessage,
    );
  }

  /// Creates an error for sing-box process crash
  static SingboxError processCrashError({
    required String technicalMessage,
    String? nativeErrorMessage,
    Map<String, dynamic>? context,
    String? stackTrace,
  }) {
    return SingboxError(
      id: _generateId(),
      category: ErrorCategory.system,
      severity: ErrorSeverity.critical,
      userMessage: 'VPN core has stopped unexpectedly. Attempting to restart.',
      technicalMessage: technicalMessage,
      errorCode: 'SINGBOX_PROCESS_CRASHED',
      context: context,
      recoveryActions: [
        'The application will attempt to restart automatically',
        'Check device memory and close other apps if needed',
        'Restart the application if auto-recovery fails',
        'Contact support if crashes continue',
      ],
      isRetryable: true,
      timestamp: DateTime.now(),
      stackTrace: stackTrace,
      singboxErrorCode: SingboxErrorCode.processCrashed,
      operation: SingboxOperation.monitoring,
      nativeErrorMessage: nativeErrorMessage,
    );
  }

  /// Creates an error for statistics collection failure
  static SingboxError statisticsError({
    required String technicalMessage,
    String? nativeErrorMessage,
    Map<String, dynamic>? context,
    String? stackTrace,
  }) {
    return SingboxError(
      id: _generateId(),
      category: ErrorCategory.system,
      severity: ErrorSeverity.medium,
      userMessage: 'Unable to collect connection statistics.',
      technicalMessage: technicalMessage,
      errorCode: 'SINGBOX_STATS_UNAVAILABLE',
      context: context,
      recoveryActions: [
        'Statistics will be retried automatically',
        'Connection functionality is not affected',
        'Restart the connection if statistics are important',
      ],
      isRetryable: true,
      shouldReport: false,
      timestamp: DateTime.now(),
      stackTrace: stackTrace,
      singboxErrorCode: SingboxErrorCode.statsUnavailable,
      operation: SingboxOperation.statistics,
      nativeErrorMessage: nativeErrorMessage,
    );
  }

  /// Creates an error for operation timeout
  static SingboxError timeoutError({
    required String technicalMessage,
    String? nativeErrorMessage,
    SingboxOperation? operation,
    String? protocol,
    String? serverEndpoint,
    Map<String, dynamic>? context,
    String? stackTrace,
  }) {
    return SingboxError(
      id: _generateId(),
      category: ErrorCategory.network,
      severity: ErrorSeverity.medium,
      userMessage: 'Operation timed out. Please check your connection and try again.',
      technicalMessage: technicalMessage,
      errorCode: 'SINGBOX_TIMEOUT',
      context: context,
      recoveryActions: [
        'Check your internet connection speed',
        'Try connecting to a different server',
        'Check if the server is overloaded',
        'Try again in a few moments',
      ],
      isRetryable: true,
      timestamp: DateTime.now(),
      stackTrace: stackTrace,
      singboxErrorCode: SingboxErrorCode.timeout,
      operation: operation ?? SingboxOperation.connection,
      nativeErrorMessage: nativeErrorMessage,
      protocol: protocol,
      serverEndpoint: serverEndpoint,
    );
  }

  /// Creates a generic sing-box error when specific categorization is not possible
  static SingboxError unknownError({
    required String technicalMessage,
    String? nativeErrorMessage,
    SingboxOperation? operation,
    String? protocol,
    String? serverEndpoint,
    Map<String, dynamic>? context,
    String? stackTrace,
  }) {
    return SingboxError(
      id: _generateId(),
      category: ErrorCategory.unknown,
      severity: ErrorSeverity.medium,
      userMessage: 'An unexpected error occurred. Please try again.',
      technicalMessage: technicalMessage,
      errorCode: 'SINGBOX_UNKNOWN',
      context: context,
      recoveryActions: [
        'Try the operation again',
        'Restart the application if the problem persists',
        'Check for app updates',
        'Contact support if the issue continues',
      ],
      isRetryable: true,
      timestamp: DateTime.now(),
      stackTrace: stackTrace,
      singboxErrorCode: SingboxErrorCode.unknown,
      operation: operation ?? SingboxOperation.connection,
      nativeErrorMessage: nativeErrorMessage,
      protocol: protocol,
      serverEndpoint: serverEndpoint,
    );
  }

  /// Maps native sing-box error codes to SingboxError instances
  static SingboxError fromNativeError({
    required String nativeErrorCode,
    required String nativeErrorMessage,
    String? technicalMessage,
    SingboxOperation? operation,
    String? protocol,
    String? serverEndpoint,
    Map<String, dynamic>? context,
    String? stackTrace,
  }) {
    final tech = technicalMessage ?? 'Native error: $nativeErrorCode - $nativeErrorMessage';
    
    switch (nativeErrorCode.toUpperCase()) {
      case 'INIT_FAILED':
      case 'INITIALIZATION_ERROR':
        return initializationError(
          technicalMessage: tech,
          nativeErrorMessage: nativeErrorMessage,
          context: context,
          stackTrace: stackTrace,
        );
      
      case 'CONFIG_INVALID':
      case 'CONFIGURATION_ERROR':
      case 'INVALID_CONFIG':
        return configurationError(
          technicalMessage: tech,
          nativeErrorMessage: nativeErrorMessage,
          protocol: protocol,
          context: context,
          stackTrace: stackTrace,
        );
      
      case 'CONNECTION_FAILED':
      case 'CONNECT_ERROR':
        return connectionError(
          technicalMessage: tech,
          nativeErrorMessage: nativeErrorMessage,
          protocol: protocol,
          serverEndpoint: serverEndpoint,
          context: context,
          stackTrace: stackTrace,
        );
      
      case 'AUTH_FAILED':
      case 'AUTHENTICATION_ERROR':
      case 'UNAUTHORIZED':
        return authenticationError(
          technicalMessage: tech,
          nativeErrorMessage: nativeErrorMessage,
          protocol: protocol,
          serverEndpoint: serverEndpoint,
          context: context,
          stackTrace: stackTrace,
        );
      
      case 'PROTOCOL_ERROR':
      case 'UNSUPPORTED_PROTOCOL':
        return protocolError(
          technicalMessage: tech,
          nativeErrorMessage: nativeErrorMessage,
          protocol: protocol ?? 'unknown',
          serverEndpoint: serverEndpoint,
          context: context,
          stackTrace: stackTrace,
        );
      
      case 'TUN_SETUP_FAILED':
      case 'INTERFACE_ERROR':
        return tunSetupError(
          technicalMessage: tech,
          nativeErrorMessage: nativeErrorMessage,
          context: context,
          stackTrace: stackTrace,
        );
      
      case 'PERMISSION_DENIED':
      case 'ACCESS_DENIED':
        return permissionError(
          technicalMessage: tech,
          nativeErrorMessage: nativeErrorMessage,
          context: context,
          stackTrace: stackTrace,
        );
      
      case 'LIBRARY_NOT_FOUND':
      case 'MISSING_LIBRARY':
        return libraryNotFoundError(
          technicalMessage: tech,
          nativeErrorMessage: nativeErrorMessage,
          context: context,
          stackTrace: stackTrace,
        );
      
      case 'PROCESS_CRASHED':
      case 'CORE_CRASHED':
        return processCrashError(
          technicalMessage: tech,
          nativeErrorMessage: nativeErrorMessage,
          context: context,
          stackTrace: stackTrace,
        );
      
      case 'TIMEOUT':
      case 'OPERATION_TIMEOUT':
        return timeoutError(
          technicalMessage: tech,
          nativeErrorMessage: nativeErrorMessage,
          operation: operation,
          protocol: protocol,
          serverEndpoint: serverEndpoint,
          context: context,
          stackTrace: stackTrace,
        );
      
      default:
        return unknownError(
          technicalMessage: tech,
          nativeErrorMessage: nativeErrorMessage,
          operation: operation,
          protocol: protocol,
          serverEndpoint: serverEndpoint,
          context: context,
          stackTrace: stackTrace,
        );
    }
  }

  static String _generateId() {
    return 'singbox_${DateTime.now().millisecondsSinceEpoch}';
  }
}