// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_preferences.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UserPreferences _$UserPreferencesFromJson(Map<String, dynamic> json) =>
    UserPreferences(
      autoConnect: json['autoConnect'] as bool? ?? false,
      autoReconnect: json['autoReconnect'] as bool? ?? true,
      themeMode:
          $enumDecodeNullable(_$AppThemeModeEnumMap, json['themeMode']) ??
          AppThemeMode.system,
      showNotifications: json['showNotifications'] as bool? ?? true,
      notifyOnConnect: json['notifyOnConnect'] as bool? ?? true,
      notifyOnDisconnect: json['notifyOnDisconnect'] as bool? ?? true,
      autoConnectConfigId: json['autoConnectConfigId'] as String?,
      reconnectionRetries: (json['reconnectionRetries'] as num?)?.toInt() ?? 3,
      reconnectionDelay: (json['reconnectionDelay'] as num?)?.toInt() ?? 5,
    );

Map<String, dynamic> _$UserPreferencesToJson(UserPreferences instance) =>
    <String, dynamic>{
      'autoConnect': instance.autoConnect,
      'autoReconnect': instance.autoReconnect,
      'themeMode': _$AppThemeModeEnumMap[instance.themeMode]!,
      'showNotifications': instance.showNotifications,
      'notifyOnConnect': instance.notifyOnConnect,
      'notifyOnDisconnect': instance.notifyOnDisconnect,
      'autoConnectConfigId': instance.autoConnectConfigId,
      'reconnectionRetries': instance.reconnectionRetries,
      'reconnectionDelay': instance.reconnectionDelay,
    };

const _$AppThemeModeEnumMap = {
  AppThemeMode.light: 'light',
  AppThemeMode.dark: 'dark',
  AppThemeMode.system: 'system',
};
