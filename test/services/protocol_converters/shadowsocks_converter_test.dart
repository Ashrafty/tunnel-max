import 'package:flutter_test/flutter_test.dart';
import 'package:tunnel_max/models/vpn_configuration.dart';
import 'package:tunnel_max/services/protocol_converters/shadowsocks_converter.dart';

void main() {
  group('ShadowsocksConverter', () {
    late ShadowsocksConverter converter;

    setUp(() {
      converter = ShadowsocksConverter();
    });

    group('convertToOutbound', () {
      test('should convert basic Shadowsocks configuration', () {
        final config = VpnConfiguration(
          id: 'test-1',
          name: 'Test Shadowsocks',
          serverAddress: 'example.com',
          serverPort: 8388,
          protocol: VpnProtocol.shadowsocks,
          authMethod: AuthenticationMethod.password,
          protocolSpecificConfig: {
            'method': 'aes-256-gcm',
            'password': 'test-password',
          },
          createdAt: DateTime.now(),
        );

        final result = converter.convertToOutbound(config);

        expect(result['type'], equals('shadowsocks'));
        expect(result['tag'], equals('proxy'));
        expect(result['server'], equals('example.com'));
        expect(result['server_port'], equals(8388));
        expect(result['method'], equals('aes-256-gcm'));
        expect(result['password'], equals('test-password'));
      });

      test('should convert Shadowsocks with plugin configuration', () {
        final config = VpnConfiguration(
          id: 'test-2',
          name: 'Test Shadowsocks Plugin',
          serverAddress: 'example.com',
          serverPort: 8388,
          protocol: VpnProtocol.shadowsocks,
          authMethod: AuthenticationMethod.password,
          protocolSpecificConfig: {
            'method': 'chacha20-ietf-poly1305',
            'password': 'test-password',
            'plugin': 'v2ray-plugin',
            'pluginOpts': 'server;tls;host=example.com',
          },
          createdAt: DateTime.now(),
        );

        final result = converter.convertToOutbound(config);

        expect(result['type'], equals('shadowsocks'));
        expect(result['method'], equals('chacha20-ietf-poly1305'));
        expect(result['password'], equals('test-password'));
        expect(result['plugin'], equals('v2ray-plugin'));
        expect(result['plugin_opts'], equals('server;tls;host=example.com'));
      });

      test('should convert Shadowsocks with UDP relay enabled', () {
        final config = VpnConfiguration(
          id: 'test-3',
          name: 'Test Shadowsocks UDP',
          serverAddress: 'example.com',
          serverPort: 8388,
          protocol: VpnProtocol.shadowsocks,
          authMethod: AuthenticationMethod.password,
          protocolSpecificConfig: {
            'method': 'aes-128-gcm',
            'password': 'test-password',
            'udpRelay': true,
          },
          createdAt: DateTime.now(),
        );

        final result = converter.convertToOutbound(config);

        expect(result['type'], equals('shadowsocks'));
        expect(result['method'], equals('aes-128-gcm'));
        expect(result['password'], equals('test-password'));
        expect(result['udp_relay'], equals(true));
      });

      test('should convert Shadowsocks with multiplex configuration', () {
        final config = VpnConfiguration(
          id: 'test-4',
          name: 'Test Shadowsocks Multiplex',
          serverAddress: 'example.com',
          serverPort: 8388,
          protocol: VpnProtocol.shadowsocks,
          authMethod: AuthenticationMethod.password,
          protocolSpecificConfig: {
            'method': 'xchacha20-ietf-poly1305',
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

        expect(result['type'], equals('shadowsocks'));
        expect(result['method'], equals('xchacha20-ietf-poly1305'));
        expect(result['password'], equals('test-password'));
        expect(result['multiplex']['enabled'], equals(true));
        expect(result['multiplex']['protocol'], equals('yamux'));
        expect(result['multiplex']['max_connections'], equals(4));
        expect(result['multiplex']['min_streams'], equals(4));
        expect(result['multiplex']['max_streams'], equals(32));
      });

      test('should throw exception for non-Shadowsocks protocol', () {
        final config = VpnConfiguration(
          id: 'test-5',
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
          throwsA(isA<ShadowsocksConfigurationException>()),
        );
      });

      test('should throw exception when method is missing', () {
        final config = VpnConfiguration(
          id: 'test-6',
          name: 'Test Shadowsocks No Method',
          serverAddress: 'example.com',
          serverPort: 8388,
          protocol: VpnProtocol.shadowsocks,
          authMethod: AuthenticationMethod.password,
          protocolSpecificConfig: {
            'password': 'test-password',
          },
          createdAt: DateTime.now(),
        );

        expect(
          () => converter.convertToOutbound(config),
          throwsA(isA<ShadowsocksConfigurationException>()),
        );
      });

      test('should throw exception when method is empty', () {
        final config = VpnConfiguration(
          id: 'test-7',
          name: 'Test Shadowsocks Empty Method',
          serverAddress: 'example.com',
          serverPort: 8388,
          protocol: VpnProtocol.shadowsocks,
          authMethod: AuthenticationMethod.password,
          protocolSpecificConfig: {
            'method': '',
            'password': 'test-password',
          },
          createdAt: DateTime.now(),
        );

        expect(
          () => converter.convertToOutbound(config),
          throwsA(isA<ShadowsocksConfigurationException>()),
        );
      });

      test('should throw exception when password is missing', () {
        final config = VpnConfiguration(
          id: 'test-8',
          name: 'Test Shadowsocks No Password',
          serverAddress: 'example.com',
          serverPort: 8388,
          protocol: VpnProtocol.shadowsocks,
          authMethod: AuthenticationMethod.password,
          protocolSpecificConfig: {
            'method': 'aes-256-gcm',
          },
          createdAt: DateTime.now(),
        );

        expect(
          () => converter.convertToOutbound(config),
          throwsA(isA<ShadowsocksConfigurationException>()),
        );
      });

      test('should throw exception when password is empty', () {
        final config = VpnConfiguration(
          id: 'test-9',
          name: 'Test Shadowsocks Empty Password',
          serverAddress: 'example.com',
          serverPort: 8388,
          protocol: VpnProtocol.shadowsocks,
          authMethod: AuthenticationMethod.password,
          protocolSpecificConfig: {
            'method': 'aes-256-gcm',
            'password': '',
          },
          createdAt: DateTime.now(),
        );

        expect(
          () => converter.convertToOutbound(config),
          throwsA(isA<ShadowsocksConfigurationException>()),
        );
      });

      test('should throw exception for unsupported method', () {
        final config = VpnConfiguration(
          id: 'test-10',
          name: 'Test Shadowsocks Invalid Method',
          serverAddress: 'example.com',
          serverPort: 8388,
          protocol: VpnProtocol.shadowsocks,
          authMethod: AuthenticationMethod.password,
          protocolSpecificConfig: {
            'method': 'invalid-cipher',
            'password': 'test-password',
          },
          createdAt: DateTime.now(),
        );

        expect(
          () => converter.convertToOutbound(config),
          throwsA(isA<ShadowsocksConfigurationException>()),
        );
      });

      test('should throw exception for unsupported plugin', () {
        final config = VpnConfiguration(
          id: 'test-11',
          name: 'Test Shadowsocks Invalid Plugin',
          serverAddress: 'example.com',
          serverPort: 8388,
          protocol: VpnProtocol.shadowsocks,
          authMethod: AuthenticationMethod.password,
          protocolSpecificConfig: {
            'method': 'aes-256-gcm',
            'password': 'test-password',
            'plugin': 'invalid-plugin',
          },
          createdAt: DateTime.now(),
        );

        expect(
          () => converter.convertToOutbound(config),
          throwsA(isA<ShadowsocksConfigurationException>()),
        );
      });

      test('should throw exception for invalid UDP relay setting', () {
        final config = VpnConfiguration(
          id: 'test-12',
          name: 'Test Shadowsocks Invalid UDP',
          serverAddress: 'example.com',
          serverPort: 8388,
          protocol: VpnProtocol.shadowsocks,
          authMethod: AuthenticationMethod.password,
          protocolSpecificConfig: {
            'method': 'aes-256-gcm',
            'password': 'test-password',
            'udpRelay': 'invalid',
          },
          createdAt: DateTime.now(),
        );

        expect(
          () => converter.convertToOutbound(config),
          throwsA(isA<ShadowsocksConfigurationException>()),
        );
      });
    });

    group('AEAD Cipher Methods', () {
      test('should support aes-128-gcm', () {
        final config = VpnConfiguration(
          id: 'test-aead-1',
          name: 'Test AES-128-GCM',
          serverAddress: 'example.com',
          serverPort: 8388,
          protocol: VpnProtocol.shadowsocks,
          authMethod: AuthenticationMethod.password,
          protocolSpecificConfig: {
            'method': 'aes-128-gcm',
            'password': 'test-password',
          },
          createdAt: DateTime.now(),
        );

        final result = converter.convertToOutbound(config);
        expect(result['method'], equals('aes-128-gcm'));
      });

      test('should support aes-192-gcm', () {
        final config = VpnConfiguration(
          id: 'test-aead-2',
          name: 'Test AES-192-GCM',
          serverAddress: 'example.com',
          serverPort: 8388,
          protocol: VpnProtocol.shadowsocks,
          authMethod: AuthenticationMethod.password,
          protocolSpecificConfig: {
            'method': 'aes-192-gcm',
            'password': 'test-password',
          },
          createdAt: DateTime.now(),
        );

        final result = converter.convertToOutbound(config);
        expect(result['method'], equals('aes-192-gcm'));
      });

      test('should support aes-256-gcm', () {
        final config = VpnConfiguration(
          id: 'test-aead-3',
          name: 'Test AES-256-GCM',
          serverAddress: 'example.com',
          serverPort: 8388,
          protocol: VpnProtocol.shadowsocks,
          authMethod: AuthenticationMethod.password,
          protocolSpecificConfig: {
            'method': 'aes-256-gcm',
            'password': 'test-password',
          },
          createdAt: DateTime.now(),
        );

        final result = converter.convertToOutbound(config);
        expect(result['method'], equals('aes-256-gcm'));
      });

      test('should support chacha20-ietf-poly1305', () {
        final config = VpnConfiguration(
          id: 'test-aead-4',
          name: 'Test ChaCha20-IETF-Poly1305',
          serverAddress: 'example.com',
          serverPort: 8388,
          protocol: VpnProtocol.shadowsocks,
          authMethod: AuthenticationMethod.password,
          protocolSpecificConfig: {
            'method': 'chacha20-ietf-poly1305',
            'password': 'test-password',
          },
          createdAt: DateTime.now(),
        );

        final result = converter.convertToOutbound(config);
        expect(result['method'], equals('chacha20-ietf-poly1305'));
      });

      test('should support xchacha20-ietf-poly1305', () {
        final config = VpnConfiguration(
          id: 'test-aead-5',
          name: 'Test XChaCha20-IETF-Poly1305',
          serverAddress: 'example.com',
          serverPort: 8388,
          protocol: VpnProtocol.shadowsocks,
          authMethod: AuthenticationMethod.password,
          protocolSpecificConfig: {
            'method': 'xchacha20-ietf-poly1305',
            'password': 'test-password',
          },
          createdAt: DateTime.now(),
        );

        final result = converter.convertToOutbound(config);
        expect(result['method'], equals('xchacha20-ietf-poly1305'));
      });
    });

    group('2022 Edition Methods', () {
      test('should support 2022-blake3-aes-128-gcm', () {
        final config = VpnConfiguration(
          id: 'test-2022-1',
          name: 'Test 2022 AES-128-GCM',
          serverAddress: 'example.com',
          serverPort: 8388,
          protocol: VpnProtocol.shadowsocks,
          authMethod: AuthenticationMethod.password,
          protocolSpecificConfig: {
            'method': '2022-blake3-aes-128-gcm',
            'password': 'test-password',
          },
          createdAt: DateTime.now(),
        );

        final result = converter.convertToOutbound(config);
        expect(result['method'], equals('2022-blake3-aes-128-gcm'));
      });

      test('should support 2022-blake3-aes-256-gcm', () {
        final config = VpnConfiguration(
          id: 'test-2022-2',
          name: 'Test 2022 AES-256-GCM',
          serverAddress: 'example.com',
          serverPort: 8388,
          protocol: VpnProtocol.shadowsocks,
          authMethod: AuthenticationMethod.password,
          protocolSpecificConfig: {
            'method': '2022-blake3-aes-256-gcm',
            'password': 'test-password',
          },
          createdAt: DateTime.now(),
        );

        final result = converter.convertToOutbound(config);
        expect(result['method'], equals('2022-blake3-aes-256-gcm'));
      });

      test('should support 2022-blake3-chacha20-poly1305', () {
        final config = VpnConfiguration(
          id: 'test-2022-3',
          name: 'Test 2022 ChaCha20-Poly1305',
          serverAddress: 'example.com',
          serverPort: 8388,
          protocol: VpnProtocol.shadowsocks,
          authMethod: AuthenticationMethod.password,
          protocolSpecificConfig: {
            'method': '2022-blake3-chacha20-poly1305',
            'password': 'test-password',
          },
          createdAt: DateTime.now(),
        );

        final result = converter.convertToOutbound(config);
        expect(result['method'], equals('2022-blake3-chacha20-poly1305'));
      });
    });

    group('Stream Cipher Methods (Legacy)', () {
      test('should support aes-128-ctr', () {
        final config = VpnConfiguration(
          id: 'test-stream-1',
          name: 'Test AES-128-CTR',
          serverAddress: 'example.com',
          serverPort: 8388,
          protocol: VpnProtocol.shadowsocks,
          authMethod: AuthenticationMethod.password,
          protocolSpecificConfig: {
            'method': 'aes-128-ctr',
            'password': 'test-password',
          },
          createdAt: DateTime.now(),
        );

        final result = converter.convertToOutbound(config);
        expect(result['method'], equals('aes-128-ctr'));
      });

      test('should support aes-256-cfb', () {
        final config = VpnConfiguration(
          id: 'test-stream-2',
          name: 'Test AES-256-CFB',
          serverAddress: 'example.com',
          serverPort: 8388,
          protocol: VpnProtocol.shadowsocks,
          authMethod: AuthenticationMethod.password,
          protocolSpecificConfig: {
            'method': 'aes-256-cfb',
            'password': 'test-password',
          },
          createdAt: DateTime.now(),
        );

        final result = converter.convertToOutbound(config);
        expect(result['method'], equals('aes-256-cfb'));
      });

      test('should support chacha20-ietf', () {
        final config = VpnConfiguration(
          id: 'test-stream-3',
          name: 'Test ChaCha20-IETF',
          serverAddress: 'example.com',
          serverPort: 8388,
          protocol: VpnProtocol.shadowsocks,
          authMethod: AuthenticationMethod.password,
          protocolSpecificConfig: {
            'method': 'chacha20-ietf',
            'password': 'test-password',
          },
          createdAt: DateTime.now(),
        );

        final result = converter.convertToOutbound(config);
        expect(result['method'], equals('chacha20-ietf'));
      });
    });

    group('Plugin Support', () {
      test('should support obfs-local plugin', () {
        final config = VpnConfiguration(
          id: 'test-plugin-1',
          name: 'Test OBFS Local',
          serverAddress: 'example.com',
          serverPort: 8388,
          protocol: VpnProtocol.shadowsocks,
          authMethod: AuthenticationMethod.password,
          protocolSpecificConfig: {
            'method': 'aes-256-gcm',
            'password': 'test-password',
            'plugin': 'obfs-local',
            'pluginOpts': 'obfs=http;obfs-host=www.bing.com',
          },
          createdAt: DateTime.now(),
        );

        final result = converter.convertToOutbound(config);
        expect(result['plugin'], equals('obfs-local'));
        expect(result['plugin_opts'], equals('obfs=http;obfs-host=www.bing.com'));
      });

      test('should support v2ray-plugin', () {
        final config = VpnConfiguration(
          id: 'test-plugin-2',
          name: 'Test V2Ray Plugin',
          serverAddress: 'example.com',
          serverPort: 8388,
          protocol: VpnProtocol.shadowsocks,
          authMethod: AuthenticationMethod.password,
          protocolSpecificConfig: {
            'method': 'chacha20-ietf-poly1305',
            'password': 'test-password',
            'plugin': 'v2ray-plugin',
            'pluginOpts': 'server;tls;host=cloudflare.com',
          },
          createdAt: DateTime.now(),
        );

        final result = converter.convertToOutbound(config);
        expect(result['plugin'], equals('v2ray-plugin'));
        expect(result['plugin_opts'], equals('server;tls;host=cloudflare.com'));
      });

      test('should handle empty plugin gracefully', () {
        final config = VpnConfiguration(
          id: 'test-plugin-3',
          name: 'Test Empty Plugin',
          serverAddress: 'example.com',
          serverPort: 8388,
          protocol: VpnProtocol.shadowsocks,
          authMethod: AuthenticationMethod.password,
          protocolSpecificConfig: {
            'method': 'aes-256-gcm',
            'password': 'test-password',
            'plugin': '',
          },
          createdAt: DateTime.now(),
        );

        final result = converter.convertToOutbound(config);
        expect(result.containsKey('plugin'), equals(false));
        expect(result.containsKey('plugin_opts'), equals(false));
      });
    });

    group('Multiplex Configuration', () {
      test('should create default multiplex configuration', () {
        final config = VpnConfiguration(
          id: 'test-mux-1',
          name: 'Test Shadowsocks Default Multiplex',
          serverAddress: 'example.com',
          serverPort: 8388,
          protocol: VpnProtocol.shadowsocks,
          authMethod: AuthenticationMethod.password,
          protocolSpecificConfig: {
            'method': 'aes-256-gcm',
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
          name: 'Test Shadowsocks Custom Multiplex',
          serverAddress: 'example.com',
          serverPort: 8388,
          protocol: VpnProtocol.shadowsocks,
          authMethod: AuthenticationMethod.password,
          protocolSpecificConfig: {
            'method': 'chacha20-ietf-poly1305',
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
      test('should return supported methods', () {
        final methods = converter.getSupportedMethods();
        expect(methods, contains('aes-128-gcm'));
        expect(methods, contains('aes-256-gcm'));
        expect(methods, contains('chacha20-ietf-poly1305'));
        expect(methods, contains('xchacha20-ietf-poly1305'));
        expect(methods, contains('2022-blake3-aes-128-gcm'));
        expect(methods, contains('aes-128-ctr'));
        expect(methods, contains('aes-256-cfb'));
        expect(methods, contains('chacha20-ietf'));
        expect(methods.length, greaterThan(10));
      });

      test('should return supported plugins', () {
        final plugins = converter.getSupportedPlugins();
        expect(plugins, contains('obfs-local'));
        expect(plugins, contains('simple-obfs'));
        expect(plugins, contains('v2ray-plugin'));
        expect(plugins, contains('kcptun'));
        expect(plugins.length, greaterThan(5));
      });

      test('should return recommended methods', () {
        final recommended = converter.getRecommendedMethods();
        expect(recommended, contains('aes-128-gcm'));
        expect(recommended, contains('aes-256-gcm'));
        expect(recommended, contains('chacha20-ietf-poly1305'));
        expect(recommended, contains('xchacha20-ietf-poly1305'));
        expect(recommended, contains('2022-blake3-aes-128-gcm'));
        expect(recommended, contains('2022-blake3-aes-256-gcm'));
        expect(recommended, contains('2022-blake3-chacha20-poly1305'));
        expect(recommended.length, equals(7));
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