import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';

import '../models/vpn_status.dart';
import '../models/vpn_configuration.dart';
import '../models/network_stats.dart';
import '../services/vpn_service_manager.dart';
import '../services/configuration_manager.dart';
import '../services/connection_monitor.dart';
import '../platform/vpn_control_platform.dart';

/// Provider for VPN service manager
final vpnServiceManagerProvider = Provider<VpnServiceManager>((ref) {
  final vpnControl = VpnControlPlatform();
  final configManager = ConfigurationManager();
  final logger = Logger();
  
  return VpnServiceManager(
    vpnControl: vpnControl,
    configurationManager: configManager,
    logger: logger,
  );
});

/// Provider for connection monitor
final connectionMonitorProvider = Provider<ConnectionMonitor>((ref) {
  final vpnControl = VpnControlPlatform();
  final logger = Logger();
  
  final monitor = ConnectionMonitor(
    vpnControl: vpnControl,
    logger: logger,
  );
  
  // Start monitoring when provider is created
  monitor.startMonitoring().catchError((error) {
    logger.e('Failed to start connection monitoring: $error');
  });
  
  ref.onDispose(() {
    monitor.stopMonitoring().catchError((error) {
      logger.e('Failed to stop connection monitoring: $error');
    });
    monitor.dispose();
  });
  
  return monitor;
});

/// Alias for vpnServiceManagerProvider to maintain compatibility
final vpnServiceProvider = vpnServiceManagerProvider;

/// Provider for current VPN status
final vpnStatusProvider = StreamProvider<VpnStatus>((ref) {
  final serviceManager = ref.watch(vpnServiceManagerProvider);
  return serviceManager.statusStream;
});

/// Provider for current network statistics
final networkStatsProvider = StreamProvider<NetworkStats?>((ref) async* {
  final serviceManager = ref.watch(vpnServiceManagerProvider);
  
  // Listen to status changes and fetch stats when connected
  await for (final status in serviceManager.statusStream) {
    if (status.isConnected) {
      try {
        final stats = await serviceManager.getNetworkStats();
        yield stats;
      } catch (e) {
        yield null;
      }
    } else {
      yield null;
    }
  }
});

/// Provider for VPN connection operations
final vpnConnectionProvider = StateNotifierProvider<VpnConnectionNotifier, VpnConnectionUIState>((ref) {
  final serviceManager = ref.watch(vpnServiceManagerProvider);
  return VpnConnectionNotifier(serviceManager);
});

/// State for VPN connection UI operations
class VpnConnectionUIState {
  final bool isConnecting;
  final bool isDisconnecting;
  final String? error;
  final VpnConfiguration? selectedConfiguration;

  const VpnConnectionUIState({
    this.isConnecting = false,
    this.isDisconnecting = false,
    this.error,
    this.selectedConfiguration,
  });

  VpnConnectionUIState copyWith({
    bool? isConnecting,
    bool? isDisconnecting,
    String? error,
    VpnConfiguration? selectedConfiguration,
  }) {
    return VpnConnectionUIState(
      isConnecting: isConnecting ?? this.isConnecting,
      isDisconnecting: isDisconnecting ?? this.isDisconnecting,
      error: error ?? this.error,
      selectedConfiguration: selectedConfiguration ?? this.selectedConfiguration,
    );
  }
}

/// Notifier for VPN connection operations
class VpnConnectionNotifier extends StateNotifier<VpnConnectionUIState> {
  final VpnServiceManager _serviceManager;
  StreamSubscription<VpnStatus>? _statusSubscription;

  VpnConnectionNotifier(this._serviceManager) : super(const VpnConnectionUIState()) {
    _initializeStatusListener();
  }

  void _initializeStatusListener() {
    _statusSubscription = _serviceManager.statusStream.listen((status) {
      // Update state based on VPN status changes
      if (status.state == VpnConnectionState.connected) {
        state = state.copyWith(
          isConnecting: false,
          isDisconnecting: false,
          error: null,
        );
      } else if (status.state == VpnConnectionState.disconnected) {
        state = state.copyWith(
          isConnecting: false,
          isDisconnecting: false,
          error: null,
        );
      } else if (status.state == VpnConnectionState.error) {
        state = state.copyWith(
          isConnecting: false,
          isDisconnecting: false,
          error: status.lastError,
        );
      }
    });
  }

  /// Connects to VPN using the provided configuration
  Future<void> connect(VpnConfiguration config) async {
    try {
      state = state.copyWith(
        isConnecting: true,
        error: null,
        selectedConfiguration: config,
      );

      await _serviceManager.connect(config);
    } catch (e) {
      state = state.copyWith(
        isConnecting: false,
        error: e.toString(),
      );
    }
  }

  /// Disconnects from current VPN connection
  Future<void> disconnect() async {
    try {
      state = state.copyWith(
        isDisconnecting: true,
        error: null,
      );

      await _serviceManager.disconnect();
    } catch (e) {
      state = state.copyWith(
        isDisconnecting: false,
        error: e.toString(),
      );
    }
  }

  /// Clears any error state
  void clearError() {
    state = state.copyWith(error: null);
  }

  @override
  void dispose() {
    _statusSubscription?.cancel();
    super.dispose();
  }
}