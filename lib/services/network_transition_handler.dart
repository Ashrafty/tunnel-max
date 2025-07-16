import 'dart:async';
import 'package:logger/logger.dart';
import 'package:connectivity_plus/connectivity_plus.dart';


import 'vpn_service_manager.dart';
import 'network_resilience_service.dart';

/// Handles graceful network transitions for VPN connections
/// 
/// This service specifically handles:
/// - WiFi to mobile data transitions
/// - Mobile data to WiFi transitions
/// - Network interface changes
/// - IP address changes
/// - DNS server changes
class NetworkTransitionHandler {
  final VpnServiceManager _vpnServiceManager;
  final NetworkResilienceService _resilienceService;
  final Logger _logger;
  
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  ConnectivityResult? _lastConnectivityResult;
  bool _isHandlingTransition = false;

  NetworkTransitionHandler({
    required VpnServiceManager vpnServiceManager,
    required NetworkResilienceService resilienceService,
    Logger? logger,
  }) : _vpnServiceManager = vpnServiceManager,
       _resilienceService = resilienceService,
       _logger = logger ?? Logger();

  /// Initializes the network transition handler
  Future<void> initialize() async {
    try {
      _logger.i('Initializing network transition handler');
      
      // Get initial connectivity state
      final connectivity = Connectivity();
      final initialResult = await connectivity.checkConnectivity();
      _lastConnectivityResult = initialResult.isNotEmpty ? initialResult.first : null;
      
      // Listen for connectivity changes
      _connectivitySubscription = connectivity.onConnectivityChanged.listen(
        _handleConnectivityChange,
        onError: (error) {
          _logger.e('Error in connectivity stream: $error');
        },
      );
      
      _logger.i('Network transition handler initialized');
    } catch (e) {
      _logger.e('Failed to initialize network transition handler: $e');
      rethrow;
    }
  }

  /// Handles network connectivity changes
  Future<void> _handleConnectivityChange(List<ConnectivityResult> results) async {
    if (_isHandlingTransition || results.isEmpty) return;
    
    final currentResult = results.first;
    
    // Skip if no change
    if (currentResult == _lastConnectivityResult) return;
    
    _isHandlingTransition = true;
    
    try {
      _logger.i('Network connectivity changed: ${_lastConnectivityResult} -> $currentResult');
      
      // Check if VPN is currently connected
      final vpnStatus = await _vpnServiceManager.getStatus();
      if (!vpnStatus.isConnected) {
        _logger.d('VPN not connected, skipping transition handling');
        return;
      }
      
      // Handle the transition based on the change type
      await _handleNetworkTransition(_lastConnectivityResult, currentResult);
      
    } catch (e) {
      _logger.e('Error handling network transition: $e');
    } finally {
      _lastConnectivityResult = currentResult;
      _isHandlingTransition = false;
    }
  }

  /// Handles specific network transitions
  Future<void> _handleNetworkTransition(
    ConnectivityResult? from,
    ConnectivityResult to,
  ) async {
    _logger.i('Handling network transition: $from -> $to');
    
    switch (to) {
      case ConnectivityResult.wifi:
        await _handleTransitionToWifi(from);
        break;
      case ConnectivityResult.mobile:
        await _handleTransitionToMobile(from);
        break;
      case ConnectivityResult.none:
        await _handleNetworkLoss();
        break;
      default:
        _logger.w('Unknown connectivity result: $to');
    }
  }

  /// Handles transition to WiFi
  Future<void> _handleTransitionToWifi(ConnectivityResult? from) async {
    _logger.i('Transitioning to WiFi from $from');
    
    // Notify resilience service about network change
    await _resilienceService.handleNetworkChange('WiFi');
    
    // Give the network a moment to stabilize
    await Future.delayed(const Duration(seconds: 2));
    
    // Check VPN connection health
    await _checkAndRecoverConnection('WiFi transition');
  }

  /// Handles transition to mobile data
  Future<void> _handleTransitionToMobile(ConnectivityResult? from) async {
    _logger.i('Transitioning to mobile data from $from');
    
    // Notify resilience service about network change
    await _resilienceService.handleNetworkChange('Mobile Data');
    
    // Give the network a moment to stabilize
    await Future.delayed(const Duration(seconds: 3));
    
    // Check VPN connection health
    await _checkAndRecoverConnection('Mobile data transition');
  }

  /// Handles network loss
  Future<void> _handleNetworkLoss() async {
    _logger.w('Network connection lost');
    
    // Notify resilience service about network loss
    await _resilienceService.handleNetworkLoss();
  }

  /// Checks VPN connection health and recovers if needed
  Future<void> _checkAndRecoverConnection(String context) async {
    try {
      _logger.d('Checking VPN connection health after $context');
      
      // Wait a bit more for network to stabilize
      await Future.delayed(const Duration(seconds: 2));
      
      // Check current VPN status
      final status = await _vpnServiceManager.getStatus();
      
      if (!status.isConnected) {
        _logger.w('VPN disconnected after $context, attempting recovery');
        
        // Attempt to reconnect
        final reconnected = await _vpnServiceManager.reconnect();
        
        if (reconnected) {
          _logger.i('VPN successfully reconnected after $context');
        } else {
          _logger.e('Failed to reconnect VPN after $context');
        }
      } else {
        _logger.i('VPN connection stable after $context');
      }
    } catch (e) {
      _logger.e('Error checking VPN connection health: $e');
    }
  }

  /// Disposes of the handler and releases resources
  void dispose() {
    _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
    _logger.i('Network transition handler disposed');
  }
}