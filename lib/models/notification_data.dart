import 'package:json_annotation/json_annotation.dart';

part 'notification_data.g.dart';

/// Enum representing different types of notifications
enum NotificationType {
  @JsonValue('connection_status')
  connectionStatus,
  @JsonValue('error')
  error,
  @JsonValue('warning')
  warning,
  @JsonValue('info')
  info,
  @JsonValue('success')
  success,
}

/// Enum representing notification priority levels
enum NotificationPriority {
  @JsonValue('low')
  low,
  @JsonValue('normal')
  normal,
  @JsonValue('high')
  high,
  @JsonValue('urgent')
  urgent,
}

/// Data model for application notifications
/// 
/// This class represents notification data that can be displayed
/// to users through various channels (in-app, system notifications, etc.)
@JsonSerializable()
class NotificationData {
  /// Unique identifier for this notification
  final String id;
  
  /// Type of notification
  final NotificationType type;
  
  /// Priority level
  final NotificationPriority priority;
  
  /// Notification title
  final String title;
  
  /// Notification message/body
  final String message;
  
  /// Optional action text (for actionable notifications)
  final String? actionText;
  
  /// Optional action data (for handling notification actions)
  final Map<String, dynamic>? actionData;
  
  /// Whether this notification should be persistent
  final bool isPersistent;
  
  /// Whether this notification should be shown as a system notification
  final bool showAsSystemNotification;
  
  /// Auto-dismiss duration (null for manual dismiss only)
  final Duration? autoDismissDuration;
  
  /// Timestamp when the notification was created
  final DateTime timestamp;
  
  /// Optional icon identifier
  final String? iconName;
  
  /// Optional color for the notification
  final String? color;

  const NotificationData({
    required this.id,
    required this.type,
    required this.priority,
    required this.title,
    required this.message,
    this.actionText,
    this.actionData,
    this.isPersistent = false,
    this.showAsSystemNotification = false,
    this.autoDismissDuration,
    required this.timestamp,
    this.iconName,
    this.color,
  });

  /// Creates a NotificationData from JSON map
  factory NotificationData.fromJson(Map<String, dynamic> json) =>
      _$NotificationDataFromJson(json);

  /// Converts this NotificationData to JSON map
  Map<String, dynamic> toJson() => _$NotificationDataToJson(this);

  /// Creates a copy of this notification with updated fields
  NotificationData copyWith({
    String? id,
    NotificationType? type,
    NotificationPriority? priority,
    String? title,
    String? message,
    String? actionText,
    Map<String, dynamic>? actionData,
    bool? isPersistent,
    bool? showAsSystemNotification,
    Duration? autoDismissDuration,
    DateTime? timestamp,
    String? iconName,
    String? color,
  }) {
    return NotificationData(
      id: id ?? this.id,
      type: type ?? this.type,
      priority: priority ?? this.priority,
      title: title ?? this.title,
      message: message ?? this.message,
      actionText: actionText ?? this.actionText,
      actionData: actionData ?? this.actionData,
      isPersistent: isPersistent ?? this.isPersistent,
      showAsSystemNotification: showAsSystemNotification ?? this.showAsSystemNotification,
      autoDismissDuration: autoDismissDuration ?? this.autoDismissDuration,
      timestamp: timestamp ?? this.timestamp,
      iconName: iconName ?? this.iconName,
      color: color ?? this.color,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is NotificationData &&
        other.id == id &&
        other.type == type &&
        other.priority == priority &&
        other.title == title &&
        other.message == message &&
        other.actionText == actionText &&
        other.isPersistent == isPersistent &&
        other.showAsSystemNotification == showAsSystemNotification &&
        other.autoDismissDuration == autoDismissDuration &&
        other.timestamp == timestamp &&
        other.iconName == iconName &&
        other.color == color;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      type,
      priority,
      title,
      message,
      actionText,
      isPersistent,
      showAsSystemNotification,
      autoDismissDuration,
      timestamp,
      iconName,
      color,
    );
  }

  @override
  String toString() {
    return 'NotificationData(id: $id, type: $type, priority: $priority, '
           'title: $title, message: $message, timestamp: $timestamp)';
  }
}

/// Factory class for creating common notification types
class NotificationFactory {
  /// Creates a VPN connection success notification
  static NotificationData connectionSuccess({
    required String serverName,
  }) {
    return NotificationData(
      id: _generateId(),
      type: NotificationType.success,
      priority: NotificationPriority.normal,
      title: 'VPN Connected',
      message: 'Successfully connected to $serverName',
      showAsSystemNotification: true,
      autoDismissDuration: const Duration(seconds: 5),
      timestamp: DateTime.now(),
      iconName: 'vpn_connected',
      color: '#4CAF50',
    );
  }

  /// Creates a VPN disconnection notification
  static NotificationData connectionDisconnected() {
    return NotificationData(
      id: _generateId(),
      type: NotificationType.info,
      priority: NotificationPriority.normal,
      title: 'VPN Disconnected',
      message: 'VPN connection has been terminated',
      showAsSystemNotification: true,
      autoDismissDuration: const Duration(seconds: 3),
      timestamp: DateTime.now(),
      iconName: 'vpn_disconnected',
      color: '#FF9800',
    );
  }

  /// Creates a VPN connection error notification
  static NotificationData connectionError({
    required String errorMessage,
    String? actionText,
    Map<String, dynamic>? actionData,
  }) {
    return NotificationData(
      id: _generateId(),
      type: NotificationType.error,
      priority: NotificationPriority.high,
      title: 'VPN Connection Failed',
      message: errorMessage,
      actionText: actionText ?? 'Retry',
      actionData: actionData,
      showAsSystemNotification: true,
      isPersistent: true,
      timestamp: DateTime.now(),
      iconName: 'vpn_error',
      color: '#F44336',
    );
  }

  /// Creates a network change warning notification
  static NotificationData networkChangeWarning({
    required String networkType,
  }) {
    return NotificationData(
      id: _generateId(),
      type: NotificationType.warning,
      priority: NotificationPriority.normal,
      title: 'Network Changed',
      message: 'Switched to $networkType. VPN connection may be affected.',
      showAsSystemNotification: false,
      autoDismissDuration: const Duration(seconds: 4),
      timestamp: DateTime.now(),
      iconName: 'network_change',
      color: '#FF9800',
    );
  }

  /// Creates a reconnection attempt notification
  static NotificationData reconnectionAttempt({
    required int attemptNumber,
    required int maxAttempts,
  }) {
    return NotificationData(
      id: _generateId(),
      type: NotificationType.info,
      priority: NotificationPriority.normal,
      title: 'Reconnecting...',
      message: 'Attempting to reconnect ($attemptNumber/$maxAttempts)',
      showAsSystemNotification: false,
      autoDismissDuration: const Duration(seconds: 3),
      timestamp: DateTime.now(),
      iconName: 'vpn_reconnecting',
      color: '#2196F3',
    );
  }

  /// Creates a permission required notification
  static NotificationData permissionRequired({
    required String permissionType,
  }) {
    return NotificationData(
      id: _generateId(),
      type: NotificationType.warning,
      priority: NotificationPriority.high,
      title: 'Permission Required',
      message: '$permissionType permission is required for VPN functionality',
      actionText: 'Grant Permission',
      actionData: {'permission_type': permissionType},
      isPersistent: true,
      showAsSystemNotification: true,
      timestamp: DateTime.now(),
      iconName: 'permission_required',
      color: '#FF9800',
    );
  }

  /// Creates a configuration import success notification
  static NotificationData configurationImported({
    required String configName,
  }) {
    return NotificationData(
      id: _generateId(),
      type: NotificationType.success,
      priority: NotificationPriority.normal,
      title: 'Configuration Imported',
      message: 'Successfully imported configuration: $configName',
      showAsSystemNotification: false,
      autoDismissDuration: const Duration(seconds: 3),
      timestamp: DateTime.now(),
      iconName: 'config_imported',
      color: '#4CAF50',
    );
  }

  /// Creates a generic error notification
  static NotificationData genericError({
    required String title,
    required String message,
    String? actionText,
    Map<String, dynamic>? actionData,
  }) {
    return NotificationData(
      id: _generateId(),
      type: NotificationType.error,
      priority: NotificationPriority.normal,
      title: title,
      message: message,
      actionText: actionText,
      actionData: actionData,
      showAsSystemNotification: false,
      autoDismissDuration: const Duration(seconds: 5),
      timestamp: DateTime.now(),
      iconName: 'error',
      color: '#F44336',
    );
  }

  static String _generateId() {
    return DateTime.now().millisecondsSinceEpoch.toString();
  }
}