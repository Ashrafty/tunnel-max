import 'package:flutter/material.dart';
import 'package:json_annotation/json_annotation.dart';
import '../ui/theme/app_theme.dart';

part 'user_preferences.g.dart';

/// User preferences model for storing application settings
@JsonSerializable()
class UserPreferences {
  /// Auto-connect to VPN on app start
  final bool autoConnect;
  
  /// Automatically reconnect when connection is lost
  final bool autoReconnect;
  
  /// Application theme mode
  final AppThemeMode themeMode;
  
  /// Application theme color
  final AppThemeColor themeColor;
  
  /// Show notifications for connection status changes
  final bool showNotifications;
  
  /// Show notifications when connection is established
  final bool notifyOnConnect;
  
  /// Show notifications when connection is lost
  final bool notifyOnDisconnect;
  
  /// Auto-connect configuration ID (if auto-connect is enabled)
  final String? autoConnectConfigId;
  
  /// Reconnection retry attempts before giving up
  final int reconnectionRetries;
  
  /// Delay between reconnection attempts in seconds
  final int reconnectionDelay;

  const UserPreferences({
    this.autoConnect = false,
    this.autoReconnect = true,
    this.themeMode = AppThemeMode.system,
    this.themeColor = AppThemeColor.darkGreen,
    this.showNotifications = true,
    this.notifyOnConnect = true,
    this.notifyOnDisconnect = true,
    this.autoConnectConfigId,
    this.reconnectionRetries = 3,
    this.reconnectionDelay = 5,
  });

  /// Creates a copy of this preferences with the given fields replaced
  UserPreferences copyWith({
    bool? autoConnect,
    bool? autoReconnect,
    AppThemeMode? themeMode,
    AppThemeColor? themeColor,
    bool? showNotifications,
    bool? notifyOnConnect,
    bool? notifyOnDisconnect,
    String? autoConnectConfigId,
    int? reconnectionRetries,
    int? reconnectionDelay,
  }) {
    return UserPreferences(
      autoConnect: autoConnect ?? this.autoConnect,
      autoReconnect: autoReconnect ?? this.autoReconnect,
      themeMode: themeMode ?? this.themeMode,
      themeColor: themeColor ?? this.themeColor,
      showNotifications: showNotifications ?? this.showNotifications,
      notifyOnConnect: notifyOnConnect ?? this.notifyOnConnect,
      notifyOnDisconnect: notifyOnDisconnect ?? this.notifyOnDisconnect,
      autoConnectConfigId: autoConnectConfigId ?? this.autoConnectConfigId,
      reconnectionRetries: reconnectionRetries ?? this.reconnectionRetries,
      reconnectionDelay: reconnectionDelay ?? this.reconnectionDelay,
    );
  }

  /// Creates UserPreferences from JSON
  factory UserPreferences.fromJson(Map<String, dynamic> json) =>
      _$UserPreferencesFromJson(json);

  /// Converts UserPreferences to JSON
  Map<String, dynamic> toJson() => _$UserPreferencesToJson(this);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserPreferences &&
          runtimeType == other.runtimeType &&
          autoConnect == other.autoConnect &&
          autoReconnect == other.autoReconnect &&
          themeMode == other.themeMode &&
          themeColor == other.themeColor &&
          showNotifications == other.showNotifications &&
          notifyOnConnect == other.notifyOnConnect &&
          notifyOnDisconnect == other.notifyOnDisconnect &&
          autoConnectConfigId == other.autoConnectConfigId &&
          reconnectionRetries == other.reconnectionRetries &&
          reconnectionDelay == other.reconnectionDelay;

  @override
  int get hashCode =>
      autoConnect.hashCode ^
      autoReconnect.hashCode ^
      themeMode.hashCode ^
      themeColor.hashCode ^
      showNotifications.hashCode ^
      notifyOnConnect.hashCode ^
      notifyOnDisconnect.hashCode ^
      autoConnectConfigId.hashCode ^
      reconnectionRetries.hashCode ^
      reconnectionDelay.hashCode;
}

/// Application theme mode options
enum AppThemeMode {
  @JsonValue('light')
  light,
  @JsonValue('dark')
  dark,
  @JsonValue('system')
  system,
}



/// Extension to convert AppThemeMode to Flutter ThemeMode
extension AppThemeModeExtension on AppThemeMode {
  /// Converts to Flutter's ThemeMode
  ThemeMode get toThemeMode {
    switch (this) {
      case AppThemeMode.light:
        return ThemeMode.light;
      case AppThemeMode.dark:
        return ThemeMode.dark;
      case AppThemeMode.system:
        return ThemeMode.system;
    }
  }
  
  /// Display name for the theme mode
  String get displayName {
    switch (this) {
      case AppThemeMode.light:
        return 'Light';
      case AppThemeMode.dark:
        return 'Dark';
      case AppThemeMode.system:
        return 'System';
    }
  }
}