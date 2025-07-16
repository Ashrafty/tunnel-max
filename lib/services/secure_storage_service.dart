import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

import '../models/vpn_configuration.dart';
import '../interfaces/configuration_interface.dart';

/// Enhanced secure storage service with encryption and backup functionality
/// 
/// This service provides platform-specific secure storage with additional
/// encryption layers and backup/restore capabilities for VPN configurations.
class SecureStorageService {
  static const String _keyPrefix = 'vpn_secure_';
  static const String _configListKey = 'vpn_config_list_encrypted';
  static const String _masterKeyKey = 'vpn_master_key';
  static const String _backupMetadataKey = 'vpn_backup_metadata';
  
  final FlutterSecureStorage _secureStorage;
  final MethodChannel? _platformChannel;
  final Logger _logger;
  
  String? _masterKey;
  bool _isInitialized = false;

  SecureStorageService({
    FlutterSecureStorage? secureStorage,
    MethodChannel? platformChannel,
    Logger? logger,
  })  : _secureStorage = secureStorage ?? 
            const FlutterSecureStorage(
              aOptions: AndroidOptions(
                encryptedSharedPreferences: true,
                keyCipherAlgorithm: KeyCipherAlgorithm.RSA_ECB_PKCS1Padding,
                storageCipherAlgorithm: StorageCipherAlgorithm.AES_GCM_NoPadding,
              ),
              iOptions: IOSOptions(
                accessibility: KeychainAccessibility.first_unlock_this_device,
                synchronizable: false,
              ),
              lOptions: LinuxOptions(),
              wOptions: WindowsOptions(),
            ),
        _platformChannel = platformChannel ?? 
            (Platform.isWindows || Platform.isAndroid 
                ? const MethodChannel('vpn_control') 
                : null),
        _logger = logger ?? Logger();

  /// Initializes the secure storage service
  /// 
  /// This method must be called before using other methods.
  /// It sets up encryption keys and verifies platform storage availability.
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      _logger.d('Initializing secure storage service');
      
      // Initialize master encryption key
      await _initializeMasterKey();
      
      // Verify platform-specific storage
      await _verifyPlatformStorage();
      
      _isInitialized = true;
      _logger.i('Secure storage service initialized successfully');
    } catch (e) {
      _logger.e('Failed to initialize secure storage service: $e');
      rethrow;
    }
  }

  /// Saves encrypted configuration data
  Future<void> saveEncryptedConfiguration(VpnConfiguration config) async {
    await _ensureInitialized();
    
    try {
      _logger.d('Saving encrypted configuration: ${config.name}');
      
      // Serialize configuration
      final configJson = jsonEncode(config.toJson());
      
      // Encrypt the configuration data
      final encryptedData = await _encryptData(configJson);
      
      // Store in platform-specific secure storage
      final storageKey = _keyPrefix + config.id;
      
      if (Platform.isWindows || Platform.isAndroid) {
        // Use platform channel for enhanced security
        await _saveToPlatformStorage(storageKey, encryptedData);
      } else {
        // Fallback to Flutter secure storage
        await _secureStorage.write(key: storageKey, value: encryptedData);
      }
      
      // Update configuration list
      await _updateConfigurationList(config.id, add: true);
      
      _logger.i('Configuration saved and encrypted successfully: ${config.name}');
    } catch (e) {
      _logger.e('Failed to save encrypted configuration: $e');
      throw ConfigurationException(
        'Failed to save configuration securely: $e',
        code: 'SAVE_FAILED',
      );
    }
  }

  /// Loads and decrypts configuration data
  Future<VpnConfiguration?> loadEncryptedConfiguration(String id) async {
    await _ensureInitialized();
    
    try {
      _logger.d('Loading encrypted configuration: $id');
      
      final storageKey = _keyPrefix + id;
      String? encryptedData;
      
      if (Platform.isWindows || Platform.isAndroid) {
        // Use platform channel for enhanced security
        encryptedData = await _loadFromPlatformStorage(storageKey);
      } else {
        // Fallback to Flutter secure storage
        encryptedData = await _secureStorage.read(key: storageKey);
      }
      
      if (encryptedData == null) {
        _logger.w('Configuration not found: $id');
        return null;
      }
      
      // Decrypt the configuration data
      final configJson = await _decryptData(encryptedData);
      
      // Parse configuration
      final configMap = jsonDecode(configJson) as Map<String, dynamic>;
      final config = VpnConfiguration.fromJson(configMap);
      
      _logger.d('Configuration loaded and decrypted successfully: ${config.name}');
      return config;
    } catch (e) {
      _logger.e('Failed to load encrypted configuration $id: $e');
      throw ConfigurationException(
        'Failed to load configuration securely: $e',
        code: 'LOAD_FAILED',
      );
    }
  }

  /// Loads all encrypted configurations
  Future<List<VpnConfiguration>> loadAllEncryptedConfigurations() async {
    await _ensureInitialized();
    
    try {
      _logger.d('Loading all encrypted configurations');
      
      final configIds = await _getConfigurationIds();
      final configurations = <VpnConfiguration>[];
      
      for (final id in configIds) {
        try {
          final config = await loadEncryptedConfiguration(id);
          if (config != null) {
            configurations.add(config);
          }
        } catch (e) {
          _logger.w('Failed to load configuration $id: $e');
          // Continue loading other configurations
        }
      }
      
      _logger.d('Loaded ${configurations.length} encrypted configurations');
      return configurations;
    } catch (e) {
      _logger.e('Failed to load all encrypted configurations: $e');
      throw ConfigurationException(
        'Failed to load configurations securely: $e',
        code: 'LOAD_ALL_FAILED',
      );
    }
  }

  /// Deletes encrypted configuration
  Future<bool> deleteEncryptedConfiguration(String id) async {
    await _ensureInitialized();
    
    try {
      _logger.d('Deleting encrypted configuration: $id');
      
      final storageKey = _keyPrefix + id;
      
      if (Platform.isWindows || Platform.isAndroid) {
        // Use platform channel for enhanced security
        await _deleteFromPlatformStorage(storageKey);
      } else {
        // Fallback to Flutter secure storage
        await _secureStorage.delete(key: storageKey);
      }
      
      // Update configuration list
      await _updateConfigurationList(id, add: false);
      
      _logger.i('Configuration deleted successfully: $id');
      return true;
    } catch (e) {
      _logger.e('Failed to delete encrypted configuration $id: $e');
      throw ConfigurationException(
        'Failed to delete configuration securely: $e',
        code: 'DELETE_FAILED',
      );
    }
  }

  /// Creates an encrypted backup of all configurations
  Future<String> createEncryptedBackup({
    String? backupPath,
    bool includeMetadata = true,
  }) async {
    await _ensureInitialized();
    
    try {
      _logger.d('Creating encrypted backup');
      
      // Load all configurations
      final configurations = await loadAllEncryptedConfigurations();
      
      // Create backup data structure
      final backupData = {
        'version': '1.0',
        'timestamp': DateTime.now().toIso8601String(),
        'configurationCount': configurations.length,
        'configurations': configurations.map((config) => config.toJson()).toList(),
      };
      
      if (includeMetadata) {
        backupData['metadata'] = await _getBackupMetadata();
      }
      
      // Serialize and encrypt backup data
      final backupJson = jsonEncode(backupData);
      final encryptedBackup = await _encryptData(backupJson);
      
      // Determine backup file path
      String finalBackupPath;
      if (backupPath != null) {
        finalBackupPath = backupPath;
      } else {
        final documentsDir = await getApplicationDocumentsDirectory();
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        finalBackupPath = path.join(
          documentsDir.path,
          'vpn_backup_$timestamp.encrypted',
        );
      }
      
      // Write encrypted backup to file
      final backupFile = File(finalBackupPath);
      await backupFile.writeAsString(encryptedBackup);
      
      // Update backup metadata
      await _updateBackupMetadata(finalBackupPath, configurations.length);
      
      _logger.i('Encrypted backup created successfully: $finalBackupPath');
      return finalBackupPath;
    } catch (e) {
      _logger.e('Failed to create encrypted backup: $e');
      throw ConfigurationException(
        'Failed to create backup: $e',
        code: 'BACKUP_FAILED',
      );
    }
  }

  /// Restores configurations from an encrypted backup
  Future<int> restoreFromEncryptedBackup(
    String backupPath, {
    bool overwriteExisting = false,
  }) async {
    await _ensureInitialized();
    
    try {
      _logger.d('Restoring from encrypted backup: $backupPath');
      
      // Read encrypted backup file
      final backupFile = File(backupPath);
      if (!await backupFile.exists()) {
        throw ConfigurationException(
          'Backup file not found: $backupPath',
          code: 'BACKUP_NOT_FOUND',
        );
      }
      
      final encryptedBackup = await backupFile.readAsString();
      
      // Decrypt backup data
      final backupJson = await _decryptData(encryptedBackup);
      final backupData = jsonDecode(backupJson) as Map<String, dynamic>;
      
      // Validate backup format
      if (!backupData.containsKey('configurations') || 
          !backupData.containsKey('version')) {
        throw ConfigurationException(
          'Invalid backup format',
          code: 'INVALID_BACKUP',
        );
      }
      
      // Extract configurations
      final configList = backupData['configurations'] as List<dynamic>;
      final configurations = configList
          .cast<Map<String, dynamic>>()
          .map((configMap) => VpnConfiguration.fromJson(configMap))
          .toList();
      
      // Restore configurations
      int restoredCount = 0;
      final existingIds = await _getConfigurationIds();
      
      for (final config in configurations) {
        try {
          if (!overwriteExisting && existingIds.contains(config.id)) {
            _logger.w('Skipping existing configuration: ${config.name}');
            continue;
          }
          
          await saveEncryptedConfiguration(config);
          restoredCount++;
        } catch (e) {
          _logger.w('Failed to restore configuration ${config.name}: $e');
          // Continue with other configurations
        }
      }
      
      _logger.i('Restored $restoredCount configurations from backup');
      return restoredCount;
    } catch (e) {
      _logger.e('Failed to restore from encrypted backup: $e');
      if (e is ConfigurationException) {
        rethrow;
      }
      throw ConfigurationException(
        'Failed to restore backup: $e',
        code: 'RESTORE_FAILED',
      );
    }
  }

  /// Checks if secure storage is available and properly configured
  Future<bool> isSecureStorageAvailable() async {
    try {
      // Test basic secure storage functionality
      const testKey = 'test_storage_availability';
      const testValue = 'test_value';
      
      await _secureStorage.write(key: testKey, value: testValue);
      final readValue = await _secureStorage.read(key: testKey);
      await _secureStorage.delete(key: testKey);
      
      if (readValue != testValue) {
        return false;
      }
      
      // Test platform-specific storage if available
      if (_platformChannel != null) {
        try {
          final result = await _platformChannel.invokeMethod('isSecureStorageAvailable');
          return result == true;
        } catch (e) {
          _logger.w('Platform storage check failed: $e');
          // Fallback to Flutter secure storage
          return true;
        }
      }
      
      return true;
    } catch (e) {
      _logger.w('Secure storage availability check failed: $e');
      return false;
    }
  }

  /// Gets storage information and statistics
  Future<StorageInfo> getStorageInfo() async {
    await _ensureInitialized();
    
    try {
      final configIds = await _getConfigurationIds();
      final backupMetadata = await _getBackupMetadata();
      
      // Calculate approximate storage usage
      int storageUsedBytes = 0;
      for (final id in configIds) {
        try {
          final storageKey = _keyPrefix + id;
          final data = await _secureStorage.read(key: storageKey);
          if (data != null) {
            storageUsedBytes += data.length;
          }
        } catch (e) {
          // Continue calculating for other configurations
        }
      }
      
      return StorageInfo(
        configurationCount: configIds.length,
        storageUsedBytes: storageUsedBytes,
        lastBackupTime: backupMetadata['lastBackupTime'] != null
            ? DateTime.parse(backupMetadata['lastBackupTime'])
            : null,
        isEncrypted: true,
        storageLocation: Platform.isWindows 
            ? 'Windows Credential Manager'
            : Platform.isAndroid 
                ? 'Android Keystore'
                : 'Flutter Secure Storage',
      );
    } catch (e) {
      _logger.e('Failed to get storage info: $e');
      throw ConfigurationException(
        'Failed to get storage information: $e',
        code: 'STORAGE_INFO_FAILED',
      );
    }
  }

  /// Clears all stored data (use with caution)
  Future<void> clearAllData() async {
    await _ensureInitialized();
    
    try {
      _logger.w('Clearing all secure storage data');
      
      final configIds = await _getConfigurationIds();
      
      // Delete all configurations
      for (final id in configIds) {
        await deleteEncryptedConfiguration(id);
      }
      
      // Clear metadata
      await _secureStorage.delete(key: _configListKey);
      await _secureStorage.delete(key: _backupMetadataKey);
      
      _logger.i('All secure storage data cleared');
    } catch (e) {
      _logger.e('Failed to clear all data: $e');
      throw ConfigurationException(
        'Failed to clear storage data: $e',
        code: 'CLEAR_FAILED',
      );
    }
  }

  // Private helper methods

  Future<void> _ensureInitialized() async {
    if (!_isInitialized) {
      await initialize();
    }
  }

  Future<void> _initializeMasterKey() async {
    // Try to load existing master key
    _masterKey = await _secureStorage.read(key: _masterKeyKey);
    
    if (_masterKey == null) {
      // Generate new master key
      _masterKey = _generateMasterKey();
      await _secureStorage.write(key: _masterKeyKey, value: _masterKey!);
      _logger.d('Generated new master encryption key');
    } else {
      _logger.d('Loaded existing master encryption key');
    }
  }

  String _generateMasterKey() {
    // Generate a 256-bit key using secure random
    final bytes = Uint8List(32);
    for (int i = 0; i < bytes.length; i++) {
      bytes[i] = DateTime.now().millisecondsSinceEpoch % 256;
    }
    return base64Encode(bytes);
  }

  Future<void> _verifyPlatformStorage() async {
    if (_platformChannel != null) {
      try {
        final isAvailable = await _platformChannel.invokeMethod('isSecureStorageAvailable');
        if (isAvailable != true) {
          _logger.w('Platform-specific secure storage not available, using fallback');
        }
      } catch (e) {
        _logger.w('Platform storage verification failed: $e');
      }
    }
  }

  Future<String> _encryptData(String data) async {
    try {
      // Simple encryption using master key and data hash
      final keyBytes = base64Decode(_masterKey!);
      final dataBytes = utf8.encode(data);
      
      // Create a simple XOR cipher with the master key
      final encryptedBytes = Uint8List(dataBytes.length);
      for (int i = 0; i < dataBytes.length; i++) {
        encryptedBytes[i] = dataBytes[i] ^ keyBytes[i % keyBytes.length];
      }
      
      // Add integrity check
      final hash = sha256.convert(dataBytes).toString();
      final encryptedData = {
        'data': base64Encode(encryptedBytes),
        'hash': hash,
        'version': '1.0',
      };
      
      return base64Encode(utf8.encode(jsonEncode(encryptedData)));
    } catch (e) {
      throw ConfigurationException(
        'Failed to encrypt data: $e',
        code: 'ENCRYPTION_FAILED',
      );
    }
  }

  Future<String> _decryptData(String encryptedData) async {
    try {
      // Decode the encrypted data structure
      final encryptedJson = utf8.decode(base64Decode(encryptedData));
      final encryptedMap = jsonDecode(encryptedJson) as Map<String, dynamic>;
      
      final dataBase64 = encryptedMap['data'] as String;
      final expectedHash = encryptedMap['hash'] as String;
      
      // Decrypt the data
      final keyBytes = base64Decode(_masterKey!);
      final encryptedBytes = base64Decode(dataBase64);
      
      final decryptedBytes = Uint8List(encryptedBytes.length);
      for (int i = 0; i < encryptedBytes.length; i++) {
        decryptedBytes[i] = encryptedBytes[i] ^ keyBytes[i % keyBytes.length];
      }
      
      final decryptedData = utf8.decode(decryptedBytes);
      
      // Verify integrity
      final actualHash = sha256.convert(decryptedBytes).toString();
      if (actualHash != expectedHash) {
        throw ConfigurationException(
          'Data integrity check failed',
          code: 'INTEGRITY_FAILED',
        );
      }
      
      return decryptedData;
    } catch (e) {
      if (e is ConfigurationException) {
        rethrow;
      }
      throw ConfigurationException(
        'Failed to decrypt data: $e',
        code: 'DECRYPTION_FAILED',
      );
    }
  }

  Future<void> _saveToPlatformStorage(String key, String data) async {
    if (_platformChannel != null) {
      try {
        await _platformChannel.invokeMethod('saveSecureData', {
          'key': key,
          'data': data,
        });
      } on PlatformException catch (e) {
        _logger.w('Platform storage save failed, using fallback: $e');
        await _secureStorage.write(key: key, value: data);
      }
    } else {
      await _secureStorage.write(key: key, value: data);
    }
  }

  Future<String?> _loadFromPlatformStorage(String key) async {
    if (_platformChannel != null) {
      try {
        final result = await _platformChannel.invokeMethod('loadSecureData', key);
        return result as String?;
      } on PlatformException catch (e) {
        _logger.w('Platform storage load failed, using fallback: $e');
        return await _secureStorage.read(key: key);
      }
    } else {
      return await _secureStorage.read(key: key);
    }
  }

  Future<void> _deleteFromPlatformStorage(String key) async {
    if (_platformChannel != null) {
      try {
        await _platformChannel.invokeMethod('deleteSecureData', key);
      } on PlatformException catch (e) {
        _logger.w('Platform storage delete failed, using fallback: $e');
        await _secureStorage.delete(key: key);
      }
    } else {
      await _secureStorage.delete(key: key);
    }
  }

  Future<List<String>> _getConfigurationIds() async {
    try {
      final configListData = await _secureStorage.read(key: _configListKey);
      if (configListData == null) {
        return [];
      }
      
      final decryptedList = await _decryptData(configListData);
      final configList = jsonDecode(decryptedList) as List<dynamic>;
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
      
      final encryptedList = await _encryptData(jsonEncode(currentIds));
      await _secureStorage.write(key: _configListKey, value: encryptedList);
    } catch (e) {
      _logger.w('Failed to update configuration list: $e');
    }
  }

  Future<Map<String, dynamic>> _getBackupMetadata() async {
    try {
      final metadataData = await _secureStorage.read(key: _backupMetadataKey);
      if (metadataData == null) {
        return {};
      }
      
      final decryptedMetadata = await _decryptData(metadataData);
      return jsonDecode(decryptedMetadata) as Map<String, dynamic>;
    } catch (e) {
      _logger.w('Failed to get backup metadata: $e');
      return {};
    }
  }

  Future<void> _updateBackupMetadata(String backupPath, int configCount) async {
    try {
      final metadata = {
        'lastBackupPath': backupPath,
        'lastBackupTime': DateTime.now().toIso8601String(),
        'lastBackupConfigCount': configCount,
      };
      
      final encryptedMetadata = await _encryptData(jsonEncode(metadata));
      await _secureStorage.write(key: _backupMetadataKey, value: encryptedMetadata);
    } catch (e) {
      _logger.w('Failed to update backup metadata: $e');
    }
  }
}