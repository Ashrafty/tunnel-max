// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'notification_data.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

NotificationData _$NotificationDataFromJson(
  Map<String, dynamic> json,
) => NotificationData(
  id: json['id'] as String,
  type: $enumDecode(_$NotificationTypeEnumMap, json['type']),
  priority: $enumDecode(_$NotificationPriorityEnumMap, json['priority']),
  title: json['title'] as String,
  message: json['message'] as String,
  actionText: json['actionText'] as String?,
  actionData: json['actionData'] as Map<String, dynamic>?,
  isPersistent: json['isPersistent'] as bool? ?? false,
  showAsSystemNotification: json['showAsSystemNotification'] as bool? ?? false,
  autoDismissDuration: json['autoDismissDuration'] == null
      ? null
      : Duration(microseconds: (json['autoDismissDuration'] as num).toInt()),
  timestamp: DateTime.parse(json['timestamp'] as String),
  iconName: json['iconName'] as String?,
  color: json['color'] as String?,
);

Map<String, dynamic> _$NotificationDataToJson(NotificationData instance) =>
    <String, dynamic>{
      'id': instance.id,
      'type': _$NotificationTypeEnumMap[instance.type]!,
      'priority': _$NotificationPriorityEnumMap[instance.priority]!,
      'title': instance.title,
      'message': instance.message,
      'actionText': instance.actionText,
      'actionData': instance.actionData,
      'isPersistent': instance.isPersistent,
      'showAsSystemNotification': instance.showAsSystemNotification,
      'autoDismissDuration': instance.autoDismissDuration?.inMicroseconds,
      'timestamp': instance.timestamp.toIso8601String(),
      'iconName': instance.iconName,
      'color': instance.color,
    };

const _$NotificationTypeEnumMap = {
  NotificationType.connectionStatus: 'connection_status',
  NotificationType.error: 'error',
  NotificationType.warning: 'warning',
  NotificationType.info: 'info',
  NotificationType.success: 'success',
};

const _$NotificationPriorityEnumMap = {
  NotificationPriority.low: 'low',
  NotificationPriority.normal: 'normal',
  NotificationPriority.high: 'high',
  NotificationPriority.urgent: 'urgent',
};
