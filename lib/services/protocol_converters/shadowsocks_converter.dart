import 'package:logger/logger.dart';

import '../../models/vpn_configuration.dart';
import '../singbox_logger.dart';

/// Exception thrown when Shadowsocks configuration conversion fails
class ShadowsocksConfigurationException implements Exception {
  final String message;
  final Map<String, dynamic>? config;

  const ShadowsocksConfigurationException(this.message, {this.config});

  @override
  String toString() => 'ShadowsocksConfigurationException: $message';
}

/// Shadowsocks Protocol Configuration Converter
class ShadowsocksConverter {
  final Logger _logger;
  final SingboxLogger _singboxLogger;

  ShadowsocksConverter({Logger? logger})
      : _logger = logger ?? Logger(),
        _singboxLogger = SingboxLogger.instance;

  /// Converts Shadowsocks configuration to sing-box outbound format
  Map<String, dynamic> convertToOutbound(VpnConfiguration config) {
    if (config.protocol != VpnProtocol.shadowsocks) {
      throw ShadowsocksConfigurationException(
        'Configuration is not Shadowsocks protocol: ${config.protocol.name}',
      );
    }

    final protocolConfig = config.protocolSpecificConfig;
    _validateShadowsocksConfig(protocolConfig);

    _logger.d('Converting Shadowsocks configuration: ${config.name}');
    _singboxLogger.info(
      'ShadowsocksConverter',
      'Converting Shadowsocks configuration',
      metadata: {
        'configName': config.name,
        'serverAddress': config.serverAddress,
        'serverPort': config.serverPort,
        'method': protocolConfig['method'],
      },
    );

    final outbound = <String, dynamic>{
      'type': 'shadowsocks',
      'tag': 'proxy',
      'server': config.serverAddress,
      'server_port': config.serverPort,
      'method': protocolConfig['method'],
      'password': protocolConfig['password'],
    };

    // Add plugin configuration if specified
    if (protocolConfig.containsKey('plugin') && protocolConfig['plugin'] != null) {
      final plugin = protocolConfig['plugin'] as String;
      if (plugin.isNotEmpty) {
        outbound['plugin'] = plugin;
        
        // Add plugin options if specified
        if (protocolConfig.containsKey('pluginOpts') && protocolConfig['pluginOpts'] != null) {
          outbound['plugin_opts'] = protocolConfig['pluginOpts'];
        }
      }
    }

    // Add UDP relay support if specified
    if (protocolConfig.containsKey('udpRelay')) {
      outbound['udp_relay'] = protocolConfig['udpRelay'];
    }

    // Add multiplex configuration if specified
    if (protocolConfig.containsKey('multiplex') && protocolConfig['multiplex'] == true) {
      outbound['multiplex'] = _createMultiplexConfig(protocolConfig);
    }

    _logger.d('Shadowsocks configuration converted successfully');
    return outbound;
  }

  void _validateShadowsocksConfig(Map<String, dynamic> config) {
    // Validate encryption method
    if (!config.containsKey('method') || config['method'] == null) {
      throw ShadowsocksConfigurationException('Shadowsocks method is required', config: config);
    }

    final method = config['method'] as String;
    if (method.isEmpty) {
      throw ShadowsocksConfigurationException('Shadowsocks method cannot be empty', config: config);
    }

    if (!_isValidMethod(method)) {
      throw ShadowsocksConfigurationException('Unsupported Shadowsocks method: $method', config: config);
    }

    // Validate password
    if (!config.containsKey('password') || config['password'] == null) {
      throw ShadowsocksConfigurationException('Shadowsocks password is required', config: config);
    }

    final password = config['password'] as String;
    if (password.isEmpty) {
      throw ShadowsocksConfigurationException('Shadowsocks password cannot be empty', config: config);
    }

    // Validate plugin if specified
    if (config.containsKey('plugin') && config['plugin'] != null) {
      final plugin = config['plugin'] as String;
      if (plugin.isNotEmpty && !_isValidPlugin(plugin)) {
        throw ShadowsocksConfigurationException('Unsupported Shadowsocks plugin: $plugin', config: config);
      }
    }

    // Validate UDP relay setting
    if (config.containsKey('udpRelay') && config['udpRelay'] != null) {
      if (config['udpRelay'] is! bool) {
        throw ShadowsocksConfigurationException('UDP relay setting must be a boolean', config: config);
      }
    }
  }

  Map<String, dynamic> _createMultiplexConfig(Map<String, dynamic> config) {
    final multiplex = <String, dynamic>{
      'enabled': true,
      'protocol': config['multiplexProtocol'] ?? 'smux',
    };

    if (config.containsKey('maxConnections')) {
      multiplex['max_connections'] = config['maxConnections'];
    }

    if (config.containsKey('minStreams')) {
      multiplex['min_streams'] = config['minStreams'];
    }

    if (config.containsKey('maxStreams')) {
      multiplex['max_streams'] = config['maxStreams'];
    }

    return multiplex;
  }

  bool _isValidMethod(String method) {
    const validMethods = [
      // AEAD ciphers (recommended)
      'aes-128-gcm',
      'aes-192-gcm',
      'aes-256-gcm',
      'chacha20-ietf-poly1305',
      'xchacha20-ietf-poly1305',
      
      // Stream ciphers (legacy, less secure)
      'aes-128-ctr',
      'aes-192-ctr',
      'aes-256-ctr',
      'aes-128-cfb',
      'aes-192-cfb',
      'aes-256-cfb',
      'chacha20-ietf',
      'xchacha20',
      
      // Additional supported methods
      '2022-blake3-aes-128-gcm',
      '2022-blake3-aes-256-gcm',
      '2022-blake3-chacha20-poly1305',
    ];
    return validMethods.contains(method.toLowerCase());
  }

  bool _isValidPlugin(String plugin) {
    const validPlugins = [
      'obfs-local',
      'simple-obfs',
      'v2ray-plugin',
      'kcptun',
      'cloak-client',
      'goquiet-client',
      'mos-tls-tunnel',
      'rabbit-tcp',
      'simple-tls',
    ];
    return validPlugins.contains(plugin.toLowerCase());
  }

  List<String> getSupportedMethods() {
    return [
      // AEAD ciphers (recommended)
      'aes-128-gcm',
      'aes-192-gcm',
      'aes-256-gcm',
      'chacha20-ietf-poly1305',
      'xchacha20-ietf-poly1305',
      
      // Stream ciphers (legacy)
      'aes-128-ctr',
      'aes-192-ctr',
      'aes-256-ctr',
      'aes-128-cfb',
      'aes-192-cfb',
      'aes-256-cfb',
      'chacha20-ietf',
      'xchacha20',
      
      // 2022 edition methods
      '2022-blake3-aes-128-gcm',
      '2022-blake3-aes-256-gcm',
      '2022-blake3-chacha20-poly1305',
    ];
  }

  List<String> getSupportedPlugins() {
    return [
      'obfs-local',
      'simple-obfs',
      'v2ray-plugin',
      'kcptun',
      'cloak-client',
      'goquiet-client',
      'mos-tls-tunnel',
      'rabbit-tcp',
      'simple-tls',
    ];
  }

  List<String> getRecommendedMethods() {
    return [
      'aes-128-gcm',
      'aes-256-gcm',
      'chacha20-ietf-poly1305',
      'xchacha20-ietf-poly1305',
      '2022-blake3-aes-128-gcm',
      '2022-blake3-aes-256-gcm',
      '2022-blake3-chacha20-poly1305',
    ];
  }

  List<String> getSupportedMultiplexProtocols() {
    return ['smux', 'yamux', 'h2mux'];
  }
}