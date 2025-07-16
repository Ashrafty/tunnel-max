import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';

import '../services/network_resilience_service.dart';
import '../services/kill_switch_service.dart';
import '../services/network_transition_handler.dart';
import '../services/network_resilience_coordinator.dart';
import '../platform/vpn_control_platform.dart';
import 'vpn_provider.dart';

/// Provider for the network resilience coordinator
final networkResilienceCoordinatorProvider = Provider<NetworkResilienceCoordinator>((ref) {
  final vpnServiceManager = ref.watch(vpnServiceManagerProvider);
  final logger = Logger();
  
  // Create individual services
  final vpnControl = VpnControlPlatform();
  final resilienceService = NetworkResilienceService(
    vpnServiceManager: vpnServiceManager,
    vpnControl: vpnControl,
    config: const NetworkResilienceConfig(),
    logger: logger,
  );
  
  final killSwitchService = KillSwitchService(logger: logger);
  
  final transitionHandler = NetworkTransitionHandler(
    vpnServiceManager: vpnServiceManager,
    resilienceService: resilienceService,
    logger: logger,
  );
  
  // Create coordinator
  final coordinator = NetworkResilienceCoordinator(
    vpnServiceManager: vpnServiceManager,
    resilienceService: resilienceService,
    killSwitchService: killSwitchService,
    transitionHandler: transitionHandler,
    logger: logger,
  );
  
  // Initialize the coordinator when the provider is created
  coordinator.initialize().catchError((error) {
    logger.e('Failed to initialize network resilience coordinator: $error');
  });
  
  // Dispose when the provider is disposed
  ref.onDispose(() {
    coordinator.dispose().catchError((error) {
      logger.e('Failed to dispose network resilience coordinator: $error');
    });
  });
  
  return coordinator;
});

/// Provider for network resilience status
final networkResilienceStatusProvider = StreamProvider<NetworkResilienceStatus>((ref) {
  final coordinator = ref.watch(networkResilienceCoordinatorProvider);
  return coordinator.resilienceStatusStream;
});

/// Provider for kill switch status
final killSwitchStatusProvider = StreamProvider<KillSwitchStatus>((ref) {
  final coordinator = ref.watch(networkResilienceCoordinatorProvider);
  return coordinator.killSwitchStatusStream;
});

/// Provider for auto-reconnection enabled state
final autoReconnectionEnabledProvider = StateProvider<bool>((ref) => true);

/// Provider for kill switch enabled state
final killSwitchEnabledProvider = StateProvider<bool>((ref) => true);

/// Provider for reconnection configuration
final reconnectionConfigProvider = StateProvider<ReconnectionConfig>((ref) {
  return const ReconnectionConfig();
});

/// Configuration for reconnection behavior
class ReconnectionConfig {
  final int maxAttempts;
  final Duration baseDelay;
  final Duration maxDelay;
  final double backoffMultiplier;

  const ReconnectionConfig({
    this.maxAttempts = 10,
    this.baseDelay = const Duration(seconds: 2),
    this.maxDelay = const Duration(minutes: 5),
    this.backoffMultiplier = 1.5,
  });

  ReconnectionConfig copyWith({
    int? maxAttempts,
    Duration? baseDelay,
    Duration? maxDelay,
    double? backoffMultiplier,
  }) {
    return ReconnectionConfig(
      maxAttempts: maxAttempts ?? this.maxAttempts,
      baseDelay: baseDelay ?? this.baseDelay,
      maxDelay: maxDelay ?? this.maxDelay,
      backoffMultiplier: backoffMultiplier ?? this.backoffMultiplier,
    );
  }
}