import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../models/vpn_configuration.dart';

/// Provider for sample VPN configurations for development and testing
final sampleConfigurationsProvider = Provider<List<VpnConfiguration>>((ref) {
  const uuid = Uuid();
  final now = DateTime.now();

  return [
    VpnConfiguration(
      id: uuid.v4(),
      name: 'US East Server',
      serverAddress: 'us-east.example.com',
      serverPort: 443,
      protocol: VpnProtocol.shadowsocks,
      authMethod: AuthenticationMethod.password,
      protocolSpecificConfig: {
        'method': 'aes-256-gcm',
        'password': 'sample-password',
      },
      autoConnect: false,
      createdAt: now.subtract(const Duration(days: 7)),
      lastUsed: now.subtract(const Duration(hours: 2)),
    ),
    VpnConfiguration(
      id: uuid.v4(),
      name: 'EU West Server',
      serverAddress: 'eu-west.example.com',
      serverPort: 8080,
      protocol: VpnProtocol.vmess,
      authMethod: AuthenticationMethod.token,
      protocolSpecificConfig: {
        'uuid': uuid.v4(),
        'alterId': 0,
        'security': 'auto',
      },
      autoConnect: false,
      createdAt: now.subtract(const Duration(days: 3)),
    ),
    VpnConfiguration(
      id: uuid.v4(),
      name: 'Asia Pacific Server',
      serverAddress: 'ap-south.example.com',
      serverPort: 1080,
      protocol: VpnProtocol.trojan,
      authMethod: AuthenticationMethod.password,
      protocolSpecificConfig: {
        'password': 'trojan-password',
        'sni': 'ap-south.example.com',
      },
      autoConnect: true,
      createdAt: now.subtract(const Duration(days: 1)),
    ),
  ];
});

/// Provider for the currently selected configuration
final selectedConfigurationProvider = StateProvider<VpnConfiguration?>((ref) {
  final configs = ref.watch(sampleConfigurationsProvider);
  return configs.isNotEmpty ? configs.first : null;
});