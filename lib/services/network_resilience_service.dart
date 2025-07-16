import 'dart:async';
import 'package:logger/logger.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import '../models/vpn_status.dart';
import '../models/vpn_configuration.dart';
import '../interfaces/vpn_control_interface.dart';
import 'vpn_service_manager.dart';

/// Configuration for network resilience behavior
class NetworkResilienceConfig {
  /// Whether to enable automatic reconnection
  final bool autoReconnectEnabled;
  
  /// Maximum number of reconnection attempts
  final int maxReconnectionAttempts;
  
  /// Base delay between reconnection attempts
  final Duration baseReconnectionDelay;
  
  /// Maximum delay between reconnection attempts
  final Duration maxReconnectionDelay;
  
  /// Multiplier for exponential backoff
  final double backoffMultiplier;
  
  /// Whether to enable kill switch functionality
  final bool killSwitchEnabled;
  
  /// Timeout for network change detection debouncing
  final Duration networkChangeDebounceTimeout;
  
  /// Timeout for connection health checks
  final Duration connectionHealthCheckTimeout;
  
  /// Whether to block traffic during reconnection
  final bool blockTrafficDuringReconnection;

  const NetworkResilienceConfig({
    this.autoReconnectEnabled = true,
    this.maxReconnectionAttempts = 10,
    this.baseReconnectionDelay = const Duration(seconds: 2),
    this.maxReconnectionDelay = const Duration(minutes: 5),
    this.backoffMultiplier = 1.5,
    this.killSwitchEnabled = true,
    this.networkChangeDebounceTimeout = const Duration(seconds: 3),
    this.connectionHealthCheckTimeout = const Duration(seconds: 10),
    this.blockTrafficDuringReconnection = true,
  });

  NetworkResilienceConfig copyWith({
    bool? autoReconnectEnabled,
    int? maxReconnectionAttempts,
    Duration? baseReconnectionDelay,
    Duration? maxReconnectionDelay,
    double? backoffMultiplier,
    bool? killSwitchEnabled,
    Duration? networkChangeDebounceTimeout,
    Duration? connectionHealthCheckTimeout,
    bool? blockTrafficDuringReconnection,
  }) {
    return NetworkResilienceConfig(
      autoReconnectEnabled: autoReconnectEnabled ?? this.autoReconnectEnabled,
      maxReconnectionAttempts: maxReconnectionAttempts ?? this.maxReconnectionAttempts,
      baseReconnectionDelay: baseReconnectionDelay ?? this.baseReconnectionDelay,
      maxReconnectionDelay: maxReconnectionDelay ?? this.maxReconnectionDelay,
      backoffMultiplier: backoffMultiplier ?? this.backoffMultiplier,
      killSwitchEnabled: killSwitchEnabled ?? this.killSwitchEnabled,
      networkChangeDebounceTimeout: networkChangeDebounceTimeout ?? this.networkChangeDebounceTimeout,
      connectionHealthCheckTimeout: connectionHealthCheckTimeout ?? this.connectionHealthCheckTimeout,
      blockTrafficDuringReconnection: blockTrafficDuringReconnection ?? this.blockTrafficDuringReconnection,
    );
  }
}

/// Network resilience service for handling network changes and connection stability
/// 
/// This service provides:
/// - Network change detection and VPN connection adaptation
/// - Automatic reconnection logic with configurable retry policies
/// - Kill switch functionality to block traffic when VPN disconnects
/// - Graceful handling of network transitions (WiFi to mobile data)
class NetworkResilienceService {
  final VpnServiceManager _vpnServiceManager;
  final Connectivity _connectivity;
  final Logger _logger;
  
  NetworkResilienceConfig _config;
  
  // Network monitoring
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  StreamSubscription<VpnStatus>? _vpnStatusSubscription;
  List<ConnectivityResult> _currentConnectivity = [];
  Timer? _networkChangeDebounceTimer;
  Timer? _connectionHealthTimer;
  
  // Reconnection state
  Timer? _reconnectionTimer;
  int _reconnectionAttempts = 0;
  bool _isReconnecting = false;
  VpnConfiguration? _lastKnownConfiguration;
  
  // Kill switch state
  bool _killSwitchActive = false;
  bool _trafficBlocked = false;
  
  // Status streams
  final StreamController<NetworkResilienceStatus> _statusController = 
      StreamController<NetworkResilienceStatus>.broadcast();
  
  // Current status tracking
  NetworkResilienceStatus? _currentStatus;

  NetworkResilienceService({
    required VpnServiceManager vpnServiceManager,
    required VpnControlInterface vpnControl,
    Connectivity? connectivity,
    NetworkResilienceConfig? config,
    Logger? logger,
  })  : _vpnServiceManager = vpnServiceManager,
        _connectivity = connectivity ?? Connectivity(),
        _config = config ?? const NetworkResilienceConfig(),
        _logger = logger ?? Logger();

  /// Current network resilience configuration
  NetworkResilienceConfig get config => _config;

  /// Updates the network resilience configuration
  set config(NetworkResilienceConfig newConfig) {
    _logger.i('Updating network resilience configuration');
    _config = newConfig;
    
    // Apply configuration changes
    if (!newConfig.autoReconnectEnabled) {
      _cancelReconnection();
    }
    
    if (!newConfig.killSwitchEnabled && _killSwitchActive) {
      _disableKillSwitch();
    }
  }



  /// Stream of network resilience status updates
  Stream<NetworkResilienceStatus> get statusStream => _statusController.stream;

  /// Current connectivity status
  List<ConnectivityResult> get currentConnectivity => List.unmodifiable(_currentConnectivity);

  /// Whether kill switch is currently active
  bool get isKillSwitchActive => _killSwitchActive;

  /// Whether traffic is currently blocked
  bool get isTrafficBlocked => _trafficBlocked;

  /// Number of current reconnection attempts
  int get reconnectionAttempts => _reconnectionAttempts;

  /// Whether currently attempting to reconnect
  bool get isReconnecting => _isReconnecting;

  /// Starts the network resilience service
  Future<void> start() async {
    try {
      _logger.i('Starting network resilience service');
      
      // Get initial connectivity status
      _currentConnectivity = await _connectivity.checkConnectivity();
      _logger.d('Initial connectivity: $_currentConnectivity');
      
      // Start monitoring network changes
      _startNetworkMonitoring();
      
      // Start monitoring VPN status
      _startVpnStatusMonitoring();
      
      // Start connection health monitoring
      _startConnectionHealthMonitoring();
      
      _logger.i('Network resilience service started successfully');
      _emitStatus(NetworkResilienceStatus.started());
      
    } catch (e) {
      _logger.e('Failed to start network resilience service: $e');
      _emitStatus(NetworkResilienceStatus.error('Failed to start: $e'));
      rethrow;
    }
  }

  /// Stops the network resilience service
  Future<void> stop() async {
    try {
      _logger.i('Stopping network resilience service');
      
      // Cancel all subscriptions and timers
      await _connectivitySubscription?.cancel();
      await _vpnStatusSubscription?.cancel();
      _networkChangeDebounceTimer?.cancel();
      _connectionHealthTimer?.cancel();
      _cancelReconnection();
      
      // Disable kill switch if active
      if (_killSwitchActive) {
        await _disableKillSwitch();
      }
      
      _logger.i('Network resilience service stopped successfully');
      _emitStatus(NetworkResilienceStatus.stopped());
      
    } catch (e) {
      _logger.e('Failed to stop network resilience service: $e');
      _emitStatus(NetworkResilienceStatus.error('Failed to stop: $e'));
      rethrow;
    }
  }

  /// Manually triggers a reconnection attempt
  Future<void> triggerReconnection() async {
    if (!_config.autoReconnectEnabled) {
      _logger.w('Auto-reconnect is disabled, ignoring manual reconnection trigger');
      return;
    }

    if (_isReconnecting) {
      _logger.w('Reconnection already in progress');
      return;
    }

    _logger.i('Triggering manual reconnection');
    await _attemptReconnection();
  }

  /// Updates the network resilience configuration
  Future<void> updateConfiguration(NetworkResilienceConfig config) async {
    try {
      _logger.i('Updating network resilience configuration');
      
      final oldConfig = _config;
      _config = config;
      
      // Restart services if needed based on configuration changes
      if (oldConfig.autoReconnectEnabled != config.autoReconnectEnabled ||
          oldConfig.killSwitchEnabled != config.killSwitchEnabled) {
        
        // Stop current monitoring
        await stop();
        
        // Restart with new configuration
        await start();
      }
      
      _logger.i('Network resilience configuration updated');
    } catch (e) {
      _logger.e('Failed to update network resilience configuration: $e');
      rethrow;
    }
  }

  /// Gets the current status
  NetworkResilienceStatus? get currentStatus => _currentStatus;

  /// Resets the reconnection attempt counter
  void resetReconnectionAttempts() {
    _logger.d('Resetting reconnection attempts counter');
    _reconnectionAttempts = 0;
    _cancelReconnection();
  }

  /// Enables kill switch functionality
  Future<void> enableKillSwitch() async {
    if (!_config.killSwitchEnabled) {
      _logger.w('Kill switch is disabled in configuration');
      return;
    }

    if (_killSwitchActive) {
      _logger.d('Kill switch is already active');
      return;
    }

    try {
      _logger.i('Enabling kill switch');
      await _activateKillSwitch();
      _emitStatus(NetworkResilienceStatus.killSwitchEnabled());
    } catch (e) {
      _logger.e('Failed to enable kill switch: $e');
      _emitStatus(NetworkResilienceStatus.error('Failed to enable kill switch: $e'));
      rethrow;
    }
  }

  /// Disables kill switch functionality
  Future<void> disableKillSwitch() async {
    if (!_killSwitchActive) {
      _logger.d('Kill switch is already inactive');
      return;
    }

    try {
      _logger.i('Disabling kill switch');
      await _disableKillSwitch();
      _emitStatus(NetworkResilienceStatus.killSwitchDisabled());
    } catch (e) {
      _logger.e('Failed to disable kill switch: $e');
      _emitStatus(NetworkResilienceStatus.error('Failed to disable kill switch: $e'));
      rethrow;
    }
  }

  /// Handles network change events from external sources
  Future<void> handleNetworkChange(String networkType) async {
    _logger.i('Handling external network change notification: $networkType');
    
    // Check current VPN status
    final vpnStatus = _vpnServiceManager.currentStatus;
    if (!vpnStatus.isConnected) {
      _logger.d('VPN not connected, no action needed for network change');
      return;
    }
    
    // Emit network change status
    _emitStatus(NetworkResilienceStatus.networkChanged(_currentConnectivity));
    
    // Schedule a connection health check after network stabilizes
    _networkChangeDebounceTimer?.cancel();
    _networkChangeDebounceTimer = Timer(_config.networkChangeDebounceTimeout, () {
      _performConnectionHealthCheck();
    });
  }

  /// Handles network loss events from external sources
  Future<void> handleNetworkLoss() async {
    _logger.w('Handling external network loss notification');
    
    // Activate kill switch if enabled
    if (_config.killSwitchEnabled) {
      await _activateKillSwitch();
    }
    
    // Emit network loss status
    _emitStatus(NetworkResilienceStatus.networkLost());
    
    // Cancel any pending reconnection attempts
    _cancelReconnection();
  }

  /// Disposes of the service and releases all resources
  void dispose() {
    _logger.d('Disposing network resilience service');
    
    // Cancel all subscriptions and timers
    _connectivitySubscription?.cancel();
    _vpnStatusSubscription?.cancel();
    _networkChangeDebounceTimer?.cancel();
    _connectionHealthTimer?.cancel();
    _reconnectionTimer?.cancel();
    
    // Close status stream
    _statusController.close();
  }

  // Private helper methods

  void _startNetworkMonitoring() {
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      _handleConnectivityChange,
      onError: (error) {
        _logger.e('Connectivity monitoring error: $error');
        _emitStatus(NetworkResilienceStatus.error('Connectivity monitoring error: $error'));
      },
    );
  }

  void _startVpnStatusMonitoring() {
    _vpnStatusSubscription = _vpnServiceManager.statusStream.listen(
      _handleVpnStatusChange,
      onError: (error) {
        _logger.e('VPN status monitoring error: $error');
        _emitStatus(NetworkResilienceStatus.error('VPN status monitoring error: $error'));
      },
    );
  }

  void _startConnectionHealthMonitoring() {
    _connectionHealthTimer = Timer.periodic(
      _config.connectionHealthCheckTimeout,
      (_) => _performConnectionHealthCheck(),
    );
  }

  void _handleConnectivityChange(List<ConnectivityResult> result) {
    _logger.d('Network connectivity changed: $result');
    
    final previousConnectivity = _currentConnectivity;
    _currentConnectivity = result;
    
    // Debounce network changes to avoid rapid reconnections
    _networkChangeDebounceTimer?.cancel();
    _networkChangeDebounceTimer = Timer(_config.networkChangeDebounceTimeout, () {
      _processNetworkChange(previousConnectivity, result);
    });
  }

  void _processNetworkChange(
    List<ConnectivityResult> previous,
    List<ConnectivityResult> current,
  ) {
    _logger.i('Processing network change: $previous -> $current');
    
    final hadConnectivity = previous.any((c) => c != ConnectivityResult.none);
    final hasConnectivity = current.any((c) => c != ConnectivityResult.none);
    
    if (hadConnectivity && !hasConnectivity) {
      _handleNetworkLoss();
    } else if (!hadConnectivity && hasConnectivity) {
      _handleNetworkRestoration();
    } else if (hasConnectivity && _hasNetworkTypeChanged(previous, current)) {
      _handleNetworkTypeChange(previous, current);
    }
    
    _emitStatus(NetworkResilienceStatus.networkChanged(current));
  }

  bool _hasNetworkTypeChanged(
    List<ConnectivityResult> previous,
    List<ConnectivityResult> current,
  ) {
    final prevPrimary = previous.firstWhere(
      (c) => c != ConnectivityResult.none,
      orElse: () => ConnectivityResult.none,
    );
    final currentPrimary = current.firstWhere(
      (c) => c != ConnectivityResult.none,
      orElse: () => ConnectivityResult.none,
    );
    
    return prevPrimary != currentPrimary;
  }

  void _handleNetworkLoss() {
    _logger.w('Network connectivity lost');
    
    final vpnStatus = _vpnServiceManager.currentStatus;
    if (vpnStatus.isConnected || vpnStatus.isTransitioning) {
      _logger.w('VPN connection may be affected by network loss');
      
      // Activate kill switch if enabled
      if (_config.killSwitchEnabled) {
        _activateKillSwitch();
      }
      
      _emitStatus(NetworkResilienceStatus.networkLost());
    }
  }

  void _handleNetworkRestoration() {
    _logger.i('Network connectivity restored');
    
    final vpnStatus = _vpnServiceManager.currentStatus;
    if (vpnStatus.state == VpnConnectionState.error || 
        (!vpnStatus.hasActiveConnection && _lastKnownConfiguration != null)) {
      _logger.i('Network restored, attempting reconnection');
      _scheduleReconnection();
    }
    
    // Disable kill switch if network is restored and VPN is connected
    if (_killSwitchActive && vpnStatus.isConnected) {
      _disableKillSwitch();
    }
    
    _emitStatus(NetworkResilienceStatus.networkRestored());
  }

  void _handleNetworkTypeChange(
    List<ConnectivityResult> previous,
    List<ConnectivityResult> current,
  ) {
    _logger.i('Network type changed: $previous -> $current');
    
    final vpnStatus = _vpnServiceManager.currentStatus;
    if (vpnStatus.isConnected) {
      _logger.i('Network type changed while VPN connected, monitoring for stability');
      
      // Schedule a connection health check
      Timer(Duration(seconds: 5), () => _performConnectionHealthCheck());
    }
    
    _emitStatus(NetworkResilienceStatus.networkTypeChanged(previous, current));
  }

  void _handleVpnStatusChange(VpnStatus status) {
    _logger.d('VPN status changed: ${status.state}');
    
    // Store last known configuration for reconnection
    if (status.isConnected && _vpnServiceManager.currentConfiguration != null) {
      _lastKnownConfiguration = _vpnServiceManager.currentConfiguration;
    }
    
    switch (status.state) {
      case VpnConnectionState.connected:
        _reconnectionAttempts = 0;
        _isReconnecting = false;
        _cancelReconnection();
        
        // Disable kill switch when successfully connected
        if (_killSwitchActive) {
          _disableKillSwitch();
        }
        break;
        
      case VpnConnectionState.disconnected:
        _isReconnecting = false;
        
        // Check if this was an unexpected disconnection
        if (_lastKnownConfiguration != null && _config.autoReconnectEnabled) {
          _logger.w('Unexpected VPN disconnection detected');
          _scheduleReconnection();
        }
        break;
        
      case VpnConnectionState.error:
        _isReconnecting = false;
        
        // Activate kill switch on error if enabled
        if (_config.killSwitchEnabled) {
          _activateKillSwitch();
        }
        
        if (_config.autoReconnectEnabled) {
          _scheduleReconnection();
        }
        break;
        
      case VpnConnectionState.connecting:
      case VpnConnectionState.reconnecting:
        // Block traffic during connection if configured
        if (_config.blockTrafficDuringReconnection && _config.killSwitchEnabled) {
          _activateKillSwitch();
        }
        break;
        
      case VpnConnectionState.disconnecting:
        // No special handling needed
        break;
    }
  }

  void _performConnectionHealthCheck() {
    final vpnStatus = _vpnServiceManager.currentStatus;
    if (!vpnStatus.isConnected) {
      return;
    }

    _logger.d('Performing connection health check');
    
    // Check if we can get current status from the VPN
    _vpnServiceManager.getStatus().then((status) {
      if (status.state == VpnConnectionState.error) {
        _logger.w('Connection health check failed, VPN is in error state');
        if (_config.autoReconnectEnabled) {
          _scheduleReconnection();
        }
      }
    }).catchError((error) {
      _logger.w('Connection health check failed: $error');
      if (_config.autoReconnectEnabled) {
        _scheduleReconnection();
      }
    });
  }

  void _scheduleReconnection() {
    if (!_config.autoReconnectEnabled) {
      _logger.d('Auto-reconnect disabled, skipping reconnection');
      return;
    }

    if (_reconnectionAttempts >= _config.maxReconnectionAttempts) {
      _logger.w('Maximum reconnection attempts (${_config.maxReconnectionAttempts}) reached');
      _emitStatus(NetworkResilienceStatus.reconnectionFailed(
        'Maximum attempts reached: ${_config.maxReconnectionAttempts}',
      ));
      return;
    }

    if (_isReconnecting) {
      _logger.d('Reconnection already scheduled');
      return;
    }

    // Check network connectivity before scheduling
    if (!_currentConnectivity.any((c) => c != ConnectivityResult.none)) {
      _logger.w('No network connectivity available for reconnection');
      return;
    }

    _cancelReconnection();
    
    final delay = _calculateReconnectionDelay();
    _logger.i('Scheduling reconnection attempt ${_reconnectionAttempts + 1}/${_config.maxReconnectionAttempts} in ${delay.inSeconds}s');
    
    _reconnectionTimer = Timer(delay, () async {
      await _attemptReconnection();
    });
    
    _emitStatus(NetworkResilienceStatus.reconnectionScheduled(
      _reconnectionAttempts + 1,
      _config.maxReconnectionAttempts,
      delay,
    ));
  }

  Duration _calculateReconnectionDelay() {
    final baseDelayMs = _config.baseReconnectionDelay.inMilliseconds;
    final exponentialDelay = baseDelayMs * 
        (1 << (_reconnectionAttempts * _config.backoffMultiplier).round());
    
    final delayMs = exponentialDelay.clamp(
      baseDelayMs,
      _config.maxReconnectionDelay.inMilliseconds,
    );
    
    return Duration(milliseconds: delayMs);
  }

  Future<void> _attemptReconnection() async {
    if (!_config.autoReconnectEnabled) {
      _logger.d('Auto-reconnect disabled during reconnection attempt');
      return;
    }

    if (_isReconnecting) {
      _logger.w('Reconnection already in progress');
      return;
    }

    if (_lastKnownConfiguration == null) {
      _logger.w('No configuration available for reconnection');
      _emitStatus(NetworkResilienceStatus.reconnectionFailed('No configuration available'));
      return;
    }

    try {
      _isReconnecting = true;
      _reconnectionAttempts++;
      
      _logger.i('Attempting reconnection (attempt $_reconnectionAttempts/${_config.maxReconnectionAttempts})');
      _emitStatus(NetworkResilienceStatus.reconnectionAttempt(_reconnectionAttempts));
      
      // Check network connectivity
      final connectivity = await _connectivity.checkConnectivity();
      if (!connectivity.any((c) => c != ConnectivityResult.none)) {
        _logger.w('No network connectivity available for reconnection');
        _isReconnecting = false;
        _scheduleReconnection(); // Try again later
        return;
      }
      
      // Attempt to reconnect
      final success = await _vpnServiceManager.connect(_lastKnownConfiguration!);
      
      if (success) {
        _logger.i('Reconnection attempt initiated successfully');
        _emitStatus(NetworkResilienceStatus.reconnectionSuccess());
      } else {
        _logger.w('Reconnection attempt failed to initiate');
        _isReconnecting = false;
        _scheduleReconnection();
      }
      
    } catch (e) {
      _logger.e('Reconnection attempt failed: $e');
      _isReconnecting = false;
      
      if (_reconnectionAttempts < _config.maxReconnectionAttempts) {
        _scheduleReconnection();
      } else {
        _emitStatus(NetworkResilienceStatus.reconnectionFailed('All attempts exhausted: $e'));
      }
    }
  }

  void _cancelReconnection() {
    _reconnectionTimer?.cancel();
    _reconnectionTimer = null;
  }

  Future<void> _activateKillSwitch() async {
    if (_killSwitchActive) {
      return;
    }

    try {
      _logger.i('Activating kill switch - blocking network traffic');
      
      // Platform-specific kill switch implementation would go here
      // For now, we'll just set the flag and emit status
      _killSwitchActive = true;
      _trafficBlocked = true;
      
      _emitStatus(NetworkResilienceStatus.killSwitchActivated());
      
    } catch (e) {
      _logger.e('Failed to activate kill switch: $e');
      throw Exception('Failed to activate kill switch: $e');
    }
  }

  Future<void> _disableKillSwitch() async {
    if (!_killSwitchActive) {
      return;
    }

    try {
      _logger.i('Disabling kill switch - restoring network traffic');
      
      // Platform-specific kill switch deactivation would go here
      // For now, we'll just clear the flags and emit status
      _killSwitchActive = false;
      _trafficBlocked = false;
      
      _emitStatus(NetworkResilienceStatus.killSwitchDeactivated());
      
    } catch (e) {
      _logger.e('Failed to disable kill switch: $e');
      throw Exception('Failed to disable kill switch: $e');
    }
  }

  void _emitStatus(NetworkResilienceStatus status) {
    _currentStatus = status;
    _statusController.add(status);
  }
}

/// Status information for network resilience operations
class NetworkResilienceStatus {
  final NetworkResilienceEventType type;
  final String message;
  final Map<String, dynamic>? data;
  final DateTime timestamp;

  NetworkResilienceStatus({
    required this.type,
    required this.message,
    this.data,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  factory NetworkResilienceStatus.started() {
    return NetworkResilienceStatus(
      type: NetworkResilienceEventType.started,
      message: 'Network resilience service started',
    );
  }

  factory NetworkResilienceStatus.stopped() {
    return NetworkResilienceStatus(
      type: NetworkResilienceEventType.stopped,
      message: 'Network resilience service stopped',
    );
  }

  factory NetworkResilienceStatus.networkChanged(List<ConnectivityResult> connectivity) {
    return NetworkResilienceStatus(
      type: NetworkResilienceEventType.networkChanged,
      message: 'Network connectivity changed',
      data: {'connectivity': connectivity.map((c) => c.toString()).toList()},
    );
  }

  factory NetworkResilienceStatus.networkLost() {
    return NetworkResilienceStatus(
      type: NetworkResilienceEventType.networkLost,
      message: 'Network connectivity lost',
    );
  }

  factory NetworkResilienceStatus.networkRestored() {
    return NetworkResilienceStatus(
      type: NetworkResilienceEventType.networkRestored,
      message: 'Network connectivity restored',
    );
  }

  factory NetworkResilienceStatus.networkTypeChanged(
    List<ConnectivityResult> previous,
    List<ConnectivityResult> current,
  ) {
    return NetworkResilienceStatus(
      type: NetworkResilienceEventType.networkTypeChanged,
      message: 'Network type changed',
      data: {
        'previous': previous.map((c) => c.toString()).toList(),
        'current': current.map((c) => c.toString()).toList(),
      },
    );
  }

  factory NetworkResilienceStatus.reconnectionScheduled(
    int attempt,
    int maxAttempts,
    Duration delay,
  ) {
    return NetworkResilienceStatus(
      type: NetworkResilienceEventType.reconnectionScheduled,
      message: 'Reconnection scheduled',
      data: {
        'attempt': attempt,
        'maxAttempts': maxAttempts,
        'delaySeconds': delay.inSeconds,
      },
    );
  }

  factory NetworkResilienceStatus.reconnectionAttempt(int attempt) {
    return NetworkResilienceStatus(
      type: NetworkResilienceEventType.reconnectionAttempt,
      message: 'Attempting reconnection',
      data: {'attempt': attempt},
    );
  }

  factory NetworkResilienceStatus.reconnectionSuccess() {
    return NetworkResilienceStatus(
      type: NetworkResilienceEventType.reconnectionSuccess,
      message: 'Reconnection successful',
    );
  }

  factory NetworkResilienceStatus.reconnectionFailed(String reason) {
    return NetworkResilienceStatus(
      type: NetworkResilienceEventType.reconnectionFailed,
      message: 'Reconnection failed: $reason',
      data: {'reason': reason},
    );
  }

  factory NetworkResilienceStatus.killSwitchEnabled() {
    return NetworkResilienceStatus(
      type: NetworkResilienceEventType.killSwitchEnabled,
      message: 'Kill switch enabled',
    );
  }

  factory NetworkResilienceStatus.killSwitchDisabled() {
    return NetworkResilienceStatus(
      type: NetworkResilienceEventType.killSwitchDisabled,
      message: 'Kill switch disabled',
    );
  }

  factory NetworkResilienceStatus.killSwitchActivated() {
    return NetworkResilienceStatus(
      type: NetworkResilienceEventType.killSwitchActivated,
      message: 'Kill switch activated - traffic blocked',
    );
  }

  factory NetworkResilienceStatus.killSwitchDeactivated() {
    return NetworkResilienceStatus(
      type: NetworkResilienceEventType.killSwitchDeactivated,
      message: 'Kill switch deactivated - traffic restored',
    );
  }

  factory NetworkResilienceStatus.error(String error) {
    return NetworkResilienceStatus(
      type: NetworkResilienceEventType.error,
      message: error,
    );
  }

  @override
  String toString() {
    return 'NetworkResilienceStatus(type: $type, message: $message, data: $data, timestamp: $timestamp)';
  }
}

/// Types of network resilience events
enum NetworkResilienceEventType {
  started,
  stopped,
  networkChanged,
  networkLost,
  networkRestored,
  networkTypeChanged,
  reconnectionScheduled,
  reconnectionAttempt,
  reconnectionSuccess,
  reconnectionFailed,
  killSwitchEnabled,
  killSwitchDisabled,
  killSwitchActivated,
  killSwitchDeactivated,
  error,
}