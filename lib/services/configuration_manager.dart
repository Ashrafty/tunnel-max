import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:logger/logger.dart';
import 'package:uuid/uuid.dart';

import '../models/vpn_configuration.dart';
import '../interfaces/platform_channels.dart';
import 'secure_storage_service.dart';

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

  ConfigurationManager({
    FlutterSecureStorage? secureStorage,
    MethodChannel? configChannel,
    Logger? logger,
    Uuid? uuid,
    SecureStorageService? secureStorageService,
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
        _secureStorageService = secureStorageService ?? SecureStorageService();

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
      
      final response = await _configChannel.invokeMethod<Map<String, dynamic>>(
        ConfigurationMethods.validateConfiguration,
        message,
      );

      if (response != null && !PlatformResponses.isSuccessResponse(response)) {
        throw ConfigurationValidationException(
          PlatformResponses.getErrorMessage(response),
        );
      }
    } on PlatformException catch (e) {
      throw ConfigurationValidationException(
        'Platform validation failed: ${e.message}',
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
    // Basic conversion from singbox format to our format
    // This is a simplified conversion - in a real implementation,
    // you would need more comprehensive parsing of singbox configurations
    
    final outbounds = singboxConfig['outbounds'] as List<dynamic>?;
    if (outbounds == null || outbounds.isEmpty) {
      throw ConfigurationValidationException(
        'No outbounds found in singbox configuration',
      );
    }

    final firstOutbound = outbounds.first as Map<String, dynamic>;
    final type = firstOutbound['type'] as String?;
    final server = firstOutbound['server'] as String?;
    final serverPort = firstOutbound['server_port'] as int?;

    if (type == null || server == null || serverPort == null) {
      throw ConfigurationValidationException(
        'Invalid singbox outbound configuration',
      );
    }

    // Map singbox protocol types to our enum values
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

    return {
      'id': _uuid.v4(),
      'name': firstOutbound['tag'] ?? 'Imported Configuration',
      'serverAddress': server,
      'serverPort': serverPort,
      'protocol': protocol.name,
      'authMethod': AuthenticationMethod.password.name,
      'protocolSpecificConfig': firstOutbound,
      'autoConnect': false,
      'createdAt': DateTime.now().toIso8601String(),
    };
  }
}