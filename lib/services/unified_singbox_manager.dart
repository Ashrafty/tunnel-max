import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:logger/logger.dart';

import '../interfaces/vpn_control_interface.dart';
import '../models/vpn_configuration.dart';
import '../models/vpn_status.dart';
import '../models/network_stats.dart';
import 'singbox_configuration_converter.dart';

/// Unified SingBox manager that implements VPN control interface
/// 
/// This service provides a unified interface to the platform-specific
/// VPN implementations through platform channels for optimal performance
/// and native integration.
class UnifiedSingboxManager implements VpnControlInterface {
  static const MethodChannel _channel = MethodChannel('com.tunnelmax.vpnclient/vpn');
  
  final Logger _logger;
  final SingboxConfigurationConverter _configConverter;
  
  VpnStatus _currentStatus = VpnStatus.disconnected();
  final StreamController<VpnStatus> _statusController = StreamController<VpnStatus>.broadcast();
  
  Timer? _statusUpdateTimer;
  bool _isInitialized = false;

  UnifiedSingboxManager({
    Logger? logger,
    SingboxConfigurationConverter? configConverter,
  }) : _logger = logger ?? Logger(),
       _configConverter = configConverter ?? SingboxConfigurationConverter() {
    _logger.d('UnifiedSingboxManager created');
  }

  @override
  Future<bool> hasVpnPermission() async {
    try {
      if (Platform.isAndroid) {
        final result = await _channel.invokeMethod<bool>('hasVpnPermission');
        return result ?? false;
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
      if (Platform.isAndroid) {
        final result = await _channel.invokeMethod<bool>('requestVpnPermission');
        return result ?? false;
      }
      
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
      
      // Update status to connecting
      await _updateStatus(VpnStatus.connecting(server: config.name));
      
      // Convert configuration to sing-box format
      final singboxConfig = _configConverter.convertToSingboxConfig(config);
      final configJson = jsonEncode(singboxConfig);
      
      // Start the connection through platform channel
      final success = await _channel.invokeMethod<bool>('connect', {
        'config': configJson,
      });
      
      if (success == true) {
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
      
      // Update status to disconnecting
      await _updateStatus(_currentStatus.copyWith(state: VpnConnectionState.disconnecting));
      
      // Stop the connection through platform channel
      final success = await _channel.invokeMethod<bool>('disconnect');
      
      if (success == true) {
        await _updateStatus(VpnStatus.disconnected());
        _stopStatusMonitoring();
        _logger.i('Successfully disconnected');
        return true;
      } else {
        await _updateStatus(VpnStatus.error(error: 'Failed to disconnect'));
        _logger.e('Failed to disconnect');
        return false;
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
      final statusMap = await _channel.invokeMethod<Map<dynamic, dynamic>>('getStatus');
      
      if (statusMap != null) {
        final status = Map<String, dynamic>.from(statusMap);
        final state = status['state'] as String? ?? 'disconnected';
        final isConnected = status['isConnected'] as bool? ?? false;
        
        VpnStatus newStatus;
        switch (state) {
          case 'connected':
            newStatus = VpnStatus.connected(
              server: status['serverAddress'] as String? ?? '',
              connectionStartTime: DateTime.fromMillisecondsSinceEpoch(
                status['connectionTime'] as int? ?? DateTime.now().millisecondsSinceEpoch,
              ),
            );
            break;
          case 'connecting':
            newStatus = VpnStatus.connecting(server: status['serverAddress'] as String? ?? '');
            break;
          case 'disconnecting':
            newStatus = _currentStatus.copyWith(state: VpnConnectionState.disconnecting);
            break;
          case 'error':
            newStatus = VpnStatus.error(error: status['error'] as String? ?? 'Unknown error');
            break;
          default:
            newStatus = VpnStatus.disconnected();
        }
        
        await _updateStatus(newStatus);
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
      if (!_currentStatus.isConnected) {
        return null;
      }
      
      final statsMap = await _channel.invokeMethod<Map<dynamic, dynamic>>('getNetworkStats');
      
      if (statsMap != null) {
        final stats = Map<String, dynamic>.from(statsMap);
        return NetworkStats(
          bytesReceived: stats['bytesReceived'] as int? ?? 0,
          bytesSent: stats['bytesSent'] as int? ?? 0,
          packetsReceived: stats['packetsReceived'] as int? ?? 0,
          packetsSent: stats['packetsSent'] as int? ?? 0,
          connectionDuration: Duration(milliseconds: stats['connectionDuration'] as int? ?? 0),
          downloadSpeed: stats['downloadSpeed'] as double? ?? 0.0,
          uploadSpeed: stats['uploadSpeed'] as double? ?? 0.0,
          lastUpdated: DateTime.now(),
        );
      }
      
      return null;
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
      
      if (Platform.isAndroid) {
        final initialized = await _channel.invokeMethod<bool>('initSingbox');
        if (initialized == true) {
          _isInitialized = true;
          _logger.i('Platform manager initialized successfully');
        } else {
          _logger.e('Failed to initialize platform manager');
          throw Exception('Platform manager initialization failed');
        }
      } else {
        _isInitialized = true;
        _logger.i('Platform manager initialized (non-Android platform)');
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
  }
}