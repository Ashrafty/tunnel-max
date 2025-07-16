import 'dart:convert';
import 'package:flutter/services.dart';
import '../interfaces/configuration_interface.dart';
import '../models/vpn_configuration.dart';

/// Windows-specific implementation of configuration interface
/// 
/// This class communicates with the native Windows plugin to provide
/// secure configuration storage using Windows Credential Manager.
class WindowsConfiguration implements ConfigurationInterface {
  static const MethodChannel _channel = MethodChannel('vpn_control');

  @override
  Future<bool> validateConfiguration(VpnConfiguration config) async {
    try {
      final configMap = config.toJson();
      final result = await _channel.invokeMethod('validateConfiguration', configMap);
      return result == true;
    } on PlatformException catch (e) {
      throw ConfigurationException(
        e.message ?? 'Configuration validation failed',
        code: e.code,
        details: e.details,
      );
    } catch (e) {
      throw ConfigurationException('Unexpected error during validation: $e');
    }
  }

  @override
  Future<void> saveConfiguration(VpnConfiguration config) async {
    try {
      final configMap = config.toJson();
      await _channel.invokeMethod('saveConfiguration', configMap);
    } on PlatformException catch (e) {
      throw ConfigurationException(
        e.message ?? 'Failed to save configuration',
        code: e.code,
        details: e.details,
      );
    } catch (e) {
      throw ConfigurationException('Unexpected error saving configuration: $e');
    }
  }

  @override
  Future<List<VpnConfiguration>> loadConfigurations() async {
    try {
      final result = await _channel.invokeMethod('loadConfigurations');
      if (result is List) {
        return result
            .cast<Map<String, dynamic>>()
            .map((configMap) => VpnConfiguration.fromJson(configMap))
            .toList();
      }
      return [];
    } on PlatformException catch (e) {
      throw ConfigurationException(
        e.message ?? 'Failed to load configurations',
        code: e.code,
        details: e.details,
      );
    } catch (e) {
      throw ConfigurationException('Unexpected error loading configurations: $e');
    }
  }

  @override
  Future<VpnConfiguration?> loadConfiguration(String id) async {
    try {
      final result = await _channel.invokeMethod('loadConfiguration', id);
      if (result is Map<String, dynamic>) {
        return VpnConfiguration.fromJson(result);
      }
      return null;
    } on PlatformException catch (e) {
      throw ConfigurationException(
        e.message ?? 'Failed to load configuration',
        code: e.code,
        details: e.details,
      );
    } catch (e) {
      throw ConfigurationException('Unexpected error loading configuration: $e');
    }
  }

  @override
  Future<bool> updateConfiguration(VpnConfiguration config) async {
    try {
      final configMap = config.toJson();
      final result = await _channel.invokeMethod('updateConfiguration', configMap);
      return result == true;
    } on PlatformException catch (e) {
      throw ConfigurationException(
        e.message ?? 'Failed to update configuration',
        code: e.code,
        details: e.details,
      );
    } catch (e) {
      throw ConfigurationException('Unexpected error updating configuration: $e');
    }
  }

  @override
  Future<bool> deleteConfiguration(String id) async {
    try {
      final result = await _channel.invokeMethod('deleteConfiguration', id);
      return result == true;
    } on PlatformException catch (e) {
      throw ConfigurationException(
        e.message ?? 'Failed to delete configuration',
        code: e.code,
        details: e.details,
      );
    } catch (e) {
      throw ConfigurationException('Unexpected error deleting configuration: $e');
    }
  }

  @override
  Future<int> deleteAllConfigurations() async {
    try {
      final result = await _channel.invokeMethod('deleteAllConfigurations');
      return result is int ? result : 0;
    } on PlatformException catch (e) {
      throw ConfigurationException(
        e.message ?? 'Failed to delete all configurations',
        code: e.code,
        details: e.details,
      );
    } catch (e) {
      throw ConfigurationException('Unexpected error deleting all configurations: $e');
    }
  }

  @override
  Future<List<VpnConfiguration>> importFromJson(String jsonString) async {
    try {
      final jsonData = json.decode(jsonString);
      final List<VpnConfiguration> configurations = [];

      if (jsonData is List) {
        // Array of configurations
        for (final configData in jsonData) {
          if (configData is Map<String, dynamic>) {
            try {
              configurations.add(VpnConfiguration.fromJson(configData));
            } catch (e) {
              // Skip invalid configurations
              continue;
            }
          }
        }
      } else if (jsonData is Map<String, dynamic>) {
        // Single configuration
        try {
          configurations.add(VpnConfiguration.fromJson(jsonData));
        } catch (e) {
          throw ConfigurationException('Invalid configuration format: $e');
        }
      } else {
        throw ConfigurationException('Invalid JSON format for configuration import');
      }

      return configurations;
    } catch (e) {
      if (e is ConfigurationException) {
        rethrow;
      }
      throw ConfigurationException('Failed to parse JSON: $e');
    }
  }

  @override
  Future<String> exportToJson({
    List<String>? configurationIds,
    bool includeSensitiveData = false,
  }) async {
    try {
      List<VpnConfiguration> configurations;
      
      if (configurationIds != null && configurationIds.isNotEmpty) {
        // Export specific configurations
        configurations = [];
        for (final id in configurationIds) {
          final config = await loadConfiguration(id);
          if (config != null) {
            configurations.add(config);
          }
        }
      } else {
        // Export all configurations
        configurations = await loadConfigurations();
      }

      // Convert to JSON, optionally excluding sensitive data
      final List<Map<String, dynamic>> exportData = configurations.map((config) {
        final configMap = config.toJson();
        
        if (!includeSensitiveData) {
          // Remove sensitive fields
          configMap.remove('protocolSpecificConfig');
          // Could remove other sensitive fields as needed
        }
        
        return configMap;
      }).toList();

      return json.encode(exportData);
    } catch (e) {
      if (e is ConfigurationException) {
        rethrow;
      }
      throw ConfigurationException('Failed to export configurations: $e');
    }
  }

  @override
  Future<bool> isSecureStorageAvailable() async {
    try {
      final result = await _channel.invokeMethod('isSecureStorageAvailable');
      return result == true;
    } on PlatformException catch (e) {
      throw ConfigurationException(
        e.message ?? 'Failed to check secure storage availability',
        code: e.code,
        details: e.details,
      );
    } catch (e) {
      throw ConfigurationException('Unexpected error checking secure storage: $e');
    }
  }

  @override
  Future<StorageInfo?> getStorageInfo() async {
    try {
      final result = await _channel.invokeMethod('getStorageInfo');
      if (result is Map<String, dynamic>) {
        return StorageInfo(
          configurationCount: result['configurationCount'] ?? 0,
          storageUsedBytes: result['storageUsedBytes'] ?? 0,
          lastBackupTime: result['lastBackupTime'] != null 
              ? DateTime.fromMillisecondsSinceEpoch(result['lastBackupTime'])
              : null,
          isEncrypted: result['isEncrypted'] ?? true,
          storageLocation: result['storageLocation'],
        );
      }
      return null;
    } on PlatformException catch (e) {
      throw ConfigurationException(
        e.message ?? 'Failed to get storage info',
        code: e.code,
        details: e.details,
      );
    } catch (e) {
      throw ConfigurationException('Unexpected error getting storage info: $e');
    }
  }
}