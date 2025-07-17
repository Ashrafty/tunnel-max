import '../models/singbox_error.dart';

/// Service responsible for mapping native sing-box errors to structured SingboxError instances
/// 
/// This service provides centralized error mapping logic that converts raw error information
/// from the native sing-box implementation into properly categorized and user-friendly errors.
class SingboxErrorMapper {
  /// Maps a native error message to a structured SingboxError
  /// 
  /// This method analyzes the native error message and attempts to categorize it
  /// based on common error patterns and keywords.
  static SingboxError mapNativeError({
    required String nativeErrorMessage,
    String? nativeErrorCode,
    SingboxOperation? operation,
    String? protocol,
    String? serverEndpoint,
    Map<String, dynamic>? singboxConfig,
    Map<String, dynamic>? context,
    String? stackTrace,
  }) {
    final errorMessage = nativeErrorMessage.toLowerCase();
    final errorCode = nativeErrorCode?.toUpperCase();
    
    // If we have a specific error code, use it for mapping
    if (errorCode != null) {
      return SingboxErrorFactory.fromNativeError(
        nativeErrorCode: errorCode,
        nativeErrorMessage: nativeErrorMessage,
        operation: operation,
        protocol: protocol,
        serverEndpoint: serverEndpoint,
        context: context,
        stackTrace: stackTrace,
      );
    }
    
    // Pattern-based error detection for common sing-box error messages
    if (_isInitializationError(errorMessage)) {
      return SingboxErrorFactory.initializationError(
        technicalMessage: 'Sing-box initialization failed: $nativeErrorMessage',
        nativeErrorMessage: nativeErrorMessage,
        context: context,
        stackTrace: stackTrace,
      );
    }
    
    if (_isConfigurationError(errorMessage)) {
      return SingboxErrorFactory.configurationError(
        technicalMessage: 'Sing-box configuration error: $nativeErrorMessage',
        nativeErrorMessage: nativeErrorMessage,
        singboxConfig: singboxConfig,
        protocol: protocol,
        context: context,
        stackTrace: stackTrace,
      );
    }
    
    if (_isConnectionError(errorMessage)) {
      return SingboxErrorFactory.connectionError(
        technicalMessage: 'Sing-box connection error: $nativeErrorMessage',
        nativeErrorMessage: nativeErrorMessage,
        protocol: protocol,
        serverEndpoint: serverEndpoint,
        context: context,
        stackTrace: stackTrace,
      );
    }
    
    if (_isAuthenticationError(errorMessage)) {
      return SingboxErrorFactory.authenticationError(
        technicalMessage: 'Sing-box authentication error: $nativeErrorMessage',
        nativeErrorMessage: nativeErrorMessage,
        protocol: protocol,
        serverEndpoint: serverEndpoint,
        context: context,
        stackTrace: stackTrace,
      );
    }
    
    if (_isProtocolError(errorMessage)) {
      return SingboxErrorFactory.protocolError(
        technicalMessage: 'Sing-box protocol error: $nativeErrorMessage',
        nativeErrorMessage: nativeErrorMessage,
        protocol: protocol ?? 'unknown',
        serverEndpoint: serverEndpoint,
        context: context,
        stackTrace: stackTrace,
      );
    }
    
    if (_isTunSetupError(errorMessage)) {
      return SingboxErrorFactory.tunSetupError(
        technicalMessage: 'Sing-box TUN setup error: $nativeErrorMessage',
        nativeErrorMessage: nativeErrorMessage,
        context: context,
        stackTrace: stackTrace,
      );
    }
    
    if (_isPermissionError(errorMessage)) {
      return SingboxErrorFactory.permissionError(
        technicalMessage: 'Sing-box permission error: $nativeErrorMessage',
        nativeErrorMessage: nativeErrorMessage,
        context: context,
        stackTrace: stackTrace,
      );
    }
    
    if (_isLibraryError(errorMessage)) {
      return SingboxErrorFactory.libraryNotFoundError(
        technicalMessage: 'Sing-box library error: $nativeErrorMessage',
        nativeErrorMessage: nativeErrorMessage,
        context: context,
        stackTrace: stackTrace,
      );
    }
    
    if (_isTimeoutError(errorMessage)) {
      return SingboxErrorFactory.timeoutError(
        technicalMessage: 'Sing-box timeout error: $nativeErrorMessage',
        nativeErrorMessage: nativeErrorMessage,
        operation: operation,
        protocol: protocol,
        serverEndpoint: serverEndpoint,
        context: context,
        stackTrace: stackTrace,
      );
    }
    
    // Default to unknown error if no pattern matches
    return SingboxErrorFactory.unknownError(
      technicalMessage: 'Unrecognized sing-box error: $nativeErrorMessage',
      nativeErrorMessage: nativeErrorMessage,
      operation: operation,
      protocol: protocol,
      serverEndpoint: serverEndpoint,
      context: context,
      stackTrace: stackTrace,
    );
  }

  /// Maps platform channel errors to SingboxError instances
  static SingboxError mapPlatformChannelError({
    required String errorCode,
    required String errorMessage,
    String? errorDetails,
    SingboxOperation? operation,
    String? protocol,
    String? serverEndpoint,
    Map<String, dynamic>? context,
    String? stackTrace,
  }) {
    final combinedContext = <String, dynamic>{
      'platformChannelError': true,
      'errorCode': errorCode,
      'errorDetails': errorDetails,
      ...?context,
    };

    return mapNativeError(
      nativeErrorMessage: errorMessage,
      nativeErrorCode: errorCode,
      operation: operation,
      protocol: protocol,
      serverEndpoint: serverEndpoint,
      context: combinedContext,
      stackTrace: stackTrace,
    );
  }

  /// Maps Dart exceptions to SingboxError instances
  static SingboxError mapDartException({
    required Exception exception,
    SingboxOperation? operation,
    String? protocol,
    String? serverEndpoint,
    Map<String, dynamic>? context,
    String? stackTrace,
  }) {
    final errorMessage = exception.toString();
    final combinedContext = <String, dynamic>{
      'dartException': true,
      'exceptionType': exception.runtimeType.toString(),
      ...?context,
    };

    return mapNativeError(
      nativeErrorMessage: errorMessage,
      operation: operation,
      protocol: protocol,
      serverEndpoint: serverEndpoint,
      context: combinedContext,
      stackTrace: stackTrace ?? StackTrace.current.toString(),
    );
  }

  // Private helper methods for error pattern detection

  static bool _isInitializationError(String errorMessage) {
    return errorMessage.contains('init') ||
           errorMessage.contains('initialize') ||
           errorMessage.contains('startup') ||
           errorMessage.contains('bootstrap') ||
           errorMessage.contains('failed to start') ||
           errorMessage.contains('cannot initialize');
  }

  static bool _isConfigurationError(String errorMessage) {
    return errorMessage.contains('config') ||
           errorMessage.contains('configuration') ||
           errorMessage.contains('invalid') ||
           errorMessage.contains('malformed') ||
           errorMessage.contains('parse') ||
           errorMessage.contains('json') ||
           errorMessage.contains('yaml') ||
           errorMessage.contains('missing field') ||
           errorMessage.contains('required field');
  }

  static bool _isConnectionError(String errorMessage) {
    return errorMessage.contains('connection') ||
           errorMessage.contains('connect') ||
           errorMessage.contains('dial') ||
           errorMessage.contains('network') ||
           errorMessage.contains('unreachable') ||
           errorMessage.contains('refused') ||
           errorMessage.contains('reset') ||
           errorMessage.contains('broken pipe') ||
           errorMessage.contains('no route to host');
  }

  static bool _isAuthenticationError(String errorMessage) {
    return errorMessage.contains('auth') ||
           errorMessage.contains('authentication') ||
           errorMessage.contains('unauthorized') ||
           errorMessage.contains('forbidden') ||
           errorMessage.contains('invalid credentials') ||
           errorMessage.contains('login failed') ||
           errorMessage.contains('access denied') ||
           errorMessage.contains('token') ||
           errorMessage.contains('certificate');
  }

  static bool _isProtocolError(String errorMessage) {
    return errorMessage.contains('protocol') ||
           errorMessage.contains('handshake') ||
           errorMessage.contains('tls') ||
           errorMessage.contains('ssl') ||
           errorMessage.contains('websocket') ||
           errorMessage.contains('grpc') ||
           errorMessage.contains('http') ||
           errorMessage.contains('unsupported') ||
           errorMessage.contains('version mismatch');
  }

  static bool _isTunSetupError(String errorMessage) {
    return errorMessage.contains('tun') ||
           errorMessage.contains('interface') ||
           errorMessage.contains('routing') ||
           errorMessage.contains('route') ||
           errorMessage.contains('adapter') ||
           errorMessage.contains('wintun') ||
           errorMessage.contains('tap');
  }

  static bool _isPermissionError(String errorMessage) {
    return errorMessage.contains('permission') ||
           errorMessage.contains('denied') ||
           errorMessage.contains('access') ||
           errorMessage.contains('privilege') ||
           errorMessage.contains('administrator') ||
           errorMessage.contains('root') ||
           errorMessage.contains('sudo') ||
           errorMessage.contains('elevation required');
  }

  static bool _isLibraryError(String errorMessage) {
    return errorMessage.contains('library') ||
           errorMessage.contains('dll') ||
           errorMessage.contains('so') ||
           errorMessage.contains('dylib') ||
           errorMessage.contains('not found') ||
           errorMessage.contains('missing') ||
           errorMessage.contains('load') ||
           errorMessage.contains('symbol');
  }

  static bool _isTimeoutError(String errorMessage) {
    return errorMessage.contains('timeout') ||
           errorMessage.contains('timed out') ||
           errorMessage.contains('deadline') ||
           errorMessage.contains('expired') ||
           errorMessage.contains('too slow') ||
           errorMessage.contains('no response');
  }
}