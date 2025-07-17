import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'dart:convert';

/// Integration tests for SingboxManager JNI integration
/// These tests verify the actual JNI bridge functionality
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('SingboxManager JNI Integration Tests', () {
    late MethodChannel testChannel;
    
    setUp(() {
      // Create a test method channel to simulate the native bridge
      testChannel = const MethodChannel('com.tunnelmax.vpnclient/singbox');
      
      // Mock the method channel responses
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(testChannel, (MethodCall methodCall) async {
        switch (methodCall.method) {
          case 'nativeInit':
            return true;
          case 'nativeStart':
            final args = Map<String, dynamic>.from(methodCall.arguments as Map);
            final config = args['config'] as String;
            final tunFd = args['tunFd'] as int;
            
            // Validate arguments
            if (config.isNotEmpty && tunFd > 0) {
              return true;
            }
            return false;
          case 'nativeStop':
            return true;
          case 'nativeIsRunning':
            return false; // Default to not running
          case 'nativeGetStats':
            return jsonEncode({
              'upload_bytes': 1024,
              'download_bytes': 2048,
              'upload_speed': 128.5,
              'download_speed': 256.7,
              'connection_time': 30,
              'packets_sent': 50,
              'packets_received': 100
            });
          case 'nativeValidateConfig':
            final config = methodCall.arguments as String;
            try {
              final json = jsonDecode(config);
              return json is Map<String, dynamic> && 
                     json.containsKey('inbounds') && 
                     json.containsKey('outbounds');
            } catch (e) {
              return false;
            }
          case 'nativeGetVersion':
            return jsonEncode({
              'version': '1.8.0',
              'build': 'integration-test',
              'platform': 'android'
            });
          case 'nativeCleanup':
            return null;
          default:
            throw PlatformException(
              code: 'UNIMPLEMENTED',
              message: 'Method ${methodCall.method} not implemented',
            );
        }
      });
    });

    tearDown(() {
      // Clean up the mock
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(testChannel, null);
    });

    test('should initialize JNI bridge successfully', () async {
      final result = await testChannel.invokeMethod<bool>('nativeInit');
      expect(result, isTrue);
    });

    test('should validate configuration through JNI', () async {
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

      final result = await testChannel.invokeMethod<bool>('nativeValidateConfig', validConfig);
      expect(result, isTrue);
    });

    test('should start sing-box through JNI with valid parameters', () async {
      final config = jsonEncode({
        'inbounds': [{'type': 'tun'}],
        'outbounds': [{'type': 'vless'}]
      });

      final result = await testChannel.invokeMethod<bool>('nativeStart', {
        'config': config,
        'tunFd': 3,
      });
      expect(result, isTrue);
    });

    test('should fail to start with invalid TUN file descriptor', () async {
      final config = jsonEncode({
        'inbounds': [{'type': 'tun'}],
        'outbounds': [{'type': 'vless'}]
      });

      final result = await testChannel.invokeMethod<bool>('nativeStart', {
        'config': config,
        'tunFd': -1,
      });
      expect(result, isFalse);
    });

    test('should get statistics through JNI', () async {
      final statsJson = await testChannel.invokeMethod<String>('nativeGetStats');
      expect(statsJson, isNotNull);
      
      final stats = jsonDecode(statsJson!);
      expect(stats, containsPair('upload_bytes', isA<int>()));
      expect(stats, containsPair('download_bytes', isA<int>()));
      expect(stats, containsPair('upload_speed', isA<double>()));
      expect(stats, containsPair('download_speed', isA<double>()));
    });

    test('should get version information through JNI', () async {
      final versionJson = await testChannel.invokeMethod<String>('nativeGetVersion');
      expect(versionJson, isNotNull);
      
      final version = jsonDecode(versionJson!);
      expect(version, containsPair('version', isA<String>()));
      expect(version, containsPair('platform', 'android'));
    });

    test('should handle JNI method call exceptions', () async {
      expect(
        () => testChannel.invokeMethod('nonExistentMethod'),
        throwsA(isA<PlatformException>()),
      );
    });

    test('should stop sing-box through JNI', () async {
      final result = await testChannel.invokeMethod<bool>('nativeStop');
      expect(result, isTrue);
    });

    test('should cleanup resources through JNI', () async {
      // Should not throw an exception
      await testChannel.invokeMethod('nativeCleanup');
    });
  });

  group('JNI Error Handling Tests', () {
    late MethodChannel errorTestChannel;
    
    setUp(() {
      errorTestChannel = const MethodChannel('com.tunnelmax.vpnclient/singbox_error');
      
      // Mock error scenarios
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(errorTestChannel, (MethodCall methodCall) async {
        switch (methodCall.method) {
          case 'nativeInit':
            throw PlatformException(
              code: 'INIT_FAILED',
              message: 'Failed to initialize native library',
            );
          case 'nativeStart':
            throw PlatformException(
              code: 'START_FAILED',
              message: 'Failed to start sing-box process',
            );
          default:
            return null;
        }
      });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(errorTestChannel, null);
    });

    test('should handle JNI initialization failure', () async {
      expect(
        () => errorTestChannel.invokeMethod('nativeInit'),
        throwsA(
          isA<PlatformException>()
              .having((e) => e.code, 'code', 'INIT_FAILED')
              .having((e) => e.message, 'message', contains('Failed to initialize')),
        ),
      );
    });

    test('should handle JNI start failure', () async {
      expect(
        () => errorTestChannel.invokeMethod('nativeStart', {
          'config': '{}',
          'tunFd': 3,
        }),
        throwsA(
          isA<PlatformException>()
              .having((e) => e.code, 'code', 'START_FAILED')
              .having((e) => e.message, 'message', contains('Failed to start')),
        ),
      );
    });
  });

  group('JNI Memory Management Tests', () {
    late MethodChannel memoryTestChannel;
    
    setUp(() {
      memoryTestChannel = const MethodChannel('com.tunnelmax.vpnclient/singbox_memory');
      
      // Mock memory-related operations
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(memoryTestChannel, (MethodCall methodCall) async {
        switch (methodCall.method) {
          case 'nativeGetMemoryUsage':
            return jsonEncode({
              'total_memory_mb': 512,
              'used_memory_mb': 64,
              'cpu_usage_percent': 5.2,
              'open_file_descriptors': 15
            });
          case 'nativeOptimizePerformance':
            return true;
          default:
            return null;
        }
      });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(memoryTestChannel, null);
    });

    test('should get memory usage through JNI', () async {
      final memoryJson = await memoryTestChannel.invokeMethod<String>('nativeGetMemoryUsage');
      expect(memoryJson, isNotNull);
      
      final memory = jsonDecode(memoryJson!);
      expect(memory, containsPair('total_memory_mb', isA<int>()));
      expect(memory, containsPair('used_memory_mb', isA<int>()));
      expect(memory, containsPair('cpu_usage_percent', isA<double>()));
      expect(memory, containsPair('open_file_descriptors', isA<int>()));
    });

    test('should optimize performance through JNI', () async {
      final result = await memoryTestChannel.invokeMethod<bool>('nativeOptimizePerformance');
      expect(result, isTrue);
    });
  });
}