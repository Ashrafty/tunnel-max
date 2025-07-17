import 'package:flutter_test/flutter_test.dart';
import 'package:tunnel_max/models/vpn_configuration.dart';
import 'package:tunnel_max/services/protocol_converters/vless_converter.dart';

void main() {
  group('VlessConverter', () {
    late VlessConverter converter;

    setUp(() {
      converter = VlessConverter();
    });

    group('convertToOutbound', () {
      test('should convert basic VLESS configuration', () {
        final config = VpnConfiguration(
          id: 'test-1',
          name: 'Test VLESS',
          serverAddress: 'example.com',
          serverPort: 443,
          protocol: VpnProtocol.vless,
          authMethod: AuthenticationMethod.none,
          protocolSpecificConfig: {
            'uuid': '12345678-1234-1234-1234-123456789abc',
          },
          createdAt: DateTime.now(),
        );

        final result = converter.convertToOutbound(config);

        expect(result['type'], equals('vless'));
        expect(result['tag'], equals('proxy'));
        expect(result['server'], equals('example.com'));
        expect(result['server_port'], equals(443));
        expect(result['uuid'], equals('12345678-1234-1234-1234-123456789abc'));
      });

      test('should add flow control when specified', () {
        final config = VpnConfiguration(
          id: 'test-2',
          name: 'Test VLESS with Flow',
          serverAddress: 'example.com',
          serverPort: 443,
          protocol: VpnProtocol.vless,
          authMethod: AuthenticationMethod.none,
          protocolSpecificConfig: {
            'uuid': '12345678-1234-1234-1234-123456789abc',
            'flow': 'xtls-rprx-vision',
          },
          createdAt: DateTime.now(),
        );

        final result = converter.convertToOutbound(config);

        expect(result['flow'], equals('xtls-rprx-vision'));
      });

      test('should throw exception for non-VLESS protocol', () {
        final config = VpnConfiguration(
          id: 'test-3',
          name: 'Test VMess',
          serverAddress: 'example.com',
          serverPort: 443,
          protocol: VpnProtocol.vmess,
          authMethod: AuthenticationMethod.none,
          protocolSpecificConfig: {
            'uuid': '12345678-1234-1234-1234-123456789abc',
          },
          createdAt: DateTime.now(),
        );

        expect(
          () => converter.convertToOutbound(config),
          throwsA(isA<VlessConfigurationException>()),
        );
      });

      test('should throw exception when UUID is missing', () {
        final config = VpnConfiguration(
          id: 'test-4',
          name: 'Test VLESS No UUID',
          serverAddress: 'example.com',
          serverPort: 443,
          protocol: VpnProtocol.vless,
          authMethod: AuthenticationMethod.none,
          protocolSpecificConfig: {},
          createdAt: DateTime.now(),
        );

        expect(
          () => converter.convertToOutbound(config),
          throwsA(isA<VlessConfigurationException>()),
        );
      });

      test('should throw exception for invalid UUID format', () {
        final config = VpnConfiguration(
          id: 'test-5',
          name: 'Test VLESS Invalid UUID',
          serverAddress: 'example.com',
          serverPort: 443,
          protocol: VpnProtocol.vless,
          authMethod: AuthenticationMethod.none,
          protocolSpecificConfig: {
            'uuid': 'invalid-uuid',
          },
          createdAt: DateTime.now(),
        );

        expect(
          () => converter.convertToOutbound(config),
          throwsA(isA<VlessConfigurationException>()),
        );
      });

      test('should throw exception for invalid flow', () {
        final config = VpnConfiguration(
          id: 'test-6',
          name: 'Test VLESS Invalid Flow',
          serverAddress: 'example.com',
          serverPort: 443,
          protocol: VpnProtocol.vless,
          authMethod: AuthenticationMethod.none,
          protocolSpecificConfig: {
            'uuid': '12345678-1234-1234-1234-123456789abc',
            'flow': 'invalid-flow',
          },
          createdAt: DateTime.now(),
        );

        expect(
          () => converter.convertToOutbound(config),
          throwsA(isA<VlessConfigurationException>()),
        );
      });
    });

    group('TCP Transport', () {
      test('should create basic TCP transport', () {
        final config = VpnConfiguration(
          id: 'test-tcp-1',
          name: 'Test VLESS TCP',
          serverAddress: 'example.com',
          serverPort: 443,
          protocol: VpnProtocol.vless,
          authMethod: AuthenticationMethod.none,
          protocolSpecificConfig: {
            'uuid': '12345678-1234-1234-1234-123456789abc',
            'transport': 'tcp',
          },
          createdAt: DateTime.now(),
        );

        final result = converter.convertToOutbound(config);

        expect(result['transport']['type'], equals('tcp'));
      });

      test('should create TCP transport with HTTP header obfuscation', () {
        final config = VpnConfiguration(
          id: 'test-tcp-2',
          name: 'Test VLESS TCP HTTP',
          serverAddress: 'example.com',
          serverPort: 443,
          protocol: VpnProtocol.vless,
          authMethod: AuthenticationMethod.none,
          protocolSpecificConfig: {
            'uuid': '12345678-1234-1234-1234-123456789abc',
            'transport': 'tcp',
            'headerType': 'http',
            'requestHeaders': {
              'Host': 'example.com',
              'User-Agent': 'Mozilla/5.0',
            },
          },
          createdAt: DateTime.now(),
        );

        final result = converter.convertToOutbound(config);

        expect(result['transport']['type'], equals('tcp'));
        expect(result['transport']['header']['type'], equals('http'));
        expect(result['transport']['header']['request']['Host'], equals('example.com'));
      });
    });

    group('WebSocket Transport', () {
      test('should create basic WebSocket transport', () {
        final config = VpnConfiguration(
          id: 'test-ws-1',
          name: 'Test VLESS WebSocket',
          serverAddress: 'example.com',
          serverPort: 443,
          protocol: VpnProtocol.vless,
          authMethod: AuthenticationMethod.none,
          protocolSpecificConfig: {
            'uuid': '12345678-1234-1234-1234-123456789abc',
            'transport': 'ws',
          },
          createdAt: DateTime.now(),
        );

        final result = converter.convertToOutbound(config);

        expect(result['transport']['type'], equals('ws'));
        expect(result['transport']['path'], equals('/'));
      });

      test('should create WebSocket transport with custom path and headers', () {
        final config = VpnConfiguration(
          id: 'test-ws-2',
          name: 'Test VLESS WebSocket Custom',
          serverAddress: 'example.com',
          serverPort: 443,
          protocol: VpnProtocol.vless,
          authMethod: AuthenticationMethod.none,
          protocolSpecificConfig: {
            'uuid': '12345678-1234-1234-1234-123456789abc',
            'transport': 'ws',
            'path': '/custom-path',
            'host': 'custom.example.com',
            'headers': {
              'User-Agent': 'Custom-Agent',
            },
          },
          createdAt: DateTime.now(),
        );

        final result = converter.convertToOutbound(config);

        expect(result['transport']['type'], equals('ws'));
        expect(result['transport']['path'], equals('/custom-path'));
        expect(result['transport']['headers']['Host'], equals('custom.example.com'));
        expect(result['transport']['headers']['User-Agent'], equals('Custom-Agent'));
      });
    });

    group('gRPC Transport', () {
      test('should create basic gRPC transport', () {
        final config = VpnConfiguration(
          id: 'test-grpc-1',
          name: 'Test VLESS gRPC',
          serverAddress: 'example.com',
          serverPort: 443,
          protocol: VpnProtocol.vless,
          authMethod: AuthenticationMethod.none,
          protocolSpecificConfig: {
            'uuid': '12345678-1234-1234-1234-123456789abc',
            'transport': 'grpc',
          },
          createdAt: DateTime.now(),
        );

        final result = converter.convertToOutbound(config);

        expect(result['transport']['type'], equals('grpc'));
        expect(result['transport']['service_name'], equals('TunService'));
      });

      test('should create gRPC transport with custom service name', () {
        final config = VpnConfiguration(
          id: 'test-grpc-2',
          name: 'Test VLESS gRPC Custom',
          serverAddress: 'example.com',
          serverPort: 443,
          protocol: VpnProtocol.vless,
          authMethod: AuthenticationMethod.none,
          protocolSpecificConfig: {
            'uuid': '12345678-1234-1234-1234-123456789abc',
            'transport': 'grpc',
            'serviceName': 'CustomService',
            'multiMode': true,
          },
          createdAt: DateTime.now(),
        );

        final result = converter.convertToOutbound(config);

        expect(result['transport']['type'], equals('grpc'));
        expect(result['transport']['service_name'], equals('CustomService'));
        expect(result['transport']['multi_mode'], equals(true));
      });
    });

    group('HTTP Transport', () {
      test('should create basic HTTP transport', () {
        final config = VpnConfiguration(
          id: 'test-http-1',
          name: 'Test VLESS HTTP',
          serverAddress: 'example.com',
          serverPort: 443,
          protocol: VpnProtocol.vless,
          authMethod: AuthenticationMethod.none,
          protocolSpecificConfig: {
            'uuid': '12345678-1234-1234-1234-123456789abc',
            'transport': 'http',
          },
          createdAt: DateTime.now(),
        );

        final result = converter.convertToOutbound(config);

        expect(result['transport']['type'], equals('http'));
      });

      test('should create HTTP transport with custom configuration', () {
        final config = VpnConfiguration(
          id: 'test-http-2',
          name: 'Test VLESS HTTP Custom',
          serverAddress: 'example.com',
          serverPort: 443,
          protocol: VpnProtocol.vless,
          authMethod: AuthenticationMethod.none,
          protocolSpecificConfig: {
            'uuid': '12345678-1234-1234-1234-123456789abc',
            'transport': 'http',
            'path': '/custom-path',
            'host': ['host1.example.com', 'host2.example.com'],
            'method': 'POST',
            'headers': {
              'Content-Type': 'application/json',
            },
          },
          createdAt: DateTime.now(),
        );

        final result = converter.convertToOutbound(config);

        expect(result['transport']['type'], equals('http'));
        expect(result['transport']['path'], equals('/custom-path'));
        expect(result['transport']['host'], equals(['host1.example.com', 'host2.example.com']));
        expect(result['transport']['method'], equals('POST'));
        expect(result['transport']['headers']['Content-Type'], equals('application/json'));
      });
    });

    group('TLS Security', () {
      test('should create TLS configuration', () {
        final config = VpnConfiguration(
          id: 'test-tls-1',
          name: 'Test VLESS TLS',
          serverAddress: 'example.com',
          serverPort: 443,
          protocol: VpnProtocol.vless,
          authMethod: AuthenticationMethod.none,
          protocolSpecificConfig: {
            'uuid': '12345678-1234-1234-1234-123456789abc',
            'security': 'tls',
          },
          createdAt: DateTime.now(),
        );

        final result = converter.convertToOutbound(config);

        expect(result['tls']['enabled'], equals(true));
        expect(result['tls']['server_name'], equals('example.com'));
      });

      test('should create TLS configuration with custom settings', () {
        final config = VpnConfiguration(
          id: 'test-tls-2',
          name: 'Test VLESS TLS Custom',
          serverAddress: 'example.com',
          serverPort: 443,
          protocol: VpnProtocol.vless,
          authMethod: AuthenticationMethod.none,
          protocolSpecificConfig: {
            'uuid': '12345678-1234-1234-1234-123456789abc',
            'security': 'tls',
            'serverName': 'custom.example.com',
            'allowInsecure': true,
            'alpn': ['h2', 'http/1.1'],
            'fingerprint': 'chrome',
          },
          createdAt: DateTime.now(),
        );

        final result = converter.convertToOutbound(config);

        expect(result['tls']['enabled'], equals(true));
        expect(result['tls']['server_name'], equals('custom.example.com'));
        expect(result['tls']['insecure'], equals(true));
        expect(result['tls']['alpn'], equals(['h2', 'http/1.1']));
        expect(result['tls']['utls']['enabled'], equals(true));
        expect(result['tls']['utls']['fingerprint'], equals('chrome'));
      });
    });

    group('Reality Security', () {
      test('should create Reality configuration', () {
        final config = VpnConfiguration(
          id: 'test-reality-1',
          name: 'Test VLESS Reality',
          serverAddress: 'example.com',
          serverPort: 443,
          protocol: VpnProtocol.vless,
          authMethod: AuthenticationMethod.none,
          protocolSpecificConfig: {
            'uuid': '12345678-1234-1234-1234-123456789abc',
            'security': 'reality',
            'publicKey': 'test-public-key',
          },
          createdAt: DateTime.now(),
        );

        final result = converter.convertToOutbound(config);

        expect(result['reality']['enabled'], equals(true));
        expect(result['reality']['server_name'], equals('example.com'));
        expect(result['reality']['public_key'], equals('test-public-key'));
      });

      test('should create Reality configuration with custom settings', () {
        final config = VpnConfiguration(
          id: 'test-reality-2',
          name: 'Test VLESS Reality Custom',
          serverAddress: 'example.com',
          serverPort: 443,
          protocol: VpnProtocol.vless,
          authMethod: AuthenticationMethod.none,
          protocolSpecificConfig: {
            'uuid': '12345678-1234-1234-1234-123456789abc',
            'security': 'reality',
            'publicKey': 'test-public-key',
            'serverName': 'custom.example.com',
            'shortId': 'abc123',
          },
          createdAt: DateTime.now(),
        );

        final result = converter.convertToOutbound(config);

        expect(result['reality']['enabled'], equals(true));
        expect(result['reality']['server_name'], equals('custom.example.com'));
        expect(result['reality']['public_key'], equals('test-public-key'));
        expect(result['reality']['short_id'], equals('abc123'));
      });

      test('should throw exception when Reality public key is missing', () {
        final config = VpnConfiguration(
          id: 'test-reality-3',
          name: 'Test VLESS Reality No Key',
          serverAddress: 'example.com',
          serverPort: 443,
          protocol: VpnProtocol.vless,
          authMethod: AuthenticationMethod.none,
          protocolSpecificConfig: {
            'uuid': '12345678-1234-1234-1234-123456789abc',
            'security': 'reality',
          },
          createdAt: DateTime.now(),
        );

        expect(
          () => converter.convertToOutbound(config),
          throwsA(isA<VlessConfigurationException>()),
        );
      });
    });

    group('Utility Methods', () {
      test('should return supported transports', () {
        final transports = converter.getSupportedTransports();
        expect(transports, contains('tcp'));
        expect(transports, contains('ws'));
        expect(transports, contains('grpc'));
        expect(transports, contains('http'));
      });

      test('should return supported flows', () {
        final flows = converter.getSupportedFlows();
        expect(flows, contains('xtls-rprx-vision'));
        expect(flows, contains('xtls-rprx-origin'));
        expect(flows, contains('xtls-rprx-direct'));
      });
    });
  });
}