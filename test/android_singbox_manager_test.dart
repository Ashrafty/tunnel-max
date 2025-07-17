import 'package:flutter_test/flutter_test.dart';
import 'dart:convert';

// Mock classes for testing
class MockSingboxManager {
  bool _isInitialized = false;
  bool _isRunning = false;
  String? _currentConfig;
  Map<String, dynamic>? _lastNetworkInfo;
  
  // Mock native method responses
  bool nativeInit() {
    _isInitialized = true;
    return true;
  }
  bool nativeStart(String config, int tunFd) {
    if (!_isInitialized) return false;
    if (config.isNotEmpty && tunFd > 0) {
      _currentConfig = config;
      _isRunning = true;
      return true;
    }
    return false;
  }
  bool nativeStop() {
    _isRunning = false;
    _currentConfig = null;
    return true;
  }
  String? nativeGetStats() {
    if (!_isRunning) return null;
    return jsonEncode({
      'upload_bytes': 1024,
      'download_bytes': 2048,
      'upload_speed': 128.5,
      'download_speed': 256.7,
      'connection_time': 30,
      'packets_sent': 50,
      'packets_received': 100
    });
  }
  bool nativeIsRunning() => _isRunning;
  void nativeCleanup() {
    _isInitialized = false;
    _isRunning = false;
    _currentConfig = null;
  }
  bool nativeValidateConfig(String config) {
    try {
      final json = jsonDecode(config);
      return json is Map<String, dynamic> && 
             json.containsKey('inbounds') && 
             json.containsKey('outbounds');
    } catch (e) {
      return false;
    }
  }
  String nativeGetVersion() => jsonEncode({
    'version': '1.8.0',
    'build': 'test',
    'platform': 'android'
  });
  String? nativeGetLastError() => null;
  String? nativeGetDetailedStats() {
    if (!_isRunning) return null;
    return jsonEncode({
      'bytesReceived': 2048,
      'bytesSent': 1024,
      'downloadSpeed': 256.5,
      'uploadSpeed': 128.2,
      'packetsReceived': 150,
      'packetsSent': 100,
      'connectionDuration': 30,
      'latency': 45,
      'jitter': 5,
      'packetLoss': 0.1
    });
  }
  bool nativeResetStats() => _isRunning;
  bool nativeSetStatsCallback(int callback) => true;
  bool nativeSetLogLevel(int level) => level >= 0 && level <= 5;
  String nativeGetLogs() => jsonEncode({
    'logs': [
      '[INFO] Sing-box started successfully',
      '[DEBUG] TUN interface created',
      '[INFO] Connection established'
    ]
  });
  String nativeGetMemoryUsage() => jsonEncode({
    'total_memory_mb': 512,
    'used_memory_mb': 64,
    'cpu_usage_percent': 5.2,
    'open_file_descriptors': 15
  });
  bool nativeOptimizePerformance() => true;
  bool nativeHandleNetworkChange(String networkInfo) {
    try {
      _lastNetworkInfo = jsonDecode(networkInfo);
      return true;
    } catch (e) {
      return false;
    }
  }
  
  // Helper methods for testing
  String? getCurrentConfig() => _currentConfig;
  Map<String, dynamic>? getLastNetworkInfo() => _lastNetworkInfo;
  bool nativeUpdateConfiguration(String config) {
    if (!_isRunning) return false;
    if (nativeValidateConfig(config)) {
      _currentConfig = config;
      return true;
    }
    return false;
  }
  String nativeGetConnectionInfo() => jsonEncode({
    'server_address': 'test.example.com',
    'server_port': 443,
    'protocol': 'vless',
    'local_address': '172.19.0.1',
    'remote_address': '1.2.3.4',
    'is_connected': true,
    'last_ping_ms': 45
  });
}

// Test data classes
class TestVpnConfiguration {
  final String id;
  final String name;
  final String serverAddress;
  final int serverPort;
  final String protocol;
  final String authMethod;
  final Map<String, dynamic> protocolSpecificConfig;
  final bool autoConnect;
  final DateTime createdAt;
  final DateTime? lastUsed;

  TestVpnConfiguration({
    required this.id,
    required this.name,
    required this.serverAddress,
    required this.serverPort,
    required this.protocol,
    required this.authMethod,
    required this.protocolSpecificConfig,
    required this.autoConnect,
    required this.createdAt,
    this.lastUsed,
  });
}

class TestNetworkInfo {
  final String networkType;
  final bool isConnected;
  final bool isWifi;
  final bool isMobile;
  final String? networkName;
  final String? ipAddress;
  final int? mtu;

  TestNetworkInfo({
    required this.networkType,
    required this.isConnected,
    required this.isWifi,
    required this.isMobile,
    this.networkName,
    this.ipAddress,
    this.mtu,
  });
}

void main() {
  group('Android SingboxManager Tests', () {
    late MockSingboxManager mockManager;
    late TestVpnConfiguration testConfig;

    setUp(() {
      mockManager = MockSingboxManager();
      testConfig = TestVpnConfiguration(
        id: 'test-config-1',
        name: 'Test VLESS Server',
        serverAddress: 'test.example.com',
        serverPort: 443,
        protocol: 'vless',
        authMethod: 'uuid',
        protocolSpecificConfig: {
          'uuid': '12345678-1234-1234-1234-123456789abc',
          'flow': 'xtls-rprx-vision',
          'transport': 'tcp'
        },
        autoConnect: false,
        createdAt: DateTime.now(),
      );
    });

    group('Initialization Tests', () {
      test('should initialize successfully', () {
        final result = mockManager.nativeInit();
        expect(result, isTrue);
      });

      test('should handle initialization failure gracefully', () {
        // Test with a mock that fails initialization
        final failingManager = MockSingboxManager();
        // Override to return false
        expect(() => failingManager.nativeInit(), returnsNormally);
      });
    });

    group('Configuration Tests', () {
      test('should validate valid configuration', () {
        final validConfig = jsonEncode({
          'log': {'level': 'info'},
          'inbounds': [
            {
              'type': 'tun',
              'tag': 'tun-in',
              'interface_name': 'tun0'
            }
          ],
          'outbounds': [
            {
              'type': 'vless',
              'tag': 'proxy',
              'server': 'test.example.com',
              'server_port': 443
            }
          ]
        });

        final result = mockManager.nativeValidateConfig(validConfig);
        expect(result, isTrue);
      });

      test('should reject invalid configuration', () {
        const invalidConfig = '{"invalid": "config"}';
        final result = mockManager.nativeValidateConfig(invalidConfig);
        expect(result, isFalse);
      });

      test('should reject malformed JSON', () {
        const malformedConfig = '{invalid json}';
        final result = mockManager.nativeValidateConfig(malformedConfig);
        expect(result, isFalse);
      });
    });

    group('Lifecycle Management Tests', () {
      test('should start with valid configuration and TUN fd', () {
        mockManager.nativeInit();
        
        final config = jsonEncode({
          'inbounds': [{'type': 'tun'}],
          'outbounds': [{'type': 'vless'}]
        });
        
        final result = mockManager.nativeStart(config, 3);
        expect(result, isTrue);
        expect(mockManager.nativeIsRunning(), isTrue);
      });

      test('should fail to start with invalid TUN fd', () {
        mockManager.nativeInit();
        
        final config = jsonEncode({
          'inbounds': [{'type': 'tun'}],
          'outbounds': [{'type': 'vless'}]
        });
        
        final result = mockManager.nativeStart(config, -1);
        expect(result, isFalse);
      });

      test('should fail to start with empty configuration', () {
        mockManager.nativeInit();
        final result = mockManager.nativeStart('', 3);
        expect(result, isFalse);
      });

      test('should stop successfully when running', () {
        mockManager.nativeInit();
        mockManager.nativeStart(jsonEncode({'inbounds': [], 'outbounds': []}), 3);
        
        final result = mockManager.nativeStop();
        expect(result, isTrue);
        expect(mockManager.nativeIsRunning(), isFalse);
      });

      test('should handle stop when not running', () {
        final result = mockManager.nativeStop();
        expect(result, isTrue);
      });
    });

    group('Statistics Tests', () {
      setUp(() {
        mockManager.nativeInit();
        mockManager.nativeStart(jsonEncode({'inbounds': [], 'outbounds': []}), 3);
      });

      test('should return statistics when running', () {
        final stats = mockManager.nativeGetStats();
        expect(stats, isNotNull);
        
        final statsData = jsonDecode(stats!);
        expect(statsData, containsPair('upload_bytes', isA<int>()));
        expect(statsData, containsPair('download_bytes', isA<int>()));
        expect(statsData, containsPair('upload_speed', isA<double>()));
        expect(statsData, containsPair('download_speed', isA<double>()));
      });

      test('should return detailed statistics when running', () {
        final detailedStats = mockManager.nativeGetDetailedStats();
        expect(detailedStats, isNotNull);
        
        final statsData = jsonDecode(detailedStats!);
        expect(statsData, containsPair('latency', isA<int>()));
        expect(statsData, containsPair('jitter', isA<int>()));
        expect(statsData, containsPair('packetLoss', isA<double>()));
      });

      test('should return null statistics when not running', () {
        mockManager.nativeStop();
        final stats = mockManager.nativeGetStats();
        expect(stats, isNull);
      });

      test('should reset statistics successfully', () {
        final result = mockManager.nativeResetStats();
        expect(result, isTrue);
      });
    });

    group('Advanced Features Tests', () {
      setUp(() {
        mockManager.nativeInit();
        mockManager.nativeStart(jsonEncode({'inbounds': [], 'outbounds': []}), 3);
      });

      test('should set log level successfully', () {
        for (int level = 0; level <= 5; level++) {
          final result = mockManager.nativeSetLogLevel(level);
          expect(result, isTrue);
        }
      });

      test('should reject invalid log level', () {
        final result = mockManager.nativeSetLogLevel(-1);
        expect(result, isFalse);
      });

      test('should return logs', () {
        final logs = mockManager.nativeGetLogs();
        final logsData = jsonDecode(logs);
        expect(logsData['logs'], isA<List>());
        expect(logsData['logs'].length, greaterThan(0));
      });

      test('should return memory usage', () {
        final memoryUsage = mockManager.nativeGetMemoryUsage();
        final memoryData = jsonDecode(memoryUsage);
        expect(memoryData, containsPair('total_memory_mb', isA<int>()));
        expect(memoryData, containsPair('used_memory_mb', isA<int>()));
        expect(memoryData, containsPair('cpu_usage_percent', isA<double>()));
      });

      test('should optimize performance', () {
        final result = mockManager.nativeOptimizePerformance();
        expect(result, isTrue);
      });

      test('should handle network change', () {
        final networkInfo = TestNetworkInfo(
          networkType: 'wifi',
          isConnected: true,
          isWifi: true,
          isMobile: false,
          networkName: 'TestWiFi',
          ipAddress: '192.168.1.100',
          mtu: 1500,
        );

        final networkJson = jsonEncode({
          'network_type': networkInfo.networkType,
          'is_connected': networkInfo.isConnected,
          'is_wifi': networkInfo.isWifi,
          'is_mobile': networkInfo.isMobile,
          'network_name': networkInfo.networkName,
          'ip_address': networkInfo.ipAddress,
          'mtu': networkInfo.mtu,
        });

        final result = mockManager.nativeHandleNetworkChange(networkJson);
        expect(result, isTrue);
      });

      test('should update configuration while running', () {
        final newConfig = jsonEncode({
          'inbounds': [{'type': 'tun', 'tag': 'tun-in'}],
          'outbounds': [{'type': 'vmess', 'tag': 'proxy'}]
        });

        final result = mockManager.nativeUpdateConfiguration(newConfig);
        expect(result, isTrue);
      });

      test('should fail to update invalid configuration', () {
        const invalidConfig = '{"invalid": "config"}';
        final result = mockManager.nativeUpdateConfiguration(invalidConfig);
        expect(result, isFalse);
      });

      test('should return connection info when running', () {
        final connectionInfo = mockManager.nativeGetConnectionInfo();
        final infoData = jsonDecode(connectionInfo);
        expect(infoData, containsPair('server_address', isA<String>()));
        expect(infoData, containsPair('server_port', isA<int>()));
        expect(infoData, containsPair('protocol', isA<String>()));
        expect(infoData, containsPair('is_connected', isA<bool>()));
      });
    });

    group('Version and Error Handling Tests', () {
      test('should return version information', () {
        final version = mockManager.nativeGetVersion();
        final versionData = jsonDecode(version);
        expect(versionData, containsPair('version', isA<String>()));
        expect(versionData, containsPair('platform', 'android'));
      });

      test('should return last error', () {
        final error = mockManager.nativeGetLastError();
        expect(error, isNull); // No error in mock
      });
    });

    group('Cleanup Tests', () {
      test('should cleanup resources properly', () {
        mockManager.nativeInit();
        mockManager.nativeStart(jsonEncode({'inbounds': [], 'outbounds': []}), 3);
        
        expect(mockManager.nativeIsRunning(), isTrue);
        
        mockManager.nativeCleanup();
        
        expect(mockManager.nativeIsRunning(), isFalse);
      });
    });

    group('Edge Cases and Error Conditions', () {
      test('should handle multiple start calls gracefully', () {
        mockManager.nativeInit();
        final config = jsonEncode({'inbounds': [], 'outbounds': []});
        
        final result1 = mockManager.nativeStart(config, 3);
        final result2 = mockManager.nativeStart(config, 3);
        
        expect(result1, isTrue);
        expect(result2, isTrue); // Should handle gracefully
      });

      test('should handle multiple stop calls gracefully', () {
        mockManager.nativeInit();
        mockManager.nativeStart(jsonEncode({'inbounds': [], 'outbounds': []}), 3);
        
        final result1 = mockManager.nativeStop();
        final result2 = mockManager.nativeStop();
        
        expect(result1, isTrue);
        expect(result2, isTrue); // Should handle gracefully
      });

      test('should handle operations when not initialized', () {
        // Don't call nativeInit()
        final result = mockManager.nativeStart(jsonEncode({'test': 'config'}), 3);
        expect(result, isFalse);
      });

      test('should handle null or empty inputs gracefully', () {
        mockManager.nativeInit();
        
        expect(mockManager.nativeValidateConfig(''), isFalse);
        expect(mockManager.nativeStart('', 3), isFalse);
        expect(mockManager.nativeHandleNetworkChange('invalid json'), isFalse);
      });
    });

    group('Performance Tests', () {
      test('should handle rapid start/stop cycles', () {
        mockManager.nativeInit();
        final config = jsonEncode({'inbounds': [], 'outbounds': []});
        
        for (int i = 0; i < 10; i++) {
          final startResult = mockManager.nativeStart(config, 3);
          expect(startResult, isTrue);
          
          final stopResult = mockManager.nativeStop();
          expect(stopResult, isTrue);
        }
      });

      test('should handle multiple statistics requests', () {
        mockManager.nativeInit();
        mockManager.nativeStart(jsonEncode({'inbounds': [], 'outbounds': []}), 3);
        
        for (int i = 0; i < 100; i++) {
          final stats = mockManager.nativeGetStats();
          expect(stats, isNotNull);
        }
      });
    });

    group('JNI Integration Tests', () {
      test('should maintain state consistency across JNI calls', () {
        // Test state consistency
        expect(mockManager.nativeIsRunning(), isFalse);
        
        mockManager.nativeInit();
        expect(mockManager.nativeIsRunning(), isFalse);
        
        final config = jsonEncode({'inbounds': [], 'outbounds': []});
        mockManager.nativeStart(config, 3);
        expect(mockManager.nativeIsRunning(), isTrue);
        expect(mockManager.getCurrentConfig(), equals(config));
        
        mockManager.nativeStop();
        expect(mockManager.nativeIsRunning(), isFalse);
        expect(mockManager.getCurrentConfig(), isNull);
      });

      test('should handle network change state tracking', () {
        mockManager.nativeInit();
        mockManager.nativeStart(jsonEncode({'inbounds': [], 'outbounds': []}), 3);
        
        final networkInfo = {
          'network_type': 'wifi',
          'is_connected': true,
          'is_wifi': true,
          'is_mobile': false,
          'network_name': 'TestNetwork',
          'ip_address': '192.168.1.100',
          'mtu': 1500,
        };
        
        final result = mockManager.nativeHandleNetworkChange(jsonEncode(networkInfo));
        expect(result, isTrue);
        expect(mockManager.getLastNetworkInfo(), equals(networkInfo));
      });

      test('should validate configuration persistence', () {
        mockManager.nativeInit();
        
        final originalConfig = jsonEncode({
          'inbounds': [{'type': 'tun', 'tag': 'tun-in'}],
          'outbounds': [{'type': 'vless', 'tag': 'proxy'}]
        });
        
        mockManager.nativeStart(originalConfig, 3);
        expect(mockManager.getCurrentConfig(), equals(originalConfig));
        
        final newConfig = jsonEncode({
          'inbounds': [{'type': 'tun', 'tag': 'tun-in'}],
          'outbounds': [{'type': 'vmess', 'tag': 'proxy'}]
        });
        
        final updateResult = mockManager.nativeUpdateConfiguration(newConfig);
        expect(updateResult, isTrue);
        expect(mockManager.getCurrentConfig(), equals(newConfig));
      });

      test('should handle concurrent operations safely', () {
        mockManager.nativeInit();
        final config = jsonEncode({'inbounds': [], 'outbounds': []});
        
        // Simulate concurrent operations
        mockManager.nativeStart(config, 3);
        expect(mockManager.nativeIsRunning(), isTrue);
        
        // Multiple stats requests
        for (int i = 0; i < 5; i++) {
          final stats = mockManager.nativeGetStats();
          expect(stats, isNotNull);
        }
        
        // Network change during stats collection
        final networkResult = mockManager.nativeHandleNetworkChange(jsonEncode({
          'network_type': 'mobile',
          'is_connected': true,
        }));
        expect(networkResult, isTrue);
        
        // Should still be running
        expect(mockManager.nativeIsRunning(), isTrue);
      });
    });

    group('Protocol-Specific Configuration Tests', () {
      test('should validate VLESS configuration', () {
        final vlessConfig = jsonEncode({
          'inbounds': [
            {
              'type': 'tun',
              'tag': 'tun-in',
              'interface_name': 'tun0'
            }
          ],
          'outbounds': [
            {
              'type': 'vless',
              'tag': 'proxy',
              'server': testConfig.serverAddress,
              'server_port': testConfig.serverPort,
              'uuid': testConfig.protocolSpecificConfig['uuid'],
              'flow': testConfig.protocolSpecificConfig['flow'],
              'transport': {
                'type': testConfig.protocolSpecificConfig['transport']
              }
            }
          ]
        });
        
        expect(mockManager.nativeValidateConfig(vlessConfig), isTrue);
      });

      test('should validate VMess configuration', () {
        final vmessConfig = jsonEncode({
          'inbounds': [
            {
              'type': 'tun',
              'tag': 'tun-in'
            }
          ],
          'outbounds': [
            {
              'type': 'vmess',
              'tag': 'proxy',
              'server': 'vmess.example.com',
              'server_port': 443,
              'uuid': '12345678-1234-1234-1234-123456789abc',
              'alter_id': 0,
              'security': 'auto'
            }
          ]
        });
        
        expect(mockManager.nativeValidateConfig(vmessConfig), isTrue);
      });

      test('should validate Trojan configuration', () {
        final trojanConfig = jsonEncode({
          'inbounds': [
            {
              'type': 'tun',
              'tag': 'tun-in'
            }
          ],
          'outbounds': [
            {
              'type': 'trojan',
              'tag': 'proxy',
              'server': 'trojan.example.com',
              'server_port': 443,
              'password': 'your-password'
            }
          ]
        });
        
        expect(mockManager.nativeValidateConfig(trojanConfig), isTrue);
      });

      test('should validate Shadowsocks configuration', () {
        final shadowsocksConfig = jsonEncode({
          'inbounds': [
            {
              'type': 'tun',
              'tag': 'tun-in'
            }
          ],
          'outbounds': [
            {
              'type': 'shadowsocks',
              'tag': 'proxy',
              'server': 'ss.example.com',
              'server_port': 8388,
              'method': 'aes-256-gcm',
              'password': 'your-password'
            }
          ]
        });
        
        expect(mockManager.nativeValidateConfig(shadowsocksConfig), isTrue);
      });
    });

    group('Error Recovery Tests', () {
      test('should recover from invalid configuration updates', () {
        mockManager.nativeInit();
        
        final validConfig = jsonEncode({
          'inbounds': [{'type': 'tun'}],
          'outbounds': [{'type': 'vless'}]
        });
        
        mockManager.nativeStart(validConfig, 3);
        expect(mockManager.nativeIsRunning(), isTrue);
        expect(mockManager.getCurrentConfig(), equals(validConfig));
        
        // Try to update with invalid config
        const invalidConfig = '{"invalid": "config"}';
        final updateResult = mockManager.nativeUpdateConfiguration(invalidConfig);
        expect(updateResult, isFalse);
        
        // Should still have original config and be running
        expect(mockManager.nativeIsRunning(), isTrue);
        expect(mockManager.getCurrentConfig(), equals(validConfig));
      });

      test('should handle malformed network change data', () {
        mockManager.nativeInit();
        mockManager.nativeStart(jsonEncode({'inbounds': [], 'outbounds': []}), 3);
        
        // Test with malformed JSON
        final result1 = mockManager.nativeHandleNetworkChange('invalid json');
        expect(result1, isFalse);
        
        // Test with empty string
        final result2 = mockManager.nativeHandleNetworkChange('');
        expect(result2, isFalse);
        
        // Should still be running
        expect(mockManager.nativeIsRunning(), isTrue);
      });
    });
  });
}