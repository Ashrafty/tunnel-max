import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:logger/logger.dart';
import 'package:uuid/uuid.dart';

import '../models/vpn_configuration.dart';
import '../interfaces/platform_channels.dart';
import 'secure_storage_service.dart';
import 'singbox_configuration_converter.dart';

/// Exception thrown when configuration validation fails
class ConfigurationValidationException implements Exception {
  final String message;
  final String? field;
  final dynamic value;

  const ConfigurationValidationException(
    this.message, {
    this.field,
    this.value,
  });

  @override
  String toString() {
    if (field != null) {
      return 'ConfigurationValidationException: $message (field: $field, value: $value)';
    }
    return 'ConfigurationValidationException: $message';
  }
}

/// Exception thrown when secure storage operations fail
class SecureStorageException implements Exception {
  final String message;
  final String? operation;

  const SecureStorageException(this.message, {this.operation});

  @override
  String toString() {
    if (operation != null) {
      return 'SecureStorageException: $message (operation: $operation)';
    }
    return 'SecureStorageException: $message';
  }
}

/// Configuration Manager for handling VPN configurations
/// 
/// This service provides functionality for:
/// - Configuration validation for different VPN protocols
/// - Secure storage of sensitive configuration data with encryption
/// - Import/export of singbox-compatible configuration formats
/// - Configuration backup and restore functionality
/// - Configuration lifecycle management
class ConfigurationManager {
  static const String _storageKeyPrefix = 'vpn_config_';
  static const String _configListKey = 'vpn_config_list';
  
  final FlutterSecureStorage _secureStorage;
  final MethodChannel _configChannel;
  final Logger _logger;
  final Uuid _uuid;
  final SecureStorageService _secureStorageService;
  final SingboxConfigurationConverter _singboxConverter;

  ConfigurationManager({
    FlutterSecureStorage? secureStorage,
    MethodChannel? configChannel,
    Logger? logger,
    Uuid? uuid,
    SecureStorageService? secureStorageService,
    SingboxConfigurationConverter? singboxConverter,
  })  : _secureStorage = secureStorage ?? 
            const FlutterSecureStorage(
              aOptions: AndroidOptions(
                encryptedSharedPreferences: true,
              ),
              iOptions: IOSOptions(
                accessibility: KeychainAccessibility.first_unlock_this_device,
              ),
              lOptions: LinuxOptions(),
              wOptions: WindowsOptions(),
            ),
        _configChannel = configChannel ?? 
            const MethodChannel(PlatformChannels.configuration),
        _logger = logger ?? Logger(),
        _uuid = uuid ?? const Uuid(),
        _secureStorageService = secureStorageService ?? SecureStorageService(),
        _singboxConverter = singboxConverter ?? SingboxConfigurationConverter();

  /// Validates a VPN configuration for correctness and protocol compliance
  /// 
  /// Performs both basic validation (required fields, port ranges) and
  /// protocol-specific validation based on the configuration type.
  /// 
  /// Throws [ConfigurationValidationException] if validation fails.
  Future<bool> validateConfiguration(VpnConfiguration config) async {
    try {
      _logger.d('Validating configuration: ${config.name}');

      // Basic validation
      _validateBasicFields(config);
      
      // Protocol-specific validation
      await _validateProtocolSpecific(config);
      
      // Platform-specific validation via native code
      await _validateWithNativePlatform(config);
      
      _logger.d('Configuration validation successful: ${config.name}');
      return true;
    } catch (e) {
      _logger.e('Configuration validation failed: $e');
      rethrow;
    }
  }

  /// Saves a VPN configuration to secure storage
  /// 
  /// The configuration is validated before saving and stored with encryption.
  /// If a configuration with the same ID already exists, it will be updated.
  Future<void> saveConfiguration(VpnConfiguration config) async {
    try {
      _logger.d('Saving configuration: ${config.name}');

      // Validate before saving
      await validateConfiguration(config);

      // Save to secure storage
      final configJson = jsonEncode(config.toJson());
      final storageKey = _storageKeyPrefix + config.id;
      
      await _secureStorage.write(key: storageKey, value: configJson);
      
      // Update configuration list
      await _updateConfigurationList(config.id, add: true);
      
      _logger.i('Configuration saved successfully: ${config.name}');
    } catch (e) {
      _logger.e('Failed to save configuration: $e');
      throw SecureStorageException(
        'Failed to save configuration: $e',
        operation: 'save',
      );
    }
  }

  /// Loads all VPN configurations from secure storage
  Future<List<VpnConfiguration>> loadConfigurations() async {
    try {
      _logger.d('Loading all configurations');

      final configIds = await _getConfigurationIds();
      final configurations = <VpnConfiguration>[];

      for (final id in configIds) {
        try {
          final config = await loadConfiguration(id);
          if (config != null) {
            configurations.add(config);
          }
        } catch (e) {
          _logger.w('Failed to load configuration $id: $e');
          // Continue loading other configurations
        }
      }

      _logger.d('Loaded ${configurations.length} configurations');
      return configurations;
    } catch (e) {
      _logger.e('Failed to load configurations: $e');
      throw SecureStorageException(
        'Failed to load configurations: $e',
        operation: 'load_all',
      );
    }
  }

  /// Loads a specific VPN configuration by ID
  Future<VpnConfiguration?> loadConfiguration(String id) async {
    try {
      _logger.d('Loading configuration: $id');

      final storageKey = _storageKeyPrefix + id;
      final configJson = await _secureStorage.read(key: storageKey);
      
      if (configJson == null) {
        _logger.w('Configuration not found: $id');
        return null;
      }

      final configMap = jsonDecode(configJson) as Map<String, dynamic>;
      final config = VpnConfiguration.fromJson(configMap);
      
      _logger.d('Configuration loaded successfully: ${config.name}');
      return config;
    } catch (e) {
      _logger.e('Failed to load configuration $id: $e');
      throw SecureStorageException(
        'Failed to load configuration: $e',
        operation: 'load',
      );
    }
  }

  /// Updates an existing VPN configuration
  Future<void> updateConfiguration(VpnConfiguration config) async {
    try {
      _logger.d('Updating configuration: ${config.name}');

      // Check if configuration exists
      final existing = await loadConfiguration(config.id);
      if (existing == null) {
        throw ConfigurationValidationException(
          'Configuration not found for update: ${config.id}',
        );
      }

      // Update with current timestamp for lastUsed if it was connected
      final updatedConfig = config.copyWith(
        lastUsed: config.lastUsed ?? existing.lastUsed,
      );

      await saveConfiguration(updatedConfig);
      _logger.i('Configuration updated successfully: ${config.name}');
    } catch (e) {
      _logger.e('Failed to update configuration: $e');
      rethrow;
    }
  }

  /// Deletes a VPN configuration by ID
  Future<bool> deleteConfiguration(String id) async {
    try {
      _logger.d('Deleting configuration: $id');

      final storageKey = _storageKeyPrefix + id;
      await _secureStorage.delete(key: storageKey);
      
      // Update configuration list
      await _updateConfigurationList(id, add: false);
      
      _logger.i('Configuration deleted successfully: $id');
      return true;
    } catch (e) {
      _logger.e('Failed to delete configuration $id: $e');
      throw SecureStorageException(
        'Failed to delete configuration: $e',
        operation: 'delete',
      );
    }
  }

  /// Deletes all VPN configurations
  Future<void> deleteAllConfigurations() async {
    try {
      _logger.d('Deleting all configurations');

      final configIds = await _getConfigurationIds();
      
      for (final id in configIds) {
        await deleteConfiguration(id);
      }
      
      // Clear the configuration list
      await _secureStorage.delete(key: _configListKey);
      
      _logger.i('All configurations deleted successfully');
    } catch (e) {
      _logger.e('Failed to delete all configurations: $e');
      throw SecureStorageException(
        'Failed to delete all configurations: $e',
        operation: 'delete_all',
      );
    }
  }

  /// Imports VPN configurations from JSON string
  /// 
  /// Supports both single configuration and array of configurations.
  /// Compatible with singbox configuration formats.
  Future<List<VpnConfiguration>> importFromJson(String jsonString) async {
    try {
      _logger.d('Importing configurations from JSON');

      final jsonData = jsonDecode(jsonString);
      final importedConfigs = <VpnConfiguration>[];

      if (jsonData is List) {
        // Array of configurations
        for (final configData in jsonData) {
          if (configData is Map<String, dynamic>) {
            final config = await _importSingleConfiguration(configData);
            if (config != null) {
              importedConfigs.add(config);
            }
          }
        }
      } else if (jsonData is Map<String, dynamic>) {
        // Single configuration or singbox format
        final config = await _importSingleConfiguration(jsonData);
        if (config != null) {
          importedConfigs.add(config);
        }
      } else {
        throw ConfigurationValidationException(
          'Invalid JSON format for configuration import',
        );
      }

      _logger.i('Imported ${importedConfigs.length} configurations');
      return importedConfigs;
    } catch (e) {
      _logger.e('Failed to import configurations: $e');
      rethrow;
    }
  }

  /// Exports VPN configurations to JSON string
  /// 
  /// Can export specific configurations or all configurations.
  /// Optionally includes sensitive data based on the flag.
  Future<String> exportToJson({
    List<String>? configurationIds,
    bool includeSensitiveData = false,
  }) async {
    try {
      _logger.d('Exporting configurations to JSON');

      List<VpnConfiguration> configurationsToExport;
      
      if (configurationIds != null && configurationIds.isNotEmpty) {
        configurationsToExport = [];
        for (final id in configurationIds) {
          final config = await loadConfiguration(id);
          if (config != null) {
            configurationsToExport.add(config);
          }
        }
      } else {
        configurationsToExport = await loadConfigurations();
      }

      final exportData = configurationsToExport.map((config) {
        final configJson = config.toJson();
        
        if (!includeSensitiveData) {
          // Remove sensitive fields for export
          configJson.remove('protocolSpecificConfig');
          configJson['protocolSpecificConfig'] = <String, dynamic>{};
        }
        
        return configJson;
      }).toList();

      final jsonString = jsonEncode(exportData);
      _logger.i('Exported ${configurationsToExport.length} configurations');
      return jsonString;
    } catch (e) {
      _logger.e('Failed to export configurations: $e');
      throw SecureStorageException(
        'Failed to export configurations: $e',
        operation: 'export',
      );
    }
  }

  /// Checks if secure storage is available on the current platform
  Future<bool> isSecureStorageAvailable() async {
    try {
      // Test write and read operation
      const testKey = 'test_storage_availability';
      const testValue = 'test';
      
      await _secureStorage.write(key: testKey, value: testValue);
      final readValue = await _secureStorage.read(key: testKey);
      await _secureStorage.delete(key: testKey);
      
      return readValue == testValue;
    } catch (e) {
      _logger.w('Secure storage not available: $e');
      return false;
    }
  }

  /// Gets storage information and statistics
  Future<Map<String, dynamic>> getStorageInfo() async {
    try {
      final configIds = await _getConfigurationIds();
      final allKeys = await _secureStorage.readAll();
      final vpnConfigKeys = allKeys.keys
          .where((key) => key.startsWith(_storageKeyPrefix))
          .toList();

      return {
        'totalConfigurations': configIds.length,
        'storageKeys': vpnConfigKeys.length,
        'isAvailable': await isSecureStorageAvailable(),
        'lastAccessed': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      _logger.e('Failed to get storage info: $e');
      return {
        'totalConfigurations': 0,
        'storageKeys': 0,
        'isAvailable': false,
        'error': e.toString(),
      };
    }
  }

  /// Creates a new configuration with generated ID
  VpnConfiguration createConfiguration({
    required String name,
    required String serverAddress,
    required int serverPort,
    required VpnProtocol protocol,
    required AuthenticationMethod authMethod,
    Map<String, dynamic>? protocolSpecificConfig,
    bool autoConnect = false,
  }) {
    return VpnConfiguration(
      id: _uuid.v4(),
      name: name,
      serverAddress: serverAddress,
      serverPort: serverPort,
      protocol: protocol,
      authMethod: authMethod,
      protocolSpecificConfig: protocolSpecificConfig ?? {},
      autoConnect: autoConnect,
      createdAt: DateTime.now(),
    );
  }

  /// Enhanced secure storage methods using SecureStorageService

  /// Initializes the secure storage service
  Future<void> initializeSecureStorage() async {
    try {
      await _secureStorageService.initialize();
      _logger.i('Secure storage service initialized');
    } catch (e) {
      _logger.e('Failed to initialize secure storage service: $e');
      rethrow;
    }
  }

  /// Saves configuration with enhanced encryption
  Future<void> saveConfigurationSecure(VpnConfiguration config) async {
    try {
      _logger.d('Saving configuration with enhanced security: ${config.name}');

      // Validate before saving
      await validateConfiguration(config);

      // Use enhanced secure storage service
      await _secureStorageService.saveEncryptedConfiguration(config);
      
      _logger.i('Configuration saved with enhanced security: ${config.name}');
    } catch (e) {
      _logger.e('Failed to save configuration securely: $e');
      rethrow;
    }
  }

  /// Loads configuration with enhanced decryption
  Future<VpnConfiguration?> loadConfigurationSecure(String id) async {
    try {
      _logger.d('Loading configuration with enhanced security: $id');
      
      final config = await _secureStorageService.loadEncryptedConfiguration(id);
      
      if (config != null) {
        _logger.d('Configuration loaded with enhanced security: ${config.name}');
      } else {
        _logger.w('Configuration not found: $id');
      }
      
      return config;
    } catch (e) {
      _logger.e('Failed to load configuration securely: $e');
      rethrow;
    }
  }

  /// Loads all configurations with enhanced decryption
  Future<List<VpnConfiguration>> loadAllConfigurationsSecure() async {
    try {
      _logger.d('Loading all configurations with enhanced security');
      
      final configurations = await _secureStorageService.loadAllEncryptedConfigurations();
      
      _logger.d('Loaded ${configurations.length} configurations with enhanced security');
      return configurations;
    } catch (e) {
      _logger.e('Failed to load all configurations securely: $e');
      rethrow;
    }
  }

  /// Deletes configuration with enhanced security
  Future<bool> deleteConfigurationSecure(String id) async {
    try {
      _logger.d('Deleting configuration with enhanced security: $id');
      
      final result = await _secureStorageService.deleteEncryptedConfiguration(id);
      
      if (result) {
        _logger.i('Configuration deleted with enhanced security: $id');
      }
      
      return result;
    } catch (e) {
      _logger.e('Failed to delete configuration securely: $e');
      rethrow;
    }
  }

  /// Creates an encrypted backup of all configurations
  Future<String> createEncryptedBackup({
    String? backupPath,
    bool includeMetadata = true,
  }) async {
    try {
      _logger.d('Creating encrypted backup of configurations');
      
      final backupFilePath = await _secureStorageService.createEncryptedBackup(
        backupPath: backupPath,
        includeMetadata: includeMetadata,
      );
      
      _logger.i('Encrypted backup created successfully: $backupFilePath');
      return backupFilePath;
    } catch (e) {
      _logger.e('Failed to create encrypted backup: $e');
      throw SecureStorageException(
        'Failed to create backup: $e',
        operation: 'backup',
      );
    }
  }

  /// Restores configurations from an encrypted backup
  Future<int> restoreFromEncryptedBackup(
    String backupPath, {
    bool overwriteExisting = false,
  }) async {
    try {
      _logger.d('Restoring configurations from encrypted backup: $backupPath');
      
      final restoredCount = await _secureStorageService.restoreFromEncryptedBackup(
        backupPath,
        overwriteExisting: overwriteExisting,
      );
      
      _logger.i('Restored $restoredCount configurations from encrypted backup');
      return restoredCount;
    } catch (e) {
      _logger.e('Failed to restore from encrypted backup: $e');
      throw SecureStorageException(
        'Failed to restore backup: $e',
        operation: 'restore',
      );
    }
  }

  /// Gets enhanced storage information including encryption status
  Future<Map<String, dynamic>> getEnhancedStorageInfo() async {
    try {
      final basicInfo = await getStorageInfo();
      final secureStorageInfo = await _secureStorageService.getStorageInfo();
      
      return {
        ...basicInfo,
        'enhancedSecurity': {
          'configurationCount': secureStorageInfo.configurationCount,
          'storageUsedBytes': secureStorageInfo.storageUsedBytes,
          'isEncrypted': secureStorageInfo.isEncrypted,
          'storageLocation': secureStorageInfo.storageLocation,
          'lastBackupTime': secureStorageInfo.lastBackupTime?.toIso8601String(),
        },
        'secureStorageAvailable': await _secureStorageService.isSecureStorageAvailable(),
      };
    } catch (e) {
      _logger.e('Failed to get enhanced storage info: $e');
      return {
        'error': e.toString(),
        'secureStorageAvailable': false,
      };
    }
  }

  /// Migrates existing configurations to enhanced secure storage
  Future<int> migrateToEnhancedStorage() async {
    try {
      _logger.d('Migrating configurations to enhanced secure storage');
      
      // Initialize secure storage service
      await initializeSecureStorage();
      
      // Load existing configurations using standard storage
      final existingConfigs = await loadConfigurations();
      
      int migratedCount = 0;
      for (final config in existingConfigs) {
        try {
          // Save to enhanced storage
          await _secureStorageService.saveEncryptedConfiguration(config);
          migratedCount++;
        } catch (e) {
          _logger.w('Failed to migrate configuration ${config.name}: $e');
          // Continue with other configurations
        }
      }
      
      _logger.i('Migrated $migratedCount configurations to enhanced secure storage');
      return migratedCount;
    } catch (e) {
      _logger.e('Failed to migrate to enhanced storage: $e');
      throw SecureStorageException(
        'Failed to migrate configurations: $e',
        operation: 'migrate',
      );
    }
  }

  /// Clears all secure storage data (use with extreme caution)
  Future<void> clearAllSecureData() async {
    try {
      _logger.w('Clearing all secure storage data');
      
      // Clear enhanced secure storage
      await _secureStorageService.clearAllData();
      
      // Clear standard storage as well
      await deleteAllConfigurations();
      
      _logger.i('All secure storage data cleared');
    } catch (e) {
      _logger.e('Failed to clear all secure data: $e');
      throw SecureStorageException(
        'Failed to clear secure data: $e',
        operation: 'clear_all',
      );
    }
  }

  /// Sing-box Configuration Integration Methods

  /// Converts a VPN configuration to sing-box format
  /// 
  /// Uses the integrated SingboxConfigurationConverter to transform
  /// the application's VPN configuration into a sing-box compatible format.
  /// 
  /// Throws [ConfigurationConversionException] if conversion fails.
  Map<String, dynamic> convertToSingboxFormat(VpnConfiguration config) {
    try {
      _logger.d('Converting configuration to sing-box format: ${config.name}');
      
      // Validate protocol support before conversion
      if (!isSingboxProtocolSupported(config.protocol)) {
        throw ConfigurationValidationException(
          'Protocol ${config.protocol.name} is not supported by sing-box',
          field: 'protocol',
          value: config.protocol.name,
        );
      }
      
      final singboxConfig = _singboxConverter.convertToSingboxConfig(config);
      
      _logger.d('Configuration converted to sing-box format successfully: ${config.name}');
      return singboxConfig;
    } catch (e) {
      _logger.e('Failed to convert configuration to sing-box format: $e');
      rethrow;
    }
  }

  /// Validates a sing-box configuration for correctness
  /// 
  /// Uses the integrated SingboxConfigurationConverter to validate
  /// the structure and content of a sing-box configuration.
  /// 
  /// Returns true if valid, throws [ConfigurationConversionException] if invalid.
  bool validateSingboxConfiguration(Map<String, dynamic> singboxConfig) {
    try {
      _logger.d('Validating sing-box configuration');
      
      final isValid = _singboxConverter.validateSingboxConfig(singboxConfig);
      
      _logger.d('Sing-box configuration validation successful');
      return isValid;
    } catch (e) {
      _logger.e('Sing-box configuration validation failed: $e');
      rethrow;
    }
  }

  /// Gets list of protocols supported for sing-box conversion
  /// 
  /// Returns the list of VPN protocols that can be converted to sing-box format.
  List<VpnProtocol> getSupportedSingboxProtocols() {
    return _singboxConverter.getSupportedProtocols();
  }

  /// Checks if a protocol is supported for sing-box conversion
  /// 
  /// Returns true if the protocol can be converted to sing-box format.
  bool isSingboxProtocolSupported(VpnProtocol protocol) {
    return _singboxConverter.isProtocolSupported(protocol);
  }

  /// Validates protocol-specific configuration for sing-box compatibility
  /// 
  /// Performs comprehensive validation of protocol-specific fields
  /// to ensure they meet sing-box requirements.
  bool validateProtocolForSingbox(VpnConfiguration config) {
    try {
      _logger.d('Validating protocol configuration for sing-box: ${config.protocol.name}');
      
      // Check if protocol is supported
      if (!isSingboxProtocolSupported(config.protocol)) {
        throw ConfigurationValidationException(
          'Protocol ${config.protocol.name} is not supported by sing-box',
          field: 'protocol',
          value: config.protocol.name,
        );
      }

      final protocolConfig = config.protocolSpecificConfig;

      // Validate protocol-specific requirements
      switch (config.protocol) {
        case VpnProtocol.vless:
          _validateVlessForSingbox(protocolConfig);
          break;
        case VpnProtocol.vmess:
          _validateVmessForSingbox(protocolConfig);
          break;
        case VpnProtocol.trojan:
          _validateTrojanForSingbox(protocolConfig);
          break;
        case VpnProtocol.shadowsocks:
          _validateShadowsocksForSingbox(protocolConfig);
          break;
        default:
          throw ConfigurationValidationException(
            'Unsupported protocol for sing-box validation: ${config.protocol.name}',
            field: 'protocol',
            value: config.protocol.name,
          );
      }

      _logger.d('Protocol validation for sing-box successful: ${config.protocol.name}');
      return true;
    } catch (e) {
      _logger.e('Protocol validation for sing-box failed: $e');
      rethrow;
    }
  }

  /// Exports configurations in sing-box format
  /// 
  /// Converts and exports VPN configurations as sing-box compatible JSON.
  /// Can export specific configurations or all configurations.
  /// 
  /// Only exports configurations that are supported by sing-box.
  Future<String> exportToSingboxFormat({
    List<String>? configurationIds,
  }) async {
    try {
      _logger.d('Exporting configurations to sing-box format');

      List<VpnConfiguration> configurationsToExport;
      
      if (configurationIds != null && configurationIds.isNotEmpty) {
        configurationsToExport = [];
        for (final id in configurationIds) {
          final config = await loadConfiguration(id);
          if (config != null) {
            configurationsToExport.add(config);
          }
        }
      } else {
        configurationsToExport = await loadConfigurations();
      }

      // Filter configurations that are supported by sing-box
      final supportedConfigs = configurationsToExport
          .where((config) => isSingboxProtocolSupported(config.protocol))
          .toList();

      if (supportedConfigs.isEmpty) {
        throw ConfigurationValidationException(
          'No configurations found that are supported by sing-box',
        );
      }

      final exportData = <Map<String, dynamic>>[];
      for (final config in supportedConfigs) {
        try {
          final singboxConfig = convertToSingboxFormat(config);
          exportData.add(singboxConfig);
        } catch (e) {
          _logger.w('Failed to convert configuration ${config.name} to sing-box format: $e');
          // Continue with other configurations
        }
      }

      final jsonString = jsonEncode(exportData);
      _logger.i('Exported ${exportData.length} configurations in sing-box format');
      return jsonString;
    } catch (e) {
      _logger.e('Failed to export configurations in sing-box format: $e');
      throw SecureStorageException(
        'Failed to export sing-box configurations: $e',
        operation: 'export_singbox',
      );
    }
  }

  /// Enhanced validation that includes sing-box compatibility check
  /// 
  /// Performs standard validation plus checks if the configuration
  /// can be successfully converted to sing-box format.
  Future<bool> validateConfigurationWithSingboxSupport(VpnConfiguration config) async {
    try {
      _logger.d('Validating configuration with sing-box support: ${config.name}');

      // Perform standard validation first
      await validateConfiguration(config);

      // Check if protocol is supported by sing-box
      if (!isSingboxProtocolSupported(config.protocol)) {
        throw ConfigurationValidationException(
          'Protocol ${config.protocol.name} is not supported by sing-box',
          field: 'protocol',
          value: config.protocol.name,
        );
      }

      // Try to convert to sing-box format to ensure compatibility
      try {
        convertToSingboxFormat(config);
      } catch (e) {
        throw ConfigurationValidationException(
          'Configuration cannot be converted to sing-box format: $e',
        );
      }

      _logger.d('Configuration validation with sing-box support successful: ${config.name}');
      return true;
    } catch (e) {
      _logger.e('Configuration validation with sing-box support failed: $e');
      rethrow;
    }
  }

  // Private helper methods

  void _validateBasicFields(VpnConfiguration config) {
    if (config.id.isEmpty) {
      throw ConfigurationValidationException(
        'Configuration ID cannot be empty',
        field: 'id',
        value: config.id,
      );
    }

    if (config.name.isEmpty) {
      throw ConfigurationValidationException(
        'Configuration name cannot be empty',
        field: 'name',
        value: config.name,
      );
    }

    if (config.serverAddress.isEmpty) {
      throw ConfigurationValidationException(
        'Server address cannot be empty',
        field: 'serverAddress',
        value: config.serverAddress,
      );
    }

    if (config.serverPort < 1 || config.serverPort > 65535) {
      throw ConfigurationValidationException(
        'Server port must be between 1 and 65535',
        field: 'serverPort',
        value: config.serverPort,
      );
    }
  }

  Future<void> _validateProtocolSpecific(VpnConfiguration config) async {
    // Perform basic protocol-specific validation
    switch (config.protocol) {
      case VpnProtocol.shadowsocks:
        _validateShadowsocksConfig(config);
        break;
      case VpnProtocol.vmess:
        _validateVmessConfig(config);
        break;
      case VpnProtocol.vless:
        _validateVlessConfig(config);
        break;
      case VpnProtocol.trojan:
        _validateTrojanConfig(config);
        break;
      case VpnProtocol.hysteria:
      case VpnProtocol.hysteria2:
        _validateHysteriaConfig(config);
        break;
      case VpnProtocol.tuic:
        _validateTuicConfig(config);
        break;
      case VpnProtocol.wireguard:
        _validateWireguardConfig(config);
        break;
    }

    // Additional validation for sing-box supported protocols
    if (isSingboxProtocolSupported(config.protocol)) {
      try {
        validateProtocolForSingbox(config);
        _logger.d('Sing-box protocol validation passed for ${config.protocol.name}');
      } catch (e) {
        _logger.w('Sing-box protocol validation failed for ${config.protocol.name}: $e');
        // Don't fail the entire validation, just log the warning
        // This allows configurations to work with other backends if sing-box validation fails
      }
    }
  }

  void _validateShadowsocksConfig(VpnConfiguration config) {
    final protocolConfig = config.protocolSpecificConfig;
    
    if (!protocolConfig.containsKey('method')) {
      throw ConfigurationValidationException(
        'Shadowsocks method is required',
        field: 'method',
      );
    }

    if (!protocolConfig.containsKey('password')) {
      throw ConfigurationValidationException(
        'Shadowsocks password is required',
        field: 'password',
      );
    }
  }

  void _validateVmessConfig(VpnConfiguration config) {
    final protocolConfig = config.protocolSpecificConfig;
    
    if (!protocolConfig.containsKey('uuid')) {
      throw ConfigurationValidationException(
        'VMess UUID is required',
        field: 'uuid',
      );
    }

    if (!protocolConfig.containsKey('alterId')) {
      throw ConfigurationValidationException(
        'VMess alterId is required',
        field: 'alterId',
      );
    }
  }

  void _validateVlessConfig(VpnConfiguration config) {
    final protocolConfig = config.protocolSpecificConfig;
    
    if (!protocolConfig.containsKey('uuid')) {
      throw ConfigurationValidationException(
        'VLESS UUID is required',
        field: 'uuid',
      );
    }
  }

  void _validateTrojanConfig(VpnConfiguration config) {
    final protocolConfig = config.protocolSpecificConfig;
    
    if (!protocolConfig.containsKey('password')) {
      throw ConfigurationValidationException(
        'Trojan password is required',
        field: 'password',
      );
    }
  }

  void _validateHysteriaConfig(VpnConfiguration config) {
    final protocolConfig = config.protocolSpecificConfig;
    
    if (!protocolConfig.containsKey('auth')) {
      throw ConfigurationValidationException(
        'Hysteria auth is required',
        field: 'auth',
      );
    }
  }

  void _validateTuicConfig(VpnConfiguration config) {
    final protocolConfig = config.protocolSpecificConfig;
    
    if (!protocolConfig.containsKey('uuid')) {
      throw ConfigurationValidationException(
        'TUIC UUID is required',
        field: 'uuid',
      );
    }

    if (!protocolConfig.containsKey('password')) {
      throw ConfigurationValidationException(
        'TUIC password is required',
        field: 'password',
      );
    }
  }

  void _validateWireguardConfig(VpnConfiguration config) {
    final protocolConfig = config.protocolSpecificConfig;
    
    if (!protocolConfig.containsKey('privateKey')) {
      throw ConfigurationValidationException(
        'WireGuard private key is required',
        field: 'privateKey',
      );
    }

    if (!protocolConfig.containsKey('publicKey')) {
      throw ConfigurationValidationException(
        'WireGuard public key is required',
        field: 'publicKey',
      );
    }
  }

  Future<void> _validateWithNativePlatform(VpnConfiguration config) async {
    try {
      final message = PlatformMessages.validateConfigurationMessage(
        config.toJson(),
      );
      
      final rawResponse = await _configChannel.invokeMethod(
        ConfigurationMethods.validateConfiguration,
        message,
      );

      // Safely convert the response to Map<String, dynamic>
      Map<String, dynamic>? response;
      if (rawResponse is Map) {
        response = Map<String, dynamic>.from(rawResponse);
      }

      if (response != null && !PlatformResponses.isSuccessResponse(response)) {
        throw ConfigurationValidationException(
          PlatformResponses.getErrorMessage(response),
        );
      }
    } on PlatformException catch (e) {
      throw ConfigurationValidationException(
        'Platform validation failed: ${e.message}',
      );
    } catch (e) {
      throw ConfigurationValidationException(
        'Configuration validation error: ${e.toString()}',
      );
    }
  }

  Future<List<String>> _getConfigurationIds() async {
    try {
      final configListJson = await _secureStorage.read(key: _configListKey);
      if (configListJson == null) {
        return [];
      }

      final configList = jsonDecode(configListJson) as List<dynamic>;
      return configList.cast<String>();
    } catch (e) {
      _logger.w('Failed to get configuration IDs: $e');
      return [];
    }
  }

  Future<void> _updateConfigurationList(String configId, {required bool add}) async {
    try {
      final currentIds = await _getConfigurationIds();
      
      if (add) {
        if (!currentIds.contains(configId)) {
          currentIds.add(configId);
        }
      } else {
        currentIds.remove(configId);
      }

      final configListJson = jsonEncode(currentIds);
      await _secureStorage.write(key: _configListKey, value: configListJson);
    } catch (e) {
      _logger.w('Failed to update configuration list: $e');
    }
  }

  Future<VpnConfiguration?> _importSingleConfiguration(
    Map<String, dynamic> configData,
  ) async {
    try {
      // Check if this is a singbox format that needs conversion
      if (configData.containsKey('outbounds') || configData.containsKey('inbounds')) {
        configData = _convertSingboxFormat(configData);
      }

      // Ensure required fields exist
      if (!configData.containsKey('id')) {
        configData['id'] = _uuid.v4();
      }
      if (!configData.containsKey('createdAt')) {
        configData['createdAt'] = DateTime.now().toIso8601String();
      }

      final config = VpnConfiguration.fromJson(configData);
      await validateConfiguration(config);
      await saveConfiguration(config);
      
      return config;
    } catch (e) {
      _logger.w('Failed to import single configuration: $e');
      return null;
    }
  }

  Map<String, dynamic> _convertSingboxFormat(Map<String, dynamic> singboxConfig) {
    try {
      _logger.d('Converting sing-box format to application configuration');
      
      // First validate the sing-box configuration structure
      validateSingboxConfiguration(singboxConfig);
      
      final outbounds = singboxConfig['outbounds'] as List<dynamic>;
      
      // Find the first proxy outbound (skip direct/block outbounds)
      Map<String, dynamic>? proxyOutbound;
      for (final outbound in outbounds) {
        if (outbound is Map<String, dynamic>) {
          final type = outbound['type'] as String?;
          if (type != null && type != 'direct' && type != 'block') {
            proxyOutbound = outbound;
            break;
          }
        }
      }
      
      if (proxyOutbound == null) {
        throw ConfigurationValidationException(
          'No proxy outbound found in sing-box configuration',
        );
      }

      final type = proxyOutbound['type']?.toString() ?? '';
      final server = proxyOutbound['server']?.toString() ?? '';
      final serverPort = int.tryParse(proxyOutbound['server_port']?.toString() ?? '0') ?? 0;

      // Map sing-box protocol types to our enum values
      VpnProtocol protocol;
      switch (type.toLowerCase()) {
        case 'shadowsocks':
          protocol = VpnProtocol.shadowsocks;
          break;
        case 'vmess':
          protocol = VpnProtocol.vmess;
          break;
        case 'vless':
          protocol = VpnProtocol.vless;
          break;
        case 'trojan':
          protocol = VpnProtocol.trojan;
          break;
        case 'hysteria':
          protocol = VpnProtocol.hysteria;
          break;
        case 'hysteria2':
          protocol = VpnProtocol.hysteria2;
          break;
        case 'tuic':
          protocol = VpnProtocol.tuic;
          break;
        case 'wireguard':
          protocol = VpnProtocol.wireguard;
          break;
        default:
          throw ConfigurationValidationException(
            'Unsupported protocol type: $type',
          );
      }

      // Check if the imported protocol is supported by sing-box
      if (!isSingboxProtocolSupported(protocol)) {
        throw ConfigurationValidationException(
          'Protocol $type is not supported by sing-box converter',
          field: 'protocol',
          value: type,
        );
      }

      // Extract protocol-specific configuration
      final protocolSpecificConfig = <String, dynamic>{};
      
      // Copy relevant fields based on protocol
      switch (protocol) {
        case VpnProtocol.vless:
          if (proxyOutbound.containsKey('uuid')) {
            protocolSpecificConfig['uuid'] = proxyOutbound['uuid'];
          }
          if (proxyOutbound.containsKey('flow')) {
            protocolSpecificConfig['flow'] = proxyOutbound['flow'];
          }
          break;
        case VpnProtocol.vmess:
          if (proxyOutbound.containsKey('uuid')) {
            protocolSpecificConfig['uuid'] = proxyOutbound['uuid'];
          }
          if (proxyOutbound.containsKey('alter_id')) {
            protocolSpecificConfig['alterId'] = proxyOutbound['alter_id'];
          }
          if (proxyOutbound.containsKey('security')) {
            protocolSpecificConfig['security'] = proxyOutbound['security'];
          }
          break;
        case VpnProtocol.trojan:
          if (proxyOutbound.containsKey('password')) {
            protocolSpecificConfig['password'] = proxyOutbound['password'];
          }
          break;
        case VpnProtocol.shadowsocks:
          if (proxyOutbound.containsKey('method')) {
            protocolSpecificConfig['method'] = proxyOutbound['method'];
          }
          if (proxyOutbound.containsKey('password')) {
            protocolSpecificConfig['password'] = proxyOutbound['password'];
          }
          if (proxyOutbound.containsKey('plugin')) {
            protocolSpecificConfig['plugin'] = proxyOutbound['plugin'];
          }
          if (proxyOutbound.containsKey('plugin_opts')) {
            protocolSpecificConfig['pluginOpts'] = proxyOutbound['plugin_opts'];
          }
          break;
        default:
          // For other protocols, copy all fields
          protocolSpecificConfig.addAll(proxyOutbound);
          break;
      }

      // Extract transport configuration
      if (proxyOutbound.containsKey('transport')) {
        final transport = proxyOutbound['transport'] as Map<String, dynamic>;
        final transportType = transport['type'] as String?;
        
        if (transportType != null) {
          protocolSpecificConfig['transport'] = transportType;
          
          switch (transportType) {
            case 'ws':
              if (transport.containsKey('path')) {
                protocolSpecificConfig['path'] = transport['path'];
              }
              if (transport.containsKey('headers')) {
                final headers = transport['headers'] as Map<String, dynamic>?;
                if (headers != null && headers.containsKey('Host')) {
                  protocolSpecificConfig['host'] = headers['Host'];
                }
              }
              break;
            case 'grpc':
              if (transport.containsKey('service_name')) {
                protocolSpecificConfig['serviceName'] = transport['service_name'];
              }
              break;
            case 'http':
              if (transport.containsKey('path')) {
                protocolSpecificConfig['path'] = transport['path'];
              }
              if (transport.containsKey('host')) {
                final hosts = transport['host'] as List<dynamic>?;
                if (hosts != null && hosts.isNotEmpty) {
                  protocolSpecificConfig['host'] = hosts.first;
                }
              }
              break;
          }
        }
      }

      // Extract TLS configuration
      if (proxyOutbound.containsKey('tls')) {
        final tls = proxyOutbound['tls'] as Map<String, dynamic>;
        if (tls['enabled'] == true) {
          protocolSpecificConfig['tls'] = true;
          if (tls.containsKey('server_name')) {
            protocolSpecificConfig['serverName'] = tls['server_name'];
          }
          if (tls.containsKey('insecure')) {
            protocolSpecificConfig['allowInsecure'] = tls['insecure'];
          }
          if (tls.containsKey('alpn')) {
            protocolSpecificConfig['alpn'] = tls['alpn'];
          }
        }
      }

      final result = {
        'id': _uuid.v4(),
        'name': proxyOutbound['tag'] ?? 'Imported Sing-box Configuration',
        'serverAddress': server,
        'serverPort': serverPort,
        'protocol': protocol.name,
        'authMethod': _determineAuthMethod(protocol, protocolSpecificConfig).name,
        'protocolSpecificConfig': protocolSpecificConfig,
        'autoConnect': false,
        'createdAt': DateTime.now().toIso8601String(),
      };

      _logger.d('Sing-box format converted to application configuration successfully');
      return result;
    } catch (e) {
      _logger.e('Failed to convert sing-box format: $e');
      rethrow;
    }
  }

  /// Determines the appropriate authentication method based on protocol and config
  AuthenticationMethod _determineAuthMethod(VpnProtocol protocol, Map<String, dynamic> config) {
    switch (protocol) {
      case VpnProtocol.shadowsocks:
      case VpnProtocol.trojan:
        return AuthenticationMethod.password;
      case VpnProtocol.vless:
      case VpnProtocol.vmess:
        return AuthenticationMethod.token;
      case VpnProtocol.wireguard:
        return AuthenticationMethod.certificate;
      default:
        return AuthenticationMethod.none;
    }
  }

  // Protocol-specific validation methods for sing-box compatibility

  void _validateVlessForSingbox(Map<String, dynamic> protocolConfig) {
    if (!protocolConfig.containsKey('uuid') || 
        (protocolConfig['uuid'] as String).isEmpty) {
      throw ConfigurationValidationException(
        'VLESS UUID is required for sing-box compatibility',
        field: 'uuid',
      );
    }

    // Validate UUID format
    final uuid = protocolConfig['uuid'] as String;
    final uuidRegex = RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$');
    if (!uuidRegex.hasMatch(uuid)) {
      throw ConfigurationValidationException(
        'Invalid UUID format for VLESS',
        field: 'uuid',
        value: uuid,
      );
    }

    // Validate flow if present
    if (protocolConfig.containsKey('flow')) {
      final flow = protocolConfig['flow'] as String;
      final validFlows = ['xtls-rprx-vision', 'xtls-rprx-vision-udp443'];
      if (flow.isNotEmpty && !validFlows.contains(flow)) {
        throw ConfigurationValidationException(
          'Invalid flow control for VLESS: $flow',
          field: 'flow',
          value: flow,
        );
      }
    }

    // Validate transport type if present
    if (protocolConfig.containsKey('transport')) {
      final transport = protocolConfig['transport'] as String;
      final validTransports = ['tcp', 'ws', 'grpc', 'http'];
      if (!validTransports.contains(transport.toLowerCase())) {
        throw ConfigurationValidationException(
          'Unsupported transport type for VLESS: $transport',
          field: 'transport',
          value: transport,
        );
      }
    }
  }

  void _validateVmessForSingbox(Map<String, dynamic> protocolConfig) {
    if (!protocolConfig.containsKey('uuid') || 
        (protocolConfig['uuid'] as String).isEmpty) {
      throw ConfigurationValidationException(
        'VMess UUID is required for sing-box compatibility',
        field: 'uuid',
      );
    }

    // Validate UUID format
    final uuid = protocolConfig['uuid'] as String;
    final uuidRegex = RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$');
    if (!uuidRegex.hasMatch(uuid)) {
      throw ConfigurationValidationException(
        'Invalid UUID format for VMess',
        field: 'uuid',
        value: uuid,
      );
    }

    // Validate security method if present
    if (protocolConfig.containsKey('security')) {
      final security = protocolConfig['security'] as String;
      final validSecurity = ['auto', 'aes-128-gcm', 'chacha20-poly1305', 'none'];
      if (!validSecurity.contains(security)) {
        throw ConfigurationValidationException(
          'Invalid security method for VMess: $security',
          field: 'security',
          value: security,
        );
      }
    }

    // Validate alterId if present
    if (protocolConfig.containsKey('alterId')) {
      final alterId = protocolConfig['alterId'];
      if (alterId is! int || alterId < 0 || alterId > 65535) {
        throw ConfigurationValidationException(
          'Invalid alterId for VMess: must be integer between 0-65535',
          field: 'alterId',
          value: alterId,
        );
      }
    }

    // Validate transport type if present
    if (protocolConfig.containsKey('transport')) {
      final transport = protocolConfig['transport'] as String;
      final validTransports = ['tcp', 'ws', 'grpc', 'http'];
      if (!validTransports.contains(transport.toLowerCase())) {
        throw ConfigurationValidationException(
          'Unsupported transport type for VMess: $transport',
          field: 'transport',
          value: transport,
        );
      }
    }
  }

  void _validateTrojanForSingbox(Map<String, dynamic> protocolConfig) {
    if (!protocolConfig.containsKey('password') || 
        (protocolConfig['password'] as String).isEmpty) {
      throw ConfigurationValidationException(
        'Trojan password is required for sing-box compatibility',
        field: 'password',
      );
    }

    // Validate password length (reasonable minimum)
    final password = protocolConfig['password'] as String;
    if (password.length < 8) {
      throw ConfigurationValidationException(
        'Trojan password should be at least 8 characters long',
        field: 'password',
      );
    }

    // Validate transport type if present
    if (protocolConfig.containsKey('transport')) {
      final transport = protocolConfig['transport'] as String;
      final validTransports = ['tcp', 'ws'];
      if (!validTransports.contains(transport.toLowerCase())) {
        throw ConfigurationValidationException(
          'Unsupported transport type for Trojan: $transport',
          field: 'transport',
          value: transport,
        );
      }
    }

    // Validate TLS configuration (Trojan requires TLS)
    if (protocolConfig.containsKey('tls') && protocolConfig['tls'] == false) {
      throw ConfigurationValidationException(
        'Trojan protocol requires TLS to be enabled',
        field: 'tls',
        value: false,
      );
    }
  }

  void _validateShadowsocksForSingbox(Map<String, dynamic> protocolConfig) {
    if (!protocolConfig.containsKey('method') || 
        (protocolConfig['method'] as String).isEmpty) {
      throw ConfigurationValidationException(
        'Shadowsocks method is required for sing-box compatibility',
        field: 'method',
      );
    }

    if (!protocolConfig.containsKey('password') || 
        (protocolConfig['password'] as String).isEmpty) {
      throw ConfigurationValidationException(
        'Shadowsocks password is required for sing-box compatibility',
        field: 'password',
      );
    }

    // Validate encryption method
    final method = protocolConfig['method'] as String;
    final validMethods = [
      'aes-128-gcm',
      'aes-192-gcm',
      'aes-256-gcm',
      'chacha20-ietf-poly1305',
      'xchacha20-ietf-poly1305',
      '2022-blake3-aes-128-gcm',
      '2022-blake3-aes-256-gcm',
      '2022-blake3-chacha20-poly1305',
    ];
    
    if (!validMethods.contains(method)) {
      throw ConfigurationValidationException(
        'Unsupported Shadowsocks method: $method',
        field: 'method',
        value: method,
      );
    }

    // Validate password length based on method
    final password = protocolConfig['password'] as String;
    if (method.startsWith('2022-blake3-')) {
      // 2022 methods require base64 encoded keys
      try {
        final decoded = base64.decode(password);
        if (method.contains('aes-128') && decoded.length != 16) {
          throw ConfigurationValidationException(
            'Invalid key length for $method: expected 16 bytes',
            field: 'password',
          );
        } else if (method.contains('aes-256') && decoded.length != 32) {
          throw ConfigurationValidationException(
            'Invalid key length for $method: expected 32 bytes',
            field: 'password',
          );
        } else if (method.contains('chacha20') && decoded.length != 32) {
          throw ConfigurationValidationException(
            'Invalid key length for $method: expected 32 bytes',
            field: 'password',
          );
        }
      } catch (e) {
        throw ConfigurationValidationException(
          'Invalid base64 encoded password for 2022 method',
          field: 'password',
        );
      }
    } else {
      // Regular methods require minimum password length
      if (password.length < 8) {
        throw ConfigurationValidationException(
          'Shadowsocks password should be at least 8 characters long',
          field: 'password',
        );
      }
    }

    // Validate plugin if present
    if (protocolConfig.containsKey('plugin')) {
      final plugin = protocolConfig['plugin'] as String;
      final validPlugins = ['obfs-local', 'v2ray-plugin'];
      if (plugin.isNotEmpty && !validPlugins.contains(plugin)) {
        _logger.w('Unknown Shadowsocks plugin: $plugin');
      }
    }
  }
}