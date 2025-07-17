import 'package:logger/logger.dart';

import '../../models/vpn_configuration.dart';
import '../singbox_logger.dart';

/// Exception thrown when VMess configuration conversion fails
class VmessConfigurationException implements Exception {
  final String message;
  final Map<String, dynamic>? config;

  const VmessConfigurationException(this.message, {this.config});

  @override
  String toString() => 'VmessConfigurationException: $message';
}

/// VMess Protocol Configuration Converter
class VmessConverter {
  final Logger _logger;
  final SingboxLogger _singboxLogger;

  VmessConverter({Logger? logger})
      : _logger = logger ?? Logger(),
        _singboxLogger = SingboxLogger.instance;

  /// Converts VMess configuration to sing-box outbound format
  Map<String, dynamic> convertToOutbound(VpnConfiguration config) {
    if (config.protocol != VpnProtocol.vmess) {
      throw VmessConfigurationException(
        'Configuration is not VMess protocol: ${config.protocol.name}',
      );
    }

    final protocolConfig = config.protocolSpecificConfig;
    _validateVmessConfig(protocolConfig);

    _logger.d('Converting VMess configuration: ${config.name}');
    _singboxLogger.info(
      'VmessConverter',
      'Converting VMess configuration',
      metadata: {
        'configName': config.name,
        'serverAddress': config.serverAddress,
        'serverPort': config.serverPort,
        'transport': protocolConfig['transport'] ?? 'tcp',
        'security': protocolConfig['security'] ?? 'auto',
      },
    );

    final outbound = <String, dynamic>{
      'type': 'vmess',
      'tag': 'proxy',
      'server': config.serverAddress,
      'server_port': config.serverPort,
      'uuid': protocolConfig['uuid'],
    };

    // Add security method (encryption)
    if (protocolConfig.containsKey('security')) {
      outbound['security'] = protocolConfig['security'];
    } else {
      outbound['security'] = 'auto';
    }

    // Add alter ID (legacy VMess compatibility)
    if (protocolConfig.containsKey('alterId')) {
      final alterId = protocolConfig['alterId'];
      if (alterId is int) {
        outbound['alter_id'] = alterId;
      } else if (alterId is String) {
        outbound['alter_id'] = int.tryParse(alterId) ?? 0;
      }
    } else {
      outbound['alter_id'] = 0; // Default for AEAD
    }

    // Add global padding (if specified)
    if (protocolConfig.containsKey('globalPadding')) {
      outbound['global_padding'] = protocolConfig['globalPadding'];
    }

    // Add authenticated length (if specified)
    if (protocolConfig.containsKey('authenticatedLength')) {
      outbound['authenticated_length'] = protocolConfig['authenticatedLength'];
    }

    // Add transport configuration
    final transport = _createTransportConfig(protocolConfig);
    if (transport.isNotEmpty) {
      outbound['transport'] = transport;
    }

    // Add TLS configuration
    final tls = _createTlsConfig(protocolConfig, config.serverAddress);
    if (tls.isNotEmpty) {
      outbound['tls'] = tls;
    }

    _logger.d('VMess configuration converted successfully');
    return outbound;
  }

  void _validateVmessConfig(Map<String, dynamic> config) {
    if (!config.containsKey('uuid') || config['uuid'] == null) {
      throw VmessConfigurationException('VMess UUID is required', config: config);
    }

    final uuid = config['uuid'] as String;
    if (uuid.isEmpty) {
      throw VmessConfigurationException('VMess UUID cannot be empty', config: config);
    }

    if (!_isValidUuid(uuid)) {
      throw VmessConfigurationException('Invalid VMess UUID format: $uuid', config: config);
    }

    if (config.containsKey('security') && config['security'] != null) {
      final security = config['security'] as String;
      if (!_isValidSecurity(security)) {
        throw VmessConfigurationException('Invalid VMess security method: $security', config: config);
      }
    }

    if (config.containsKey('alterId') && config['alterId'] != null) {
      final alterId = config['alterId'];
      int? alterIdInt;
      
      if (alterId is int) {
        alterIdInt = alterId;
      } else if (alterId is String) {
        alterIdInt = int.tryParse(alterId);
      }
      
      if (alterIdInt == null || alterIdInt < 0 || alterIdInt > 65535) {
        throw VmessConfigurationException('Invalid VMess alter ID: $alterId', config: config);
      }
    }

    if (config.containsKey('transport') && config['transport'] != null) {
      final transport = config['transport'] as String;
      if (!_isValidTransport(transport)) {
        throw VmessConfigurationException('Unsupported VMess transport: $transport', config: config);
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
      case 'kcp':
        return _createKcpTransport(config);
      case 'quic':
        return _createQuicTransport(config);
      default:
        _logger.w('Unsupported VMess transport type: $transportType');
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

    if (config.containsKey('maxEarlyData')) {
      transport['max_early_data'] = config['maxEarlyData'];
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

    if (config.containsKey('idleTimeout')) {
      transport['idle_timeout'] = config['idleTimeout'];
    }

    if (config.containsKey('healthCheckTimeout')) {
      transport['health_check_timeout'] = config['healthCheckTimeout'];
    }

    if (config.containsKey('permitWithoutStream')) {
      transport['permit_without_stream'] = config['permitWithoutStream'];
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

    if (config.containsKey('idleTimeout')) {
      transport['idle_timeout'] = config['idleTimeout'];
    }

    if (config.containsKey('pingTimeout')) {
      transport['ping_timeout'] = config['pingTimeout'];
    }

    return transport;
  }

  Map<String, dynamic> _createKcpTransport(Map<String, dynamic> config) {
    final transport = <String, dynamic>{'type': 'kcp'};

    if (config.containsKey('mtu')) {
      transport['mtu'] = config['mtu'];
    }

    if (config.containsKey('tti')) {
      transport['tti'] = config['tti'];
    }

    if (config.containsKey('uplinkCapacity')) {
      transport['uplink_capacity'] = config['uplinkCapacity'];
    }

    if (config.containsKey('downlinkCapacity')) {
      transport['downlink_capacity'] = config['downlinkCapacity'];
    }

    if (config.containsKey('congestion')) {
      transport['congestion'] = config['congestion'];
    }

    if (config.containsKey('readBufferSize')) {
      transport['read_buffer_size'] = config['readBufferSize'];
    }

    if (config.containsKey('writeBufferSize')) {
      transport['write_buffer_size'] = config['writeBufferSize'];
    }

    if (config.containsKey('headerType')) {
      final header = <String, dynamic>{'type': config['headerType']};
      
      if (config.containsKey('seed')) {
        header['seed'] = config['seed'];
      }
      
      transport['header'] = header;
    }

    return transport;
  }

  Map<String, dynamic> _createQuicTransport(Map<String, dynamic> config) {
    final transport = <String, dynamic>{'type': 'quic'};

    if (config.containsKey('security')) {
      transport['security'] = config['security'];
    }

    if (config.containsKey('key')) {
      transport['key'] = config['key'];
    }

    if (config.containsKey('headerType')) {
      final header = <String, dynamic>{'type': config['headerType']};
      transport['header'] = header;
    }

    return transport;
  }

  Map<String, dynamic> _createTlsConfig(Map<String, dynamic> config, String serverAddress) {
    if (config.containsKey('tls') && config['tls'] == true ||
        config.containsKey('security') && config['security'] == 'tls') {
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

      if (config.containsKey('certificates')) {
        tls['certificate'] = config['certificates'];
      }

      if (config.containsKey('certificatePath')) {
        tls['certificate_path'] = config['certificatePath'];
      }

      return tls;
    }

    return <String, dynamic>{};
  }

  bool _isValidUuid(String uuid) {
    final uuidRegex = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');
    return uuidRegex.hasMatch(uuid);
  }

  bool _isValidSecurity(String security) {
    const validSecurityMethods = [
      'auto',
      'aes-128-gcm',
      'chacha20-poly1305',
      'none',
      'zero',
    ];
    return validSecurityMethods.contains(security.toLowerCase());
  }

  bool _isValidTransport(String transport) {
    const validTransports = ['tcp', 'ws', 'websocket', 'grpc', 'http', 'kcp', 'quic'];
    return validTransports.contains(transport.toLowerCase());
  }

  List<String> getSupportedTransports() {
    return ['tcp', 'ws', 'grpc', 'http', 'kcp', 'quic'];
  }

  List<String> getSupportedSecurityMethods() {
    return [
      'auto',
      'aes-128-gcm',
      'chacha20-poly1305',
      'none',
      'zero',
    ];
  }
}