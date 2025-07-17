import 'package:flutter_test/flutter_test.dart';
import 'dart:convert';
import 'dart:io';

// Mock classes for testing Windows SingboxManager functionality
class MockWindowsSingboxManager {
  bool _isInitialized = false;
  bool _isRunning = false;
  String? _currentConfig;
  String? _executablePath;
  int _processId = 0;
  Map<String, dynamic>? _lastNetworkInfo;
  List<String> _errorHistory = [];
  Map<String, int> _operationTimings = {};
  
  // Mock Windows-specific data
  static const String mockExecutablePath = "C:\\Program Files\\TunnelMax\\sing-box\\sing-box.exe";
  static const int mockProcessId = 12345;
  
  // Core lifecycle methods
  bool initialize() {
    if (_isInitialized) return true;
    
    // Simulate finding sing-box executable
    _executablePath = mockExecutablePath;
    _isInitialized = true;
    return true;
  }
  
  bool start(String configJson) {
    if (!_isInitialized) return false;
    if (_isRunning) return true;
    
    if (configJson.isEmpty || !_validateConfiguration(configJson)) {
      return false;
    }
    
    _currentConfig = configJson;
    _processId = mockProcessId;
    _isRunning = true;
    return true;
  }
  
  bool stop() {
    if (!_isRunning) return true;
    
    _isRunning = false;
    _currentConfig = null;
    _processId = 0;
    return true;
  }
  
  void cleanup() {
    stop();
    _isInitialized = false;
    _executablePath = null;
    _errorHistory.clear();
    _operationTimings.clear();
  }
  
  // Status and statistics
  bool isRunning() => _isRunning;
  
  Map<String, dynamic> getStatus() {
    return {
      'is_running': _isRunning,
      'process_id': _processId,
      'executable_path': _executablePath,
      'last_error': 'None',
      'error_message': '',
    };
  }
  
  Map<String, dynamic> getStatistics() {
    if (!_isRunning) {
      return {
        'bytes_received': 0,
        'bytes_sent': 0,
        'connection_duration': 0,
        'upload_speed': 0.0,
        'download_speed': 0.0,
        'packets_received': 0,
        'packets_sent': 0,
      };
    }
    
    return {
      'bytes_received': 2048000,
      'bytes_sent': 1024000,
      'connection_duration': 120,
      'upload_speed': 128.5,
      'download_speed': 256.7,
      'packets_received': 1500,
      'packets_sent': 800,
      'timestamp': DateTime.now().millisecondsSinceEpoch ~/ 1000,
    };
  }
  
  // Configuration management
  bool validateConfiguration(String configJson) {
    return _validateConfiguration(configJson);
  }
  
  List<String> getSupportedProtocols() {
    return ['vless', 'vmess', 'trojan', 'shadowsocks', 'http', 'socks'];
  }
  
  // Advanced features
  bool setLogLevel(int level) {
    return level >= 0 && level <= 5;
  }
  
  List<String> getLogs() {
    if (!_isRunning) {
      return ['[INFO] Sing-box is not running'];
    }
    
    return [
      '[INFO] Sing-box process is running',
      '[DEBUG] TUN interface active',
      '[INFO] Connection established',
      '[DEBUG] Statistics updated',
    ];
  }
  
  bool updateConfiguration(String configJson) {
    if (!_isRunning) return false;
    if (!_validateConfiguration(configJson)) return false;
    
    _currentConfig = configJson;
    return true;
  }
  
  Map<String, int> getMemoryUsage() {
    if (!_isRunning) return {};
    
    return {
      'working_set_mb': 64,
      'private_bytes_mb': 48,
      'peak_working_set_mb': 72,
      'system_total_mb': 8192,
      'system_available_mb': 4096,
      'memory_load_percent': 50,
    };
  }
  
  bool optimizePerformance() {
    return _isRunning;
  }
  
  bool handleNetworkChange(String networkInfoJson) {
    if (!_isRunning) return false;
    
    try {
      _lastNetworkInfo = jsonDecode(networkInfoJson);
      return true;
    } catch (e) {
      return false;
    }
  }
  
  Map<String, String> getConnectionInfo() {
    if (!_isRunning) {
      return {'status': 'not_running'};
    }
    
    return {
      'status': 'running',
      'process_id': _processId.toString(),
      'executable_path': _executablePath ?? '',
      'connection_duration_seconds': '120',
      'bytes_received': '2048000',
      'bytes_sent': '1024000',
      'download_speed': '256.7',
      'upload_speed': '128.5',
      'memory_usage_mb': '64',
    };
  }
  
  String getVersion() {
    return '1.8.0-windows-dev';
  }
  
  // Enhanced logging and debugging
  List<String> getErrorHistory() {
    return List.from(_errorHistory);
  }
  
  Map<String, int> getOperationTimings() {
    return Map.from(_operationTimings);
  }
  
  void clearDiagnosticData() {
    _errorHistory.clear();
    _operationTimings.clear();
  }
  
  Map<String, String> generateDiagnosticReport() {
    return {
      'is_running': _isRunning.toString(),
      'is_initialized': _isInitialized.toString(),
      'process_id': _processId.toString(),
      'executable_path': _executablePath ?? '',
      'last_error': 'None',
      'bytes_received': _isRunning ? '2048000' : '0',
      'bytes_sent': _isRunning ? '1024000' : '0',
      'system_memory_total': '8192',
      'system_memory_available': '4096',
    };
  }
  
  String exportDiagnosticLogs() {
    return jsonEncode({
      'timestamp': DateTime.now().millisecondsSinceEpoch ~/ 1000,
      'version': getVersion(),
      'is_running': _isRunning,
      'error_history': _errorHistory,
      'operation_timings': _operationTimings,
      'system_info': generateDiagnosticReport(),
    });
  }
  
  // Private helper methods
  bool _validateConfiguration(String configJson) {
    if (configJson.isEmpty) return false;
    
    try {
      final config = jsonDecode(configJson);
      return config is Map<String, dynamic> &&
             config.containsKey('inbounds') &&
             config.containsKey('outbounds') &&
             config['inbounds'] is List &&
             config['outbounds'] is List;
    } catch (e) {
      return false;
    }
  }
  
  void _addError(String error) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    _errorHistory.add('$timestamp: $error');
    if (_errorHistory.length > 50) {
      _errorHistory.removeAt(0);
    }
  }
  
  void _addOperationTiming(String operation, int durationMs) {
    _operationTimings[operation] = durationMs;
  }
}

// Test data classes
class TestWindowsNetworkInfo {
  final String networkType;
  final bool isConnected;
  final bool isWifi;
  final bool isEthernet;
  final String? networkName;
  final String? ipAddress;
  final int? mtu;

  TestWindowsNetworkInfo({
    required this.networkType,
    required this.isConnected,
    required this.isWifi,
    required this.isEthernet,
    this.networkName,
    this.ipAddress,
    this.mtu,
  });
}

void main() {
  group('Windows SingboxManager Tests', () {
    late MockWindowsSingboxManager mockManager;

    setUp(() {
      mockManager = MockWindowsSingboxManager();
    });

    tearDown(() {
      mockManager.cleanup();
    });

    group('Initialization Tests', () {
      test('should initialize successfully', () {
        final result = mockManager.initialize();
        expect(result, isTrue);
        expect(mockManager._isInitialized, isTrue);
        expect(mockManager._executablePath, isNotNull);
      });

      test('should handle multiple initialization calls', () {
        expect(mockManager.initialize(), isTrue);
        expect(mockManager.initialize(), isTrue); // Should not fail
      });

      test('should find sing-box executable in expected location', () {
        mockManager.initialize();
        expect(mockManager._executablePath, equals(MockWindowsSingboxManager.mockExecutablePath));
      });
    });

    group('Configuration Tests', () {
      setUp(() {
        mockManager.initialize();
      });

      test('should validate valid sing-box configuration', () {
        final validConfig = jsonEncode({
          'log': {'level': 'info'},
          'inbounds': [
            {
              'type': 'tun',
              'tag': 'tun-in',
              'interface_name': 'tun0',
              'inet4_address': '172.19.0.1/30',
              'auto_route': true,
            }
          ],
          'outbounds': [
            {
              'type': 'vless',
              'tag': 'proxy',
              'server': 'example.com',
              'server_port': 443,
              'uuid': '12345678-1234-1234-1234-123456789abc',
            },
            {
              'type': 'direct',
              'tag': 'direct',
            }
          ],
          'route': {
            'final': 'proxy',
          }
        });

        expect(mockManager.validateConfiguration(validConfig), isTrue);
      });

      test('should reject invalid configuration', () {
        const invalidConfigs = [
          '', // Empty
          '{}', // Missing required fields
          '{"inbounds": []}', // Missing outbounds
          '{"outbounds": []}', // Missing inbounds
          '{invalid json}', // Malformed JSON
        ];

        for (final config in invalidConfigs) {
          expect(mockManager.validateConfiguration(config), isFalse);
        }
      });

      test('should return supported protocols', () {
        final protocols = mockManager.getSupportedProtocols();
        expect(protocols, contains('vless'));
        expect(protocols, contains('vmess'));
        expect(protocols, contains('trojan'));
        expect(protocols, contains('shadowsocks'));
        expect(protocols, contains('http'));
        expect(protocols, contains('socks'));
      });
    });

    group('Process Lifecycle Tests', () {
      late String validConfig;

      setUp(() {
        mockManager.initialize();
        validConfig = jsonEncode({
          'inbounds': [{'type': 'tun'}],
          'outbounds': [{'type': 'vless', 'server': 'test.com'}]
        });
      });

      test('should start with valid configuration', () {
        final result = mockManager.start(validConfig);
        expect(result, isTrue);
        expect(mockManager.isRunning(), isTrue);
        expect(mockManager._processId, equals(MockWindowsSingboxManager.mockProcessId));
      });

      test('should fail to start without initialization', () {
        final uninitializedManager = MockWindowsSingboxManager();
        final result = uninitializedManager.start(validConfig);
        expect(result, isFalse);
      });

      test('should fail to start with invalid configuration', () {
        final result = mockManager.start('invalid config');
        expect(result, isFalse);
        expect(mockManager.isRunning(), isFalse);
      });

      test('should handle multiple start calls gracefully', () {
        expect(mockManager.start(validConfig), isTrue);
        expect(mockManager.start(validConfig), isTrue); // Should not fail
        expect(mockManager.isRunning(), isTrue);
      });

      test('should stop successfully', () {
        mockManager.start(validConfig);
        expect(mockManager.isRunning(), isTrue);

        final result = mockManager.stop();
        expect(result, isTrue);
        expect(mockManager.isRunning(), isFalse);
        expect(mockManager._processId, equals(0));
      });

      test('should handle stop when not running', () {
        final result = mockManager.stop();
        expect(result, isTrue);
      });

      test('should cleanup resources properly', () {
        mockManager.start(validConfig);
        expect(mockManager.isRunning(), isTrue);

        mockManager.cleanup();
        expect(mockManager.isRunning(), isFalse);
        expect(mockManager._isInitialized, isFalse);
      });
    });

    group('Statistics and Monitoring Tests', () {
      late String validConfig;

      setUp(() {
        mockManager.initialize();
        validConfig = jsonEncode({
          'inbounds': [{'type': 'tun'}],
          'outbounds': [{'type': 'vless'}]
        });
      });

      test('should return statistics when running', () {
        mockManager.start(validConfig);
        final stats = mockManager.getStatistics();

        expect(stats['bytes_received'], isA<int>());
        expect(stats['bytes_sent'], isA<int>());
        expect(stats['upload_speed'], isA<double>());
        expect(stats['download_speed'], isA<double>());
        expect(stats['connection_duration'], isA<int>());
        expect(stats['packets_received'], isA<int>());
        expect(stats['packets_sent'], isA<int>());
      });

      test('should return zero statistics when not running', () {
        final stats = mockManager.getStatistics();
        expect(stats['bytes_received'], equals(0));
        expect(stats['bytes_sent'], equals(0));
        expect(stats['upload_speed'], equals(0.0));
        expect(stats['download_speed'], equals(0.0));
      });

      test('should return process status', () {
        mockManager.start(validConfig);
        final status = mockManager.getStatus();

        expect(status['is_running'], isTrue);
        expect(status['process_id'], equals(MockWindowsSingboxManager.mockProcessId));
        expect(status['executable_path'], isNotNull);
      });

      test('should return connection info when running', () {
        mockManager.start(validConfig);
        final info = mockManager.getConnectionInfo();

        expect(info['status'], equals('running'));
        expect(info['process_id'], isNotNull);
        expect(info['bytes_received'], isNotNull);
        expect(info['bytes_sent'], isNotNull);
        expect(info['memory_usage_mb'], isNotNull);
      });

      test('should return not running status when stopped', () {
        final info = mockManager.getConnectionInfo();
        expect(info['status'], equals('not_running'));
      });
    });

    group('Advanced Features Tests', () {
      late String validConfig;

      setUp(() {
        mockManager.initialize();
        validConfig = jsonEncode({
          'inbounds': [{'type': 'tun'}],
          'outbounds': [{'type': 'vless'}]
        });
        mockManager.start(validConfig);
      });

      test('should set log level successfully', () {
        for (int level = 0; level <= 5; level++) {
          expect(mockManager.setLogLevel(level), isTrue);
        }
      });

      test('should reject invalid log levels', () {
        expect(mockManager.setLogLevel(-1), isFalse);
        expect(mockManager.setLogLevel(6), isFalse);
      });

      test('should return logs when running', () {
        final logs = mockManager.getLogs();
        expect(logs, isNotEmpty);
        expect(logs.any((log) => log.contains('running')), isTrue);
      });

      test('should return appropriate logs when not running', () {
        mockManager.stop();
        final logs = mockManager.getLogs();
        expect(logs, contains('[INFO] Sing-box is not running'));
      });

      test('should update configuration while running', () {
        final newConfig = jsonEncode({
          'inbounds': [{'type': 'tun', 'tag': 'tun-in'}],
          'outbounds': [{'type': 'vmess', 'tag': 'proxy'}]
        });

        final result = mockManager.updateConfiguration(newConfig);
        expect(result, isTrue);
        expect(mockManager._currentConfig, equals(newConfig));
      });

      test('should fail to update with invalid configuration', () {
        const invalidConfig = '{"invalid": "config"}';
        final result = mockManager.updateConfiguration(invalidConfig);
        expect(result, isFalse);
      });

      test('should fail to update when not running', () {
        mockManager.stop();
        final result = mockManager.updateConfiguration(validConfig);
        expect(result, isFalse);
      });

      test('should return memory usage information', () {
        final memory = mockManager.getMemoryUsage();
        expect(memory['working_set_mb'], isA<int>());
        expect(memory['system_total_mb'], isA<int>());
        expect(memory['system_available_mb'], isA<int>());
        expect(memory['memory_load_percent'], isA<int>());
      });

      test('should optimize performance when running', () {
        final result = mockManager.optimizePerformance();
        expect(result, isTrue);
      });

      test('should fail to optimize when not running', () {
        mockManager.stop();
        final result = mockManager.optimizePerformance();
        expect(result, isFalse);
      });

      test('should handle network changes', () {
        final networkInfo = TestWindowsNetworkInfo(
          networkType: 'ethernet',
          isConnected: true,
          isWifi: false,
          isEthernet: true,
          networkName: 'Local Area Connection',
          ipAddress: '192.168.1.100',
          mtu: 1500,
        );

        final networkJson = jsonEncode({
          'network_type': networkInfo.networkType,
          'is_connected': networkInfo.isConnected,
          'is_wifi': networkInfo.isWifi,
          'is_ethernet': networkInfo.isEthernet,
          'network_name': networkInfo.networkName,
          'ip_address': networkInfo.ipAddress,
          'mtu': networkInfo.mtu,
        });

        final result = mockManager.handleNetworkChange(networkJson);
        expect(result, isTrue);
        expect(mockManager._lastNetworkInfo, isNotNull);
      });

      test('should fail network change with invalid JSON', () {
        final result = mockManager.handleNetworkChange('invalid json');
        expect(result, isFalse);
      });

      test('should return version information', () {
        final version = mockManager.getVersion();
        expect(version, contains('1.8.0'));
        expect(version, contains('windows'));
      });
    });

    group('Diagnostic and Logging Tests', () {
      setUp(() {
        mockManager.initialize();
      });

      test('should track error history', () {
        mockManager._addError('Test error 1');
        mockManager._addError('Test error 2');

        final errors = mockManager.getErrorHistory();
        expect(errors.length, equals(2));
        expect(errors.any((error) => error.contains('Test error 1')), isTrue);
        expect(errors.any((error) => error.contains('Test error 2')), isTrue);
      });

      test('should track operation timings', () {
        mockManager._addOperationTiming('test_operation', 150);
        final timings = mockManager.getOperationTimings();
        expect(timings['test_operation'], equals(150));
      });

      test('should clear diagnostic data', () {
        mockManager._addError('Test error');
        mockManager._addOperationTiming('test_op', 100);

        mockManager.clearDiagnosticData();

        expect(mockManager.getErrorHistory(), isEmpty);
        expect(mockManager.getOperationTimings(), isEmpty);
      });

      test('should generate diagnostic report', () {
        final validConfig = jsonEncode({
          'inbounds': [{'type': 'tun'}],
          'outbounds': [{'type': 'vless'}]
        });
        mockManager.start(validConfig);

        final report = mockManager.generateDiagnosticReport();
        expect(report['is_running'], equals('true'));
        expect(report['is_initialized'], equals('true'));
        expect(report['process_id'], isNotNull);
        expect(report['executable_path'], isNotNull);
      });

      test('should export diagnostic logs as JSON', () {
        mockManager._addError('Test error');
        mockManager._addOperationTiming('test_op', 100);

        final logsJson = mockManager.exportDiagnosticLogs();
        final logs = jsonDecode(logsJson);

        expect(logs['timestamp'], isA<int>());
        expect(logs['version'], isA<String>());
        expect(logs['is_running'], isA<bool>());
        expect(logs['error_history'], isA<List>());
        expect(logs['operation_timings'], isA<Map>());
        expect(logs['system_info'], isA<Map>());
      });
    });

    group('Error Handling and Edge Cases', () {
      test('should handle operations on uninitialized manager', () {
        final uninitializedManager = MockWindowsSingboxManager();
        expect(uninitializedManager.start('{}'), isFalse);
        expect(uninitializedManager.isRunning(), isFalse);
      });

      test('should handle rapid start/stop cycles', () {
        mockManager.initialize();
        final config = jsonEncode({
          'inbounds': [{'type': 'tun'}],
          'outbounds': [{'type': 'vless'}]
        });

        for (int i = 0; i < 5; i++) {
          expect(mockManager.start(config), isTrue);
          expect(mockManager.stop(), isTrue);
        }
      });

      test('should handle null and empty inputs gracefully', () {
        mockManager.initialize();
        
        expect(mockManager.validateConfiguration(''), isFalse);
        expect(mockManager.start(''), isFalse);
        expect(mockManager.handleNetworkChange(''), isFalse);
      });

      test('should maintain error history size limit', () {
        for (int i = 0; i < 60; i++) {
          mockManager._addError('Error $i');
        }

        final errors = mockManager.getErrorHistory();
        expect(errors.length, lessThanOrEqualTo(50));
      });
    });

    group('Windows-Specific Features', () {
      setUp(() {
        mockManager.initialize();
      });

      test('should handle Windows process management', () {
        final config = jsonEncode({
          'inbounds': [{'type': 'tun'}],
          'outbounds': [{'type': 'vless'}]
        });

        expect(mockManager.start(config), isTrue);
        expect(mockManager._processId, equals(MockWindowsSingboxManager.mockProcessId));
        expect(mockManager.stop(), isTrue);
        expect(mockManager._processId, equals(0));
      });

      test('should handle Windows network types', () {
        final config = jsonEncode({
          'inbounds': [{'type': 'tun'}],
          'outbounds': [{'type': 'vless'}]
        });
        mockManager.start(config);

        final ethernetInfo = jsonEncode({
          'network_type': 'ethernet',
          'is_connected': true,
          'is_wifi': false,
          'is_ethernet': true,
        });

        final wifiInfo = jsonEncode({
          'network_type': 'wifi',
          'is_connected': true,
          'is_wifi': true,
          'is_ethernet': false,
        });

        expect(mockManager.handleNetworkChange(ethernetInfo), isTrue);
        expect(mockManager.handleNetworkChange(wifiInfo), isTrue);
      });

      test('should provide Windows-specific memory information', () {
        final config = jsonEncode({
          'inbounds': [{'type': 'tun'}],
          'outbounds': [{'type': 'vless'}]
        });
        mockManager.start(config);

        final memory = mockManager.getMemoryUsage();
        expect(memory, containsPair('working_set_mb', isA<int>()));
        expect(memory, containsPair('private_bytes_mb', isA<int>()));
        expect(memory, containsPair('peak_working_set_mb', isA<int>()));
        expect(memory, containsPair('system_total_mb', isA<int>()));
        expect(memory, containsPair('system_available_mb', isA<int>()));
      });
    });

    group('Performance Tests', () {
      test('should handle multiple statistics requests efficiently', () {
        mockManager.initialize();
        final config = jsonEncode({
          'inbounds': [{'type': 'tun'}],
          'outbounds': [{'type': 'vless'}]
        });
        mockManager.start(config);

        final stopwatch = Stopwatch()..start();
        
        for (int i = 0; i < 100; i++) {
          final stats = mockManager.getStatistics();
          expect(stats, isNotNull);
        }
        
        stopwatch.stop();
        expect(stopwatch.elapsedMilliseconds, lessThan(1000)); // Should complete in under 1 second
      });

      test('should handle concurrent operations', () {
        mockManager.initialize();
        final config = jsonEncode({
          'inbounds': [{'type': 'tun'}],
          'outbounds': [{'type': 'vless'}]
        });
        mockManager.start(config);

        // Simulate concurrent access
        final futures = <Future>[];
        for (int i = 0; i < 10; i++) {
          futures.add(Future(() => mockManager.getStatistics()));
          futures.add(Future(() => mockManager.getStatus()));
          futures.add(Future(() => mockManager.getLogs()));
        }

        expect(() => Future.wait(futures), returnsNormally);
      });
    });
  });
}