import 'package:logger/logger.dart';

import '../../models/vpn_configuration.dart';
import '../singbox_logger.dart';

/// Exception thrown when Hysteria configuration conversion fails
class HysteriaConfigurationException implements Exception {
  final String message;
  final Map<String, dynamic>? config;

  const HysteriaConfigurationException(this.message, {this.config});

  @override
  String toString() => 'HysteriaConfigurationException: $message';
}

/// Hysteria Protocol Configuration Converter
class HysteriaConverter {
  final Logger _logger;
  final SingboxLogger _singboxLogger;

  HysteriaConverter({Logger? logger})
      : _logger = logger ?? Logger(),
        _singboxLogger = SingboxLogger.instance;

  /// Converts Hysteria configuration to sing-box outbound format
  Map<String, dynamic> convertToOutbound(VpnConfiguration config) {
    if (config.protocol != VpnProtocol.hysteria) {
      throw HysteriaConfigurationException(
        'Configuration is not Hysteria protocol: ${config.protocol.name}',
      );
    }

    final protocolConfig = config.protocolSpecificConfig;
    _validateHysteriaConfig(protocolConfig);

    _logger.d('Converting Hysteria configuration: ${config.name}');
    _singboxLogger.info(
      'HysteriaConverter',
      'Converting Hysteria configuration',
      metadata: {
        'configName': config.name,
        'serverAddress': config.serverAddress,
        'serverPort': config.serverPort,
        'transport': protocolConfig['transport'] ?? 'udp',
      },
    );

    final outbound = <String, dynamic>{
      'type': 'hysteria',
      'tag': 'proxy',
      'server': config.serverAddress,
      'server_port': config.serverPort,
    };

    // Add authentication
    if (protocolConfig.containsKey('auth')) {
      outbound['auth'] = protocolConfig['auth'];
    } else if (protocolConfig.containsKey('authString')) {
      outbound['auth_str'] = protocolConfig['authString'];
    }

    // Add OBFS configuration if specified
    if (protocolConfig.containsKey('obfs')) {
      outbound['obfs'] = protocolConfig['obfs'];
    }

    // Add bandwidth configuration
    _addBandwidthConfig(outbound, protocolConfig);

    // Add transport configuration
    final transport = _createTransportConfig(protocolConfig);
    if (transport.isNotEmpty) {
      outbound.addAll(transport);
    }

    // Add TLS configuration
    final tls = _createTlsConfig(protocolConfig, config.serverAddress);
    if (tls.isNotEmpty) {
      outbound['tls'] = tls;
    }

    // Add additional Hysteria-specific options
    _addHysteriaSpecificOptions(outbound, protocolConfig);

    _logger.d('Hysteria configuration converted successfully');
    return outbound;
  }

  void _validateHysteriaConfig(Map<String, dynamic> config) {
    // Validate authentication
    if (!config.containsKey('auth') && !config.containsKey('authString')) {
      throw HysteriaConfigurationException(
        'Hysteria authentication (auth or authString) is required',
        config: config,
      );
    }

    // Validate transport if specified
    if (config.containsKey('transport') && config['transport'] != null) {
      final transport = config['transport'] as String;
      if (!_isValidTransport(transport)) {
        throw HysteriaConfigurationException(
          'Unsupported Hysteria transport: $transport',
          config: config,
        );
      }
    }

    // Validate bandwidth settings
    if (config.containsKey('upMbps') && config['upMbps'] != null) {
      final upMbps = config['upMbps'];
      if (upMbps is! num || upMbps <= 0) {
        throw HysteriaConfigurationException(
          'Invalid upMbps value: must be a positive number',
          config: config,
        );
      }
    }

    if (config.containsKey('downMbps') && config['downMbps'] != null) {
      final downMbps = config['downMbps'];
      if (downMbps is! num || downMbps <= 0) {
        throw HysteriaConfigurationException(
          'Invalid downMbps value: must be a positive number',
          config: config,
        );
      }
    }

    // Validate OBFS if specified
    if (config.containsKey('obfs') && config['obfs'] != null) {
      final obfs = config['obfs'] as String;
      if (obfs.isEmpty) {
        throw HysteriaConfigurationException(
          'OBFS password cannot be empty',
          config: config,
        );
      }
    }
  }

  void _addBandwidthConfig(Map<String, dynamic> outbound, Map<String, dynamic> config) {
    if (config.containsKey('upMbps')) {
      outbound['up_mbps'] = config['upMbps'];
    }

    if (config.containsKey('downMbps')) {
      outbound['down_mbps'] = config['downMbps'];
    }

    // Add receive window configuration
    if (config.containsKey('recvWindowConn')) {
      outbound['recv_window_conn'] = config['recvWindowConn'];
    }

    if (config.containsKey('recvWindow')) {
      outbound['recv_window'] = config['recvWindow'];
    }

    // Add disable MTU discovery option
    if (config.containsKey('disableMtuDiscovery')) {
      outbound['disable_mtu_discovery'] = config['disableMtuDiscovery'];
    }
  }

  Map<String, dynamic> _createTransportConfig(Map<String, dynamic> config) {
    final transportType = config['transport'] as String? ?? 'udp';
    final transportConfig = <String, dynamic>{};

    switch (transportType.toLowerCase()) {
      case 'udp':
        // UDP is the default transport for Hysteria, no additional config needed
        break;
      case 'tcp':
        // TCP transport configuration
        transportConfig['network'] = 'tcp';
        break;
      case 'ws':
      case 'websocket':
        // WebSocket transport configuration
        transportConfig['network'] = 'tcp';
        if (config.containsKey('wsPath')) {
          transportConfig['ws_path'] = config['wsPath'];
        }
        if (config.containsKey('wsHeaders')) {
          transportConfig['ws_headers'] = config['wsHeaders'];
        }
        break;
      case 'grpc':
        // gRPC transport configuration
        transportConfig['network'] = 'tcp';
        if (config.containsKey('grpcServiceName')) {
          transportConfig['grpc_service_name'] = config['grpcServiceName'];
        }
        break;
      default:
        _logger.w('Unsupported Hysteria transport type: $transportType');
    }

    return transportConfig;
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
    } else {
      // Default ALPN for Hysteria
      tls['alpn'] = ['h3'];
    }

    if (config.containsKey('fingerprint')) {
      tls['utls'] = <String, dynamic>{
        'enabled': true,
        'fingerprint': config['fingerprint'],
      };
    }

    return tls;
  }

  void _addHysteriaSpecificOptions(Map<String, dynamic> outbound, Map<String, dynamic> config) {
    // Add hop interval for port hopping
    if (config.containsKey('hopInterval')) {
      outbound['hop_interval'] = config['hopInterval'];
    }

    // Add congestion control algorithm
    if (config.containsKey('congestionControl')) {
      outbound['congestion_control'] = config['congestionControl'];
    }

    // Add fast open option
    if (config.containsKey('fastOpen')) {
      outbound['fast_open'] = config['fastOpen'];
    }

    // Add lazy start option
    if (config.containsKey('lazyStart')) {
      outbound['lazy_start'] = config['lazyStart'];
    }

    // Add heartbeat interval
    if (config.containsKey('heartbeat')) {
      outbound['heartbeat'] = config['heartbeat'];
    }
  }

  bool _isValidTransport(String transport) {
    const validTransports = ['udp', 'tcp', 'ws', 'websocket', 'grpc'];
    return validTransports.contains(transport.toLowerCase());
  }

  List<String> getSupportedTransports() {
    return ['udp', 'tcp', 'ws', 'grpc'];
  }

  List<String> getSupportedCongestionControls() {
    return ['cubic', 'newreno', 'bbr'];
  }

  List<String> getRecommendedAlpn() {
    return ['h3', 'h2', 'http/1.1'];
  }

  Map<String, dynamic> getDefaultBandwidthSettings() {
    return {
      'upMbps': 10,
      'downMbps': 50,
      'recvWindowConn': 15728640, // 15MB
      'recvWindow': 67108864, // 64MB
    };
  }
}