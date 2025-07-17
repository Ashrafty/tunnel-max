import '../models/singbox_error.dart';
import '../models/app_error.dart';

/// Utility class for categorizing and analyzing sing-box errors
/// 
/// This class provides advanced error categorization capabilities including:
/// - Error pattern recognition and classification
/// - Severity assessment based on context and impact
/// - Recovery strategy recommendations
/// - Error correlation and root cause analysis
class SingboxErrorCategorizer {
  
  /// Categorizes an error based on its characteristics and context
  static ErrorCategory categorizeError({
    required SingboxErrorCode errorCode,
    required SingboxOperation operation,
    String? nativeErrorMessage,
    String? protocol,
    Map<String, dynamic>? context,
  }) {
    // Primary categorization based on error code
    switch (errorCode) {
      case SingboxErrorCode.initFailed:
      case SingboxErrorCode.libraryNotFound:
      case SingboxErrorCode.processCrashed:
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
      
      case SingboxErrorCode.statsUnavailable:
        return ErrorCategory.system;
      
      case SingboxErrorCode.unknown:
        return _categorizeUnknownError(nativeErrorMessage, context);
    }
  }

  /// Determines error severity based on multiple factors
  static ErrorSeverity assessSeverity({
    required SingboxErrorCode errorCode,
    required SingboxOperation operation,
    String? protocol,
    String? serverEndpoint,
    Map<String, dynamic>? context,
    bool isRecurring = false,
  }) {
    // Base severity from error code
    ErrorSeverity baseSeverity = _getBaseSeverity(errorCode);
    
    // Adjust severity based on operation criticality
    baseSeverity = _adjustSeverityForOperation(baseSeverity, operation);
    
    // Adjust severity for recurring errors
    if (isRecurring) {
      baseSeverity = _escalateSeverity(baseSeverity);
    }
    
    // Adjust severity based on context
    baseSeverity = _adjustSeverityForContext(baseSeverity, context);
    
    return baseSeverity;
  }

  /// Determines if an error is retryable based on its characteristics
  static bool isRetryable({
    required SingboxErrorCode errorCode,
    required SingboxOperation operation,
    String? nativeErrorMessage,
    Map<String, dynamic>? context,
  }) {
    // Non-retryable error codes
    switch (errorCode) {
      case SingboxErrorCode.configInvalid:
      case SingboxErrorCode.libraryNotFound:
      case SingboxErrorCode.permissionDenied:
        return false;
      
      case SingboxErrorCode.authFailed:
        // Auth failures might be retryable if it's a temporary server issue
        return _isTemporaryAuthFailure(nativeErrorMessage);
      
      case SingboxErrorCode.protocolError:
        // Protocol errors might be retryable with different settings
        return _isRetryableProtocolError(nativeErrorMessage);
      
      default:
        return true;
    }
  }

  /// Generates recovery actions based on error characteristics
  static List<String> generateRecoveryActions({
    required SingboxErrorCode errorCode,
    required SingboxOperation operation,
    String? protocol,
    String? serverEndpoint,
    Map<String, dynamic>? context,
  }) {
    final actions = <String>[];
    
    // Base recovery actions for error code
    actions.addAll(_getBaseRecoveryActions(errorCode));
    
    // Operation-specific actions
    actions.addAll(_getOperationSpecificActions(operation, errorCode));
    
    // Protocol-specific actions
    if (protocol != null) {
      actions.addAll(_getProtocolSpecificActions(protocol, errorCode));
    }
    
    // Context-specific actions
    if (context != null) {
      actions.addAll(_getContextSpecificActions(context, errorCode));
    }
    
    // Remove duplicates and return
    return actions.toSet().toList();
  }

  /// Analyzes error correlation to identify root causes
  static Map<String, dynamic> analyzeErrorCorrelation(List<SingboxError> errors) {
    if (errors.isEmpty) {
      return {'correlation': 'none', 'confidence': 0.0};
    }
    
    final analysis = <String, dynamic>{};
    
    // Time-based correlation
    analysis['temporal_correlation'] = _analyzeTemporalCorrelation(errors);
    
    // Operation-based correlation
    analysis['operation_correlation'] = _analyzeOperationCorrelation(errors);
    
    // Protocol-based correlation
    analysis['protocol_correlation'] = _analyzeProtocolCorrelation(errors);
    
    // Server-based correlation
    analysis['server_correlation'] = _analyzeServerCorrelation(errors);
    
    // Error cascade detection
    analysis['cascade_detection'] = _detectErrorCascades(errors);
    
    // Root cause suggestions
    analysis['root_cause_suggestions'] = _generateRootCauseSuggestions(errors);
    
    return analysis;
  }

  /// Determines if an error should be reported to external systems
  static bool shouldReport({
    required SingboxErrorCode errorCode,
    required ErrorSeverity severity,
    required SingboxOperation operation,
    bool isRecurring = false,
  }) {
    // Always report critical errors
    if (severity == ErrorSeverity.critical) {
      return true;
    }
    
    // Report recurring errors even if they're low severity
    if (isRecurring && severity != ErrorSeverity.low) {
      return true;
    }
    
    // Report initialization and connection failures
    if (operation == SingboxOperation.initialization || 
        operation == SingboxOperation.connection) {
      return severity != ErrorSeverity.low;
    }
    
    // Don't report statistics collection failures
    if (errorCode == SingboxErrorCode.statsUnavailable) {
      return false;
    }
    
    // Report high severity errors by default
    return severity == ErrorSeverity.high;
  }

  /// Estimates recovery time based on error characteristics
  static Duration estimateRecoveryTime({
    required SingboxErrorCode errorCode,
    required SingboxOperation operation,
    bool isRecurring = false,
  }) {
    Duration baseTime = _getBaseRecoveryTime(errorCode);
    
    // Adjust for operation complexity
    baseTime = _adjustRecoveryTimeForOperation(baseTime, operation);
    
    // Increase time for recurring errors
    if (isRecurring) {
      baseTime = Duration(milliseconds: (baseTime.inMilliseconds * 1.5).round());
    }
    
    return baseTime;
  }

  // Private helper methods

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
    
    // Default based on operation
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

  static ErrorCategory _categorizeUnknownError(
    String? nativeErrorMessage,
    Map<String, dynamic>? context,
  ) {
    if (nativeErrorMessage != null) {
      final message = nativeErrorMessage.toLowerCase();
      
      if (message.contains('network') || message.contains('connection') || 
          message.contains('timeout') || message.contains('unreachable')) {
        return ErrorCategory.network;
      }
      
      if (message.contains('config') || message.contains('invalid') || 
          message.contains('parse') || message.contains('format')) {
        return ErrorCategory.configuration;
      }
      
      if (message.contains('permission') || message.contains('denied') || 
          message.contains('access')) {
        return ErrorCategory.permission;
      }
      
      if (message.contains('auth') || message.contains('login') || 
          message.contains('credential')) {
        return ErrorCategory.authentication;
      }
    }
    
    return ErrorCategory.unknown;
  }

  static ErrorSeverity _getBaseSeverity(SingboxErrorCode errorCode) {
    switch (errorCode) {
      case SingboxErrorCode.initFailed:
      case SingboxErrorCode.libraryNotFound:
      case SingboxErrorCode.processCrashed:
      case SingboxErrorCode.permissionDenied:
      case SingboxErrorCode.tunSetupFailed:
        return ErrorSeverity.critical;
      
      case SingboxErrorCode.connectionFailed:
      case SingboxErrorCode.authFailed:
      case SingboxErrorCode.configInvalid:
      case SingboxErrorCode.startFailed:
      case SingboxErrorCode.stopFailed:
        return ErrorSeverity.high;
      
      case SingboxErrorCode.protocolError:
      case SingboxErrorCode.networkUnreachable:
      case SingboxErrorCode.timeout:
        return ErrorSeverity.medium;
      
      case SingboxErrorCode.statsUnavailable:
      case SingboxErrorCode.unknown:
        return ErrorSeverity.low;
    }
  }

  static ErrorSeverity _adjustSeverityForOperation(
    ErrorSeverity baseSeverity, 
    SingboxOperation operation,
  ) {
    switch (operation) {
      case SingboxOperation.initialization:
      case SingboxOperation.connection:
        // Critical operations - escalate severity
        return _escalateSeverity(baseSeverity);
      
      case SingboxOperation.statistics:
      case SingboxOperation.monitoring:
        // Non-critical operations - reduce severity
        return _reduceSeverity(baseSeverity);
      
      default:
        return baseSeverity;
    }
  }

  static ErrorSeverity _escalateSeverity(ErrorSeverity severity) {
    switch (severity) {
      case ErrorSeverity.low:
        return ErrorSeverity.medium;
      case ErrorSeverity.medium:
        return ErrorSeverity.high;
      case ErrorSeverity.high:
        return ErrorSeverity.critical;
      case ErrorSeverity.critical:
        return ErrorSeverity.critical;
    }
  }

  static ErrorSeverity _reduceSeverity(ErrorSeverity severity) {
    switch (severity) {
      case ErrorSeverity.critical:
        return ErrorSeverity.high;
      case ErrorSeverity.high:
        return ErrorSeverity.medium;
      case ErrorSeverity.medium:
        return ErrorSeverity.low;
      case ErrorSeverity.low:
        return ErrorSeverity.low;
    }
  }

  static ErrorSeverity _adjustSeverityForContext(
    ErrorSeverity baseSeverity,
    Map<String, dynamic>? context,
  ) {
    if (context == null) return baseSeverity;
    
    // Check for system resource constraints
    if (context.containsKey('memory_pressure') && context['memory_pressure'] == true) {
      return _escalateSeverity(baseSeverity);
    }
    
    // Check for network conditions
    if (context.containsKey('network_quality') && context['network_quality'] == 'poor') {
      return _reduceSeverity(baseSeverity);
    }
    
    return baseSeverity;
  }

  static bool _isTemporaryAuthFailure(String? nativeErrorMessage) {
    if (nativeErrorMessage == null) return true;
    
    final message = nativeErrorMessage.toLowerCase();
    
    // Permanent auth failures
    if (message.contains('invalid credentials') || 
        message.contains('account disabled') ||
        message.contains('subscription expired')) {
      return false;
    }
    
    // Temporary failures
    return message.contains('server error') || 
           message.contains('timeout') ||
           message.contains('temporary');
  }

  static bool _isRetryableProtocolError(String? nativeErrorMessage) {
    if (nativeErrorMessage == null) return true;
    
    final message = nativeErrorMessage.toLowerCase();
    
    // Non-retryable protocol errors
    if (message.contains('unsupported') || 
        message.contains('not implemented') ||
        message.contains('version mismatch')) {
      return false;
    }
    
    return true;
  }

  static List<String> _getBaseRecoveryActions(SingboxErrorCode errorCode) {
    switch (errorCode) {
      case SingboxErrorCode.initFailed:
        return [
          'Restart the application',
          'Check available system memory',
          'Verify app installation integrity',
        ];
      
      case SingboxErrorCode.configInvalid:
        return [
          'Verify server configuration details',
          'Check protocol-specific settings',
          'Import a valid configuration file',
        ];
      
      case SingboxErrorCode.connectionFailed:
        return [
          'Check internet connectivity',
          'Verify server is online',
          'Try a different server location',
        ];
      
      case SingboxErrorCode.authFailed:
        return [
          'Verify credentials are correct',
          'Check account status',
          'Contact service provider',
        ];
      
      case SingboxErrorCode.permissionDenied:
        return [
          'Grant VPN permission when prompted',
          'Check app permissions in settings',
          'Run as administrator if needed',
        ];
      
      case SingboxErrorCode.libraryNotFound:
        return [
          'Reinstall the application',
          'Download from official sources',
          'Check installation completeness',
        ];
      
      case SingboxErrorCode.timeout:
        return [
          'Check network connection speed',
          'Try again in a few moments',
          'Switch to a closer server',
        ];
      
      default:
        return [
          'Try the operation again',
          'Restart the application if needed',
        ];
    }
  }

  static List<String> _getOperationSpecificActions(
    SingboxOperation operation,
    SingboxErrorCode errorCode,
  ) {
    switch (operation) {
      case SingboxOperation.initialization:
        return [
          'Ensure sufficient system resources',
          'Check for conflicting VPN software',
          'Verify system compatibility',
        ];
      
      case SingboxOperation.connection:
        return [
          'Test with different protocols',
          'Check firewall settings',
          'Verify DNS configuration',
        ];
      
      case SingboxOperation.configuration:
        return [
          'Validate configuration syntax',
          'Check required fields',
          'Test with minimal configuration',
        ];
      
      default:
        return [];
    }
  }

  static List<String> _getProtocolSpecificActions(
    String protocol,
    SingboxErrorCode errorCode,
  ) {
    switch (protocol.toLowerCase()) {
      case 'vless':
        return [
          'Verify UUID format',
          'Check transport settings',
          'Validate TLS configuration',
        ];
      
      case 'vmess':
        return [
          'Check alterId setting',
          'Verify security method',
          'Validate transport options',
        ];
      
      case 'trojan':
        return [
          'Verify password format',
          'Check SNI settings',
          'Validate certificate',
        ];
      
      case 'shadowsocks':
        return [
          'Check cipher method',
          'Verify password',
          'Test with different encryption',
        ];
      
      default:
        return [];
    }
  }

  static List<String> _getContextSpecificActions(
    Map<String, dynamic> context,
    SingboxErrorCode errorCode,
  ) {
    final actions = <String>[];
    
    if (context.containsKey('platform')) {
      final platform = context['platform'].toString().toLowerCase();
      
      if (platform.contains('android')) {
        actions.addAll([
          'Check Android VPN permission',
          'Disable battery optimization',
          'Check for MIUI restrictions',
        ]);
      } else if (platform.contains('windows')) {
        actions.addAll([
          'Run as administrator',
          'Check Windows Defender settings',
          'Verify WinTUN installation',
        ]);
      }
    }
    
    if (context.containsKey('network_type')) {
      final networkType = context['network_type'].toString().toLowerCase();
      
      if (networkType.contains('cellular')) {
        actions.add('Try connecting on Wi-Fi');
      } else if (networkType.contains('wifi')) {
        actions.add('Check Wi-Fi network restrictions');
      }
    }
    
    return actions;
  }

  static Duration _getBaseRecoveryTime(SingboxErrorCode errorCode) {
    switch (errorCode) {
      case SingboxErrorCode.initFailed:
      case SingboxErrorCode.libraryNotFound:
        return const Duration(seconds: 30);
      
      case SingboxErrorCode.connectionFailed:
      case SingboxErrorCode.authFailed:
        return const Duration(seconds: 15);
      
      case SingboxErrorCode.configInvalid:
        return const Duration(seconds: 5);
      
      case SingboxErrorCode.timeout:
        return const Duration(seconds: 10);
      
      default:
        return const Duration(seconds: 5);
    }
  }

  static Duration _adjustRecoveryTimeForOperation(
    Duration baseTime,
    SingboxOperation operation,
  ) {
    switch (operation) {
      case SingboxOperation.initialization:
        return Duration(milliseconds: (baseTime.inMilliseconds * 2).round());
      
      case SingboxOperation.connection:
        return Duration(milliseconds: (baseTime.inMilliseconds * 1.5).round());
      
      default:
        return baseTime;
    }
  }

  // Error correlation analysis methods

  static Map<String, dynamic> _analyzeTemporalCorrelation(List<SingboxError> errors) {
    if (errors.length < 2) return {'correlation': 'insufficient_data'};
    
    final timeGaps = <Duration>[];
    for (int i = 1; i < errors.length; i++) {
      timeGaps.add(errors[i-1].timestamp.difference(errors[i].timestamp));
    }
    
    final avgGap = timeGaps.fold<Duration>(
      Duration.zero,
      (prev, gap) => Duration(milliseconds: prev.inMilliseconds + gap.inMilliseconds),
    );
    
    final avgGapMs = avgGap.inMilliseconds / timeGaps.length;
    
    return {
      'correlation': avgGapMs < 60000 ? 'high' : avgGapMs < 300000 ? 'medium' : 'low',
      'average_gap_seconds': avgGapMs / 1000,
      'pattern': avgGapMs < 10000 ? 'burst' : avgGapMs < 60000 ? 'cascade' : 'sporadic',
    };
  }

  static Map<String, dynamic> _analyzeOperationCorrelation(List<SingboxError> errors) {
    final operationCounts = <SingboxOperation, int>{};
    
    for (final error in errors) {
      operationCounts[error.operation] = (operationCounts[error.operation] ?? 0) + 1;
    }
    
    final dominantOperation = operationCounts.entries
        .reduce((a, b) => a.value > b.value ? a : b);
    
    return {
      'dominant_operation': dominantOperation.key.toString(),
      'concentration': dominantOperation.value / errors.length,
      'distribution': operationCounts.map((k, v) => MapEntry(k.toString(), v)),
    };
  }

  static Map<String, dynamic> _analyzeProtocolCorrelation(List<SingboxError> errors) {
    final protocolCounts = <String, int>{};
    
    for (final error in errors) {
      if (error.protocol != null) {
        protocolCounts[error.protocol!] = (protocolCounts[error.protocol!] ?? 0) + 1;
      }
    }
    
    if (protocolCounts.isEmpty) {
      return {'correlation': 'no_protocol_data'};
    }
    
    final dominantProtocol = protocolCounts.entries
        .reduce((a, b) => a.value > b.value ? a : b);
    
    return {
      'dominant_protocol': dominantProtocol.key,
      'concentration': dominantProtocol.value / errors.length,
      'affected_protocols': protocolCounts.keys.toList(),
    };
  }

  static Map<String, dynamic> _analyzeServerCorrelation(List<SingboxError> errors) {
    final serverCounts = <String, int>{};
    
    for (final error in errors) {
      if (error.serverEndpoint != null) {
        serverCounts[error.serverEndpoint!] = (serverCounts[error.serverEndpoint!] ?? 0) + 1;
      }
    }
    
    if (serverCounts.isEmpty) {
      return {'correlation': 'no_server_data'};
    }
    
    final dominantServer = serverCounts.entries
        .reduce((a, b) => a.value > b.value ? a : b);
    
    return {
      'dominant_server': dominantServer.key,
      'concentration': dominantServer.value / errors.length,
      'affected_servers': serverCounts.keys.toList(),
    };
  }

  static Map<String, dynamic> _detectErrorCascades(List<SingboxError> errors) {
    final cascades = <Map<String, dynamic>>[];
    
    for (int i = 0; i < errors.length - 1; i++) {
      final current = errors[i];
      final next = errors[i + 1];
      
      final timeDiff = current.timestamp.difference(next.timestamp);
      
      if (timeDiff.inSeconds < 30 && 
          current.operation != next.operation &&
          current.severity != ErrorSeverity.low) {
        cascades.add({
          'trigger_error': current.singboxErrorCode.toString(),
          'cascade_error': next.singboxErrorCode.toString(),
          'time_gap_seconds': timeDiff.inSeconds,
          'severity_escalation': next.severity.index > current.severity.index,
        });
      }
    }
    
    return {
      'detected_cascades': cascades.length,
      'cascades': cascades,
      'cascade_rate': cascades.length / errors.length,
    };
  }

  static List<String> _generateRootCauseSuggestions(List<SingboxError> errors) {
    final suggestions = <String>[];
    
    // Analyze error patterns
    final configErrors = errors.where((e) => e.category == ErrorCategory.configuration).length;
    final networkErrors = errors.where((e) => e.category == ErrorCategory.network).length;
    final systemErrors = errors.where((e) => e.category == ErrorCategory.system).length;
    final permissionErrors = errors.where((e) => e.category == ErrorCategory.permission).length;
    
    final total = errors.length;
    
    if (configErrors > total * 0.5) {
      suggestions.add('High configuration error rate suggests server configuration issues');
    }
    
    if (networkErrors > total * 0.4) {
      suggestions.add('Network connectivity or server availability issues detected');
    }
    
    if (systemErrors > total * 0.3) {
      suggestions.add('System resource or compatibility issues may be present');
    }
    
    if (permissionErrors > 0) {
      suggestions.add('Permission-related issues require user intervention');
    }
    
    // Check for initialization failures
    final initErrors = errors.where((e) => e.operation == SingboxOperation.initialization).length;
    if (initErrors > 0) {
      suggestions.add('Initialization failures suggest core system issues');
    }
    
    return suggestions;
  }
}