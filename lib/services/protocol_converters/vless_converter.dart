import 'package:logger/logger.dart';

import '../../models/vpn_configuration.dart';
import '../singbox_logger.dart';

/// Exception thrown when VLESS configuration conversion fails
class VlessConfigurationException implements Exception {
  final String message;
  final Map<String, dynamic>? config;

  const VlessConfigurationException(this.message, {this.config});

  @override
  String toString() => 'VlessConfigurationException: $message';
}

/// VLESS Protocol Configuration Converter
class VlessConverter {
  final Logger _logger;
  final SingboxLogger _singboxLogger;

  VlessConverter({Logger? logger})
      : _logger = logger ?? Logger(),
        _singboxLogger = SingboxLogger.instance;

  /// Converts VLESS configuration to sing-box outbound format
  Map<String, dynamic> convertToOutbound(VpnConfiguration config) {
    if (config.protocol != VpnProtocol.vless) {
      throw VlessConfigurationException(
        'Configuration is not VLESS protocol: ${config.protocol.name}',
      );
    }

    final protocolConfig = config.protocolSpecificConfig;
    _validateVlessConfig(protocolConfig);

    _logger.d('Converting VLESS configuration: ${config.name}');
    _singboxLogger.info(
      'VlessConverter',
      'Converting VLESS configuration',
      metadata: {
        'configName': config.name,
        'serverAddress': config.serverAddress,
        'serverPort': config.serverPort,
        'transport': protocolConfig['transport'] ?? 'tcp',
      },
    );

    final outbound = <String, dynamic>{
      'type': 'vless',
      'tag': 'proxy',
      'server': config.serverAddress,
      'server_port': config.serverPort,
      'uuid': protocolConfig['uuid'],
    };

    // Add flow control for XTLS
    if (protocolConfig.containsKey('flow') && protocolConfig['flow'] != null) {
      outbound['flow'] = protocolConfig['flow'];
      _logger.d('Added VLESS flow control: ${protocolConfig['flow']}');
    }

    // Add transport configuration
    final transport = _createTransportConfig(protocolConfig);
    if (transport.isNotEmpty) {
      outbound['transport'] = transport;
    }

    // Add security configuration (TLS/Reality)
    final security = _createSecurityConfig(protocolConfig, config.serverAddress);
    if (security.isNotEmpty) {
      outbound.addAll(security);
    }

    _logger.d('VLESS configuration converted successfully');
    return outbound;
  }

  void _validateVlessConfig(Map<String, dynamic> config) {
    if (!config.containsKey('uuid') || config['uuid'] == null) {
      throw VlessConfigurationException('VLESS UUID is required', config: config);
    }

    final uuid = config['uuid'] as String;
    if (uuid.isEmpty) {
      throw VlessConfigurationException('VLESS UUID cannot be empty', config: config);
    }

    if (!_isValidUuid(uuid)) {
      throw VlessConfigurationException('Invalid VLESS UUID format: $uuid', config: config);
    }

    if (config.containsKey('flow') && config['flow'] != null) {
      final flow = config['flow'] as String;
      if (!_isValidFlow(flow)) {
        throw VlessConfigurationException('Invalid VLESS flow: $flow', config: config);
      }
    }

    if (config.containsKey('transport') && config['transport'] != null) {
      final transport = config['transport'] as String;
      if (!_isValidTransport(transport)) {
        throw VlessConfigurationException('Unsupported VLESS transport: $transport', config: config);
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
      case 'grpc':
        return _createGrpcTransport(config);
      case 'http':
        return _createHttpTransport(config);
      default:
        _logger.w('Unsupported VLESS transport type: $transportType');
        return <String, dynamic>{};
    }
  }

  Map<String, dynamic> _createTcpTransport(Map<String, dynamic> config) {
    final transport = <String, dynamic>{'type': 'tcp'};

    if (config.containsKey('headerType') && config['headerType'] == 'http') {
      final header = <String, dynamic>{'type': 'http'};

      if (config.containsKey('requestHeaders')) {
        header['request'] = config['requestHeaders'];
      }

      if (config.containsKey('responseHeaders')) {
        header['response'] = config['responseHeaders'];
      }

      transport['header'] = header;
    }

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

  Map<String, dynamic> _createGrpcTransport(Map<String, dynamic> config) {
    final transport = <String, dynamic>{'type': 'grpc'};

    if (config.containsKey('serviceName')) {
      transport['service_name'] = config['serviceName'];
    } else {
      transport['service_name'] = 'TunService';
    }

    if (config.containsKey('multiMode')) {
      transport['multi_mode'] = config['multiMode'];
    }

    return transport;
  }

  Map<String, dynamic> _createHttpTransport(Map<String, dynamic> config) {
    final transport = <String, dynamic>{'type': 'http'};

    if (config.containsKey('path')) {
      transport['path'] = config['path'];
    }

    if (config.containsKey('host')) {
      if (config['host'] is List) {
        transport['host'] = config['host'];
      } else {
        transport['host'] = [config['host']];
      }
    }

    if (config.containsKey('method')) {
      transport['method'] = config['method'];
    }

    if (config.containsKey('headers')) {
      transport['headers'] = config['headers'];
    }

    return transport;
  }

  Map<String, dynamic> _createSecurityConfig(Map<String, dynamic> config, String serverAddress) {
    if (config.containsKey('security') && config['security'] == 'reality') {
      return _createRealityConfig(config, serverAddress);
    }

    if (config.containsKey('security') && config['security'] == 'tls' ||
        config.containsKey('tls') && config['tls'] == true) {
      return <String, dynamic>{'tls': _createTlsConfig(config, serverAddress)};
    }

    return <String, dynamic>{};
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

  Map<String, dynamic> _createRealityConfig(Map<String, dynamic> config, String serverAddress) {
    final reality = <String, dynamic>{
      'enabled': true,
      'server_name': config['serverName'] ?? serverAddress,
    };

    if (config.containsKey('publicKey')) {
      reality['public_key'] = config['publicKey'];
    } else {
      throw VlessConfigurationException('Reality public key is required', config: config);
    }

    if (config.containsKey('shortId')) {
      reality['short_id'] = config['shortId'];
    }

    return <String, dynamic>{'reality': reality};
  }

  bool _isValidUuid(String uuid) {
    final uuidRegex = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');
    return uuidRegex.hasMatch(uuid);
  }

  bool _isValidFlow(String flow) {
    const validFlows = [
      'xtls-rprx-vision',
      'xtls-rprx-vision-udp443',
      'xtls-rprx-origin',
      'xtls-rprx-origin-udp443',
      'xtls-rprx-direct',
      'xtls-rprx-direct-udp443',
    ];
    return validFlows.contains(flow);
  }

  bool _isValidTransport(String transport) {
    const validTransports = ['tcp', 'ws', 'websocket', 'grpc', 'http'];
    return validTransports.contains(transport.toLowerCase());
  }

  List<String> getSupportedTransports() {
    return ['tcp', 'ws', 'grpc', 'http'];
  }

  List<String> getSupportedFlows() {
    return [
      'xtls-rprx-vision',
      'xtls-rprx-vision-udp443',
      'xtls-rprx-origin',
      'xtls-rprx-origin-udp443',
      'xtls-rprx-direct',
      'xtls-rprx-direct-udp443',
    ];
  }
}