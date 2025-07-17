import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';

import '../models/vpn_configuration.dart';
import '../models/vpn_status.dart';
import '../models/network_stats.dart';
import '../services/enhanced_vpn_service_manager.dart';
import '../services/error_handler_service.dart';
import '../services/notification_service.dart';
import '../services/unified_singbox_manager.dart';
import '../interfaces/vpn_control_interface.dart';
import 'configuration_provider.dart';
import 'error_handling_provider.dart';

/// Provider for the logger instance
final loggerProvider = Provider<Logger>((ref) {
  return Logger(
    printer: PrettyPrinter(
      methodCount: 2,
      errorMethodCount: 8,
      lineLength: 120,
      colors: true,
      printEmojis: true,
      printTime: true,
    ),
  );
});

/// Provider for the error handler service
final errorHandlerServiceProvider = Provider<ErrorHandlerService>((ref) {
  final logger = ref.watch(loggerProvider);
  final notificationService = ref.watch(notificationServiceProvider);
  final logsService = ref.watch(logsServiceProvider);
  return ErrorHandlerService(
    notificationService: notificationService,
    logsService: logsService,
    logger: logger,
  );
});

/// Provider for the notification service
final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

/// Provider for the unified singbox manager (VPN control interface)
final vpnControlInterfaceProvider = Provider<VpnControlInterface>((ref) {
  final logger = ref.watch(loggerProvider);
  return UnifiedSingboxManager(logger: logger);
});

/// Provider for the enhanced VPN service manager
final vpnServiceManagerProvider = Provider<EnhancedVpnServiceManager>((ref) {
  final vpnControl = ref.watch(vpnControlInterfaceProvider);
  final configManager = ref.watch(configurationManagerProvider);
  final errorHandler = ref.watch(errorHandlerServiceProvider);
  final notificationService = ref.watch(notificationServiceProvider);
  final logger = ref.watch(loggerProvider);

  return EnhancedVpnServiceManager(
    vpnControl: vpnControl,
    configurationManager: configManager,
    errorHandler: errorHandler,
    notificationService: notificationService,
    logger: logger,
  );
});

/// Provider for the current VPN status
final vpnStatusProvider = StreamProvider<VpnStatus>((ref) {
  final vpnService = ref.watch(vpnServiceManagerProvider);
  return vpnService.statusStream;
});

/// Provider for the current VPN connection state
final vpnConnectionStateProvider = Provider<VpnConnectionState>((ref) {
  final statusAsync = ref.watch(vpnStatusProvider);
  return statusAsync.when(
    data: (status) => status.state,
    loading: () => VpnConnectionState.disconnected,
    error: (_, __) => VpnConnectionState.error,
  );
});

/// Provider for checking if VPN is connected
final isVpnConnectedProvider = Provider<bool>((ref) {
  final connectionState = ref.watch(vpnConnectionStateProvider);
  return connectionState == VpnConnectionState.connected;
});

/// Provider for checking if VPN is connecting
final isVpnConnectingProvider = Provider<bool>((ref) {
  final connectionState = ref.watch(vpnConnectionStateProvider);
  return connectionState == VpnConnectionState.connecting ||
         connectionState == VpnConnectionState.reconnecting;
});

/// Provider for current network statistics
final networkStatsProvider = FutureProvider<NetworkStats?>((ref) async {
  final vpnService = ref.watch(vpnServiceManagerProvider);
  try {
    return await vpnService.getNetworkStats();
  } catch (e) {
    return null;
  }
});

/// Provider for VPN service actions
final vpnServiceActionsProvider = Provider<VpnServiceActions>((ref) {
  final vpnService = ref.watch(vpnServiceManagerProvider);
  return VpnServiceActions(vpnService);
});

/// Class to encapsulate VPN service actions
class VpnServiceActions {
  final EnhancedVpnServiceManager _vpnService;

  VpnServiceActions(this._vpnService);

  /// Connect to a VPN server
  Future<bool> connect(VpnConfiguration config) async {
    try {
      return await _vpnService.connect(config);
    } catch (e) {
      rethrow;
    }
  }

  /// Disconnect from VPN
  Future<bool> disconnect() async {
    try {
      return await _vpnService.disconnect();
    } catch (e) {
      rethrow;
    }
  }

  /// Reconnect to current server
  Future<bool> reconnect() async {
    try {
      return await _vpnService.reconnect();
    } catch (e) {
      rethrow;
    }
  }

  /// Get current VPN status
  Future<VpnStatus> getStatus() async {
    try {
      return await _vpnService.getStatus();
    } catch (e) {
      rethrow;
    }
  }

  /// Get network statistics
  Future<NetworkStats?> getNetworkStats() async {
    try {
      return await _vpnService.getNetworkStats();
    } catch (e) {
      return null;
    }
  }

  /// Toggle VPN connection (connect if disconnected, disconnect if connected)
  Future<bool> toggleConnection(VpnConfiguration? config) async {
    if (_vpnService.isConnected) {
      return await disconnect();
    } else if (config != null) {
      return await connect(config);
    } else {
      throw Exception('No configuration provided for connection');
    }
  }

  /// Check if currently connected
  bool get isConnected => _vpnService.isConnected;

  /// Check if in transitional state
  bool get isTransitioning => _vpnService.isTransitioning;

  /// Get current configuration
  VpnConfiguration? get currentConfiguration => _vpnService.currentConfiguration;
}