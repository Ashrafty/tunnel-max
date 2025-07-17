import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:logger/logger.dart';
import 'package:path/path.dart' as path;

import '../../interfaces/singbox_manager_interface.dart';
import '../../models/vpn_configuration.dart';
import '../../models/network_stats.dart';
import '../../models/singbox_error.dart' as ErrorModels;
import '../singbox_configuration_converter.dart';

/// Windows-specific implementation of SingboxManager using process management
/// 
/// This implementation manages sing-box as a separate process and communicates
/// through named pipes and file-based configuration for optimal Windows integration.
class WindowsSingboxManager implements SingboxManagerInterface {
  static const MethodChannel _channel = MethodChannel('com.tunnelmax.vpnclient/singbox');
  
  final Logger _logger;
  final SingboxConfigurationConverter _configConverter;
  
  // State management
  bool _isInitialized = false;
  bool _isRunning = false;
  VpnConfiguration? _currentConfig;
  ErrorModels.SingboxError? _lastError;
  
  // Process management
  Process? _singboxProcess;
  String? _configFilePath;
  String? _logFilePath;
  
  // Stream controllers for real-time data
  final StreamController<NetworkStats> _statsController = StreamController<NetworkStats>.broadcast();
  final StreamController<SingboxError> _errorController = StreamController<SingboxError>.broadcast();
  
  // Statistics collection timer
  Timer? _statsTimer;
  Timer? _processMonitorTimer;
  
  WindowsSingboxManager({
    Logger? logger,
    SingboxConfigurationConverter? configConverter,
  }) : _logger = logger ?? Logger(),
       _configConverter = configConverter ?? SingboxConfigurationConverter() {
    _logger.d('WindowsSingboxManager created');
    _setupMethodCallHandler();
  }

  @override
  Future<bool> initialize() async {
    try {
      _logger.i('Initializing Windows SingboxManager');
      
      // Initialize through platform channel for Windows-specific setup
      final result = await _channel.invokeMethod<bool>('initialize');
      _isInitialized = result ?? false;
      
      if (_isInitialized) {
        await _setupWorkingDirectory();
        _startProcessMonitoring();
        await clearError();
        _logger.i('Windows SingboxManager initialized successfully');
      } else {
        final error = ErrorModels.SingboxErrorFactory.initializationError(
          technicalMessage: 'Failed to initialize Windows sing-box manager',
          nativeErrorMessage: 'Platform channel initialization failed',
        );
        await _setError(error);
        _logger.e('Windows SingboxManager initialization failed');
      }
      
      return _isInitialized;
    } catch (e, stackTrace) {
      final error = ErrorModels.SingboxErrorFactory.initializationError(
        technicalMessage: 'Exception during Windows sing-box initialization: $e',
        stackTrace: stackTrace.toString(),
      );
      await _setError(error);
      _logger.e('Exception during Windows SingboxManager initialization', error: e, stackTrace: stackTrace);
      return false;
    }
  }

  @override
  Future<bool> start(VpnConfiguration config, {int? tunFileDescriptor}) async {
    try {
      _logger.i('Starting Windows sing-box with config: ${config.name}');
      
      if (!_isInitialized) {
        throw SingboxException(SingboxError(
          code: SingboxErrorCode.initializationFailed,
          message: 'Cannot start sing-box: manager not initialized',
          timestamp: DateTime.now(),
        ));
      }

      // Stop any existing process
      if (_isRunning) {
        await stop();
      }

      // Convert configuration to sing-box format
      final singboxConfig = _configConverter.convertToSingboxConfig(config);
      
      // Write configuration to file
      await _writeConfigurationFile(singboxConfig);
      
      // Start sing-box process
      final started = await _startSingboxProcess();
      
      if (started) {
        _currentConfig = config;
        _isRunning = true;
        _startStatisticsCollection();
        await clearError();
        _logger.i('Windows sing-box started successfully');
      } else {
        final error = ErrorModels.SingboxErrorFactory.connectionError(
          technicalMessage: 'Failed to start Windows sing-box process',
          protocol: config.protocol.name,
          serverEndpoint: '${config.serverAddress}:${config.serverPort}',
        );
        await _setError(error);
        _logger.e('Failed to start Windows sing-box');
      }
      
      return started;
    } catch (e, stackTrace) {
      final error = ErrorModels.SingboxErrorFactory.connectionError(
        technicalMessage: 'Exception during Windows sing-box start: $e',
        protocol: config.protocol.name,
        serverEndpoint: '${config.serverAddress}:${config.serverPort}',
        stackTrace: stackTrace.toString(),
      );
      await _setError(error);
      _logger.e('Exception during Windows sing-box start', error: e, stackTrace: stackTrace);
      return false;
    }
  }

  @override
  Future<bool> stop() async {
    try {
      _logger.i('Stopping Windows sing-box');
      
      _stopStatisticsCollection();
      
      bool stopped = false;
      
      if (_singboxProcess != null) {
        // Try graceful shutdown first
        _singboxProcess!.kill(ProcessSignal.sigterm);
        
        // Wait for process to exit gracefully
        final exitCode = await _singboxProcess!.exitCode.timeout(
          const Duration(seconds: 5),
          onTimeout: () {
            // Force kill if graceful shutdown fails
            _singboxProcess!.kill(ProcessSignal.sigkill);
            return -1;
          },
        );
        
        stopped = true;
        _singboxProcess = null;
        _logger.i('Windows sing-box process stopped with exit code: $exitCode');
      } else {
        stopped = true;
      }
      
      if (stopped) {
        _isRunning = false;
        _currentConfig = null;
        await _cleanupFiles();
        await clearError();
        _logger.i('Windows sing-box stopped successfully');
      } else {
        final error = ErrorModels.SingboxErrorFactory.createCategorizedError(
          singboxErrorCode: ErrorModels.SingboxErrorCode.stopFailed,
          operation: ErrorModels.SingboxOperation.connection,
          technicalMessage: 'Failed to stop Windows sing-box process',
        );
        await _setError(error);
        _logger.e('Failed to stop Windows sing-box');
      }
      
      return stopped;
    } catch (e, stackTrace) {
      final error = ErrorModels.SingboxErrorFactory.createCategorizedError(
        singboxErrorCode: ErrorModels.SingboxErrorCode.stopFailed,
        operation: ErrorModels.SingboxOperation.connection,
        technicalMessage: 'Exception during Windows sing-box stop: $e',
        stackTrace: stackTrace.toString(),
      );
      await _setError(error);
      _logger.e('Exception during Windows sing-box stop', error: e, stackTrace: stackTrace);
      return false;
    }
  }

  @override
  Future<bool> restart({VpnConfiguration? config}) async {
    _logger.i('Restarting Windows sing-box');
    
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
    await Future.delayed(const Duration(milliseconds: 1000));
    
    return await start(configToUse);
  }

  @override
  Future<bool> isRunning() async {
    try {
      if (_singboxProcess != null) {
        // Check if process is still alive
        try {
          _singboxProcess!.kill(ProcessSignal.sigusr1); // Non-destructive signal
          _isRunning = true;
        } catch (e) {
          _isRunning = false;
          _singboxProcess = null;
        }
      } else {
        _isRunning = false;
      }
      
      return _isRunning;
    } catch (e) {
      _logger.w('Failed to check if Windows sing-box is running: $e');
      return _isRunning; // Return cached state
    }
  }

  @override
  Future<void> cleanup() async {
    _logger.i('Cleaning up Windows SingboxManager');
    
    _stopStatisticsCollection();
    _stopProcessMonitoring();
    
    if (_isRunning) {
      await stop();
    }
    
    await _statsController.close();
    await _errorController.close();
    
    try {
      await _channel.invokeMethod('cleanup');
    } catch (e) {
      _logger.w('Error during Windows sing-box cleanup: $e');
    }
    
    await _cleanupFiles();
    _isInitialized = false;
    _logger.i('Windows SingboxManager cleanup completed');
  }

  @override
  Future<bool> validateConfiguration(String configJson) async {
    try {
      // Write config to temporary file for validation
      final tempFile = File(path.join(Directory.systemTemp.path, 'singbox_validate_${DateTime.now().millisecondsSinceEpoch}.json'));
      await tempFile.writeAsString(configJson);
      
      try {
        // Use sing-box to validate the configuration
        final result = await Process.run(
          await _getSingboxExecutablePath(),
          ['check', '-c', tempFile.path],
          runInShell: true,
        );
        
        return result.exitCode == 0;
      } finally {
        // Clean up temp file
        try {
          await tempFile.delete();
        } catch (e) {
          _logger.w('Failed to delete temp validation file: $e');
        }
      }
    } catch (e) {
      _logger.e('Failed to validate configuration: $e');
      return false;
    }
  }

  @override
  Future<bool> updateConfiguration(VpnConfiguration config) async {
    try {
      _logger.i('Updating Windows sing-box configuration');
      
      if (!_isRunning) {
        _logger.w('Cannot update configuration: sing-box is not running');
        return false;
      }

      // For Windows, we need to restart with new configuration
      // as hot reload is not always supported
      return await restart(config: config);
    } catch (e, stackTrace) {
      final error = ErrorModels.SingboxErrorFactory.configurationError(
        technicalMessage: 'Exception during configuration update: $e',
        protocol: config.protocol.name,
        stackTrace: stackTrace.toString(),
      );
      await _setError(error);
      _logger.e('Exception during Windows sing-box configuration update', error: e, stackTrace: stackTrace);
      return false;
    }
  }

  @override
  Future<String?> getCurrentConfiguration() async {
    try {
      if (_configFilePath != null && File(_configFilePath!).existsSync()) {
        return await File(_configFilePath!).readAsString();
      }
      return null;
    } catch (e) {
      _logger.w('Failed to get current configuration: $e');
      return null;
    }
  }

  @override
  Future<NetworkStats?> getStatistics() async {
    try {
      // Get statistics through platform channel
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
      if (_logFilePath != null && File(_logFilePath!).existsSync()) {
        final logContent = await File(_logFilePath!).readAsString();
        return logContent.split('\n').where((line) => line.isNotEmpty).toList();
      }
      return [];
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
      if (_singboxProcess != null) {
        // Get process memory usage through platform channel
        final result = await _channel.invokeMethod<Map<dynamic, dynamic>>('getMemoryUsage', {
          'processId': _singboxProcess!.pid,
        });
        if (result != null) {
          final memoryMap = Map<String, dynamic>.from(result);
          return MemoryStats.fromJson(memoryMap);
        }
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
      
      // For Windows, we may need to restart the connection on network changes
      if (_isRunning && _currentConfig != null) {
        _logger.i('Restarting connection due to network change');
        return await restart();
      }
      
      return true;
    } catch (e) {
      _logger.e('Exception during network change handling: $e');
      return false;
    }
  }

  @override
  Future<String?> getVersion() async {
    try {
      final executablePath = await _getSingboxExecutablePath();
      final result = await Process.run(
        executablePath,
        ['version'],
        runInShell: true,
      );
      
      if (result.exitCode == 0) {
        return result.stdout.toString().trim();
      }
      return null;
    } catch (e) {
      _logger.w('Failed to get version: $e');
      return null;
    }
  }

  @override
  Future<List<String>> getSupportedProtocols() async {
    try {
      // This would need to be implemented based on sing-box capabilities
      // For now, return common protocols
      return [
        'vless',
        'vmess',
        'trojan',
        'shadowsocks',
        'hysteria',
        'hysteria2',
        'wireguard',
      ];
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
  Stream<SingboxError> get errorStream => _errorController.stream;

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
        case 'onProcessExit':
          await _handleProcessExit(call.arguments);
          break;
        default:
          _logger.w('Unknown method call from native: ${call.method}');
      }
    });
  }

  Future<void> _setupWorkingDirectory() async {
    try {
      final appDir = Directory(path.join(Directory.current.path, 'sing-box'));
      if (!await appDir.exists()) {
        await appDir.create(recursive: true);
      }
      
      _configFilePath = path.join(appDir.path, 'config.json');
      _logFilePath = path.join(appDir.path, 'sing-box.log');
    } catch (e) {
      _logger.e('Failed to setup working directory: $e');
      rethrow;
    }
  }

  Future<String> _getSingboxExecutablePath() async {
    // Try different possible locations for sing-box executable
    final possiblePaths = [
      path.join(Directory.current.path, 'windows', 'sing-box', 'sing-box.exe'),
      path.join(Directory.current.path, 'sing-box.exe'),
      'sing-box.exe', // In PATH
    ];
    
    for (final execPath in possiblePaths) {
      if (await File(execPath).exists() || execPath == 'sing-box.exe') {
        return execPath;
      }
    }
    
    throw Exception('sing-box executable not found');
  }

  Future<void> _writeConfigurationFile(Map<String, dynamic> config) async {
    if (_configFilePath == null) {
      throw Exception('Configuration file path not set');
    }
    
    final configJson = const JsonEncoder.withIndent('  ').convert(config);
    await File(_configFilePath!).writeAsString(configJson);
  }

  Future<bool> _startSingboxProcess() async {
    try {
      final executablePath = await _getSingboxExecutablePath();
      
      _singboxProcess = await Process.start(
        executablePath,
        [
          'run',
          '-c', _configFilePath!,
          '--log-level', 'info',
          '--log-output', _logFilePath!,
        ],
        runInShell: true,
      );
      
      // Wait a moment to see if process starts successfully
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Check if process is still running
      try {
        _singboxProcess!.kill(ProcessSignal.sigusr1); // Non-destructive signal
        return true;
      } catch (e) {
        _logger.e('sing-box process failed to start: $e');
        _singboxProcess = null;
        return false;
      }
    } catch (e) {
      _logger.e('Failed to start sing-box process: $e');
      _singboxProcess = null;
      return false;
    }
  }

  void _startProcessMonitoring() {
    _processMonitorTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      if (_isRunning && _singboxProcess != null) {
        try {
          _singboxProcess!.kill(ProcessSignal.sigusr1); // Non-destructive signal
        } catch (e) {
          // Process has died
          _logger.w('sing-box process has died unexpectedly');
          _isRunning = false;
          _singboxProcess = null;
          
          final error = ErrorModels.SingboxErrorFactory.processCrashError(
            technicalMessage: 'sing-box process crashed unexpectedly',
            nativeErrorMessage: e.toString(),
          );
          await _setError(error);
        }
      }
    });
  }

  void _stopProcessMonitoring() {
    _processMonitorTimer?.cancel();
    _processMonitorTimer = null;
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

  Future<void> _handleProcessExit(dynamic arguments) async {
    try {
      final exitCode = arguments['exitCode'] as int? ?? -1;
      _logger.i('sing-box process exited with code: $exitCode');
      
      _isRunning = false;
      _singboxProcess = null;
      
      if (exitCode != 0) {
        final error = ErrorModels.SingboxErrorFactory.processCrashError(
          technicalMessage: 'sing-box process exited with non-zero code: $exitCode',
        );
        await _setError(error);
      }
    } catch (e) {
      _logger.w('Failed to handle process exit: $e');
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

  Future<void> _cleanupFiles() async {
    try {
      if (_configFilePath != null && File(_configFilePath!).existsSync()) {
        await File(_configFilePath!).delete();
      }
      if (_logFilePath != null && File(_logFilePath!).existsSync()) {
        // Keep log file for debugging, just truncate it
        await File(_logFilePath!).writeAsString('');
      }
    } catch (e) {
      _logger.w('Failed to cleanup files: $e');
    }
  }

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
      default:
        return SingboxErrorCode.unknown;
    }
  }
}