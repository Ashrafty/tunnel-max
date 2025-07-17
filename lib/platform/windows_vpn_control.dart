import 'dart:async';
import 'package:flutter/services.dart';
import '../interfaces/vpn_control_interface.dart';
import '../models/vpn_configuration.dart';
import '../models/vpn_status.dart';
import '../models/network_stats.dart';

/// Windows-specific implementation of VPN control interface
/// 
/// This class communicates with the native Windows VPN plugin through
/// platform channels to provide VPN functionality on Windows.
class WindowsVpnControl implements VpnControlInterface {
  static const MethodChannel _channel = MethodChannel('vpn_control');
  static const EventChannel _statusChannel = EventChannel('vpn_status');
  
  StreamController<VpnStatus>? _statusController;
  StreamSubscription? _statusSubscription;

  WindowsVpnControl() {
    _initializeStatusStream();
  }

  void _initializeStatusStream() {
    _statusController = StreamController<VpnStatus>.broadcast();
    
    // Listen to native status updates
    _statusSubscription = _statusChannel.receiveBroadcastStream().listen(
      (dynamic event) {
        if (event is Map<String, dynamic>) {
          try {
            final status = VpnStatus.fromJson(Map<String, dynamic>.from(event));
            _statusController?.add(status);
          } catch (e) {
            // Handle parsing errors gracefully
            _statusController?.add(VpnStatus.error(error: 'Status parsing error: $e'));
          }
        }
      },
      onError: (error) {
        _statusController?.add(VpnStatus.error(error: 'Status stream error: $error'));
      },
    );
  }

  @override
  Future<bool> connect(VpnConfiguration config) async {
    try {
      // Generate singbox configuration
      final singboxConfig = _generateSingboxConfig(config);
      
      final result = await _channel.invokeMethod('connect', {
        'config': config.toJson(),
        'singboxConfig': singboxConfig,
      });
      return result == true;
    } on PlatformException catch (e) {
      throw VpnException(
        e.message ?? 'Connection failed',
        code: e.code,
        details: e.details,
      );
    } catch (e) {
      throw VpnException('Unexpected error during connection: $e');
    }
  }

  @override
  Future<bool> disconnect() async {
    try {
      final result = await _channel.invokeMethod('disconnect');
      return result == true;
    } on PlatformException catch (e) {
      throw VpnException(
        e.message ?? 'Disconnection failed',
        code: e.code,
        details: e.details,
      );
    } catch (e) {
      throw VpnException('Unexpected error during disconnection: $e');
    }
  }

  @override
  Future<VpnStatus> getStatus() async {
    try {
      final result = await _channel.invokeMethod('getStatus');
      if (result is Map<String, dynamic>) {
        return VpnStatus.fromJson(result);
      }
      return VpnStatus.disconnected();
    } on PlatformException catch (e) {
      throw VpnException(
        e.message ?? 'Failed to get status',
        code: e.code,
        details: e.details,
      );
    } catch (e) {
      throw VpnException('Unexpected error getting status: $e');
    }
  }

  @override
  Stream<VpnStatus> statusStream() {
    return _statusController?.stream ?? Stream.empty();
  }

  @override
  Future<NetworkStats?> getNetworkStats() async {
    try {
      final result = await _channel.invokeMethod('getNetworkStats');
      if (result is Map<String, dynamic>) {
        return NetworkStats.fromJson(result);
      }
      return null;
    } on PlatformException catch (e) {
      throw VpnException(
        e.message ?? 'Failed to get network stats',
        code: e.code,
        details: e.details,
      );
    } catch (e) {
      throw VpnException('Unexpected error getting network stats: $e');
    }
  }

  @override
  Future<bool> hasVpnPermission() async {
    try {
      final result = await _channel.invokeMethod('hasVpnPermission');
      return result == true;
    } on PlatformException catch (e) {
      throw VpnException(
        e.message ?? 'Failed to check VPN permission',
        code: e.code,
        details: e.details,
      );
    } catch (e) {
      throw VpnException('Unexpected error checking VPN permission: $e');
    }
  }

  @override
  Future<bool> requestVpnPermission() async {
    try {
      final result = await _channel.invokeMethod('requestVpnPermission');
      return result == true;
    } on PlatformException catch (e) {
      throw VpnException(
        e.message ?? 'Failed to request VPN permission',
        code: e.code,
        details: e.details,
      );
    } catch (e) {
      throw VpnException('Unexpected error requesting VPN permission: $e');
    }
  }

  /// Generates singbox configuration JSON from VPN configuration
  Map<String, dynamic> _generateSingboxConfig(VpnConfiguration config) {
    final singboxConfig = {
      'log': {
        'level': 'info',
        'timestamp': true,
      },
      'dns': {
        'servers': [
          {
            'tag': 'cloudflare',
            'address': '1.1.1.1',
            'strategy': 'prefer_ipv4',
          },
          {
            'tag': 'google',
            'address': '8.8.8.8',
            'strategy': 'prefer_ipv4',
          },
        ],
        'rules': [
          {
            'outbound': ['any'],
            'server': 'cloudflare',
          },
        ],
        'final': 'google',
        'strategy': 'prefer_ipv4',
      },
      'inbounds': [
        {
          'type': 'tun',
          'tag': 'tun-in',
          'interface_name': 'tun0',
          'inet4_address': '172.19.0.1/30',
          'mtu': 9000,
          'auto_route': true,
          'strict_route': true,
          'stack': 'system',
          'sniff': true,
          'sniff_override_destination': true,
        },
      ],
      'outbounds': [
        _generateOutboundConfig(config),
        {
          'type': 'direct',
          'tag': 'direct',
        },
        {
          'type': 'block',
          'tag': 'block',
        },
      ],
      'route': {
        'rules': [
          {
            'inbound': ['tun-in'],
            'outbound': 'proxy',
          },
        ],
        'final': 'proxy',
        'auto_detect_interface': true,
      },
    };

    return singboxConfig;
  }

  /// Generates outbound configuration based on VPN protocol
  Map<String, dynamic> _generateOutboundConfig(VpnConfiguration config) {
    final baseConfig = {
      'tag': 'proxy',
      'server': config.serverAddress,
      'server_port': config.serverPort,
    };

    switch (config.protocol) {
      case VpnProtocol.shadowsocks:
        return {
          ...baseConfig,
          'type': 'shadowsocks',
          'method': config.protocolSpecificConfig['method'] ?? 'aes-256-gcm',
          'password': config.protocolSpecificConfig['password'] ?? '',
        };

      case VpnProtocol.vmess:
        return {
          ...baseConfig,
          'type': 'vmess',
          'uuid': config.protocolSpecificConfig['uuid'] ?? '',
          'security': config.protocolSpecificConfig['security'] ?? 'auto',
          'alter_id': config.protocolSpecificConfig['alterId'] ?? 0,
          'transport': {
            'type': 'ws',
            'path': config.protocolSpecificConfig['path'] ?? '/',
            'headers': config.protocolSpecificConfig['headers'] ?? {},
          },
        };

      case VpnProtocol.trojan:
        return {
          ...baseConfig,
          'type': 'trojan',
          'password': config.protocolSpecificConfig['password'] ?? '',
          'tls': {
            'enabled': true,
            'server_name': config.protocolSpecificConfig['sni'] ?? config.serverAddress,
            'insecure': config.protocolSpecificConfig['allowInsecure'] ?? false,
          },
        };

      case VpnProtocol.vless:
        return {
          ...baseConfig,
          'type': 'vless',
          'uuid': config.protocolSpecificConfig['uuid'] ?? '',
          'flow': config.protocolSpecificConfig['flow'] ?? '',
          'transport': {
            'type': config.protocolSpecificConfig['network'] ?? 'tcp',
            'path': config.protocolSpecificConfig['path'] ?? '/',
          },
          'tls': {
            'enabled': config.protocolSpecificConfig['tls'] ?? false,
            'server_name': config.protocolSpecificConfig['sni'] ?? config.serverAddress,
          },
        };

      case VpnProtocol.hysteria2:
        return {
          ...baseConfig,
          'type': 'hysteria2',
          'password': config.protocolSpecificConfig['password'] ?? '',
          'tls': {
            'enabled': true,
            'server_name': config.protocolSpecificConfig['sni'] ?? config.serverAddress,
            'insecure': config.protocolSpecificConfig['allowInsecure'] ?? false,
          },
        };

      case VpnProtocol.tuic:
        return {
          ...baseConfig,
          'type': 'tuic',
          'uuid': config.protocolSpecificConfig['uuid'] ?? '',
          'password': config.protocolSpecificConfig['password'] ?? '',
          'congestion_control': config.protocolSpecificConfig['congestionControl'] ?? 'cubic',
          'tls': {
            'enabled': true,
            'server_name': config.protocolSpecificConfig['sni'] ?? config.serverAddress,
          },
        };

      case VpnProtocol.hysteria:
        return {
          ...baseConfig,
          'type': 'hysteria',
          'auth_str': config.protocolSpecificConfig['auth'] ?? '',
          'up_mbps': config.protocolSpecificConfig['upMbps'] ?? 10,
          'down_mbps': config.protocolSpecificConfig['downMbps'] ?? 50,
          'tls': {
            'enabled': true,
            'server_name': config.protocolSpecificConfig['sni'] ?? config.serverAddress,
            'insecure': config.protocolSpecificConfig['allowInsecure'] ?? false,
          },
        };

      case VpnProtocol.wireguard:
        return {
          ...baseConfig,
          'type': 'wireguard',
          'private_key': config.protocolSpecificConfig['privateKey'] ?? '',
          'peer_public_key': config.protocolSpecificConfig['publicKey'] ?? '',
          'pre_shared_key': config.protocolSpecificConfig['preSharedKey'] ?? '',
          'local_address': config.protocolSpecificConfig['localAddress'] ?? ['10.0.0.2/32'],
        };
    }
  }

  /// Dispose resources when no longer needed
  void dispose() {
    _statusSubscription?.cancel();
    _statusController?.close();
  }
}