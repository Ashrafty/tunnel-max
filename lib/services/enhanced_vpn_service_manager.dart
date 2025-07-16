import 'dart:async';
import 'package:logger/logger.dart';

import '../models/vpn_configuration.dart';
import '../models/vpn_status.dart';
import '../models/network_stats.dart';
import '../models/notification_data.dart';
import '../interfaces/vpn_control_interface.dart';
import 'configuration_manager.dart';
import 'error_handler_service.dart';
import 'notification_service.dart';
import 'vpn_service_manager.dart';

/// Enhanced VPN service manager with integrated error handling and notifications
/// 
/// This service extends the base VPN service manager with:
/// - Comprehensive error handling and user-friendly error messages
/// - Automatic error reporting and notification system
/// - Enhanced connection monitoring with error recovery
/// - User feedback integration for connection issues
class EnhancedVpnServiceManager extends VpnServiceManager {
  final ErrorHandlerService _errorHandler;
  final NotificationService _notificationService;

  EnhancedVpnServiceManager({
    required VpnControlInterface vpnControl,
    required ConfigurationManager configurationManager,
    required ErrorHandlerService errorHandler,
    required NotificationService notificationService,
    Logger? logger,
  })  : _errorHandler = errorHandler,
        _notificationService = notificationService,
        super(
          vpnControl: vpnControl,
          configurationManager: configurationManager,
          logger: logger,
        ) {
    _initializeErrorHandling();
  }

  /// Establishes a VPN connection with enhanced error handling
  @override
  Future<bool> connect(VpnConfiguration config) async {
    try {
      final result = await super.connect(config);
      
      // Show success notification
      if (result) {
        await _notificationService.showConnectionStatusNotification(
          isConnected: true,
          serverName: config.name,
        );
      }
      
      return result;
    } catch (e, stackTrace) {
      // Handle VPN connection errors with user-friendly messages
      await _errorHandler.handleVpnError(
        e,
        stackTrace: stackTrace,
        serverName: config.name,
        configurationId: config.id,
        showNotification: true,
      );
      
      // Show connection error notification
      await _notificationService.showConnectionStatusNotification(
        isConnected: false,
        errorMessage: _getConnectionErrorMessage(e),
      );
      
      rethrow;
    }
  }

  /// Disconnects the VPN connection with enhanced error handling
  @override
  Future<bool> disconnect() async {
    try {
      final result = await super.disconnect();
      
      // Show disconnection notification
      if (result) {
        await _notificationService.showConnectionStatusNotification(
          isConnected: false,
        );
      }
      
      return result;
    } catch (e, stackTrace) {
      // Handle disconnection errors
      await _errorHandler.handleVpnError(
        e,
        stackTrace: stackTrace,
        showNotification: true,
      );
      
      rethrow;
    }
  }

  /// Gets VPN status with error handling
  @override
  Future<VpnStatus> getStatus() async {
    try {
      return await super.getStatus();
    } catch (e, stackTrace) {
      // Handle status retrieval errors (don't show notifications for these)
      await _errorHandler.handleVpnError(
        e,
        stackTrace: stackTrace,
        showNotification: false,
      );
      
      // Return error status instead of throwing
      return VpnStatus.error(error: 'Failed to get connection status');
    }
  }

  /// Gets network statistics with error handling
  @override
  Future<NetworkStats?> getNetworkStats() async {
    try {
      return await super.getNetworkStats();
    } catch (e, stackTrace) {
      // Handle network stats errors silently (these are not critical)
      await _errorHandler.handleException(
        e,
        stackTrace: stackTrace,
        context: 'Getting network statistics',
        showNotification: false,
      );
      
      return null;
    }
  }

  /// Reconnects with enhanced error handling and notifications
  @override
  Future<bool> reconnect() async {
    try {
      // Show reconnection notification
      await _notificationService.showReconnectionNotification(
        attemptNumber: 1,
        maxAttempts: 1,
      );
      
      final result = await super.reconnect();
      
      if (result && currentConfiguration != null) {
        await _notificationService.showConnectionStatusNotification(
          isConnected: true,
          serverName: currentConfiguration!.name,
        );
      }
      
      return result;
    } catch (e, stackTrace) {
      await _errorHandler.handleVpnError(
        e,
        stackTrace: stackTrace,
        serverName: currentConfiguration?.name,
        configurationId: currentConfiguration?.id,
        showNotification: true,
      );
      
      rethrow;
    }
  }

  /// Handles network changes with notifications
  Future<void> handleNetworkChange(String networkType) async {
    try {
      // Show network change notification
      await _notificationService.showNetworkChangeNotification(networkType);
      
      // If connected, monitor for connection stability
      if (isConnected) {
        _monitorConnectionAfterNetworkChange();
      }
    } catch (e, stackTrace) {
      await _errorHandler.handleException(
        e,
        stackTrace: stackTrace,
        context: 'Handling network change',
        showNotification: false,
      );
    }
  }

  /// Reports a connection issue with user feedback
  Future<void> reportConnectionIssue({
    required String title,
    required String description,
    String? userEmail,
  }) async {
    try {
      // This would integrate with the user feedback service
      // For now, we'll create an error and handle it
      final connectionError = VpnServiceException(
        'User reported connection issue: $description',
        code: 'USER_REPORTED_ISSUE',
      );
      
      await _errorHandler.handleVpnError(
        connectionError,
        serverName: currentConfiguration?.name,
        configurationId: currentConfiguration?.id,
        showNotification: false, // Don't show notification for user reports
      );
      
      // Show confirmation that the issue was reported
      await _notificationService.showNotification(
        NotificationFactory.genericError(
          title: 'Issue Reported',
          message: 'Thank you for reporting the issue. We\'ll investigate and improve the service.',
        ),
      );
    } catch (e, stackTrace) {
      await _errorHandler.handleException(
        e,
        stackTrace: stackTrace,
        context: 'Reporting connection issue',
        showNotification: true,
      );
    }
  }

  // Private helper methods

  void _initializeErrorHandling() {
    // Listen to status changes and handle errors
    statusStream.listen(
      (status) {
        _handleStatusChange(status);
      },
      onError: (error, stackTrace) {
        _errorHandler.handleException(
          error,
          stackTrace: stackTrace,
          context: 'VPN status stream error',
          showNotification: true,
        );
      },
    );
  }

  void _handleStatusChange(VpnStatus status) {
    // Handle status-specific notifications and error handling
    switch (status.state) {
      case VpnConnectionState.connected:
        // Connection successful - already handled in connect method
        break;
        
      case VpnConnectionState.disconnected:
        // Check if this was an unexpected disconnection
        if (status.lastError != null) {
          _handleUnexpectedDisconnection(status.lastError!);
        }
        break;
        
      case VpnConnectionState.error:
        // Handle connection errors
        if (status.lastError != null) {
          _handleConnectionError(status.lastError!);
        }
        break;
        
      case VpnConnectionState.connecting:
      case VpnConnectionState.disconnecting:
      case VpnConnectionState.reconnecting:
        // Transitional states - no special handling needed
        break;
    }
  }

  void _handleUnexpectedDisconnection(String errorMessage) {
    _errorHandler.handleVpnError(
      VpnServiceException(
        'Unexpected disconnection: $errorMessage',
        code: 'UNEXPECTED_DISCONNECTION',
      ),
      serverName: currentConfiguration?.name,
      configurationId: currentConfiguration?.id,
      showNotification: true,
    );
  }

  void _handleConnectionError(String errorMessage) {
    _errorHandler.handleVpnError(
      VpnServiceException(
        'Connection error: $errorMessage',
        code: 'CONNECTION_ERROR',
      ),
      serverName: currentConfiguration?.name,
      configurationId: currentConfiguration?.id,
      showNotification: true,
    );
  }

  void _monitorConnectionAfterNetworkChange() {
    // Monitor connection stability after network change
    Timer(const Duration(seconds: 5), () async {
      try {
        final status = await getStatus();
        if (!status.isConnected && status.lastError != null) {
          // Connection lost after network change
          await _errorHandler.handleVpnError(
            VpnServiceException(
              'Connection lost after network change: ${status.lastError}',
              code: 'NETWORK_CHANGE_DISCONNECTION',
            ),
            serverName: currentConfiguration?.name,
            configurationId: currentConfiguration?.id,
            showNotification: true,
          );
        }
      } catch (e) {
        // Ignore monitoring errors
      }
    });
  }

  String _getConnectionErrorMessage(dynamic error) {
    if (error is VpnServiceException) {
      return error.message;
    } else if (error is VpnException) {
      return error.message;
    } else {
      return 'Connection failed: ${error.toString()}';
    }
  }
}