import '../models/vpn_configuration.dart';

/// Abstract interface for secure configuration storage operations
/// 
/// This interface defines the contract for platform-specific secure storage
/// implementations. It provides methods for storing, retrieving, and managing
/// VPN configurations with encryption and secure storage mechanisms.
abstract class ConfigurationInterface {
  /// Validates a VPN configuration for correctness and completeness
  /// 
  /// Performs comprehensive validation including:
  /// - Required field validation
  /// - Protocol-specific parameter validation
  /// - Network address and port validation
  /// - Authentication method compatibility
  /// 
  /// Returns true if the configuration is valid and can be used for connection.
  /// 
  /// Throws [ConfigurationException] with detailed error information if invalid.
  Future<bool> validateConfiguration(VpnConfiguration config);

  /// Saves a VPN configuration to secure storage
  /// 
  /// Encrypts sensitive configuration data and stores it using
  /// platform-appropriate secure storage mechanisms:
  /// - Android: Android Keystore
  /// - Windows: Windows Credential Manager
  /// 
  /// The configuration will be validated before saving.
  /// 
  /// Throws [ConfigurationException] if the configuration cannot be saved.
  Future<void> saveConfiguration(VpnConfiguration config);

  /// Loads all stored VPN configurations
  /// 
  /// Retrieves and decrypts all stored configurations from secure storage.
  /// Returns an empty list if no configurations are stored.
  /// 
  /// Throws [ConfigurationException] if configurations cannot be loaded.
  Future<List<VpnConfiguration>> loadConfigurations();

  /// Loads a specific configuration by ID
  /// 
  /// Retrieves and decrypts a single configuration from secure storage.
  /// Returns null if the configuration with the specified ID is not found.
  /// 
  /// Throws [ConfigurationException] if the configuration cannot be loaded.
  Future<VpnConfiguration?> loadConfiguration(String id);

  /// Updates an existing configuration
  /// 
  /// Updates the configuration with the same ID in secure storage.
  /// The configuration will be validated before updating.
  /// 
  /// Returns true if the configuration was successfully updated.
  /// Returns false if no configuration with the specified ID exists.
  /// 
  /// Throws [ConfigurationException] if the configuration cannot be updated.
  Future<bool> updateConfiguration(VpnConfiguration config);

  /// Deletes a configuration by ID
  /// 
  /// Removes the configuration from secure storage and clears any
  /// associated encrypted data.
  /// 
  /// Returns true if the configuration was successfully deleted.
  /// Returns false if no configuration with the specified ID exists.
  /// 
  /// Throws [ConfigurationException] if the configuration cannot be deleted.
  Future<bool> deleteConfiguration(String id);

  /// Deletes all stored configurations
  /// 
  /// Removes all configurations from secure storage and clears all
  /// associated encrypted data. This operation cannot be undone.
  /// 
  /// Returns the number of configurations that were deleted.
  /// 
  /// Throws [ConfigurationException] if configurations cannot be deleted.
  Future<int> deleteAllConfigurations();

  /// Imports configurations from a JSON string
  /// 
  /// Parses and validates configurations from JSON format.
  /// Supports both single configuration objects and arrays of configurations.
  /// 
  /// Returns a list of successfully parsed configurations.
  /// Invalid configurations in the input will be skipped.
  /// 
  /// Throws [ConfigurationException] if the JSON format is invalid.
  Future<List<VpnConfiguration>> importFromJson(String jsonString);

  /// Exports configurations to JSON string
  /// 
  /// Serializes the specified configurations to JSON format.
  /// If no configuration IDs are provided, exports all configurations.
  /// 
  /// Sensitive data (passwords, keys) may be excluded from export
  /// based on the [includeSensitiveData] parameter.
  /// 
  /// Returns a JSON string containing the exported configurations.
  /// 
  /// Throws [ConfigurationException] if configurations cannot be exported.
  Future<String> exportToJson({
    List<String>? configurationIds,
    bool includeSensitiveData = false,
  });

  /// Checks if secure storage is available and properly initialized
  /// 
  /// Verifies that the platform-specific secure storage mechanism
  /// is available and can be used for storing configurations.
  /// 
  /// Returns true if secure storage is ready for use.
  Future<bool> isSecureStorageAvailable();

  /// Gets storage statistics and information
  /// 
  /// Returns information about the current storage usage including:
  /// - Number of stored configurations
  /// - Storage space used
  /// - Last backup timestamp (if applicable)
  /// 
  /// Returns null if storage information cannot be retrieved.
  Future<StorageInfo?> getStorageInfo();
}

/// Exception thrown by configuration operations
class ConfigurationException implements Exception {
  final String message;
  final String? code;
  final dynamic details;

  const ConfigurationException(this.message, {this.code, this.details});

  @override
  String toString() {
    if (code != null) {
      return 'ConfigurationException($code): $message';
    }
    return 'ConfigurationException: $message';
  }
}

/// Information about configuration storage usage and status
class StorageInfo {
  /// Number of configurations currently stored
  final int configurationCount;
  
  /// Approximate storage space used in bytes
  final int storageUsedBytes;
  
  /// Timestamp of last backup operation (if applicable)
  final DateTime? lastBackupTime;
  
  /// Whether secure storage is encrypted
  final bool isEncrypted;
  
  /// Platform-specific storage location or identifier
  final String? storageLocation;

  const StorageInfo({
    required this.configurationCount,
    required this.storageUsedBytes,
    this.lastBackupTime,
    required this.isEncrypted,
    this.storageLocation,
  });

  @override
  String toString() {
    return 'StorageInfo(configurationCount: $configurationCount, '
           'storageUsedBytes: $storageUsedBytes, lastBackupTime: $lastBackupTime, '
           'isEncrypted: $isEncrypted, storageLocation: $storageLocation)';
  }
}