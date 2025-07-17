import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:logger/logger.dart';

import '../../interfaces/singbox_manager_interface.dart';
import '../../models/vpn_configuration.dart';
import '../../models/network_stats.dart';
import '../../models/singbox_error.dart' as ErrorModels;
import '../singbox_configuration_converter.dart';

/// Android-specific implementation of SingboxManager using JNI integration
/// 
/// This implementation communicates with the native Android sing-box library
/// through JNI (Java Native Interface) for optimal performance and integration.
class AndroidSingboxManager implements SingboxManagerInterface {
  static const MethodChannel _channel = MethodChannel('com.tunnelmax.vpnclient/singbox');
  
  final Logger _logger;
  final SingboxConfigurationConverter _configConverter;
  
  // State management
  bool _isInitialized = false;
  bool _isRunning = false;
  VpnConfiguration? _currentConfig;
  ErrorModels.SingboxError? _lastError;
  
  // Stream controllers for real-time data
  final StreamController<NetworkStats> _statsController = StreamController<NetworkStats>.broadcast();
  final StreamController<ErrorModels.SingboxError> _errorController = StreamController<ErrorModels.SingboxError>.broadcast();
  
  // Statistics collection timer
  Timer? _statsTimer;
  
  AndroidSingboxManager({
    Logger? logger,
    SingboxConfigurationConverter? configConverter,
  }) : _logger = logger ?? Logger(),
       _configConverter = configConverter ?? SingboxConfigurationConverter() {
    _logger.d('AndroidSingboxManager created');
    _setupMethodCallHandler();
  }

  @override
  Future<bool> initialize() async {
    try {
      _logger.i('Initializing Android SingboxManager');
      
      final result = await _channel.invokeMethod<bool>('initialize');
      _isInitialized = result ?? false;
      
      if (_isInitialized) {
        _logger.i('Android SingboxManager initialized successfully');
        await clearError();
      } else {
        final error = ErrorModels.SingboxErrorFactory.initializationError(
          technicalMessage: 'Failed to initialize Android sing-box manager',
          nativeErrorMessage: 'JNI initialization failed',
        );
        await _setError(error);
        _logger.e('Android SingboxManager initialization failed');
      }
      
      return _isInitialized;
    } catch (e, stackTrace) {
      final error = ErrorModels.SingboxErrorFactory.initializationError(
        technicalMessage: 'Exception during Android sing-box initialization: $e',
        stackTrace: stackTrace.toString(),
      );
      await _setError(error);
      _logger.e('Exception during Android SingboxManager initialization', error: e, stackTrace: stackTrace);
      return false;
    }
  }

  @override
  Future<bool> start(VpnConfiguration config, {int? tunFileDescriptor}) async {
    try {
      _logger.i('Starting Android sing-box with config: ${config.name}');
      
      if (!_isInitialized) {
        throw SingboxException(SingboxError(
          code: SingboxErrorCode.initializationFailed,
          message: 'Cannot start sing-box: manager not initialized',
          timestamp: DateTime.now(),
        ));
      }

      // Convert configuration to sing-box format
      final singboxConfig = _configConverter.convertToSingboxConfig(config);
      final configJson = jsonEncode(singboxConfig);
      
      // Validate configuration before starting
      final isValid = await validateConfiguration(configJson);
      if (!isValid) {
        throw SingboxException(SingboxError(
          code: SingboxErrorCode.configurationInvalid,
          message: 'Configuration validation failed',
          timestamp: DateTime.now(),
        ));
      }

      final arguments = {
        'config': configJson,
        if (tunFileDescriptor != null) 'tunFd': tunFileDescriptor,
      };

      final result = await _channel.invokeMethod<bool>('start', arguments);
      _isRunning = result ?? false;
      
      if (_isRunning) {
        _currentConfig = config;
        _startStatisticsCollection();
        await clearError();
        _logger.i('Android sing-box started successfully');
      } else {
        final error = ErrorModels.SingboxErrorFactory.connectionError(
          technicalMessage: 'Failed to start Android sing-box',
          protocol: config.protocol.name,
          serverEndpoint: '${config.serverAddress}:${config.serverPort}',
        );
        await _setError(error);
        _logger.e('Failed to start Android sing-box');
      }
      
      return _isRunning;
    } catch (e, stackTrace) {
      final error = ErrorModels.SingboxErrorFactory.connectionError(
        technicalMessage: 'Exception during Android sing-box start: $e',
        protocol: config.protocol.name,
        serverEndpoint: '${config.serverAddress}:${config.serverPort}',
        stackTrace: stackTrace.toString(),
      );
      await _setError(error);
      _logger.e('Exception during Android sing-box start', error: e, stackTrace: stackTrace);
      return false;
    }
  }

  @override
  Future<bool> stop() async {
    try {
      _logger.i('Stopping Android sing-box');
      
      _stopStatisticsCollection();
      
      final result = await _channel.invokeMethod<bool>('stop');
      final stopped = result ?? false;
      
      if (stopped) {
        _isRunning = false;
        _currentConfig = null;
        await clearError();
        _logger.i('Android sing-box stopped successfully');
      } else {
        final error = ErrorModels.SingboxErrorFactory.createCategorizedError(
          singboxErrorCode: ErrorModels.SingboxErrorCode.stopFailed,
          operation: ErrorModels.SingboxOperation.connection,
          technicalMessage: 'Failed to stop Android sing-box',
        );
        await _setError(error);
        _logger.e('Failed to stop Android sing-box');
      }
      
      return stopped;
    } catch (e, stackTrace) {
      final error = ErrorModels.SingboxErrorFactory.createCategorizedError(
        singboxErrorCode: ErrorModels.SingboxErrorCode.stopFailed,
        operation: ErrorModels.SingboxOperation.connection,
        technicalMessage: 'Exception during Android sing-box stop: $e',
        stackTrace: stackTrace.toString(),
      );
      await _setError(error);
      _logger.e('Exception during Android sing-box stop', error: e, stackTrace: stackTrace);
      return false;
    }
  }

  @override
  Future<bool> restart({VpnConfiguration? config}) async {
    _logger.i('Restarting Android sing-box');
    
    final configToUse = config ?? _currentConfig;
    if (configToUse == null) {
      final error = ErrorModels.SingboxErrorFactory.configurationError(
        technicalMessage: 'Cannot restart: no configuration available',
      );
      await _setError(error);
      return false;
    }

    final stopped = await stop();
    if (!stopped) {
      _logger.e('Failed to stop sing-box during restart');
      return false;
    }

    // Wait a moment before restarting
    await Future.delayed(const Duration(milliseconds: 500));
    
    return await start(configToUse);
  }

  @override
  Future<bool> isRunning() async {
    try {
      final result = await _channel.invokeMethod<bool>('isRunning');
      _isRunning = result ?? false;
      return _isRunning;
    } catch (e) {
      _logger.w('Failed to check if Android sing-box is running: $e');
      return _isRunning; // Return cached state
    }
  }

  @override
  Future<void> cleanup() async {
    _logger.i('Cleaning up Android SingboxManager');
    
    _stopStatisticsCollection();
    
    if (_isRunning) {
      await stop();
    }
    
    await _statsController.close();
    await _errorController.close();
    
    try {
      await _channel.invokeMethod('cleanup');
    } catch (e) {
      _logger.w('Error during Android sing-box cleanup: $e');
    }
    
    _isInitialized = false;
    _logger.i('Android SingboxManager cleanup completed');
  }

  @override
  Future<bool> validateConfiguration(String configJson) async {
    try {
      final result = await _channel.invokeMethod<bool>('validateConfig', {
        'config': configJson,
      });
      return result ?? false;
    } catch (e) {
      _logger.e('Failed to validate configuration: $e');
      return false;
    }
  }

  @override
  Future<bool> updateConfiguration(VpnConfiguration config) async {
    try {
      _logger.i('Updating Android sing-box configuration');
      
      final singboxConfig = _configConverter.convertToSingboxConfig(config);
      final configJson = jsonEncode(singboxConfig);
      
      final result = await _channel.invokeMethod<bool>('updateConfig', {
        'config': configJson,
      });
      
      final updated = result ?? false;
      if (updated) {
        _currentConfig = config;
        _logger.i('Android sing-box configuration updated successfully');
      } else {
        _logger.e('Failed to update Android sing-box configuration');
      }
      
      return updated;
    } catch (e, stackTrace) {
      final error = ErrorModels.SingboxErrorFactory.configurationError(
        technicalMessage: 'Exception during configuration update: $e',
        protocol: config.protocol.name,
        stackTrace: stackTrace.toString(),
      );
      await _setError(error);
      _logger.e('Exception during Android sing-box configuration update', error: e, stackTrace: stackTrace);
      return false;
    }
  }

  @override
  Future<String?> getCurrentConfiguration() async {
    try {
      return await _channel.invokeMethod<String>('getCurrentConfig');
    } catch (e) {
      _logger.w('Failed to get current configuration: $e');
      return null;
    }
  }

  @override
  Future<NetworkStats?> getStatistics() async {
    try {
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>('getStats');
      if (result != null) {
        final statsMap = Map<String, dynamic>.from(result);
        return NetworkStats.fromJson(statsMap);
      }
      return null;
    } catch (e) {
      _logger.w('Failed to get statistics: $e');
      return null;
    }
  }

  @override
  Future<DetailedNetworkStats?> getDetailedStatistics() async {
    try {
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>('getDetailedStats');
      if (result != null) {
        final statsMap = Map<String, dynamic>.from(result);
        return DetailedNetworkStats.fromJson(statsMap);
      }
      return null;
    } catch (e) {
      _logger.w('Failed to get detailed statistics: $e');
      return null;
    }
  }

  @override
  Future<bool> resetStatistics() async {
    try {
      final result = await _channel.invokeMethod<bool>('resetStats');
      return result ?? false;
    } catch (e) {
      _logger.w('Failed to reset statistics: $e');
      return false;
    }
  }

  @override
  Stream<NetworkStats> get statisticsStream => _statsController.stream;

  @override
  Future<bool> setLogLevel(LogLevel level) async {
    try {
      final result = await _channel.invokeMethod<bool>('setLogLevel', {
        'level': level.index,
      });
      return result ?? false;
    } catch (e) {
      _logger.w('Failed to set log level: $e');
      return false;
    }
  }

  @override
  Future<List<String>> getLogs() async {
    try {
      final result = await _channel.invokeMethod<List<dynamic>>('getLogs');
      return result?.cast<String>() ?? [];
    } catch (e) {
      _logger.w('Failed to get logs: $e');
      return [];
    }
  }

  @override
  Future<ConnectionInfo?> getConnectionInfo() async {
    try {
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>('getConnectionInfo');
      if (result != null) {
        final infoMap = Map<String, dynamic>.from(result);
        return ConnectionInfo.fromJson(infoMap);
      }
      return null;
    } catch (e) {
      _logger.w('Failed to get connection info: $e');
      return null;
    }
  }

  @override
  Future<MemoryStats?> getMemoryUsage() async {
    try {
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>('getMemoryUsage');
      if (result != null) {
        final memoryMap = Map<String, dynamic>.from(result);
        return MemoryStats.fromJson(memoryMap);
      }
      return null;
    } catch (e) {
      _logger.w('Failed to get memory usage: $e');
      return null;
    }
  }

  @override
  Future<bool> optimizePerformance() async {
    try {
      final result = await _channel.invokeMethod<bool>('optimizePerformance');
      return result ?? false;
    } catch (e) {
      _logger.w('Failed to optimize performance: $e');
      return false;
    }
  }

  @override
  Future<bool> handleNetworkChange(NetworkInfo networkInfo) async {
    try {
      _logger.i('Handling network change: ${networkInfo.networkType}');
      
      final result = await _channel.invokeMethod<bool>('handleNetworkChange', {
        'networkInfo': networkInfo.toJson(),
      });
      
      final handled = result ?? false;
      if (handled) {
        _logger.i('Network change handled successfully');
      } else {
        _logger.w('Failed to handle network change');
      }
      
      return handled;
    } catch (e) {
      _logger.e('Exception during network change handling: $e');
      return false;
    }
  }

  @override
  Future<String?> getVersion() async {
    try {
      return await _channel.invokeMethod<String>('getVersion');
    } catch (e) {
      _logger.w('Failed to get version: $e');
      return null;
    }
  }

  @override
  Future<List<String>> getSupportedProtocols() async {
    try {
      final result = await _channel.invokeMethod<List<dynamic>>('getSupportedProtocols');
      return result?.cast<String>() ?? [];
    } catch (e) {
      _logger.w('Failed to get supported protocols: $e');
      return [];
    }
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
  Stream<SingboxError> get errorStream => _errorController.stream.map((error) => 
    SingboxError(
      code: _convertErrorCode(error.singboxErrorCode),
      message: error.userMessage,
      nativeMessage: error.nativeErrorMessage,
      timestamp: error.timestamp,
    )
  );

  @override
  Future<List<String>> getErrorHistory() async {
    try {
      final result = await _channel.invokeMethod<List<dynamic>>('getErrorHistory');
      return result?.cast<String>() ?? [];
    } catch (e) {
      _logger.w('Failed to get error history: $e');
      return [];
    }
  }

  @override
  Future<Map<String, int>> getOperationTimings() async {
    try {
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>('getOperationTimings');
      if (result != null) {
        return Map<String, int>.from(result);
      }
      return {};
    } catch (e) {
      _logger.w('Failed to get operation timings: $e');
      return {};
    }
  }

  @override
  Future<void> clearDiagnosticData() async {
    try {
      await _channel.invokeMethod('clearDiagnosticData');
    } catch (e) {
      _logger.w('Failed to clear diagnostic data: $e');
    }
  }

  @override
  Future<Map<String, String>> generateDiagnosticReport() async {
    try {
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>('generateDiagnosticReport');
      if (result != null) {
        return Map<String, String>.from(result);
      }
      return {};
    } catch (e) {
      _logger.w('Failed to generate diagnostic report: $e');
      return {};
    }
  }

  @override
  Future<String> exportDiagnosticLogs() async {
    try {
      final result = await _channel.invokeMethod<String>('exportDiagnosticLogs');
      return result ?? '{}';
    } catch (e) {
      _logger.w('Failed to export diagnostic logs: $e');
      return '{}';
    }
  }

  // Private helper methods

  void _setupMethodCallHandler() {
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'onError':
          await _handleNativeError(call.arguments);
          break;
        case 'onStatsUpdate':
          await _handleStatsUpdate(call.arguments);
          break;
        case 'onConnectionStateChanged':
          await _handleConnectionStateChange(call.arguments);
          break;
        default:
          _logger.w('Unknown method call from native: ${call.method}');
      }
    });
  }

  Future<void> _handleNativeError(dynamic arguments) async {
    try {
      final errorMap = Map<String, dynamic>.from(arguments);
      final error = ErrorModels.SingboxError.fromJson(errorMap);
      await _setError(error);
      _logger.e('Native error received: ${error.userMessage}');
    } catch (e) {
      _logger.e('Failed to handle native error: $e');
    }
  }

  Future<void> _handleStatsUpdate(dynamic arguments) async {
    try {
      final statsMap = Map<String, dynamic>.from(arguments);
      final stats = NetworkStats.fromJson(statsMap);
      _statsController.add(stats);
    } catch (e) {
      _logger.w('Failed to handle stats update: $e');
    }
  }

  Future<void> _handleConnectionStateChange(dynamic arguments) async {
    try {
      final stateMap = Map<String, dynamic>.from(arguments);
      final isConnected = stateMap['isConnected'] as bool? ?? false;
      _isRunning = isConnected;
      _logger.i('Connection state changed: ${isConnected ? 'connected' : 'disconnected'}');
    } catch (e) {
      _logger.w('Failed to handle connection state change: $e');
    }
  }

  void _startStatisticsCollection() {
    _stopStatisticsCollection(); // Ensure no duplicate timers
    
    _statsTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (_isRunning) {
        final stats = await getStatistics();
        if (stats != null) {
          _statsController.add(stats);
        }
      }
    });
  }

  void _stopStatisticsCollection() {
    _statsTimer?.cancel();
    _statsTimer = null;
  }

  Future<void> _setError(ErrorModels.SingboxError error) async {
    _lastError = error;
    _errorController.add(error);
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
      default:
        return SingboxErrorCode.unknown;
    }
  }
}