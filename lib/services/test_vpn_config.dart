import '../models/vpn_configuration.dart';

/// Test VPN configurations for development and testing
class TestVpnConfig {
  /// Creates a test VLESS configuration
  static VpnConfiguration createTestVlessConfig() {
    return VpnConfiguration(
      id: 'test-vless-001',
      name: 'Test VLESS Server',
      serverAddress: '127.0.0.1',
      serverPort: 1080,
      protocol: VpnProtocol.vless,
      authMethod: AuthenticationMethod.none,
      protocolSpecificConfig: {
        'uuid': '12345678-1234-1234-1234-123456789abc',
        'flow': 'xtls-rprx-vision',
        'encryption': 'none',
        'network': 'tcp',
        'security': 'none',
        'type': 'none',
      },
      autoConnect: false,
      createdAt: DateTime.now(),
      lastUsed: null,
    );
  }

  /// Creates a test Shadowsocks configuration
  static VpnConfiguration createTestShadowsocksConfig() {
    return VpnConfiguration(
      id: 'test-ss-001',
      name: 'Test Shadowsocks Server',
      serverAddress: '127.0.0.1',
      serverPort: 8388,
      protocol: VpnProtocol.shadowsocks,
      authMethod: AuthenticationMethod.password,
      protocolSpecificConfig: {
        'method': 'aes-256-gcm',
        'password': 'test-password-123',
        'plugin': '',
        'plugin_opts': '',
      },
      autoConnect: false,
      createdAt: DateTime.now(),
      lastUsed: null,
    );
  }

  /// Creates a test Trojan configuration
  static VpnConfiguration createTestTrojanConfig() {
    return VpnConfiguration(
      id: 'test-trojan-001',
      name: 'Test Trojan Server',
      serverAddress: '127.0.0.1',
      serverPort: 443,
      protocol: VpnProtocol.trojan,
      authMethod: AuthenticationMethod.password,
      protocolSpecificConfig: {
        'password': 'test-trojan-password',
        'sni': 'example.com',
        'alpn': ['h2', 'http/1.1'],
        'skip_cert_verify': true,
        'network': 'tcp',
        'security': 'tls',
      },
      autoConnect: false,
      createdAt: DateTime.now(),
      lastUsed: null,
    );
  }

  /// Creates a test VMess configuration
  static VpnConfiguration createTestVmessConfig() {
    return VpnConfiguration(
      id: 'test-vmess-001',
      name: 'Test VMess Server',
      serverAddress: '127.0.0.1',
      serverPort: 10086,
      protocol: VpnProtocol.vmess,
      authMethod: AuthenticationMethod.none,
      protocolSpecificConfig: {
        'uuid': '12345678-1234-1234-1234-123456789abc',
        'alterId': 0,
        'security': 'auto',
        'network': 'tcp',
        'type': 'none',
        'host': '',
        'path': '',
        'tls': 'none',
      },
      autoConnect: false,
      createdAt: DateTime.now(),
      lastUsed: null,
    );
  }

  /// Gets all test configurations
  static List<VpnConfiguration> getAllTestConfigs() {
    return [
      createTestVlessConfig(),
      createTestShadowsocksConfig(),
      createTestTrojanConfig(),
      createTestVmessConfig(),
    ];
  }

  /// Creates a mock working configuration for testing
  static VpnConfiguration createMockWorkingConfig() {
    return VpnConfiguration(
      id: 'mock-working-001',
      name: 'Mock Working Server',
      serverAddress: '1.1.1.1',
      serverPort: 443,
      protocol: VpnProtocol.vless,
      authMethod: AuthenticationMethod.none,
      protocolSpecificConfig: {
        'uuid': 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee',
        'flow': 'xtls-rprx-vision',
        'encryption': 'none',
        'network': 'tcp',
        'security': 'tls',
        'type': 'none',
        'sni': 'cloudflare.com',
        'alpn': ['h2', 'http/1.1'],
      },
      autoConnect: false,
      createdAt: DateTime.now(),
      lastUsed: null,
    );
  }
}