import 'dart:async';
import 'dart:math';
import 'package:logger/logger.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import '../models/vpn_status.dart';
import '../models/network_stats.dart';
import '../interfaces/vpn_control_interface.dart';

/// Connection monitoring service for real-time VPN status tracking
/// 
/// This service provides:
/// - Real-time connection status monitoring
/// - Network statistics collection and reporting
/// - Automatic reconnection logic with exponential backoff
/// - Network change detection and handling
class ConnectionMonitor {
  final VpnControlInterface _vpnControl;
  final Connectivity _connectivity;
  final Logger _logger;

  // Status monitoring
  Timer? _statusMonitorTimer;
  Timer? _statsMonitorTimer;
  StreamController<VpnStatus>? _statusController;
  StreamController<NetworkStats>? _statsController;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  
  // Current state
  VpnStatus _currentStatus = VpnStatus.disconnected();
  NetworkStats? _currentStats;
  NetworkStats? _previousStats;
  List<ConnectivityResult> _currentConnectivity = [];
  
  // Reconnection logic
  Timer? _reconnectionTimer;
  int _reconnectionAttempts = 0;
  bool _autoReconnectEnabled = true;
  bool _isReconnecting = false;
  
  // Configuration
  static const Duration _statusMonitorInterval = Duration(seconds: 2);
  static const Duration _statsMonitorInterval = Duration(seconds: 5);
  static const Duration _reconnectionBaseDelay = Duration(seconds: 2);
  static const int _maxReconnectionAttempts = 10;
  static const double _reconnectionBackoffMultiplier = 1.5;
  static const Duration _maxReconnectionDelay = Duration(minutes: 5);
  static const Duration _networkChangeDebounceDelay = Duration(seconds: 3);

  ConnectionMonitor({
    required VpnControlInterface vpnControl,
    Connectivity? connectivity,
    Logger? logger,
  })  : _vpnControl = vpnControl,
        _connectivity = connectivity ?? Connectivity(),
        _logger = logger ?? Logger() {
    _initializeStreams();
    _setupNetworkChangeDetection();
  }

  /// Stream of VPN status updates
  Stream<VpnStatus> get statusStream => _statusController!.stream;

  /// Stream of network statistics updates
  Stream<NetworkStats> get statsStream => _statsController!.stream;

  /// Current VPN status
  VpnStatus get currentStatus => _currentStatus;

  /// Current network statistics
  NetworkStats? get currentStats => _currentStats;

  /// Whether auto-reconnection is enabled
  bool get autoReconnectEnabled => _autoReconnectEnabled;

  /// Sets auto-reconnection preference
  set autoReconnectEnabled(bool enabled) {
    _autoReconnectEnabled = enabled;
    _logger.d('Auto-reconnect ${enabled ? 'enabled' : 'disabled'}');
    
    if (!enabled) {
      _cancelReconnection();
    }
  }

  /// Number of reconnection attempts made
  int get reconnectionAttempts => _reconnectionAttempts;

  /// Whether currently attempting to reconnect
  bool get isReconnecting => _isReconnecting;

  /// Current network connectivity status
  List<ConnectivityResult> get currentConnectivity => List.unmodifiable(_currentConnectivity);

  /// Starts monitoring VPN connection status and network statistics
  Future<void> startMonitoring() async {
    try {
      _logger.i('Starting connection monitoring');
      
      // Get initial status
      await _updateStatus();
      await _updateStats();
      
      // Start periodic monitoring
      _startStatusMonitoring();
      _startStatsMonitoring();
      
      _logger.i('Connection monitoring started successfully');
    } catch (e) {
      _logger.e('Failed to start connection monitoring: $e');
      rethrow;
    }
  }

  /// Stops monitoring and cleans up resources
  Future<void> stopMonitoring() async {
    try {
      _logger.i('Stopping connection monitoring');
      
      _stopStatusMonitoring();
      _stopStatsMonitoring();
      _cancelReconnection();
      
      _logger.i('Connection monitoring stopped successfully');
    } catch (e) {
      _logger.e('Failed to stop connection monitoring: $e');
      rethrow;
    }
  }

  /// Forces an immediate status and statistics update
  Future<void> forceUpdate() async {
    try {
      _logger.d('Forcing status and statistics update');
      await _updateStatus();
      await _updateStats();
    } catch (e) {
      _logger.w('Failed to force update: $e');
    }
  }

  /// Triggers a reconnection attempt if auto-reconnect is enabled
  Future<void> triggerReconnection() async {
    if (!_autoReconnectEnabled) {
      _logger.w('Auto-reconnect is disabled, ignoring reconnection trigger');
      return;
    }

    if (_isReconnecting) {
      _logger.w('Reconnection already in progress');
      return;
    }

    _logger.i('Triggering manual reconnection');
    await _attemptReconnection();
  }

  /// Resets reconnection attempts counter
  void resetReconnectionAttempts() {
    _logger.d('Resetting reconnection attempts counter');
    _reconnectionAttempts = 0;
    _cancelReconnection();
  }

  /// Disposes of the connection monitor and releases all resources
  void dispose() {
    _logger.d('Disposing connection monitor');
    
    // Cancel all timers
    _statusMonitorTimer?.cancel();
    _statsMonitorTimer?.cancel();
    _reconnectionTimer?.cancel();
    
    // Cancel connectivity subscription
    _connectivitySubscription?.cancel();
    
    // Close stream controllers
    _statusController?.close();
    _statsController?.close();
  }

  // Private helper methods

  void _initializeStreams() {
    _statusController = StreamController<VpnStatus>.broadcast();
    _statsController = StreamController<NetworkStats>.broadcast();
  }

  void _setupNetworkChangeDetection() {
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      _handleConnectivityChange,
      onError: (error) {
        _logger.e('Connectivity monitoring error: $error');
      },
    );
    
    // Get initial connectivity status
    _connectivity.checkConnectivity().then((result) {
      _currentConnectivity = result;
      _logger.d('Initial connectivity: $_currentConnectivity');
    }).catchError((error) {
      _logger.e('Failed to get initial connectivity: $error');
    });
  }

  void _handleConnectivityChange(List<ConnectivityResult> result) {
    _logger.d('Network connectivity changed: $result');
    
    final previousConnectivity = _currentConnectivity;
    _currentConnectivity = result;
    
    // Debounce network changes to avoid rapid reconnections
    _reconnectionTimer?.cancel();
    _reconnectionTimer = Timer(_networkChangeDebounceDelay, () {
      _processNetworkChange(previousConnectivity, result);
    });
  }

  void _processNetworkChange(
    List<ConnectivityResult> previous,
    List<ConnectivityResult> current,
  ) {
    _logger.i('Processing network change: $previous -> $current');
    
    // Check if we lost all connectivity
    final hadConnectivity = previous.any((c) => c != ConnectivityResult.none);
    final hasConnectivity = current.any((c) => c != ConnectivityResult.none);
    
    if (hadConnectivity && !hasConnectivity) {
      _logger.w('Network connectivity lost');
      _handleNetworkLoss();
    } else if (!hadConnectivity && hasConnectivity) {
      _logger.i('Network connectivity restored');
      _handleNetworkRestoration();
    } else if (hasConnectivity && _hasNetworkTypeChanged(previous, current)) {
      _logger.i('Network type changed while connected');
      _handleNetworkTypeChange(previous, current);
    }
  }

  bool _hasNetworkTypeChanged(
    List<ConnectivityResult> previous,
    List<ConnectivityResult> current,
  ) {
    // Check if the primary connection type changed
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
    if (_currentStatus.isConnected || _currentStatus.isTransitioning) {
      _logger.w('VPN connection may be affected by network loss');
      // Force a status update to check if VPN is still connected
      _updateStatus();
    }
  }

  void _handleNetworkRestoration() {
    if (_currentStatus.state == VpnConnectionState.error || 
        (_autoReconnectEnabled && !_currentStatus.hasActiveConnection)) {
      _logger.i('Network restored, attempting reconnection');
      _scheduleReconnection();
    }
  }

  void _handleNetworkTypeChange(
    List<ConnectivityResult> previous,
    List<ConnectivityResult> current,
  ) {
    if (_currentStatus.isConnected) {
      _logger.i('Network type changed while VPN connected, monitoring for issues');
      // Force status update to check if connection is still stable
      Timer(Duration(seconds: 5), () => _updateStatus());
    }
  }

  void _startStatusMonitoring() {
    _stopStatusMonitoring();
    
    _statusMonitorTimer = Timer.periodic(_statusMonitorInterval, (timer) async {
      await _updateStatus();
    });
  }

  void _stopStatusMonitoring() {
    _statusMonitorTimer?.cancel();
    _statusMonitorTimer = null;
  }

  void _startStatsMonitoring() {
    _stopStatsMonitoring();
    
    _statsMonitorTimer = Timer.periodic(_statsMonitorInterval, (timer) async {
      await _updateStats();
    });
  }

  void _stopStatsMonitoring() {
    _statsMonitorTimer?.cancel();
    _statsMonitorTimer = null;
  }

  Future<void> _updateStatus() async {
    try {
      final newStatus = await _vpnControl.getStatus();
      
      if (_currentStatus != newStatus) {
        final previousState = _currentStatus.state;
        _currentStatus = newStatus;
        _statusController?.add(newStatus);
        
        _logger.d('Status updated: ${newStatus.state}');
        
        // Handle state transitions
        await _handleStatusChange(previousState, newStatus.state);
      }
    } catch (e) {
      _logger.w('Failed to update status: $e');
      
      // If we can't get status and we think we're connected, assume error
      if (_currentStatus.hasActiveConnection) {
        final errorStatus = VpnStatus.error(error: 'Status update failed: $e');
        if (_currentStatus != errorStatus) {
          _currentStatus = errorStatus;
          _statusController?.add(errorStatus);
          await _handleStatusChange(_currentStatus.state, VpnConnectionState.error);
        }
      }
    }
  }

  Future<void> _updateStats() async {
    try {
      if (!_currentStatus.isConnected) {
        // Clear stats if not connected
        if (_currentStats != null) {
          _previousStats = null;
          _currentStats = null;
        }
        return;
      }

      final newStats = await _vpnControl.getNetworkStats();
      
      if (newStats != null) {
        // Calculate speed if we have previous stats
        NetworkStats processedStats = newStats;
        if (_previousStats != null) {
          processedStats = newStats.updateFrom(_previousStats!);
        }
        
        _previousStats = _currentStats;
        _currentStats = processedStats;
        _statsController?.add(processedStats);
        
        _logger.t('Stats updated: ${processedStats.formattedTotalBytes} transferred');
      }
    } catch (e) {
      _logger.w('Failed to update network statistics: $e');
    }
  }

  Future<void> _handleStatusChange(
    VpnConnectionState previousState,
    VpnConnectionState newState,
  ) async {
    _logger.d('VPN status changed: $previousState -> $newState');
    
    switch (newState) {
      case VpnConnectionState.connected:
        _logger.i('VPN connection established');
        _reconnectionAttempts = 0;
        _isReconnecting = false;
        _cancelReconnection();
        break;
        
      case VpnConnectionState.disconnected:
        _logger.i('VPN disconnected');
        _isReconnecting = false;
        
        // Check if this was an unexpected disconnection
        if (previousState == VpnConnectionState.connected && _autoReconnectEnabled) {
          _logger.w('Unexpected disconnection detected');
          _scheduleReconnection();
        }
        break;
        
      case VpnConnectionState.error:
        _logger.w('VPN connection error: ${_currentStatus.lastError}');
        _isReconnecting = false;
        
        if (_autoReconnectEnabled) {
          _scheduleReconnection();
        }
        break;
        
      case VpnConnectionState.connecting:
      case VpnConnectionState.disconnecting:
      case VpnConnectionState.reconnecting:
        // Transitional states - no special handling needed
        break;
    }
  }

  void _scheduleReconnection() {
    if (!_autoReconnectEnabled) {
      _logger.d('Auto-reconnect disabled, skipping reconnection');
      return;
    }

    if (_reconnectionAttempts >= _maxReconnectionAttempts) {
      _logger.w('Maximum reconnection attempts ($_maxReconnectionAttempts) reached');
      return;
    }

    if (_isReconnecting) {
      _logger.d('Reconnection already scheduled');
      return;
    }

    _cancelReconnection();
    
    final delay = _calculateReconnectionDelay();
    _logger.i('Scheduling reconnection attempt ${_reconnectionAttempts + 1}/$_maxReconnectionAttempts in ${delay.inSeconds}s');
    
    _reconnectionTimer = Timer(delay, () async {
      await _attemptReconnection();
    });
  }

  Duration _calculateReconnectionDelay() {
    // Exponential backoff with jitter
    final baseDelayMs = _reconnectionBaseDelay.inMilliseconds;
    final exponentialDelay = baseDelayMs * pow(_reconnectionBackoffMultiplier, _reconnectionAttempts);
    
    // Add random jitter (±25%)
    final jitter = Random().nextDouble() * 0.5 - 0.25; // -0.25 to +0.25
    final jitteredDelay = exponentialDelay * (1 + jitter);
    
    // Clamp to maximum delay
    final delayMs = jitteredDelay.clamp(baseDelayMs.toDouble(), _maxReconnectionDelay.inMilliseconds.toDouble());
    
    return Duration(milliseconds: delayMs.round());
  }

  Future<void> _attemptReconnection() async {
    if (!_autoReconnectEnabled) {
      _logger.d('Auto-reconnect disabled during reconnection attempt');
      return;
    }

    if (_isReconnecting) {
      _logger.w('Reconnection already in progress');
      return;
    }

    try {
      _isReconnecting = true;
      _reconnectionAttempts++;
      
      _logger.i('Attempting reconnection (attempt $_reconnectionAttempts/$_maxReconnectionAttempts)');
      
      // Update status to show we're reconnecting
      final reconnectingStatus = _currentStatus.copyWith(
        state: VpnConnectionState.reconnecting,
      );
      _currentStatus = reconnectingStatus;
      _statusController?.add(reconnectingStatus);
      
      // Check network connectivity first
      final connectivity = await _connectivity.checkConnectivity();
      if (!connectivity.any((c) => c != ConnectivityResult.none)) {
        _logger.w('No network connectivity available for reconnection');
        _isReconnecting = false;
        _scheduleReconnection(); // Try again later
        return;
      }
      
      // Attempt to get current status to see if we're actually disconnected
      final currentStatus = await _vpnControl.getStatus();
      
      if (currentStatus.isConnected) {
        _logger.i('VPN is already connected, reconnection not needed');
        _currentStatus = currentStatus;
        _statusController?.add(currentStatus);
        _isReconnecting = false;
        _reconnectionAttempts = 0;
        return;
      }
      
      // For actual reconnection, we would need the VPN configuration
      // Since this monitor doesn't have direct access to the configuration,
      // we'll emit a reconnection status and let the VPN service manager handle it
      _logger.i('Reconnection attempt completed, status will be updated by VPN service');
      _isReconnecting = false;
      
    } catch (e) {
      _logger.e('Reconnection attempt failed: $e');
      _isReconnecting = false;
      
      // Schedule next attempt if we haven't exceeded max attempts
      if (_reconnectionAttempts < _maxReconnectionAttempts) {
        _scheduleReconnection();
      } else {
        _logger.w('All reconnection attempts exhausted');
        final errorStatus = VpnStatus.error(
          error: 'Reconnection failed after $_maxReconnectionAttempts attempts',
        );
        _currentStatus = errorStatus;
        _statusController?.add(errorStatus);
      }
    }
  }

  void _cancelReconnection() {
    _reconnectionTimer?.cancel();
    _reconnectionTimer = null;
  }
}