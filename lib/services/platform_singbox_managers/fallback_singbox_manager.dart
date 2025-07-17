import 'dart:async';
import 'package:logger/logger.dart';

import '../../interfaces/singbox_manager_interface.dart';
import '../../models/vpn_configuration.dart';
import '../../models/network_stats.dart';
import '../../models/singbox_error.dart' as ErrorModels;

/// Fallback implementation of SingboxManager for unsupported platforms
/// 
/// This implementation provides a non-functional but safe fallback for platforms
/// that don't have native sing-box integration. All operations will fail gracefully
/// with appropriate error messages.
class FallbackSingboxManager implements SingboxManagerInterface {
  final Logger _logger;
  
  // State management
  bool _isInitialized = false;
  ErrorModels.SingboxError? _lastError;
  
  // Stream controllers for consistency with other implementations
  final StreamController<NetworkStats> _statsController = StreamController<NetworkStats>.broadcast();
  final StreamController<SingboxError> _errorController = StreamController<SingboxError>.broadcast();
  
  FallbackSingboxManager({
    Logger? logger,
  }) : _logger = logger ?? Logger() {
    _logger.d('FallbackSingboxManager created for unsupported platform');
  }

  @override
  Future<bool> initialize() async {
    _logger.w('Attempting to initialize sing-box on unsupported platform');
    
    final error = ErrorModels.SingboxErrorFactory.createCategorizedError(
      singboxErrorCode: ErrorModels.SingboxErrorCode.libraryNotFound,
      operation: ErrorModels.SingboxOperation.initialization,
      technicalMessage: 'sing-box is not supported on this platform',
      userMessage: 'VPN functionality is not available on this platform',
    );
    
    await _setError(error);
    return false;
  }

  @override
  Future<bool> start(VpnConfiguration config, {int? tunFileDescriptor}) async {
    _logger.w('Attempting to start sing-box on unsupported platform');
    
    final error = ErrorModels.SingboxErrorFactory.connectionError(
      technicalMessage: 'Cannot start sing-box: platform not supported',
      protocol: config.protocol.name,
      serverEndpoint: '${config.serverAddress}:${config.serverPort}',
    );
    
    await _setError(error);
    return false;
  }

  @override
  Future<bool> stop() async {
    _logger.w('Attempting to stop sing-box on unsupported platform');
    return true; // Always succeed for stop operations
  }

  @override
  Future<bool> restart({VpnConfiguration? config}) async {
    _logger.w('Attempting to restart sing-box on unsupported platform');
    
    final error = ErrorModels.SingboxErrorFactory.connectionError(
      technicalMessage: 'Cannot restart sing-box: platform not supported',
    );
    
    await _setError(error);
    return false;
  }

  @override
  Future<bool> isRunning() async {
    return false; // Never running on unsupported platforms
  }

  @override
  Future<void> cleanup() async {
    _logger.i('Cleaning up FallbackSingboxManager');
    
    await _statsController.close();
    await _errorController.close();
    
    _isInitialized = false;
    _logger.i('FallbackSingboxManager cleanup completed');
  }

  @override
  Future<bool> validateConfiguration(String configJson) async {
    _logger.w('Configuration validation not available on unsupported platform');
    return false;
  }

  @override
  Future<bool> updateConfiguration(VpnConfiguration config) async {
    _logger.w('Configuration update not available on unsupported platform');
    
    final error = ErrorModels.SingboxErrorFactory.configurationError(
      technicalMessage: 'Cannot update configuration: platform not supported',
      protocol: config.protocol.name,
    );
    
    await _setError(error);
    return false;
  }

  @override
  Future<String?> getCurrentConfiguration() async {
    return null;
  }

  @override
  Future<NetworkStats?> getStatistics() async {
    return null;
  }

  @override
  Future<DetailedNetworkStats?> getDetailedStatistics() async {
    return null;
  }

  @override
  Future<bool> resetStatistics() async {
    return false;
  }

  @override
  Stream<NetworkStats> get statisticsStream => _statsController.stream;

  @override
  Future<bool> setLogLevel(LogLevel level) async {
    return false;
  }

  @override
  Future<List<String>> getLogs() async {
    return ['Platform not supported - no logs available'];
  }

  @override
  Future<ConnectionInfo?> getConnectionInfo() async {
    return null;
  }

  @override
  Future<MemoryStats?> getMemoryUsage() async {
    return null;
  }

  @override
  Future<bool> optimizePerformance() async {
    return false;
  }

  @override
  Future<bool> handleNetworkChange(NetworkInfo networkInfo) async {
    return false;
  }

  @override
  Future<String?> getVersion() async {
    return 'Not available (unsupported platform)';
  }

  @override
  Future<List<String>> getSupportedProtocols() async {
    return []; // No protocols supported
  }

  @override
  Future<SingboxError?> getLastError() async {
    if (_lastError == null) return null;
    
    // Convert from models.SingboxError to interface.SingboxError
    return SingboxError(
      code: _convertErrorCode(_lastError!.singboxErrorCode),
      message: _lastError!.userMessage,
      nativeMessage: _lastError!.nativeErrorMessage,
      timestamp: _lastError!.timestamp,
    );
  }

  @override
  Future<void> clearError() async {
    _lastError = null;
  }

  @override
  Stream<SingboxError> get errorStream => _errorController.stream;

  @override
  Future<List<String>> getErrorHistory() async {
    return ['Platform not supported'];
  }

  @override
  Future<Map<String, int>> getOperationTimings() async {
    return {};
  }

  @override
  Future<void> clearDiagnosticData() async {
    // No-op for unsupported platforms
  }

  @override
  Future<Map<String, String>> generateDiagnosticReport() async {
    return {
      'platform': 'unsupported',
      'status': 'not_available',
      'message': 'sing-box is not supported on this platform',
    };
  }

  @override
  Future<String> exportDiagnosticLogs() async {
    return '{"platform": "unsupported", "message": "No diagnostic logs available"}';
  }

  // Private helper methods

  Future<void> _setError(ErrorModels.SingboxError error) async {
    _lastError = error;
    // Convert to interface SingboxError for the stream
    final interfaceError = SingboxError(
      code: _convertErrorCode(error.singboxErrorCode),
      message: error.userMessage,
      nativeMessage: error.nativeErrorMessage,
      timestamp: error.timestamp,
    );
    _errorController.add(interfaceError);
  }

  /// Convert from models.SingboxErrorCode to interface.SingboxErrorCode
  SingboxErrorCode _convertErrorCode(ErrorModels.SingboxErrorCode modelCode) {
    switch (modelCode) {
      case ErrorModels.SingboxErrorCode.initFailed:
        return SingboxErrorCode.initializationFailed;
      case ErrorModels.SingboxErrorCode.configInvalid:
        return SingboxErrorCode.configurationInvalid;
      case ErrorModels.SingboxErrorCode.startFailed:
      case ErrorModels.SingboxErrorCode.connectionFailed:
        return SingboxErrorCode.networkUnreachable;
      case ErrorModels.SingboxErrorCode.authFailed:
        return SingboxErrorCode.authenticationFailed;
      case ErrorModels.SingboxErrorCode.protocolError:
        return SingboxErrorCode.tlsHandshakeFailed;
      case ErrorModels.SingboxErrorCode.tunSetupFailed:
        return SingboxErrorCode.tunInterfaceError;
      case ErrorModels.SingboxErrorCode.permissionDenied:
        return SingboxErrorCode.permissionDenied;
      case ErrorModels.SingboxErrorCode.processCrashed:
        return SingboxErrorCode.processTerminated;
      case ErrorModels.SingboxErrorCode.timeout:
        return SingboxErrorCode.timeout;
      case ErrorModels.SingboxErrorCode.libraryNotFound:
        return SingboxErrorCode.unknown;
      default:
        return SingboxErrorCode.unknown;
    }
  }
}