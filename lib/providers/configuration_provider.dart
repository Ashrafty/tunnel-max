import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../models/vpn_configuration.dart';
import '../services/configuration_manager.dart';

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

/// Provider for the configuration manager instance
final configurationManagerProvider = Provider<ConfigurationManager>((ref) {
  return ConfigurationManager();
});

/// Provider for loading actual saved configurations
final savedConfigurationsProvider = FutureProvider<List<VpnConfiguration>>((ref) async {
  final configManager = ref.watch(configurationManagerProvider);
  try {
    return await configManager.loadConfigurations();
  } catch (e) {
    // If loading fails, return empty list
    return <VpnConfiguration>[];
  }
});

/// Provider for all configurations (combines saved and sample for development)
final allConfigurationsProvider = Provider<AsyncValue<List<VpnConfiguration>>>((ref) {
  final savedConfigs = ref.watch(savedConfigurationsProvider);
  
  return savedConfigs.when(
    data: (configs) {
      // If we have saved configurations, use them; otherwise use sample data for development
      if (configs.isNotEmpty) {
        return AsyncValue.data(configs);
      } else {
        // Return sample configurations for development when no saved configs exist
        final sampleConfigs = ref.watch(sampleConfigurationsProvider);
        return AsyncValue.data(sampleConfigs);
      }
    },
    loading: () => const AsyncValue.loading(),
    error: (error, stack) {
      // On error, fall back to sample configurations
      final sampleConfigs = ref.watch(sampleConfigurationsProvider);
      return AsyncValue.data(sampleConfigs);
    },
  );
});

/// Provider for the currently selected configuration
final selectedConfigurationProvider = StateProvider<VpnConfiguration?>((ref) {
  final configsAsync = ref.watch(allConfigurationsProvider);
  return configsAsync.when(
    data: (configs) => configs.isNotEmpty ? configs.first : null,
    loading: () => null,
    error: (_, __) => null,
  );
});

/// Provider to refresh configurations (used after import/add/delete operations)
final configurationRefreshProvider = StateProvider<int>((ref) => 0);

/// Provider that automatically refreshes when configurations change
final refreshableConfigurationsProvider = FutureProvider<List<VpnConfiguration>>((ref) async {
  // Watch the refresh trigger
  ref.watch(configurationRefreshProvider);
  
  final configManager = ref.watch(configurationManagerProvider);
  try {
    return await configManager.loadConfigurations();
  } catch (e) {
    return <VpnConfiguration>[];
  }
});