import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:logger/logger.dart';

import '../models/notification_data.dart';

/// Platform-specific notification service
/// 
/// This service provides cross-platform notification functionality with:
/// - In-app notification display
/// - System notification integration (Android/Windows)
/// - Notification management and persistence
/// - Action handling for interactive notifications
class NotificationService {
  static const MethodChannel _channel = MethodChannel('tunnel_max/notifications');
  
  final Logger _logger;
  
  // Notification management
  final List<NotificationData> _activeNotifications = [];
  final StreamController<NotificationData> _notificationController = 
      StreamController<NotificationData>.broadcast();
  final StreamController<String> _notificationActionController = 
      StreamController<String>.broadcast();
  
  // Configuration
  bool _systemNotificationsEnabled = true;
  bool _inAppNotificationsEnabled = true;
  
  NotificationService({Logger? logger}) : _logger = logger ?? Logger() {
    _initializePlatformChannel();
  }

  /// Stream of new notifications
  Stream<NotificationData> get notificationStream => _notificationController.stream;
  
  /// Stream of notification actions (when user taps notification actions)
  Stream<String> get notificationActionStream => _notificationActionController.stream;
  
  /// List of currently active notifications
  List<NotificationData> get activeNotifications => List.unmodifiable(_activeNotifications);
  
  /// Whether system notifications are enabled
  bool get systemNotificationsEnabled => _systemNotificationsEnabled;
  
  /// Whether in-app notifications are enabled
  bool get inAppNotificationsEnabled => _inAppNotificationsEnabled;

  /// Initializes the notification service
  Future<void> initialize() async {
    try {
      _logger.i('Initializing notification service');
      
      // Check and request notification permissions
      await _requestNotificationPermissions();
      
      // Initialize platform-specific notification channels
      await _initializeNotificationChannels();
      
      _logger.i('Notification service initialized successfully');
    } catch (e) {
      _logger.e('Failed to initialize notification service: $e');
      rethrow;
    }
  }

  /// Shows a notification
  Future<void> showNotification(NotificationData notification) async {
    try {
      _logger.d('Showing notification: ${notification.id}');
      
      // Add to active notifications
      _addToActiveNotifications(notification);
      
      // Show system notification if enabled and requested
      if (_systemNotificationsEnabled && notification.showAsSystemNotification) {
        await _showSystemNotification(notification);
      }
      
      // Emit notification for in-app display
      if (_inAppNotificationsEnabled) {
        _notificationController.add(notification);
      }
      
      // Schedule auto-dismiss if configured
      if (notification.autoDismissDuration != null) {
        Timer(notification.autoDismissDuration!, () {
          dismissNotification(notification.id);
        });
      }
      
      _logger.d('Notification shown successfully: ${notification.id}');
    } catch (e) {
      _logger.e('Failed to show notification: $e');
      rethrow;
    }
  }

  /// Dismisses a notification by ID
  Future<void> dismissNotification(String notificationId) async {
    try {
      _logger.d('Dismissing notification: $notificationId');
      
      // Remove from active notifications
      _activeNotifications.removeWhere((n) => n.id == notificationId);
      
      // Dismiss system notification
      await _dismissSystemNotification(notificationId);
      
      _logger.d('Notification dismissed: $notificationId');
    } catch (e) {
      _logger.e('Failed to dismiss notification: $e');
    }
  }

  /// Dismisses all notifications
  Future<void> dismissAllNotifications() async {
    try {
      _logger.d('Dismissing all notifications');
      
      final notificationIds = _activeNotifications.map((n) => n.id).toList();
      
      for (final id in notificationIds) {
        await dismissNotification(id);
      }
      
      _logger.d('All notifications dismissed');
    } catch (e) {
      _logger.e('Failed to dismiss all notifications: $e');
    }
  }

  /// Shows a VPN connection status notification
  Future<void> showConnectionStatusNotification({
    required bool isConnected,
    String? serverName,
    String? errorMessage,
  }) async {
    try {
      NotificationData notification;
      
      if (isConnected && serverName != null) {
        notification = NotificationFactory.connectionSuccess(serverName: serverName);
      } else if (!isConnected && errorMessage != null) {
        notification = NotificationFactory.connectionError(errorMessage: errorMessage);
      } else {
        notification = NotificationFactory.connectionDisconnected();
      }
      
      await showNotification(notification);
    } catch (e) {
      _logger.e('Failed to show connection status notification: $e');
    }
  }

  /// Shows a network change notification
  Future<void> showNetworkChangeNotification(String networkType) async {
    try {
      final notification = NotificationFactory.networkChangeWarning(
        networkType: networkType,
      );
      await showNotification(notification);
    } catch (e) {
      _logger.e('Failed to show network change notification: $e');
    }
  }

  /// Shows a reconnection attempt notification
  Future<void> showReconnectionNotification({
    required int attemptNumber,
    required int maxAttempts,
  }) async {
    try {
      final notification = NotificationFactory.reconnectionAttempt(
        attemptNumber: attemptNumber,
        maxAttempts: maxAttempts,
      );
      await showNotification(notification);
    } catch (e) {
      _logger.e('Failed to show reconnection notification: $e');
    }
  }

  /// Enables or disables system notifications
  Future<void> setSystemNotificationsEnabled(bool enabled) async {
    try {
      _systemNotificationsEnabled = enabled;
      _logger.i('System notifications ${enabled ? 'enabled' : 'disabled'}');
      
      if (!enabled) {
        // Dismiss all system notifications when disabled
        await _dismissAllSystemNotifications();
      }
    } catch (e) {
      _logger.e('Failed to set system notifications enabled: $e');
    }
  }

  /// Enables or disables in-app notifications
  void setInAppNotificationsEnabled(bool enabled) {
    _inAppNotificationsEnabled = enabled;
    _logger.i('In-app notifications ${enabled ? 'enabled' : 'disabled'}');
  }

  /// Checks if notification permissions are granted
  Future<bool> hasNotificationPermissions() async {
    try {
      if (kIsWeb) return true; // Web doesn't need explicit permissions
      
      final result = await _channel.invokeMethod<bool>('hasNotificationPermissions');
      return result ?? false;
    } catch (e) {
      _logger.w('Failed to check notification permissions: $e');
      return false;
    }
  }

  /// Requests notification permissions from the user
  Future<bool> requestNotificationPermissions() async {
    try {
      if (kIsWeb) return true; // Web doesn't need explicit permissions
      
      final result = await _channel.invokeMethod<bool>('requestNotificationPermissions');
      return result ?? false;
    } catch (e) {
      _logger.e('Failed to request notification permissions: $e');
      return false;
    }
  }

  /// Disposes of the service and releases resources
  void dispose() {
    _notificationController.close();
    _notificationActionController.close();
    _activeNotifications.clear();
  }

  // Private helper methods

  void _initializePlatformChannel() {
    _channel.setMethodCallHandler((call) async {
      try {
        switch (call.method) {
          case 'onNotificationAction':
            final actionData = call.arguments as Map<String, dynamic>;
            final notificationId = actionData['notificationId'] as String;
            final action = actionData['action'] as String;
            
            _logger.d('Notification action received: $action for $notificationId');
            _notificationActionController.add(action);
            break;
            
          case 'onNotificationDismissed':
            final notificationId = call.arguments as String;
            _logger.d('Notification dismissed: $notificationId');
            await dismissNotification(notificationId);
            break;
            
          default:
            _logger.w('Unknown method call: ${call.method}');
        }
      } catch (e) {
        _logger.e('Error handling platform method call: $e');
      }
    });
  }

  Future<void> _requestNotificationPermissions() async {
    try {
      final hasPermissions = await hasNotificationPermissions();
      if (!hasPermissions) {
        _logger.i('Requesting notification permissions');
        final granted = await requestNotificationPermissions();
        if (!granted) {
          _logger.w('Notification permissions not granted');
          _systemNotificationsEnabled = false;
        }
      }
    } catch (e) {
      _logger.e('Failed to request notification permissions: $e');
      _systemNotificationsEnabled = false;
    }
  }

  Future<void> _initializeNotificationChannels() async {
    try {
      if (kIsWeb) return; // Web doesn't use notification channels
      
      await _channel.invokeMethod('initializeNotificationChannels', {
        'channels': [
          {
            'id': 'vpn_status',
            'name': 'VPN Status',
            'description': 'Notifications about VPN connection status',
            'importance': 'high',
          },
          {
            'id': 'vpn_errors',
            'name': 'VPN Errors',
            'description': 'Error notifications and alerts',
            'importance': 'high',
          },
          {
            'id': 'vpn_info',
            'name': 'VPN Information',
            'description': 'General information and updates',
            'importance': 'normal',
          },
        ],
      });
      
      _logger.d('Notification channels initialized');
    } catch (e) {
      _logger.e('Failed to initialize notification channels: $e');
    }
  }

  Future<void> _showSystemNotification(NotificationData notification) async {
    try {
      if (kIsWeb) return; // Web notifications handled differently
      
      final channelId = _getChannelIdForNotification(notification);
      
      await _channel.invokeMethod('showNotification', {
        'id': notification.id,
        'channelId': channelId,
        'title': notification.title,
        'message': notification.message,
        'priority': notification.priority.toString().split('.').last,
        'persistent': notification.isPersistent,
        'actionText': notification.actionText,
        'actionData': notification.actionData,
        'iconName': notification.iconName,
        'color': notification.color,
      });
      
      _logger.d('System notification shown: ${notification.id}');
    } catch (e) {
      _logger.e('Failed to show system notification: $e');
    }
  }

  Future<void> _dismissSystemNotification(String notificationId) async {
    try {
      if (kIsWeb) return; // Web notifications handled differently
      
      await _channel.invokeMethod('dismissNotification', {
        'id': notificationId,
      });
      
      _logger.d('System notification dismissed: $notificationId');
    } catch (e) {
      _logger.e('Failed to dismiss system notification: $e');
    }
  }

  Future<void> _dismissAllSystemNotifications() async {
    try {
      if (kIsWeb) return; // Web notifications handled differently
      
      await _channel.invokeMethod('dismissAllNotifications');
      _logger.d('All system notifications dismissed');
    } catch (e) {
      _logger.e('Failed to dismiss all system notifications: $e');
    }
  }

  String _getChannelIdForNotification(NotificationData notification) {
    switch (notification.type) {
      case NotificationType.connectionStatus:
        return 'vpn_status';
      case NotificationType.error:
        return 'vpn_errors';
      case NotificationType.warning:
      case NotificationType.info:
      case NotificationType.success:
        return 'vpn_info';
    }
  }

  void _addToActiveNotifications(NotificationData notification) {
    // Remove existing notification with same ID
    _activeNotifications.removeWhere((n) => n.id == notification.id);
    
    // Add new notification
    _activeNotifications.insert(0, notification);
    
    // Keep only recent notifications (limit to prevent memory issues)
    const maxNotifications = 20;
    if (_activeNotifications.length > maxNotifications) {
      _activeNotifications.removeRange(maxNotifications, _activeNotifications.length);
    }
  }
}