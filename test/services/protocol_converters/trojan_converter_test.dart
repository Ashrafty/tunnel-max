import 'package:flutter_test/flutter_test.dart';
import 'package:tunnel_max/models/vpn_configuration.dart';
import 'package:tunnel_max/services/protocol_converters/trojan_converter.dart';

void main() {
  group('TrojanConverter', () {
    late TrojanConverter converter;

    setUp(() {
      converter = TrojanConverter();
    });

    group('convertToOutbound', () {
      test('should convert basic Trojan configuration', () {
        final config = VpnConfiguration(
          id: 'test-1',
          name: 'Test Trojan',
          serverAddress: 'example.com',
          serverPort: 443,
          protocol: VpnProtocol.trojan,
          authMethod: AuthenticationMethod.password,
          protocolSpecificConfig: {
            'password': 'test-password',
          },
          createdAt: DateTime.now(),
        );

        final result = converter.convertToOutbound(config);

        expect(result['type'], equals('trojan'));
        expect(result['tag'], equals('proxy'));
        expect(result['server'], equals('example.com'));
        expect(result['server_port'], equals(443));
        expect(result['password'], equals('test-password'));
        expect(result['tls']['enabled'], equals(true));
        expect(result['tls']['server_name'], equals('example.com'));
        expect(result['tls']['insecure'], equals(false));
      });

      test('should add custom TLS configuration when specified', () {
        final config = VpnConfiguration(
          id: 'test-2',
          name: 'Test Trojan Custom TLS',
          serverAddress: 'example.com',
          serverPort: 443,
          protocol: VpnProtocol.trojan,
          authMethod: AuthenticationMethod.password,
          protocolSpecificConfig: {
            'password': 'test-password',
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

      test('should add multiplex configuration when enabled', () {
        final config = VpnConfiguration(
          id: 'test-3',
          name: 'Test Trojan Multiplex',
          serverAddress: 'example.com',
          serverPort: 443,
          protocol: VpnProtocol.trojan,
          authMethod: AuthenticationMethod.password,
          protocolSpecificConfig: {
            'password': 'test-password',
            'multiplex': true,
            'multiplexProtocol': 'yamux',
            'maxConnections': 4,
            'minStreams': 4,
            'maxStreams': 32,
          },
          createdAt: DateTime.now(),
        );

        final result = converter.convertToOutbound(config);

        expect(result['multiplex']['enabled'], equals(true));
        expect(result['multiplex']['protocol'], equals('yamux'));
        expect(result['multiplex']['max_connections'], equals(4));
        expect(result['multiplex']['min_streams'], equals(4));
        expect(result['multiplex']['max_streams'], equals(32));
      });

      test('should throw exception for non-Trojan protocol', () {
        final config = VpnConfiguration(
          id: 'test-4',
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
          throwsA(isA<TrojanConfigurationException>()),
        );
      });

      test('should throw exception when password is missing', () {
        final config = VpnConfiguration(
          id: 'test-5',
          name: 'Test Trojan No Password',
          serverAddress: 'example.com',
          serverPort: 443,
          protocol: VpnProtocol.trojan,
          authMethod: AuthenticationMethod.password,
          protocolSpecificConfig: {},
          createdAt: DateTime.now(),
        );

        expect(
          () => converter.convertToOutbound(config),
          throwsA(isA<TrojanConfigurationException>()),
        );
      });

      test('should throw exception when password is empty', () {
        final config = VpnConfiguration(
          id: 'test-6',
          name: 'Test Trojan Empty Password',
          serverAddress: 'example.com',
          serverPort: 443,
          protocol: VpnProtocol.trojan,
          authMethod: AuthenticationMethod.password,
          protocolSpecificConfig: {
            'password': '',
          },
          createdAt: DateTime.now(),
        );

        expect(
          () => converter.convertToOutbound(config),
          throwsA(isA<TrojanConfigurationException>()),
        );
      });

      test('should throw exception for unsupported transport', () {
        final config = VpnConfiguration(
          id: 'test-7',
          name: 'Test Trojan Invalid Transport',
          serverAddress: 'example.com',
          serverPort: 443,
          protocol: VpnProtocol.trojan,
          authMethod: AuthenticationMethod.password,
          protocolSpecificConfig: {
            'password': 'test-password',
            'transport': 'grpc',
          },
          createdAt: DateTime.now(),
        );

        expect(
          () => converter.convertToOutbound(config),
          throwsA(isA<TrojanConfigurationException>()),
        );
      });

      test('should throw exception when server name is empty', () {
        final config = VpnConfiguration(
          id: 'test-8',
          name: 'Test Trojan Empty Server Name',
          serverAddress: 'example.com',
          serverPort: 443,
          protocol: VpnProtocol.trojan,
          authMethod: AuthenticationMethod.password,
          protocolSpecificConfig: {
            'password': 'test-password',
            'serverName': '',
          },
          createdAt: DateTime.now(),
        );

        expect(
          () => converter.convertToOutbound(config),
          throwsA(isA<TrojanConfigurationException>()),
        );
      });
    });

    group('TCP Transport', () {
      test('should create basic TCP transport', () {
        final config = VpnConfiguration(
          id: 'test-tcp-1',
          name: 'Test Trojan TCP',
          serverAddress: 'example.com',
          serverPort: 443,
          protocol: VpnProtocol.trojan,
          authMethod: AuthenticationMethod.password,
          protocolSpecificConfig: {
            'password': 'test-password',
            'transport': 'tcp',
          },
          createdAt: DateTime.now(),
        );

        final result = converter.convertToOutbound(config);

        expect(result['transport']['type'], equals('tcp'));
      });
    });

    group('WebSocket Transport', () {
      test('should create basic WebSocket transport', () {
        final config = VpnConfiguration(
          id: 'test-ws-1',
          name: 'Test Trojan WebSocket',
          serverAddress: 'example.com',
          serverPort: 443,
          protocol: VpnProtocol.trojan,
          authMethod: AuthenticationMethod.password,
          protocolSpecificConfig: {
            'password': 'test-password',
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
          name: 'Test Trojan WebSocket Custom',
          serverAddress: 'example.com',
          serverPort: 443,
          protocol: VpnProtocol.trojan,
          authMethod: AuthenticationMethod.password,
          protocolSpecificConfig: {
            'password': 'test-password',
            'transport': 'ws',
            'path': '/trojan-ws',
            'host': 'ws.example.com',
            'headers': {
              'User-Agent': 'Trojan-Client',
            },
            'earlyDataHeaderName': 'Sec-WebSocket-Protocol',
          },
          createdAt: DateTime.now(),
        );

        final result = converter.convertToOutbound(config);

        expect(result['transport']['type'], equals('ws'));
        expect(result['transport']['path'], equals('/trojan-ws'));
        expect(result['transport']['headers']['Host'], equals('ws.example.com'));
        expect(result['transport']['headers']['User-Agent'], equals('Trojan-Client'));
        expect(result['transport']['early_data_header_name'], equals('Sec-WebSocket-Protocol'));
      });
    });

    group('TLS Configuration', () {
      test('should create default TLS configuration', () {
        final config = VpnConfiguration(
          id: 'test-tls-1',
          name: 'Test Trojan Default TLS',
          serverAddress: 'example.com',
          serverPort: 443,
          protocol: VpnProtocol.trojan,
          authMethod: AuthenticationMethod.password,
          protocolSpecificConfig: {
            'password': 'test-password',
          },
          createdAt: DateTime.now(),
        );

        final result = converter.convertToOutbound(config);

        expect(result['tls']['enabled'], equals(true));
        expect(result['tls']['server_name'], equals('example.com'));
        expect(result['tls']['insecure'], equals(false));
      });

      test('should create custom TLS configuration', () {
        final config = VpnConfiguration(
          id: 'test-tls-2',
          name: 'Test Trojan Custom TLS',
          serverAddress: 'example.com',
          serverPort: 443,
          protocol: VpnProtocol.trojan,
          authMethod: AuthenticationMethod.password,
          protocolSpecificConfig: {
            'password': 'test-password',
            'serverName': 'tls.example.com',
            'allowInsecure': true,
            'alpn': 'h2',
            'fingerprint': 'firefox',
          },
          createdAt: DateTime.now(),
        );

        final result = converter.convertToOutbound(config);

        expect(result['tls']['enabled'], equals(true));
        expect(result['tls']['server_name'], equals('tls.example.com'));
        expect(result['tls']['insecure'], equals(true));
        expect(result['tls']['alpn'], equals(['h2']));
        expect(result['tls']['utls']['enabled'], equals(true));
        expect(result['tls']['utls']['fingerprint'], equals('firefox'));
      });
    });

    group('Multiplex Configuration', () {
      test('should create default multiplex configuration', () {
        final config = VpnConfiguration(
          id: 'test-mux-1',
          name: 'Test Trojan Default Multiplex',
          serverAddress: 'example.com',
          serverPort: 443,
          protocol: VpnProtocol.trojan,
          authMethod: AuthenticationMethod.password,
          protocolSpecificConfig: {
            'password': 'test-password',
            'multiplex': true,
          },
          createdAt: DateTime.now(),
        );

        final result = converter.convertToOutbound(config);

        expect(result['multiplex']['enabled'], equals(true));
        expect(result['multiplex']['protocol'], equals('smux'));
      });

      test('should create custom multiplex configuration', () {
        final config = VpnConfiguration(
          id: 'test-mux-2',
          name: 'Test Trojan Custom Multiplex',
          serverAddress: 'example.com',
          serverPort: 443,
          protocol: VpnProtocol.trojan,
          authMethod: AuthenticationMethod.password,
          protocolSpecificConfig: {
            'password': 'test-password',
            'multiplex': true,
            'multiplexProtocol': 'h2mux',
            'maxConnections': 8,
            'minStreams': 2,
            'maxStreams': 64,
          },
          createdAt: DateTime.now(),
        );

        final result = converter.convertToOutbound(config);

        expect(result['multiplex']['enabled'], equals(true));
        expect(result['multiplex']['protocol'], equals('h2mux'));
        expect(result['multiplex']['max_connections'], equals(8));
        expect(result['multiplex']['min_streams'], equals(2));
        expect(result['multiplex']['max_streams'], equals(64));
      });
    });

    group('Utility Methods', () {
      test('should return supported transports', () {
        final transports = converter.getSupportedTransports();
        expect(transports, contains('tcp'));
        expect(transports, contains('ws'));
        expect(transports.length, equals(2));
      });

      test('should return supported security options', () {
        final security = converter.getSupportedSecurityOptions();
        expect(security, contains('tls'));
        expect(security.length, equals(1));
      });

      test('should return supported multiplex protocols', () {
        final protocols = converter.getSupportedMultiplexProtocols();
        expect(protocols, contains('smux'));
        expect(protocols, contains('yamux'));
        expect(protocols, contains('h2mux'));
        expect(protocols.length, equals(3));
      });
    });
  });
}