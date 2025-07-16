import 'dart:async';
import 'package:logger/logger.dart';

import '../models/vpn_status.dart';
import 'vpn_service_manager.dart';
import 'network_resilience_service.dart';
import 'kill_switch_service.dart';
import 'network_transition_handler.dart';

/// Coordinates all network resilience functionality
/// 
/// This service integrates:
/// - Network change detection and VPN connection adaptation
/// - Automatic reconnection logic with configurable retry policies
/// - Kill switch functionality to block traffic when VPN disconnects
/// - Graceful handling of network transitions (WiFi to mobile data)
class NetworkResilienceCoordinator {
  final VpnServiceManager _vpnServiceManager;
  final NetworkResilienceService _resilienceService;
  final KillSwitchService _killSwitchService;
  final NetworkTransitionHandler _transitionHandler;
  final Logger _logger;

  // State tracking
  bool _isInitialized = false;
  StreamSubscription<VpnStatus>? _vpnStatusSubscription;
  StreamSubscription<NetworkResilienceStatus>? _resilienceStatusSubscription;
  StreamSubscription<KillSwitchStatus>? _killSwitchStatusSubscription;

  NetworkResilienceCoordinator({
    required VpnServiceManager vpnServiceManager,
    required NetworkResilienceService resilienceService,
    required KillSwitchService killSwitchService,
    required NetworkTransitionHandler transitionHandler,
    Logger? logger,
  }) : _vpnServiceManager = vpnServiceManager,
       _resilienceService = resilienceService,
       _killSwitchService = killSwitchService,
       _transitionHandler = transitionHandler,
       _logger = logger ?? Logger();

  /// Initializes the network resilience coordinator
  Future<void> initialize() async {
    if (_isInitialized) {
      _logger.w('Network resilience coordinator already initialized');
      return;
    }

    try {
      _logger.i('Initializing network resilience coordinator');

      // Initialize all services
      await _resilienceService.start();
      await _killSwitchService.initialize();
      await _transitionHandler.initialize();

      // Set up event listeners
      _setupEventListeners();

      _isInitialized = true;
      _logger.i('Network resilience coordinator initialized successfully');
    } catch (e) {
      _logger.e('Failed to initialize network resilience coordinator: $e');
      rethrow;
    }
  }

  /// Enables automatic reconnection with specified configuration
  Future<void> enableAutoReconnection({
    int maxAttempts = 10,
    Duration baseDelay = const Duration(seconds: 2),
    Duration maxDelay = const Duration(minutes: 5),
    double backoffMultiplier = 1.5,
  }) async {
    try {
      _logger.i('Enabling automatic reconnection');
      
      // Update resilience service configuration
      final config = NetworkResilienceConfig(
        autoReconnectEnabled: true,
        maxReconnectionAttempts: maxAttempts,
        baseReconnectionDelay: baseDelay,
        maxReconnectionDelay: maxDelay,
        backoffMultiplier: backoffMultiplier,
      );
      
      await _resilienceService.updateConfiguration(config);
      _logger.i('Automatic reconnection enabled');
    } catch (e) {
      _logger.e('Failed to enable automatic reconnection: $e');
      rethrow;
    }
  }

  /// Disables automatic reconnection
  Future<void> disableAutoReconnection() async {
    try {
      _logger.i('Disabling automatic reconnection');
      
      final config = NetworkResilienceConfig(
        autoReconnectEnabled: false,
      );
      
      await _resilienceService.updateConfiguration(config);
      _logger.i('Automatic reconnection disabled');
    } catch (e) {
      _logger.e('Failed to disable automatic reconnection: $e');
      rethrow;
    }
  }

  /// Enables kill switch functionality
  Future<void> enableKillSwitch() async {
    try {
      _logger.i('Enabling kill switch');
      await _killSwitchService.enable();
      
      // Also enable in resilience service
      final config = NetworkResilienceConfig(
        killSwitchEnabled: true,
      );
      await _resilienceService.updateConfiguration(config);
      
      _logger.i('Kill switch enabled');
    } catch (e) {
      _logger.e('Failed to enable kill switch: $e');
      rethrow;
    }
  }

  /// Disables kill switch functionality
  Future<void> disableKillSwitch() async {
    try {
      _logger.i('Disabling kill switch');
      await _killSwitchService.disable();
      
      // Also disable in resilience service
      final config = NetworkResilienceConfig(
        killSwitchEnabled: false,
      );
      await _resilienceService.updateConfiguration(config);
      
      _logger.i('Kill switch disabled');
    } catch (e) {
      _logger.e('Failed to disable kill switch: $e');
      rethrow;
    }
  }

  /// Manually triggers a reconnection attempt
  Future<void> triggerReconnection() async {
    try {
      _logger.i('Manually triggering reconnection');
      await _resilienceService.triggerReconnection();
    } catch (e) {
      _logger.e('Failed to trigger reconnection: $e');
      rethrow;
    }
  }

  /// Gets the current network resilience status
  NetworkResilienceStatus? get currentResilienceStatus => _resilienceService.currentStatus;

  /// Gets the current kill switch status
  KillSwitchStatus? get currentKillSwitchStatus => _killSwitchService.currentStatus;

  /// Stream of network resilience status updates
  Stream<NetworkResilienceStatus> get resilienceStatusStream => _resilienceService.statusStream;

  /// Stream of kill switch status updates
  Stream<KillSwitchStatus> get killSwitchStatusStream => _killSwitchService.statusStream;

  /// Disposes of the coordinator and releases resources
  Future<void> dispose() async {
    try {
      _logger.i('Disposing network resilience coordinator');

      // Cancel subscriptions
      _vpnStatusSubscription?.cancel();
      _resilienceStatusSubscription?.cancel();
      _killSwitchStatusSubscription?.cancel();

      // Dispose services
      await _resilienceService.stop();
      _killSwitchService.dispose();
      _transitionHandler.dispose();

      _isInitialized = false;
      _logger.i('Network resilience coordinator disposed');
    } catch (e) {
      _logger.e('Error disposing network resilience coordinator: $e');
    }
  }

  // Private helper methods

  void _setupEventListeners() {
    // Listen to VPN status changes
    _vpnStatusSubscription = _vpnServiceManager.statusStream.listen(
      _handleVpnStatusChange,
      onError: (error) {
        _logger.e('Error in VPN status stream: $error');
      },
    );

    // Listen to resilience service status changes
    _resilienceStatusSubscription = _resilienceService.statusStream.listen(
      _handleResilienceStatusChange,
      onError: (error) {
        _logger.e('Error in resilience status stream: $error');
      },
    );

    // Listen to kill switch status changes
    _killSwitchStatusSubscription = _killSwitchService.statusStream.listen(
      _handleKillSwitchStatusChange,
      onError: (error) {
        _logger.e('Error in kill switch status stream: $error');
      },
    );
  }

  void _handleVpnStatusChange(VpnStatus status) {
    _logger.d('VPN status changed: ${status.state}');

    switch (status.state) {
      case VpnConnectionState.connected:
        _handleVpnConnected(status);
        break;
      case VpnConnectionState.disconnected:
        _handleVpnDisconnected(status);
        break;
      case VpnConnectionState.error:
        _handleVpnError(status);
        break;
      case VpnConnectionState.connecting:
      case VpnConnectionState.disconnecting:
      case VpnConnectionState.reconnecting:
        // Transitional states - no special handling needed
        break;
    }
  }

  void _handleVpnConnected(VpnStatus status) {
    _logger.i('VPN connected - disabling kill switch if active');
    
    // Disable kill switch when VPN is connected
    if (_killSwitchService.isActive) {
      _killSwitchService.deactivate();
    }
    
    // Reset reconnection attempts
    _resilienceService.resetReconnectionAttempts();
  }

  void _handleVpnDisconnected(VpnStatus status) {
    _logger.w('VPN disconnected');
    
    // Check if this was an unexpected disconnection
    if (status.lastError != null) {
      _logger.w('Unexpected VPN disconnection: ${status.lastError}');
      
      // Activate kill switch if enabled
      if (_resilienceService.config.killSwitchEnabled) {
        _killSwitchService.activate();
      }
      
      // Trigger automatic reconnection if enabled
      if (_resilienceService.config.autoReconnectEnabled) {
        _resilienceService.triggerReconnection();
      }
    }
  }

  void _handleVpnError(VpnStatus status) {
    _logger.e('VPN error: ${status.lastError}');
    
    // Activate kill switch if enabled
    if (_resilienceService.config.killSwitchEnabled) {
      _killSwitchService.activate();
    }
    
    // Trigger automatic reconnection if enabled
    if (_resilienceService.config.autoReconnectEnabled) {
      _resilienceService.triggerReconnection();
    }
  }

  void _handleResilienceStatusChange(NetworkResilienceStatus status) {
    _logger.d('Resilience status changed: ${status.type}');
    
    switch (status.type) {
      case NetworkResilienceEventType.networkChanged:
        _logger.i('Network change detected - monitoring VPN stability');
        break;
      case NetworkResilienceEventType.networkLost:
        _logger.w('Network lost - kill switch should be active');
        break;
      case NetworkResilienceEventType.networkRestored:
        _logger.i('Network restored - checking VPN connection');
        break;
      case NetworkResilienceEventType.reconnectionAttempt:
        _logger.i('Reconnection attempt in progress');
        break;
      case NetworkResilienceEventType.reconnectionSuccess:
        _logger.i('Reconnection successful');
        break;
      case NetworkResilienceEventType.reconnectionFailed:
        _logger.w('Reconnection failed: ${status.message}');
        break;
      default:
        // Other status types don't need special handling
        break;
    }
  }

  void _handleKillSwitchStatusChange(KillSwitchStatus status) {
    _logger.d('Kill switch status changed: ${status.type}');
    
    switch (status.type) {
      case KillSwitchEventType.activated:
        _logger.w('Kill switch activated - network traffic blocked');
        break;
      case KillSwitchEventType.deactivated:
        _logger.i('Kill switch deactivated - network traffic restored');
        break;
      case KillSwitchEventType.error:
        _logger.e('Kill switch error: ${status.message}');
        break;
      default:
        // Other status types don't need special handling
        break;
    }
  }
}