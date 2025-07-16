import 'dart:async';
import 'package:logger/logger.dart';

import '../models/vpn_configuration.dart';
import '../models/vpn_status.dart';
import '../models/network_stats.dart';
import '../interfaces/vpn_control_interface.dart';
import '../interfaces/platform_channels.dart';
import 'configuration_manager.dart';


/// Exception thrown by VPN service manager operations
class VpnServiceException implements Exception {
  final String message;
  final String? code;
  final dynamic details;

  const VpnServiceException(this.message, {this.code, this.details});

  @override
  String toString() {
    if (code != null) {
      return 'VpnServiceException($code): $message';
    }
    return 'VpnServiceException: $message';
  }
}

/// Central coordinator for VPN operations
/// 
/// This service manages the complete VPN connection lifecycle, including:
/// - Connection state management with proper state transitions
/// - Connection lifecycle methods (connect, disconnect, status monitoring)
/// - Error handling and recovery mechanisms for connection failures
/// - Integration with platform-specific VPN implementations
class VpnServiceManager {
  final VpnControlInterface _vpnControl;
  final ConfigurationManager _configurationManager;
  final Logger _logger;

  // State management
  VpnStatus _currentStatus = VpnStatus.disconnected();
  VpnConfiguration? _currentConfiguration;
  Timer? _statusUpdateTimer;
  Timer? _reconnectionTimer;
  StreamController<VpnStatus>? _statusController;
  
  // Connection management
  bool _isConnecting = false;
  bool _isDisconnecting = false;
  bool _autoReconnectEnabled = true;
  int _reconnectionAttempts = 0;
  static const int _maxReconnectionAttempts = 5;
  static const Duration _reconnectionBaseDelay = Duration(seconds: 2);
  static const Duration _statusUpdateInterval = Duration(seconds: 5);

  VpnServiceManager({
    required VpnControlInterface vpnControl,
    required ConfigurationManager configurationManager,
    Logger? logger,
  })  : _vpnControl = vpnControl,
        _configurationManager = configurationManager,
        _logger = logger ?? Logger() {
    _initializeStatusStream();
  }

  /// Current VPN connection status
  VpnStatus get currentStatus => _currentStatus;

  /// Current VPN configuration (null if not connected)
  VpnConfiguration? get currentConfiguration => _currentConfiguration;

  /// Stream of VPN status updates
  Stream<VpnStatus> get statusStream => _statusController!.stream;

  /// Whether auto-reconnection is enabled
  bool get autoReconnectEnabled => _autoReconnectEnabled;

  /// Sets auto-reconnection preference
  set autoReconnectEnabled(bool enabled) {
    _autoReconnectEnabled = enabled;
    _logger.d('Auto-reconnect ${enabled ? 'enabled' : 'disabled'}');
  }

  /// Whether the VPN is currently connected
  bool get isConnected => _currentStatus.isConnected;

  /// Whether the VPN is in a transitional state
  bool get isTransitioning => _currentStatus.isTransitioning;

  /// Whether there's an active connection or connection attempt
  bool get hasActiveConnection => _currentStatus.hasActiveConnection;

  /// Establishes a VPN connection using the provided configuration
  /// 
  /// Returns true if the connection was successfully initiated.
  /// The actual connection status should be monitored through [statusStream].
  /// 
  /// Throws [VpnServiceException] if the connection cannot be initiated.
  Future<bool> connect(VpnConfiguration config) async {
    try {
      _logger.i('Initiating VPN connection to ${config.name}');

      // Validate current state
      if (_isConnecting) {
        throw VpnServiceException(
          'Connection already in progress',
          code: 'CONNECTION_IN_PROGRESS',
        );
      }

      if (_currentStatus.isConnected && _currentConfiguration?.id == config.id) {
        _logger.w('Already connected to the same configuration');
        return true;
      }

      // Disconnect if currently connected to a different server
      if (_currentStatus.hasActiveConnection) {
        _logger.d('Disconnecting from current connection before connecting to new server');
        await disconnect();
        
        // Wait for disconnection to complete
        await _waitForState(VpnConnectionState.disconnected, timeout: Duration(seconds: 10));
      }

      // Validate configuration
      await _configurationManager.validateConfiguration(config);

      // Check VPN permissions
      if (!await _vpnControl.hasVpnPermission()) {
        _logger.w('VPN permission not granted, requesting permission');
        final permissionGranted = await _vpnControl.requestVpnPermission();
        if (!permissionGranted) {
          throw VpnServiceException(
            'VPN permission denied by user',
            code: PlatformErrorCodes.permissionDenied,
          );
        }
      }

      // Set connecting state
      _isConnecting = true;
      _currentConfiguration = config;
      _reconnectionAttempts = 0;
      
      await _updateStatus(VpnStatus.connecting(server: config.name));

      // Initiate connection through platform interface
      final connectionInitiated = await _vpnControl.connect(config);
      
      if (!connectionInitiated) {
        _isConnecting = false;
        await _updateStatus(VpnStatus.error(error: 'Failed to initiate connection'));
        throw VpnServiceException(
          'Failed to initiate VPN connection',
          code: PlatformErrorCodes.connectionFailed,
        );
      }

      // Update configuration last used timestamp
      final updatedConfig = config.copyWith(lastUsed: DateTime.now());
      await _configurationManager.updateConfiguration(updatedConfig);
      _currentConfiguration = updatedConfig;

      // Start monitoring connection status
      _startStatusMonitoring();

      _logger.i('VPN connection initiated successfully');
      return true;

    } catch (e) {
      _isConnecting = false;
      _logger.e('Failed to connect to VPN: $e');
      
      if (e is VpnServiceException) {
        rethrow;
      } else if (e is VpnException) {
        throw VpnServiceException(
          'VPN control error: ${e.message}',
          code: e.code,
          details: e.details,
        );
      } else {
        throw VpnServiceException(
          'Unexpected error during connection: $e',
          code: PlatformErrorCodes.internalError,
          details: e,
        );
      }
    }
  }

  /// Disconnects the current VPN connection
  /// 
  /// Returns true if the disconnection was successfully initiated.
  /// The actual disconnection status should be monitored through [statusStream].
  /// 
  /// Throws [VpnServiceException] if the disconnection cannot be initiated.
  Future<bool> disconnect() async {
    try {
      _logger.i('Initiating VPN disconnection');

      // Validate current state
      if (_isDisconnecting) {
        _logger.w('Disconnection already in progress');
        return true;
      }

      if (!_currentStatus.hasActiveConnection) {
        _logger.w('No active connection to disconnect');
        return true;
      }

      // Set disconnecting state
      _isDisconnecting = true;
      await _updateStatus(_currentStatus.copyWith(state: VpnConnectionState.disconnecting));

      // Cancel any ongoing reconnection attempts
      _cancelReconnection();

      // Initiate disconnection through platform interface
      final disconnectionInitiated = await _vpnControl.disconnect();
      
      if (!disconnectionInitiated) {
        _isDisconnecting = false;
        await _updateStatus(VpnStatus.error(error: 'Failed to initiate disconnection'));
        throw VpnServiceException(
          'Failed to initiate VPN disconnection',
          code: PlatformErrorCodes.connectionFailed,
        );
      }

      _logger.i('VPN disconnection initiated successfully');
      return true;

    } catch (e) {
      _isDisconnecting = false;
      _logger.e('Failed to disconnect VPN: $e');
      
      if (e is VpnServiceException) {
        rethrow;
      } else if (e is VpnException) {
        throw VpnServiceException(
          'VPN control error: ${e.message}',
          code: e.code,
          details: e.details,
        );
      } else {
        throw VpnServiceException(
          'Unexpected error during disconnection: $e',
          code: PlatformErrorCodes.internalError,
          details: e,
        );
      }
    }
  }

  /// Gets the current VPN connection status
  /// 
  /// Returns the current [VpnStatus] including connection state,
  /// server information, and network statistics.
  Future<VpnStatus> getStatus() async {
    try {
      _logger.d('Fetching current VPN status');
      
      final platformStatus = await _vpnControl.getStatus();
      await _updateStatus(platformStatus);
      
      return _currentStatus;
    } catch (e) {
      _logger.e('Failed to get VPN status: $e');
      
      if (e is VpnException) {
        throw VpnServiceException(
          'Failed to get status: ${e.message}',
          code: e.code,
          details: e.details,
        );
      } else {
        throw VpnServiceException(
          'Unexpected error getting status: $e',
          code: PlatformErrorCodes.internalError,
          details: e,
        );
      }
    }
  }

  /// Gets current network statistics for the VPN connection
  /// 
  /// Returns [NetworkStats] with current performance metrics
  /// including data usage, connection speed, and packet counts.
  /// 
  /// Returns null if no active connection exists.
  Future<NetworkStats?> getNetworkStats() async {
    try {
      if (!_currentStatus.hasActiveConnection) {
        return null;
      }

      _logger.d('Fetching network statistics');
      return await _vpnControl.getNetworkStats();
    } catch (e) {
      _logger.e('Failed to get network statistics: $e');
      return null;
    }
  }

  /// Reconnects to the current VPN configuration
  /// 
  /// This method will disconnect and then reconnect using the same configuration.
  /// Useful for refreshing the connection or recovering from connection issues.
  Future<bool> reconnect() async {
    try {
      _logger.i('Reconnecting VPN');

      if (_currentConfiguration == null) {
        throw VpnServiceException(
          'No configuration available for reconnection',
          code: 'NO_CONFIGURATION',
        );
      }

      final config = _currentConfiguration!;
      
      // Disconnect first if connected
      if (_currentStatus.hasActiveConnection) {
        await disconnect();
        await _waitForState(VpnConnectionState.disconnected, timeout: Duration(seconds: 10));
      }

      // Reconnect with the same configuration
      return await connect(config);
    } catch (e) {
      _logger.e('Failed to reconnect VPN: $e');
      rethrow;
    }
  }

  /// Starts the service manager and initializes monitoring
  Future<void> start() async {
    try {
      _logger.i('Starting VPN service manager');
      
      // Initialize status from platform
      await getStatus();
      
      // Start status monitoring if connected
      if (_currentStatus.hasActiveConnection) {
        _startStatusMonitoring();
      }
      
      _logger.i('VPN service manager started successfully');
    } catch (e) {
      _logger.e('Failed to start VPN service manager: $e');
      rethrow;
    }
  }

  /// Stops the service manager and cleans up resources
  Future<void> stop() async {
    try {
      _logger.i('Stopping VPN service manager');
      
      // Cancel timers
      _stopStatusMonitoring();
      _cancelReconnection();
      
      // Close status stream
      await _statusController?.close();
      
      _logger.i('VPN service manager stopped successfully');
    } catch (e) {
      _logger.e('Failed to stop VPN service manager: $e');
      rethrow;
    }
  }

  /// Disposes of the service manager and releases all resources
  void dispose() {
    _logger.d('Disposing VPN service manager');
    
    // Cancel all timers
    _statusUpdateTimer?.cancel();
    _reconnectionTimer?.cancel();
    
    // Close stream controller
    _statusController?.close();
  }

  // Private helper methods

  void _initializeStatusStream() {
    _statusController = StreamController<VpnStatus>.broadcast();
    
    // Listen to platform status updates
    _vpnControl.statusStream().listen(
      (status) async {
        await _handlePlatformStatusUpdate(status);
      },
      onError: (error) {
        _logger.e('Error in platform status stream: $error');
        _handleConnectionError(error);
      },
    );
  }

  Future<void> _handlePlatformStatusUpdate(VpnStatus status) async {
    _logger.d('Received platform status update: ${status.state}');
    
    final previousState = _currentStatus.state;
    await _updateStatus(status);
    
    // Handle state transitions
    if (previousState != status.state) {
      await _handleStateTransition(previousState, status.state);
    }
  }

  Future<void> _handleStateTransition(
    VpnConnectionState fromState,
    VpnConnectionState toState,
  ) async {
    _logger.d('VPN state transition: $fromState -> $toState');
    
    switch (toState) {
      case VpnConnectionState.connected:
        _isConnecting = false;
        _reconnectionAttempts = 0;
        _startStatusMonitoring();
        break;
        
      case VpnConnectionState.disconnected:
        _isConnecting = false;
        _isDisconnecting = false;
        _stopStatusMonitoring();
        
        // Handle unexpected disconnection
        if (fromState == VpnConnectionState.connected && _autoReconnectEnabled) {
          _logger.w('Unexpected disconnection detected, attempting reconnection');
          _scheduleReconnection();
        }
        break;
        
      case VpnConnectionState.error:
        _isConnecting = false;
        _isDisconnecting = false;
        _stopStatusMonitoring();
        
        // Handle connection error
        if (_autoReconnectEnabled && _currentConfiguration != null) {
          _logger.w('Connection error detected, attempting reconnection');
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

  void _handleConnectionError(dynamic error) {
    _logger.e('Connection error occurred: $error');
    
    final errorMessage = error is VpnException ? error.message : error.toString();
    final errorStatus = VpnStatus.error(error: errorMessage);
    
    _updateStatus(errorStatus);
    
    // Schedule reconnection if enabled
    if (_autoReconnectEnabled && _currentConfiguration != null) {
      _scheduleReconnection();
    }
  }

  void _scheduleReconnection() {
    if (_reconnectionAttempts >= _maxReconnectionAttempts) {
      _logger.w('Maximum reconnection attempts reached, giving up');
      return;
    }

    _cancelReconnection();
    
    final delay = _calculateReconnectionDelay();
    _logger.i('Scheduling reconnection attempt ${_reconnectionAttempts + 1} in ${delay.inSeconds} seconds');
    
    _reconnectionTimer = Timer(delay, () async {
      try {
        _reconnectionAttempts++;
        await _updateStatus(_currentStatus.copyWith(state: VpnConnectionState.reconnecting));
        
        if (_currentConfiguration != null) {
          await connect(_currentConfiguration!);
        }
      } catch (e) {
        _logger.e('Reconnection attempt failed: $e');
        _scheduleReconnection();
      }
    });
  }

  Duration _calculateReconnectionDelay() {
    // Exponential backoff with jitter
    final baseDelayMs = _reconnectionBaseDelay.inMilliseconds;
    final exponentialDelay = baseDelayMs * (1 << _reconnectionAttempts);
    final maxDelayMs = Duration(minutes: 5).inMilliseconds;
    
    final delayMs = exponentialDelay.clamp(baseDelayMs, maxDelayMs);
    return Duration(milliseconds: delayMs);
  }

  void _cancelReconnection() {
    _reconnectionTimer?.cancel();
    _reconnectionTimer = null;
  }

  void _startStatusMonitoring() {
    _stopStatusMonitoring();
    
    _statusUpdateTimer = Timer.periodic(_statusUpdateInterval, (timer) async {
      try {
        if (_currentStatus.hasActiveConnection) {
          await getStatus();
          
          // Update network statistics
          final stats = await getNetworkStats();
          if (stats != null) {
            await _updateStatus(_currentStatus.copyWith(currentStats: stats));
          }
        } else {
          _stopStatusMonitoring();
        }
      } catch (e) {
        _logger.w('Status monitoring error: $e');
      }
    });
  }

  void _stopStatusMonitoring() {
    _statusUpdateTimer?.cancel();
    _statusUpdateTimer = null;
  }

  Future<void> _updateStatus(VpnStatus newStatus) async {
    if (_currentStatus != newStatus) {
      _currentStatus = newStatus;
      _statusController?.add(newStatus);
      _logger.d('Status updated: ${newStatus.state}');
    }
  }

  Future<void> _waitForState(
    VpnConnectionState targetState, {
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final completer = Completer<void>();
    late StreamSubscription<VpnStatus> subscription;
    
    subscription = statusStream.listen((status) {
      if (status.state == targetState) {
        subscription.cancel();
        if (!completer.isCompleted) {
          completer.complete();
        }
      }
    });
    
    // Set up timeout
    Timer(timeout, () {
      subscription.cancel();
      if (!completer.isCompleted) {
        completer.completeError(
          VpnServiceException(
            'Timeout waiting for state $targetState',
            code: PlatformErrorCodes.timeout,
          ),
        );
      }
    });
    
    return completer.future;
  }
}