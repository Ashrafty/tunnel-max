import 'dart:async';
import 'dart:io';
import 'package:logger/logger.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import '../interfaces/singbox_manager_interface.dart';
import '../interfaces/vpn_control_interface.dart';
import '../models/vpn_configuration.dart';
import '../models/vpn_status.dart';
import '../models/network_stats.dart';
import '../models/singbox_error.dart';
import 'singbox_manager_factory.dart';

/// Unified SingBox manager that implements VPN control interface
/// 
/// This service provides a unified interface to the platform-specific
/// SingBox managers and implements the VPN control interface for
/// integration with the VPN service manager.
class UnifiedSingboxManager implements VpnControlInterface {
  final Logger _logger;
  final SingboxManagerFactory _factory;
  
  SingboxManagerInterface? _platformManager;
  VpnStatus _currentStatus = VpnStatus.disconnected();
  final StreamController<VpnStatus> _statusController = StreamController<VpnStatus>.broadcast();
  
  Timer? _statusUpdateTimer;
  bool _isInitialized = false;

  UnifiedSingboxManager({
    Logger? logger,
    SingboxManagerFactory? factory,
  }) : _logger = logger ?? Logger(),
       _factory = factory ?? SingboxManagerFactory();

  @override
  Future<bool> hasVpnPermission() async {
    try {
      // On Android, we need VPN permission
      if (Platform.isAndroid) {
        // This would typically check VPN permission through platform channel
        // For now, we'll assume permission is needed and return false to trigger request
        return false;
      }
      
      // On other platforms, assume permission is available
      return true;
    } catch (e) {
      _logger.e('Error checking VPN permission: $e');
      return false;
    }
  }

  @override
  Future<bool> requestVpnPermission() async {
    try {
      // This would typically request VPN permission through platform channel
      // For now, we'll simulate permission being granted
      _logger.i('VPN permission requested');
      return true;
    } catch (e) {
      _logger.e('Error requesting VPN permission: $e');
      return false;
    }
  }

  @override
  Future<bool> connect(VpnConfiguration config) async {
    try {
      _logger.i('Connecting to ${config.name}');
      
      // Initialize platform manager if needed
      if (!_isInitialized) {
        await _initializePlatformManager();
      }
      
      if (_platformManager == null) {
        throw Exception('Platform manager not available');
      }
      
      // Update status to connecting
      await _updateStatus(VpnStatus.connecting(server: config.name));
      
      // Start the connection
      final success = await _platformManager!.start(config);
      
      if (success) {
        await _updateStatus(VpnStatus.connected(
          server: config.name,
          connectionStartTime: DateTime.now(),
        ));
        
        // Start status monitoring
        _startStatusMonitoring();
        
        _logger.i('Successfully connected to ${config.name}');
        return true;
      } else {
        await _updateStatus(VpnStatus.error(error: 'Failed to connect'));
        _logger.e('Failed to connect to ${config.name}');
        return false;
      }
    } catch (e, stackTrace) {
      _logger.e('Exception during connection: $e', error: e, stackTrace: stackTrace);
      await _updateStatus(VpnStatus.error(error: e.toString()));
      return false;
    }
  }

  @override
  Future<bool> disconnect() async {
    try {
      _logger.i('Disconnecting VPN');
      
      if (_platformManager == null) {
        _logger.w('Platform manager not available, creating new instance');
        _platformManager = SingboxManagerFactory.getInstance();
      }
      
      // Check if already disconnected
      if (_platformManager != null) {
        final isRunning = await _platformManager!.isRunning();
        if (!isRunning) {
          _logger.i('Already disconnected');
          await _updateStatus(VpnStatus.disconnected());
          return true;
        }
      }
      
      // Update status to disconnecting
      await _updateStatus(_currentStatus.copyWith(state: VpnConnectionState.disconnecting));
      
      // Stop the connection
      if (_platformManager != null) {
        _logger.d('Calling platform manager stop()');
        final success = await _platformManager!.stop();
        _logger.d('Platform manager stop() returned: $success');
        
        if (success) {
          await _updateStatus(VpnStatus.disconnected());
          _stopStatusMonitoring();
          _logger.i('Successfully disconnected');
          return true;
        } else {
          // For unsupported platforms, treat as success
          final platformName = SingboxManagerFactory.getPlatformName();
          if (!SingboxManagerFactory.isPlatformSupported()) {
            _logger.i('Unsupported platform ($platformName), treating as successful disconnection');
            await _updateStatus(VpnStatus.disconnected());
            return true;
          }
          
          await _updateStatus(VpnStatus.error(error: 'Failed to disconnect'));
          _logger.e('Failed to disconnect on supported platform: $platformName');
          return false;
        }
      } else {
        _logger.w('Platform manager unavailable, simulating successful disconnection');
        await _updateStatus(VpnStatus.disconnected());
        return true;
      }
    } catch (e, stackTrace) {
      _logger.e('Exception during disconnection: $e', error: e, stackTrace: stackTrace);
      await _updateStatus(VpnStatus.error(error: e.toString()));
      return false;
    }
  }

  @override
  Future<VpnStatus> getStatus() async {
    try {
      if (_platformManager == null) {
        return VpnStatus.disconnected();
      }
      
      final isRunning = await _platformManager!.isRunning();
      
      if (isRunning && _currentStatus.state != VpnConnectionState.connected) {
        // Update status if we're running but status doesn't reflect it
        await _updateStatus(_currentStatus.copyWith(state: VpnConnectionState.connected));
      } else if (!isRunning && _currentStatus.state == VpnConnectionState.connected) {
        // Update status if we're not running but status shows connected
        await _updateStatus(VpnStatus.disconnected());
      }
      
      return _currentStatus;
    } catch (e) {
      _logger.e('Error getting VPN status: $e');
      return VpnStatus.error(error: e.toString());
    }
  }

  @override
  Future<NetworkStats?> getNetworkStats() async {
    try {
      if (_platformManager == null || !_currentStatus.isConnected) {
        return null;
      }
      
      return await _platformManager!.getStatistics();
    } catch (e) {
      _logger.e('Error getting network stats: $e');
      return null;
    }
  }

  @override
  Stream<VpnStatus> statusStream() {
    return _statusController.stream;
  }

  /// Initialize the platform-specific manager
  Future<void> _initializePlatformManager() async {
    try {
      _logger.i('Initializing platform manager');
      
      _platformManager = SingboxManagerFactory.getInstance();
      
      if (_platformManager != null) {
        final initialized = await _platformManager!.initialize();
        if (initialized) {
          _isInitialized = true;
          _logger.i('Platform manager initialized successfully');
        } else {
          _logger.e('Failed to initialize platform manager');
          throw Exception('Platform manager initialization failed');
        }
      } else {
        _logger.e('Failed to create platform manager');
        throw Exception('Platform manager creation failed');
      }
    } catch (e) {
      _logger.e('Error initializing platform manager: $e');
      rethrow;
    }
  }

  /// Start monitoring connection status
  void _startStatusMonitoring() {
    _stopStatusMonitoring();
    
    _statusUpdateTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      try {
        await getStatus();
        
        // Update network statistics if connected
        if (_currentStatus.isConnected) {
          final stats = await getNetworkStats();
          if (stats != null) {
            await _updateStatus(_currentStatus.copyWith(currentStats: stats));
          }
        }
      } catch (e) {
        _logger.w('Status monitoring error: $e');
      }
    });
  }

  /// Stop monitoring connection status
  void _stopStatusMonitoring() {
    _statusUpdateTimer?.cancel();
    _statusUpdateTimer = null;
  }

  /// Update the current status and notify listeners
  Future<void> _updateStatus(VpnStatus newStatus) async {
    if (_currentStatus != newStatus) {
      _currentStatus = newStatus;
      _statusController.add(newStatus);
      _logger.d('Status updated: ${newStatus.state}');
    }
  }

  /// Dispose of resources
  void dispose() {
    _stopStatusMonitoring();
    _statusController.close();
    _platformManager?.cleanup();
  }
}