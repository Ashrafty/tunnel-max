import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:logger/logger.dart';
import '../models/user_preferences.dart';

/// Service for managing user preferences and application settings
class PreferencesService {
  static const String _preferencesKey = 'user_preferences';
  
  final FlutterSecureStorage _secureStorage;
  final Logger _logger;
  
  PreferencesService({
    FlutterSecureStorage? secureStorage,
    Logger? logger,
  }) : _secureStorage = secureStorage ?? const FlutterSecureStorage(),
       _logger = logger ?? Logger();

  /// Loads user preferences from secure storage
  Future<UserPreferences> loadPreferences() async {
    try {
      final preferencesJson = await _secureStorage.read(key: _preferencesKey);
      
      if (preferencesJson == null) {
        _logger.i('No saved preferences found, using defaults');
        return const UserPreferences();
      }
      
      final preferencesMap = jsonDecode(preferencesJson) as Map<String, dynamic>;
      final preferences = UserPreferences.fromJson(preferencesMap);
      
      _logger.i('Loaded user preferences successfully');
      return preferences;
    } catch (e) {
      _logger.e('Failed to load preferences: $e');
      return const UserPreferences();
    }
  }

  /// Saves user preferences to secure storage
  Future<void> savePreferences(UserPreferences preferences) async {
    try {
      final preferencesJson = jsonEncode(preferences.toJson());
      await _secureStorage.write(key: _preferencesKey, value: preferencesJson);
      
      _logger.i('Saved user preferences successfully');
    } catch (e) {
      _logger.e('Failed to save preferences: $e');
      throw Exception('Failed to save preferences: $e');
    }
  }

  /// Updates a specific preference setting
  Future<UserPreferences> updatePreference<T>(
    UserPreferences currentPreferences,
    T value,
    UserPreferences Function(UserPreferences, T) updater,
  ) async {
    try {
      final updatedPreferences = updater(currentPreferences, value);
      await savePreferences(updatedPreferences);
      return updatedPreferences;
    } catch (e) {
      _logger.e('Failed to update preference: $e');
      rethrow;
    }
  }

  /// Clears all stored preferences
  Future<void> clearPreferences() async {
    try {
      await _secureStorage.delete(key: _preferencesKey);
      _logger.i('Cleared all preferences');
    } catch (e) {
      _logger.e('Failed to clear preferences: $e');
      throw Exception('Failed to clear preferences: $e');
    }
  }
}