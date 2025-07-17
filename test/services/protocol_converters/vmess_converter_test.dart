import 'package:flutter_test/flutter_test.dart';
import 'package:tunnel_max/models/vpn_configuration.dart';
import 'package:tunnel_max/services/protocol_converters/vmess_converter.dart';

void main() {
  group('VmessConverter', () {
    late VmessConverter converter;

    setUp(() {
      converter = VmessConverter();
    });

    group('convertToOutbound', () {
      test('should convert basic VMess configuration', () {
        final config = VpnConfiguration(
          id: 'test-1',
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

        final result = converter.convertToOutbound(config);

        expect(result['type'], equals('vmess'));
        expect(result['tag'], equals('proxy'));
        expect(result['server'], equals('example.com'));
        expect(result['server_port'], equals(443));
        expect(result['uuid'], equals('12345678-1234-1234-1234-123456789abc'));
        expect(result['security'], equals('auto'));
        expect(result['alter_id'], equals(0));
      });

      test('should add custom security method when specified', () {
        final config = VpnConfiguration(
          id: 'test-2',
          name: 'Test VMess with Security',
          serverAddress: 'example.com',
          serverPort: 443,
          protocol: VpnProtocol.vmess,
          authMethod: AuthenticationMethod.none,
          protocolSpecificConfig: {
            'uuid': '12345678-1234-1234-1234-123456789abc',
            'security': 'aes-128-gcm',
          },
          createdAt: DateTime.now(),
        );

        final result = converter.convertToOutbound(config);

        expect(result['security'], equals('aes-128-gcm'));
      });

      test('should add alter ID when specified as integer', () {
        final config = VpnConfiguration(
          id: 'test-3',
          name: 'Test VMess with Alter ID',
          serverAddress: 'example.com',
          serverPort: 443,
          protocol: VpnProtocol.vmess,
          authMethod: AuthenticationMethod.none,
          protocolSpecificConfig: {
            'uuid': '12345678-1234-1234-1234-123456789abc',
            'alterId': 64,
          },
          createdAt: DateTime.now(),
        );

        final result = converter.convertToOutbound(config);

        expect(result['alter_id'], equals(64));
      });

      test('should add alter ID when specified as string', () {
        final config = VpnConfiguration(
          id: 'test-4',
          name: 'Test VMess with Alter ID String',
          serverAddress: 'example.com',
          serverPort: 443,
          protocol: VpnProtocol.vmess,
          authMethod: AuthenticationMethod.none,
          protocolSpecificConfig: {
            'uuid': '12345678-1234-1234-1234-123456789abc',
            'alterId': '32',
          },
          createdAt: DateTime.now(),
        );

        final result = converter.convertToOutbound(config);

        expect(result['alter_id'], equals(32));
      });

      test('should add global padding when specified', () {
        final config = VpnConfiguration(
          id: 'test-5',
          name: 'Test VMess with Global Padding',
          serverAddress: 'example.com',
          serverPort: 443,
          protocol: VpnProtocol.vmess,
          authMethod: AuthenticationMethod.none,
          protocolSpecificConfig: {
            'uuid': '12345678-1234-1234-1234-123456789abc',
            'globalPadding': true,
          },
          createdAt: DateTime.now(),
        );

        final result = converter.convertToOutbound(config);

        expect(result['global_padding'], equals(true));
      });

      test('should add authenticated length when specified', () {
        final config = VpnConfiguration(
          id: 'test-6',
          name: 'Test VMess with Auth Length',
          serverAddress: 'example.com',
          serverPort: 443,
          protocol: VpnProtocol.vmess,
          authMethod: AuthenticationMethod.none,
          protocolSpecificConfig: {
            'uuid': '12345678-1234-1234-1234-123456789abc',
            'authenticatedLength': true,
          },
          createdAt: DateTime.now(),
        );

        final result = converter.convertToOutbound(config);

        expect(result['authenticated_length'], equals(true));
      });

      test('should throw exception for non-VMess protocol', () {
        final config = VpnConfiguration(
          id: 'test-7',
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

        expect(
          () => converter.convertToOutbound(config),
          throwsA(isA<VmessConfigurationException>()),
        );
      });

      test('should throw exception when UUID is missing', () {
        final config = VpnConfiguration(
          id: 'test-8',
          name: 'Test VMess No UUID',
          serverAddress: 'example.com',
          serverPort: 443,
          protocol: VpnProtocol.vmess,
          authMethod: AuthenticationMethod.none,
          protocolSpecificConfig: {},
          createdAt: DateTime.now(),
        );

        expect(
          () => converter.convertToOutbound(config),
          throwsA(isA<VmessConfigurationException>()),
        );
      });

      test('should throw exception for invalid UUID format', () {
        final config = VpnConfiguration(
          id: 'test-9',
          name: 'Test VMess Invalid UUID',
          serverAddress: 'example.com',
          serverPort: 443,
          protocol: VpnProtocol.vmess,
          authMethod: AuthenticationMethod.none,
          protocolSpecificConfig: {
            'uuid': 'invalid-uuid',
          },
          createdAt: DateTime.now(),
        );

        expect(
          () => converter.convertToOutbound(config),
          throwsA(isA<VmessConfigurationException>()),
        );
      });

      test('should throw exception for invalid security method', () {
        final config = VpnConfiguration(
          id: 'test-10',
          name: 'Test VMess Invalid Security',
          serverAddress: 'example.com',
          serverPort: 443,
          protocol: VpnProtocol.vmess,
          authMethod: AuthenticationMethod.none,
          protocolSpecificConfig: {
            'uuid': '12345678-1234-1234-1234-123456789abc',
            'security': 'invalid-security',
          },
          createdAt: DateTime.now(),
        );

        expect(
          () => converter.convertToOutbound(config),
          throwsA(isA<VmessConfigurationException>()),
        );
      });

      test('should throw exception for invalid alter ID', () {
        final config = VpnConfiguration(
          id: 'test-11',
          name: 'Test VMess Invalid Alter ID',
          serverAddress: 'example.com',
          serverPort: 443,
          protocol: VpnProtocol.vmess,
          authMethod: AuthenticationMethod.none,
          protocolSpecificConfig: {
            'uuid': '12345678-1234-1234-1234-123456789abc',
            'alterId': -1,
          },
          createdAt: DateTime.now(),
        );

        expect(
          () => converter.convertToOutbound(config),
          throwsA(isA<VmessConfigurationException>()),
        );
      });
    });

    group('TCP Transport', () {
      test('should create basic TCP transport', () {
        final config = VpnConfiguration(
          id: 'test-tcp-1',
          name: 'Test VMess TCP',
          serverAddress: 'example.com',
          serverPort: 443,
          protocol: VpnProtocol.vmess,
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
          name: 'Test VMess TCP HTTP',
          serverAddress: 'example.com',
          serverPort: 443,
          protocol: VpnProtocol.vmess,
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
          name: 'Test VMess WebSocket',
          serverAddress: 'example.com',
          serverPort: 443,
          protocol: VpnProtocol.vmess,
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
          name: 'Test VMess WebSocket Custom',
          serverAddress: 'example.com',
          serverPort: 443,
          protocol: VpnProtocol.vmess,
          authMethod: AuthenticationMethod.none,
          protocolSpecificConfig: {
            'uuid': '12345678-1234-1234-1234-123456789abc',
            'transport': 'ws',
            'path': '/custom-path',
            'host': 'custom.example.com',
            'headers': {
              'User-Agent': 'Custom-Agent',
            },
            'earlyDataHeaderName': 'Sec-WebSocket-Protocol',
            'maxEarlyData': 2048,
          },
          createdAt: DateTime.now(),
        );

        final result = converter.convertToOutbound(config);

        expect(result['transport']['type'], equals('ws'));
        expect(result['transport']['path'], equals('/custom-path'));
        expect(result['transport']['headers']['Host'], equals('custom.example.com'));
        expect(result['transport']['headers']['User-Agent'], equals('Custom-Agent'));
        expect(result['transport']['early_data_header_name'], equals('Sec-WebSocket-Protocol'));
        expect(result['transport']['max_early_data'], equals(2048));
      });
    });

    group('gRPC Transport', () {
      test('should create basic gRPC transport', () {
        final config = VpnConfiguration(
          id: 'test-grpc-1',
          name: 'Test VMess gRPC',
          serverAddress: 'example.com',
          serverPort: 443,
          protocol: VpnProtocol.vmess,
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

      test('should create gRPC transport with custom settings', () {
        final config = VpnConfiguration(
          id: 'test-grpc-2',
          name: 'Test VMess gRPC Custom',
          serverAddress: 'example.com',
          serverPort: 443,
          protocol: VpnProtocol.vmess,
          authMethod: AuthenticationMethod.none,
          protocolSpecificConfig: {
            'uuid': '12345678-1234-1234-1234-123456789abc',
            'transport': 'grpc',
            'serviceName': 'CustomService',
            'multiMode': true,
            'idleTimeout': '30s',
            'healthCheckTimeout': '20s',
            'permitWithoutStream': true,
          },
          createdAt: DateTime.now(),
        );

        final result = converter.convertToOutbound(config);

        expect(result['transport']['type'], equals('grpc'));
        expect(result['transport']['service_name'], equals('CustomService'));
        expect(result['transport']['multi_mode'], equals(true));
        expect(result['transport']['idle_timeout'], equals('30s'));
        expect(result['transport']['health_check_timeout'], equals('20s'));
        expect(result['transport']['permit_without_stream'], equals(true));
      });
    });

    group('HTTP Transport', () {
      test('should create basic HTTP transport', () {
        final config = VpnConfiguration(
          id: 'test-http-1',
          name: 'Test VMess HTTP',
          serverAddress: 'example.com',
          serverPort: 443,
          protocol: VpnProtocol.vmess,
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
          name: 'Test VMess HTTP Custom',
          serverAddress: 'example.com',
          serverPort: 443,
          protocol: VpnProtocol.vmess,
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
            'idleTimeout': '60s',
            'pingTimeout': '30s',
          },
          createdAt: DateTime.now(),
        );

        final result = converter.convertToOutbound(config);

        expect(result['transport']['type'], equals('http'));
        expect(result['transport']['path'], equals('/custom-path'));
        expect(result['transport']['host'], equals(['host1.example.com', 'host2.example.com']));
        expect(result['transport']['method'], equals('POST'));
        expect(result['transport']['headers']['Content-Type'], equals('application/json'));
        expect(result['transport']['idle_timeout'], equals('60s'));
        expect(result['transport']['ping_timeout'], equals('30s'));
      });
    });

    group('KCP Transport', () {
      test('should create basic KCP transport', () {
        final config = VpnConfiguration(
          id: 'test-kcp-1',
          name: 'Test VMess KCP',
          serverAddress: 'example.com',
          serverPort: 443,
          protocol: VpnProtocol.vmess,
          authMethod: AuthenticationMethod.none,
          protocolSpecificConfig: {
            'uuid': '12345678-1234-1234-1234-123456789abc',
            'transport': 'kcp',
          },
          createdAt: DateTime.now(),
        );

        final result = converter.convertToOutbound(config);

        expect(result['transport']['type'], equals('kcp'));
      });

      test('should create KCP transport with custom settings', () {
        final config = VpnConfiguration(
          id: 'test-kcp-2',
          name: 'Test VMess KCP Custom',
          serverAddress: 'example.com',
          serverPort: 443,
          protocol: VpnProtocol.vmess,
          authMethod: AuthenticationMethod.none,
          protocolSpecificConfig: {
            'uuid': '12345678-1234-1234-1234-123456789abc',
            'transport': 'kcp',
            'mtu': 1350,
            'tti': 50,
            'uplinkCapacity': 5,
            'downlinkCapacity': 20,
            'congestion': false,
            'readBufferSize': 2,
            'writeBufferSize': 2,
            'headerType': 'wechat-video',
            'seed': 'test-seed',
          },
          createdAt: DateTime.now(),
        );

        final result = converter.convertToOutbound(config);

        expect(result['transport']['type'], equals('kcp'));
        expect(result['transport']['mtu'], equals(1350));
        expect(result['transport']['tti'], equals(50));
        expect(result['transport']['uplink_capacity'], equals(5));
        expect(result['transport']['downlink_capacity'], equals(20));
        expect(result['transport']['congestion'], equals(false));
        expect(result['transport']['read_buffer_size'], equals(2));
        expect(result['transport']['write_buffer_size'], equals(2));
        expect(result['transport']['header']['type'], equals('wechat-video'));
        expect(result['transport']['header']['seed'], equals('test-seed'));
      });
    });

    group('QUIC Transport', () {
      test('should create basic QUIC transport', () {
        final config = VpnConfiguration(
          id: 'test-quic-1',
          name: 'Test VMess QUIC',
          serverAddress: 'example.com',
          serverPort: 443,
          protocol: VpnProtocol.vmess,
          authMethod: AuthenticationMethod.none,
          protocolSpecificConfig: {
            'uuid': '12345678-1234-1234-1234-123456789abc',
            'transport': 'quic',
          },
          createdAt: DateTime.now(),
        );

        final result = converter.convertToOutbound(config);

        expect(result['transport']['type'], equals('quic'));
      });

      test('should create QUIC transport with custom settings', () {
        final config = VpnConfiguration(
          id: 'test-quic-2',
          name: 'Test VMess QUIC Custom',
          serverAddress: 'example.com',
          serverPort: 443,
          protocol: VpnProtocol.vmess,
          authMethod: AuthenticationMethod.none,
          protocolSpecificConfig: {
            'uuid': '12345678-1234-1234-1234-123456789abc',
            'transport': 'quic',
            'security': 'aes-128-gcm',
            'key': 'test-key',
            'headerType': 'none',
          },
          createdAt: DateTime.now(),
        );

        final result = converter.convertToOutbound(config);

        expect(result['transport']['type'], equals('quic'));
        expect(result['transport']['security'], equals('aes-128-gcm'));
        expect(result['transport']['key'], equals('test-key'));
        expect(result['transport']['header']['type'], equals('none'));
      });
    });

    group('TLS Security', () {
      test('should create TLS configuration with tls flag', () {
        final config = VpnConfiguration(
          id: 'test-tls-1',
          name: 'Test VMess TLS',
          serverAddress: 'example.com',
          serverPort: 443,
          protocol: VpnProtocol.vmess,
          authMethod: AuthenticationMethod.none,
          protocolSpecificConfig: {
            'uuid': '12345678-1234-1234-1234-123456789abc',
            'tls': true,
          },
          createdAt: DateTime.now(),
        );

        final result = converter.convertToOutbound(config);

        expect(result['tls']['enabled'], equals(true));
        expect(result['tls']['server_name'], equals('example.com'));
      });

      test('should not create TLS configuration with security field set to encryption method', () {
        final config = VpnConfiguration(
          id: 'test-tls-2',
          name: 'Test VMess Security Method',
          serverAddress: 'example.com',
          serverPort: 443,
          protocol: VpnProtocol.vmess,
          authMethod: AuthenticationMethod.none,
          protocolSpecificConfig: {
            'uuid': '12345678-1234-1234-1234-123456789abc',
            'security': 'aes-128-gcm',
          },
          createdAt: DateTime.now(),
        );

        final result = converter.convertToOutbound(config);

        expect(result['security'], equals('aes-128-gcm'));
        expect(result.containsKey('tls'), equals(false));
      });

      test('should create TLS configuration with custom settings', () {
        final config = VpnConfiguration(
          id: 'test-tls-3',
          name: 'Test VMess TLS Custom',
          serverAddress: 'example.com',
          serverPort: 443,
          protocol: VpnProtocol.vmess,
          authMethod: AuthenticationMethod.none,
          protocolSpecificConfig: {
            'uuid': '12345678-1234-1234-1234-123456789abc',
            'tls': true,
            'serverName': 'custom.example.com',
            'allowInsecure': true,
            'alpn': ['h2', 'http/1.1'],
            'fingerprint': 'chrome',
            'certificates': ['cert1', 'cert2'],
            'certificatePath': '/path/to/cert',
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
        expect(result['tls']['certificate'], equals(['cert1', 'cert2']));
        expect(result['tls']['certificate_path'], equals('/path/to/cert'));
      });
    });

    group('Utility Methods', () {
      test('should return supported transports', () {
        final transports = converter.getSupportedTransports();
        expect(transports, contains('tcp'));
        expect(transports, contains('ws'));
        expect(transports, contains('grpc'));
        expect(transports, contains('http'));
        expect(transports, contains('kcp'));
        expect(transports, contains('quic'));
      });

      test('should return supported security methods', () {
        final securityMethods = converter.getSupportedSecurityMethods();
        expect(securityMethods, contains('auto'));
        expect(securityMethods, contains('aes-128-gcm'));
        expect(securityMethods, contains('chacha20-poly1305'));
        expect(securityMethods, contains('none'));
        expect(securityMethods, contains('zero'));
      });
    });
  });
}