import 'package:logger/logger.dart';

import '../../models/vpn_configuration.dart';
import '../singbox_logger.dart';

/// Exception thrown when Trojan configuration conversion fails
class TrojanConfigurationException implements Exception {
  final String message;
  final Map<String, dynamic>? config;

  const TrojanConfigurationException(this.message, {this.config});

  @override
  String toString() => 'TrojanConfigurationException: $message';
}

/// Trojan Protocol Configuration Converter
class TrojanConverter {
  final Logger _logger;
  final SingboxLogger _singboxLogger;

  TrojanConverter({Logger? logger})
      : _logger = logger ?? Logger(),
        _singboxLogger = SingboxLogger.instance;

  /// Converts Trojan configuration to sing-box outbound format
  Map<String, dynamic> convertToOutbound(VpnConfiguration config) {
    if (config.protocol != VpnProtocol.trojan) {
      throw TrojanConfigurationException(
        'Configuration is not Trojan protocol: ${config.protocol.name}',
      );
    }

    final protocolConfig = config.protocolSpecificConfig;
    _validateTrojanConfig(protocolConfig);

    _logger.d('Converting Trojan configuration: ${config.name}');
    _singboxLogger.info(
      'TrojanConverter',
      'Converting Trojan configuration',
      metadata: {
        'configName': config.name,
        'serverAddress': config.serverAddress,
        'serverPort': config.serverPort,
        'transport': protocolConfig['transport'] ?? 'tcp',
      },
    );

    final outbound = <String, dynamic>{
      'type': 'trojan',
      'tag': 'proxy',
      'server': config.serverAddress,
      'server_port': config.serverPort,
      'password': protocolConfig['password'],
    };

    // Add transport configuration
    final transport = _createTransportConfig(protocolConfig);
    if (transport.isNotEmpty) {
      outbound['transport'] = transport;
    }

    // Add TLS configuration (Trojan typically uses TLS)
    final tls = _createTlsConfig(protocolConfig, config.serverAddress);
    if (tls.isNotEmpty) {
      outbound['tls'] = tls;
    } else {
      // Default TLS configuration for Trojan
      outbound['tls'] = <String, dynamic>{
        'enabled': true,
        'server_name': protocolConfig['serverName'] ?? config.serverAddress,
        'insecure': protocolConfig['allowInsecure'] ?? false,
      };
    }

    // Add multiplex configuration if specified
    if (protocolConfig.containsKey('multiplex') && protocolConfig['multiplex'] == true) {
      outbound['multiplex'] = _createMultiplexConfig(protocolConfig);
    }

    _logger.d('Trojan configuration converted successfully');
    return outbound;
  }

  void _validateTrojanConfig(Map<String, dynamic> config) {
    if (!config.containsKey('password') || config['password'] == null) {
      throw TrojanConfigurationException('Trojan password is required', config: config);
    }

    final password = config['password'] as String;
    if (password.isEmpty) {
      throw TrojanConfigurationException('Trojan password cannot be empty', config: config);
    }

    if (config.containsKey('transport') && config['transport'] != null) {
      final transport = config['transport'] as String;
      if (!_isValidTransport(transport)) {
        throw TrojanConfigurationException('Unsupported Trojan transport: $transport', config: config);
      }
    }

    if (config.containsKey('serverName') && config['serverName'] != null) {
      final serverName = config['serverName'] as String;
      if (serverName.isEmpty) {
        throw TrojanConfigurationException('Server name cannot be empty', config: config);
      }
    }
  }

  Map<String, dynamic> _createTransportConfig(Map<String, dynamic> config) {
    final transportType = config['transport'] as String? ?? 'tcp';

    switch (transportType.toLowerCase()) {
      case 'tcp':
        return _createTcpTransport(config);
      case 'ws':
      case 'websocket':
        return _createWebSocketTransport(config);
      default:
        _logger.w('Unsupported Trojan transport type: $transportType');
        return <String, dynamic>{};
    }
  }

  Map<String, dynamic> _createTcpTransport(Map<String, dynamic> config) {
    final transport = <String, dynamic>{'type': 'tcp'};

    // TCP transport for Trojan is typically plain
    // No additional configuration needed for basic TCP
    
    return transport;
  }

  Map<String, dynamic> _createWebSocketTransport(Map<String, dynamic> config) {
    final transport = <String, dynamic>{'type': 'ws'};

    if (config.containsKey('path')) {
      transport['path'] = config['path'];
    } else {
      transport['path'] = '/';
    }

    final headers = <String, dynamic>{};
    
    if (config.containsKey('host')) {
      headers['Host'] = config['host'];
    }

    if (config.containsKey('headers') && config['headers'] is Map) {
      headers.addAll(config['headers'] as Map<String, dynamic>);
    }

    if (headers.isNotEmpty) {
      transport['headers'] = headers;
    }

    if (config.containsKey('earlyDataHeaderName')) {
      transport['early_data_header_name'] = config['earlyDataHeaderName'];
    }

    return transport;
  }

  Map<String, dynamic> _createTlsConfig(Map<String, dynamic> config, String serverAddress) {
    final tls = <String, dynamic>{'enabled': true};

    if (config.containsKey('serverName')) {
      tls['server_name'] = config['serverName'];
    } else {
      tls['server_name'] = serverAddress;
    }

    if (config.containsKey('allowInsecure')) {
      tls['insecure'] = config['allowInsecure'];
    } else {
      tls['insecure'] = false;
    }

    if (config.containsKey('alpn')) {
      if (config['alpn'] is List) {
        tls['alpn'] = config['alpn'];
      } else {
        tls['alpn'] = [config['alpn']];
      }
    }

    if (config.containsKey('fingerprint')) {
      tls['utls'] = <String, dynamic>{
        'enabled': true,
        'fingerprint': config['fingerprint'],
      };
    }

    return tls;
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

  bool _isValidTransport(String transport) {
    const validTransports = ['tcp', 'ws', 'websocket'];
    return validTransports.contains(transport.toLowerCase());
  }

  List<String> getSupportedTransports() {
    return ['tcp', 'ws'];
  }

  List<String> getSupportedSecurityOptions() {
    return ['tls'];
  }

  List<String> getSupportedMultiplexProtocols() {
    return ['smux', 'yamux', 'h2mux'];
  }
}