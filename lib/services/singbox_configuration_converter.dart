import 'dart:convert';
import '../models/vpn_configuration.dart';

/// Exception thrown when configuration conversion fails
class ConfigurationConversionException implements Exception {
  final String message;
  final String? protocol;
  final String? field;

  const ConfigurationConversionException(
    this.message, {
    this.protocol,
    this.field,
  });

  @override
  String toString() {
    return 'ConfigurationConversionException: $message${protocol != null ? ' (protocol: $protocol)' : ''}${field != null ? ' (field: $field)' : ''}';
  }
}

/// Converts VPN configurations to sing-box format for actual connections
class SingboxConfigurationConverter {
  
  /// Converts a VPN configuration to sing-box JSON format
  Map<String, dynamic> convertToSingboxConfig(VpnConfiguration config) {
    switch (config.protocol) {
      case VpnProtocol.vless:
        return _convertVlessConfig(config);
      case VpnProtocol.vmess:
        return _convertVmessConfig(config);
      case VpnProtocol.trojan:
        return _convertTrojanConfig(config);
      case VpnProtocol.shadowsocks:
        return _convertShadowsocksConfig(config);
      case VpnProtocol.hysteria:
        return _convertHysteriaConfig(config);
      case VpnProtocol.hysteria2:
        return _convertHysteria2Config(config);
      default:
        throw ConfigurationConversionException(
          'Unsupported protocol: ${config.protocol.name}',
          protocol: config.protocol.name,
        );
    }
  }

  /// Creates a complete sing-box configuration with inbounds and outbounds
  Map<String, dynamic> createFullSingboxConfig(VpnConfiguration config) {
    final outbound = convertToSingboxConfig(config);
    
    return {
      "log": {
        "level": "info",
        "timestamp": true
      },
      "dns": {
        "servers": [
          {
            "tag": "google",
            "address": "8.8.8.8"
          },
          {
            "tag": "cloudflare", 
            "address": "1.1.1.1"
          }
        ],
        "rules": [],
        "final": "google"
      },
      "inbounds": [
        {
          "type": "tun",
          "tag": "tun-in",
          "interface_name": "tun0",
          "inet4_address": "172.19.0.1/30",
          "mtu": 9000,
          "auto_route": true,
          "strict_route": true,
          "stack": "system",
          "sniff": true,
          "sniff_override_destination": true
        }
      ],
      "outbounds": [
        outbound,
        {
          "type": "direct",
          "tag": "direct"
        },
        {
          "type": "block",
          "tag": "block"
        },
        {
          "type": "dns",
          "tag": "dns-out"
        }
      ],
      "route": {
        "rules": [
          {
            "protocol": "dns",
            "outbound": "dns-out"
          },
          {
            "ip_is_private": true,
            "outbound": "direct"
          }
        ],
        "final": "proxy",
        "auto_detect_interface": true
      }
    };
  }

  /// Convert VLESS configuration
  Map<String, dynamic> _convertVlessConfig(VpnConfiguration config) {
    final protocolConfig = config.protocolSpecificConfig;
    
    final uuid = protocolConfig['uuid'] as String?;
    if (uuid == null || uuid.isEmpty) {
      throw ConfigurationConversionException(
        'VLESS UUID is required',
        protocol: 'vless',
        field: 'uuid',
      );
    }

    final baseConfig = {
      "type": "vless",
      "tag": "proxy",
      "server": config.serverAddress,
      "server_port": config.serverPort,
      "uuid": uuid,
    };

    // Add flow if specified
    final flow = protocolConfig['flow'] as String?;
    if (flow != null && flow.isNotEmpty) {
      baseConfig["flow"] = flow;
    }

    // Add transport configuration
    final network = protocolConfig['network'] as String? ?? 'tcp';
    if (network != 'tcp') {
      baseConfig["transport"] = _createTransportConfig(network, protocolConfig);
    }

    // Add TLS configuration
    final tls = protocolConfig['tls'] as bool? ?? false;
    if (tls) {
      baseConfig["tls"] = {
        "enabled": true,
        "server_name": protocolConfig['sni'] as String? ?? config.serverAddress,
        "insecure": protocolConfig['allowInsecure'] as bool? ?? false,
      };
    }

    return baseConfig;
  }

  /// Convert VMess configuration
  Map<String, dynamic> _convertVmessConfig(VpnConfiguration config) {
    final protocolConfig = config.protocolSpecificConfig;
    
    final uuid = protocolConfig['uuid'] as String?;
    if (uuid == null || uuid.isEmpty) {
      throw ConfigurationConversionException(
        'VMess UUID is required',
        protocol: 'vmess',
        field: 'uuid',
      );
    }

    final baseConfig = {
      "type": "vmess",
      "tag": "proxy",
      "server": config.serverAddress,
      "server_port": config.serverPort,
      "uuid": uuid,
      "security": protocolConfig['security'] as String? ?? 'auto',
      "alter_id": protocolConfig['alterId'] as int? ?? 0,
    };

    // Add transport configuration
    final network = protocolConfig['network'] as String? ?? 'tcp';
    if (network != 'tcp') {
      baseConfig["transport"] = _createTransportConfig(network, protocolConfig);
    }

    // Add TLS configuration
    final tls = protocolConfig['tls'] as bool? ?? false;
    if (tls) {
      baseConfig["tls"] = {
        "enabled": true,
        "server_name": protocolConfig['sni'] as String? ?? config.serverAddress,
        "insecure": protocolConfig['allowInsecure'] as bool? ?? false,
      };
    }

    return baseConfig;
  }

  /// Convert Trojan configuration
  Map<String, dynamic> _convertTrojanConfig(VpnConfiguration config) {
    final protocolConfig = config.protocolSpecificConfig;
    
    final password = protocolConfig['password'] as String?;
    if (password == null || password.isEmpty) {
      throw ConfigurationConversionException(
        'Trojan password is required',
        protocol: 'trojan',
        field: 'password',
      );
    }

    final baseConfig = {
      "type": "trojan",
      "tag": "proxy",
      "server": config.serverAddress,
      "server_port": config.serverPort,
      "password": password,
    };

    // Add transport configuration
    final network = protocolConfig['network'] as String? ?? 'tcp';
    if (network != 'tcp') {
      baseConfig["transport"] = _createTransportConfig(network, protocolConfig);
    }

    // Trojan always uses TLS
    baseConfig["tls"] = {
      "enabled": true,
      "server_name": protocolConfig['sni'] as String? ?? config.serverAddress,
      "insecure": protocolConfig['allowInsecure'] as bool? ?? false,
    };

    return baseConfig;
  }

  /// Convert Shadowsocks configuration
  Map<String, dynamic> _convertShadowsocksConfig(VpnConfiguration config) {
    final protocolConfig = config.protocolSpecificConfig;
    
    final method = protocolConfig['method'] as String?;
    final password = protocolConfig['password'] as String?;
    
    if (method == null || method.isEmpty) {
      throw ConfigurationConversionException(
        'Shadowsocks method is required',
        protocol: 'shadowsocks',
        field: 'method',
      );
    }
    
    if (password == null || password.isEmpty) {
      throw ConfigurationConversionException(
        'Shadowsocks password is required',
        protocol: 'shadowsocks',
        field: 'password',
      );
    }

    return {
      "type": "shadowsocks",
      "tag": "proxy",
      "server": config.serverAddress,
      "server_port": config.serverPort,
      "method": method,
      "password": password,
    };
  }

  /// Convert Hysteria configuration
  Map<String, dynamic> _convertHysteriaConfig(VpnConfiguration config) {
    final protocolConfig = config.protocolSpecificConfig;
    
    final auth = protocolConfig['auth'] as String?;
    if (auth == null || auth.isEmpty) {
      throw ConfigurationConversionException(
        'Hysteria auth is required',
        protocol: 'hysteria',
        field: 'auth',
      );
    }

    final baseConfig = {
      "type": "hysteria",
      "tag": "proxy",
      "server": config.serverAddress,
      "server_port": config.serverPort,
      "auth_str": auth,
    };

    // Add TLS configuration
    baseConfig["tls"] = {
      "enabled": true,
      "server_name": protocolConfig['sni'] as String? ?? config.serverAddress,
      "insecure": protocolConfig['allowInsecure'] as bool? ?? false,
    };

    return baseConfig;
  }

  /// Convert Hysteria2 configuration
  Map<String, dynamic> _convertHysteria2Config(VpnConfiguration config) {
    final protocolConfig = config.protocolSpecificConfig;
    
    final password = protocolConfig['password'] as String?;
    if (password == null || password.isEmpty) {
      throw ConfigurationConversionException(
        'Hysteria2 password is required',
        protocol: 'hysteria2',
        field: 'password',
      );
    }

    final baseConfig = {
      "type": "hysteria2",
      "tag": "proxy",
      "server": config.serverAddress,
      "server_port": config.serverPort,
      "password": password,
    };

    // Add TLS configuration
    baseConfig["tls"] = {
      "enabled": true,
      "server_name": protocolConfig['sni'] as String? ?? config.serverAddress,
      "insecure": protocolConfig['allowInsecure'] as bool? ?? false,
    };

    return baseConfig;
  }

  /// Create transport configuration based on network type
  Map<String, dynamic> _createTransportConfig(String network, Map<String, dynamic> protocolConfig) {
    switch (network.toLowerCase()) {
      case 'ws':
      case 'websocket':
        return {
          "type": "ws",
          "path": protocolConfig['path'] as String? ?? '/',
          "headers": protocolConfig['host'] != null 
            ? {"Host": protocolConfig['host'] as String}
            : {},
        };
      
      case 'grpc':
        return {
          "type": "grpc",
          "service_name": protocolConfig['serviceName'] as String? ?? 'GunService',
        };
      
      case 'http':
        return {
          "type": "http",
          "host": [protocolConfig['host'] as String? ?? ''],
          "path": protocolConfig['path'] as String? ?? '/',
        };
      
      default:
        return {
          "type": "tcp",
        };
    }
  }

  /// Validates if a protocol is supported for conversion
  bool isProtocolSupported(VpnProtocol protocol) {
    return [
      VpnProtocol.vless,
      VpnProtocol.vmess,
      VpnProtocol.trojan,
      VpnProtocol.shadowsocks,
      VpnProtocol.hysteria,
      VpnProtocol.hysteria2,
    ].contains(protocol);
  }

  /// Gets list of supported protocols
  List<VpnProtocol> getSupportedProtocols() {
    return [
      VpnProtocol.vless,
      VpnProtocol.vmess,
      VpnProtocol.trojan,
      VpnProtocol.shadowsocks,
      VpnProtocol.hysteria,
      VpnProtocol.hysteria2,
    ];
  }

  /// Validates a sing-box configuration
  bool validateSingboxConfig(Map<String, dynamic> config) {
    try {
      // Check required top-level fields
      if (!config.containsKey('outbounds') || config['outbounds'] is! List) {
        return false;
      }

      final outbounds = config['outbounds'] as List;
      if (outbounds.isEmpty) {
        return false;
      }

      // Validate first outbound (proxy)
      final firstOutbound = outbounds[0] as Map<String, dynamic>;
      if (!firstOutbound.containsKey('type') || 
          !firstOutbound.containsKey('server') ||
          !firstOutbound.containsKey('server_port')) {
        return false;
      }

      return true;
    } catch (e) {
      return false;
    }
  }
}