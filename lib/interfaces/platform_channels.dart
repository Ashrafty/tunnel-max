/// Platform channel constants and message structures for VPN operations
///
/// This file defines the method names, channel names, and message structures
/// used for communication between Flutter and native platform code.

/// Platform channel names
class PlatformChannels {
  /// Channel for VPN control operations
  static const String vpnControl = 'com.tunnelmax.vpn/control';

  /// Channel for configuration management operations
  static const String configuration = 'com.tunnelmax.vpn/configuration';

  /// Channel for receiving VPN status updates
  static const String statusUpdates = 'com.tunnelmax.vpn/status';

  /// Channel for network statistics updates
  static const String networkStats = 'com.tunnelmax.vpn/stats';
}

/// Method names for VPN control operations
class VpnControlMethods {
  /// Connect to VPN with provided configuration
  static const String connect = 'connect';

  /// Disconnect from current VPN connection
  static const String disconnect = 'disconnect';

  /// Get current VPN connection status
  static const String getStatus = 'getStatus';

  /// Get current network statistics
  static const String getNetworkStats = 'getNetworkStats';

  /// Check if VPN permission is granted
  static const String hasVpnPermission = 'hasVpnPermission';

  /// Request VPN permission from user
  static const String requestVpnPermission = 'requestVpnPermission';

  /// Start listening for status updates
  static const String startStatusUpdates = 'startStatusUpdates';

  /// Stop listening for status updates
  static const String stopStatusUpdates = 'stopStatusUpdates';

  /// Enable kill switch functionality
  static const String enableKillSwitch = 'enableKillSwitch';

  /// Disable kill switch functionality
  static const String disableKillSwitch = 'disableKillSwitch';

  /// Activate kill switch (block traffic)
  static const String activateKillSwitch = 'activateKillSwitch';

  /// Deactivate kill switch (restore traffic)
  static const String deactivateKillSwitch = 'deactivateKillSwitch';

  /// Get kill switch status
  static const String getKillSwitchStatus = 'getKillSwitchStatus';

  /// Check if kill switch is supported
  static const String isKillSwitchSupported = 'isKillSwitchSupported';

  /// Get kill switch capabilities
  static const String getKillSwitchCapabilities = 'getKillSwitchCapabilities';
}

/// Method names for configuration management operations
class ConfigurationMethods {
  /// Validate a VPN configuration
  static const String validateConfiguration = 'validateConfiguration';

  /// Save a configuration to secure storage
  static const String saveConfiguration = 'saveConfiguration';

  /// Load all configurations from secure storage
  static const String loadConfigurations = 'loadConfigurations';

  /// Load a specific configuration by ID
  static const String loadConfiguration = 'loadConfiguration';

  /// Update an existing configuration
  static const String updateConfiguration = 'updateConfiguration';

  /// Delete a configuration by ID
  static const String deleteConfiguration = 'deleteConfiguration';

  /// Delete all configurations
  static const String deleteAllConfigurations = 'deleteAllConfigurations';

  /// Import configurations from JSON
  static const String importFromJson = 'importFromJson';

  /// Export configurations to JSON
  static const String exportToJson = 'exportToJson';

  /// Check if secure storage is available
  static const String isSecureStorageAvailable = 'isSecureStorageAvailable';

  /// Get storage information and statistics
  static const String getStorageInfo = 'getStorageInfo';
}

/// Message structures for platform channel communication
class PlatformMessages {
  /// Creates a connect message with VPN configuration
  static Map<String, dynamic> connectMessage(Map<String, dynamic> config) {
    return {
      'method': VpnControlMethods.connect,
      'configuration': config,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
  }

  /// Creates a disconnect message
  static Map<String, dynamic> disconnectMessage() {
    return {
      'method': VpnControlMethods.disconnect,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
  }

  /// Creates a status request message
  static Map<String, dynamic> getStatusMessage() {
    return {
      'method': VpnControlMethods.getStatus,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
  }

  /// Creates a network stats request message
  static Map<String, dynamic> getNetworkStatsMessage() {
    return {
      'method': VpnControlMethods.getNetworkStats,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
  }

  /// Creates a permission check message
  static Map<String, dynamic> hasVpnPermissionMessage() {
    return {
      'method': VpnControlMethods.hasVpnPermission,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
  }

  /// Creates a permission request message
  static Map<String, dynamic> requestVpnPermissionMessage() {
    return {
      'method': VpnControlMethods.requestVpnPermission,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
  }

  /// Creates a save configuration message
  static Map<String, dynamic> saveConfigurationMessage(
    Map<String, dynamic> config,
  ) {
    return {
      'method': ConfigurationMethods.saveConfiguration,
      'configuration': config,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
  }

  /// Creates a load configurations message
  static Map<String, dynamic> loadConfigurationsMessage() {
    return {
      'method': ConfigurationMethods.loadConfigurations,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
  }

  /// Creates a load specific configuration message
  static Map<String, dynamic> loadConfigurationMessage(String id) {
    return {
      'method': ConfigurationMethods.loadConfiguration,
      'configurationId': id,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
  }

  /// Creates a delete configuration message
  static Map<String, dynamic> deleteConfigurationMessage(String id) {
    return {
      'method': ConfigurationMethods.deleteConfiguration,
      'configurationId': id,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
  }

  /// Creates a validate configuration message
  static Map<String, dynamic> validateConfigurationMessage(
    Map<String, dynamic> config,
  ) {
    return {
      'method': ConfigurationMethods.validateConfiguration,
      'configuration': config,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
  }

  /// Creates an import from JSON message
  static Map<String, dynamic> importFromJsonMessage(String jsonString) {
    return {
      'method': ConfigurationMethods.importFromJson,
      'jsonData': jsonString,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
  }

  /// Creates an export to JSON message
  static Map<String, dynamic> exportToJsonMessage({
    List<String>? configurationIds,
    bool includeSensitiveData = false,
  }) {
    return {
      'method': ConfigurationMethods.exportToJson,
      'configurationIds': configurationIds,
      'includeSensitiveData': includeSensitiveData,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
  }
}

/// Response message structures from native platforms
class PlatformResponses {
  /// Parses a success response
  static Map<String, dynamic> parseSuccessResponse(dynamic response) {
    if (response is Map<String, dynamic>) {
      return response;
    }
    return {'success': true, 'data': response};
  }

  /// Parses an error response
  static Map<String, dynamic> parseErrorResponse(dynamic error) {
    if (error is Map<String, dynamic>) {
      return {
        'success': false,
        'error': error['message'] ?? 'Unknown error',
        'code': error['code'],
        'details': error['details'],
      };
    }
    return {'success': false, 'error': error.toString()};
  }

  /// Checks if a response indicates success
  static bool isSuccessResponse(Map<String, dynamic> response) {
    return response['success'] == true;
  }

  /// Extracts error information from response
  static String getErrorMessage(Map<String, dynamic> response) {
    return response['error'] ?? 'Unknown error occurred';
  }

  /// Extracts error code from response
  static String? getErrorCode(Map<String, dynamic> response) {
    return response['code'];
  }

  /// Extracts data from successful response
  static dynamic getResponseData(Map<String, dynamic> response) {
    return response['data'];
  }
}

/// Event types for status update streams
class StatusUpdateEvents {
  /// VPN connection state changed
  static const String connectionStateChanged = 'connectionStateChanged';

  /// Network statistics updated
  static const String networkStatsUpdated = 'networkStatsUpdated';

  /// VPN configuration changed
  static const String configurationChanged = 'configurationChanged';

  /// Error occurred during VPN operation
  static const String errorOccurred = 'errorOccurred';

  /// Permission status changed
  static const String permissionChanged = 'permissionChanged';
}

/// Error codes for platform channel operations
class PlatformErrorCodes {
  /// Configuration validation failed
  static const String configurationInvalid = 'CONFIGURATION_INVALID';

  /// VPN permission not granted
  static const String permissionDenied = 'PERMISSION_DENIED';

  /// VPN connection failed
  static const String connectionFailed = 'CONNECTION_FAILED';

  /// Secure storage not available
  static const String storageUnavailable = 'STORAGE_UNAVAILABLE';

  /// Configuration not found
  static const String configurationNotFound = 'CONFIGURATION_NOT_FOUND';

  /// Network error occurred
  static const String networkError = 'NETWORK_ERROR';

  /// Platform not supported
  static const String platformUnsupported = 'PLATFORM_UNSUPPORTED';

  /// Invalid method call
  static const String invalidMethod = 'INVALID_METHOD';

  /// Internal platform error
  static const String internalError = 'INTERNAL_ERROR';

  /// Timeout occurred
  static const String timeout = 'TIMEOUT';
}
