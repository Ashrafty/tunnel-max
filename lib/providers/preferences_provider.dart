import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import '../models/user_preferences.dart';
import '../services/preferences_service.dart';

/// Provider for preferences service
final preferencesServiceProvider = Provider<PreferencesService>((ref) {
  return PreferencesService(logger: Logger());
});

/// Provider for user preferences
final userPreferencesProvider = StateNotifierProvider<UserPreferencesNotifier, AsyncValue<UserPreferences>>((ref) {
  final preferencesService = ref.watch(preferencesServiceProvider);
  return UserPreferencesNotifier(preferencesService);
});

/// Notifier for managing user preferences state
class UserPreferencesNotifier extends StateNotifier<AsyncValue<UserPreferences>> {
  final PreferencesService _preferencesService;

  UserPreferencesNotifier(this._preferencesService) : super(const AsyncValue.loading()) {
    _loadPreferences();
  }

  /// Loads preferences from storage
  Future<void> _loadPreferences() async {
    try {
      final preferences = await _preferencesService.loadPreferences();
      state = AsyncValue.data(preferences);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    }
  }

  /// Updates auto-connect setting
  Future<void> updateAutoConnect(bool enabled) async {
    await _updatePreference((prefs, value) => prefs.copyWith(autoConnect: value), enabled);
  }

  /// Updates auto-reconnect setting
  Future<void> updateAutoReconnect(bool enabled) async {
    await _updatePreference((prefs, value) => prefs.copyWith(autoReconnect: value), enabled);
  }

  /// Updates theme mode setting
  Future<void> updateThemeMode(AppThemeMode themeMode) async {
    await _updatePreference((prefs, value) => prefs.copyWith(themeMode: value), themeMode);
  }

  /// Updates notification settings
  Future<void> updateShowNotifications(bool enabled) async {
    await _updatePreference((prefs, value) => prefs.copyWith(showNotifications: value), enabled);
  }

  /// Updates notify on connect setting
  Future<void> updateNotifyOnConnect(bool enabled) async {
    await _updatePreference((prefs, value) => prefs.copyWith(notifyOnConnect: value), enabled);
  }

  /// Updates notify on disconnect setting
  Future<void> updateNotifyOnDisconnect(bool enabled) async {
    await _updatePreference((prefs, value) => prefs.copyWith(notifyOnDisconnect: value), enabled);
  }

  /// Updates auto-connect configuration ID
  Future<void> updateAutoConnectConfigId(String? configId) async {
    await _updatePreference((prefs, value) => prefs.copyWith(autoConnectConfigId: value), configId);
  }

  /// Updates reconnection retry count
  Future<void> updateReconnectionRetries(int retries) async {
    await _updatePreference((prefs, value) => prefs.copyWith(reconnectionRetries: value), retries);
  }

  /// Updates reconnection delay
  Future<void> updateReconnectionDelay(int delay) async {
    await _updatePreference((prefs, value) => prefs.copyWith(reconnectionDelay: value), delay);
  }

  /// Generic method to update preferences
  Future<void> _updatePreference<T>(
    UserPreferences Function(UserPreferences, T) updater,
    T value,
  ) async {
    final currentState = state;
    if (currentState is AsyncData<UserPreferences>) {
      try {
        state = const AsyncValue.loading();
        final updatedPreferences = await _preferencesService.updatePreference(
          currentState.value,
          value,
          updater,
        );
        state = AsyncValue.data(updatedPreferences);
      } catch (e, stackTrace) {
        state = AsyncValue.error(e, stackTrace);
        // Restore previous state on error
        state = currentState;
      }
    }
  }

  /// Resets all preferences to defaults
  Future<void> resetToDefaults() async {
    try {
      state = const AsyncValue.loading();
      await _preferencesService.clearPreferences();
      const defaultPreferences = UserPreferences();
      await _preferencesService.savePreferences(defaultPreferences);
      state = const AsyncValue.data(defaultPreferences);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    }
  }
}