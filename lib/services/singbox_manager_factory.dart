import 'dart:io';
import '../interfaces/singbox_manager_interface.dart';
import 'platform_singbox_managers/android_singbox_manager.dart';
import 'platform_singbox_managers/windows_singbox_manager.dart';
import 'platform_singbox_managers/fallback_singbox_manager.dart';

/// Factory for creating platform-specific SingboxManager instances
/// 
/// This factory provides a unified way to create SingboxManager instances
/// that are optimized for the current platform. It automatically detects
/// the platform and returns the appropriate implementation.
class SingboxManagerFactory {
  static SingboxManagerInterface? _instance;
  
  /// Get the singleton instance of the platform-specific SingboxManager
  /// 
  /// Returns the appropriate SingboxManager implementation for the current platform:
  /// - [AndroidSingboxManager] for Android
  /// - [WindowsSingboxManager] for Windows
  /// - [FallbackSingboxManager] for unsupported platforms
  static SingboxManagerInterface getInstance() {
    _instance ??= _createPlatformSpecificManager();
    return _instance!;
  }

  /// Create a new instance (useful for testing or multiple instances)
  /// 
  /// [forceAndroid] - Force creation of Android manager (for testing)
  /// [forceWindows] - Force creation of Windows manager (for testing)
  static SingboxManagerInterface createInstance({
    bool forceAndroid = false,
    bool forceWindows = false,
  }) {
    if (forceAndroid) {
      return AndroidSingboxManager();
    }
    if (forceWindows) {
      return WindowsSingboxManager();
    }
    return _createPlatformSpecificManager();
  }

  /// Reset the singleton instance (useful for testing)
  static void resetInstance() {
    _instance?.cleanup();
    _instance = null;
  }

  /// Check if the current platform is supported
  /// 
  /// Returns true if the current platform has a native SingboxManager implementation.
  static bool isPlatformSupported() {
    return Platform.isAndroid || Platform.isWindows;
  }

  /// Get the name of the current platform
  /// 
  /// Returns a string identifying the current platform.
  static String getPlatformName() {
    if (Platform.isAndroid) return 'Android';
    if (Platform.isWindows) return 'Windows';
    if (Platform.isIOS) return 'iOS';
    if (Platform.isMacOS) return 'macOS';
    if (Platform.isLinux) return 'Linux';
    return 'Unknown';
  }

  /// Get platform-specific capabilities
  /// 
  /// Returns a map of capabilities supported by the current platform.
  static Map<String, bool> getPlatformCapabilities() {
    if (Platform.isAndroid) {
      return {
        'nativeIntegration': true,
        'vpnService': true,
        'tunInterface': true,
        'backgroundExecution': true,
        'processManagement': false,
        'namedPipes': false,
        'jniInterface': true,
      };
    } else if (Platform.isWindows) {
      return {
        'nativeIntegration': true,
        'vpnService': false,
        'tunInterface': true,
        'backgroundExecution': true,
        'processManagement': true,
        'namedPipes': true,
        'jniInterface': false,
      };
    } else {
      return {
        'nativeIntegration': false,
        'vpnService': false,
        'tunInterface': false,
        'backgroundExecution': false,
        'processManagement': false,
        'namedPipes': false,
        'jniInterface': false,
      };
    }
  }

  /// Get recommended configuration for the current platform
  /// 
  /// Returns platform-specific configuration recommendations.
  static Map<String, dynamic> getPlatformRecommendations() {
    if (Platform.isAndroid) {
      return {
        'preferredMtu': 1500,
        'maxConnections': 100,
        'statsUpdateInterval': 1000, // milliseconds
        'logLevel': 'info',
        'enableMultiplexing': true,
        'enableTcpFastOpen': true,
        'preferredDnsServers': ['1.1.1.1', '8.8.8.8'],
      };
    } else if (Platform.isWindows) {
      return {
        'preferredMtu': 1500,
        'maxConnections': 200,
        'statsUpdateInterval': 1000, // milliseconds
        'logLevel': 'info',
        'enableMultiplexing': true,
        'enableTcpFastOpen': false, // Not always supported on Windows
        'preferredDnsServers': ['1.1.1.1', '8.8.8.8'],
      };
    } else {
      return {
        'preferredMtu': 1500,
        'maxConnections': 50,
        'statsUpdateInterval': 2000, // milliseconds
        'logLevel': 'warn',
        'enableMultiplexing': false,
        'enableTcpFastOpen': false,
        'preferredDnsServers': ['1.1.1.1'],
      };
    }
  }

  /// Private method to create the appropriate platform-specific manager
  static SingboxManagerInterface _createPlatformSpecificManager() {
    if (Platform.isAndroid) {
      return AndroidSingboxManager();
    } else if (Platform.isWindows) {
      return WindowsSingboxManager();
    } else {
      // For unsupported platforms, return a fallback implementation
      return FallbackSingboxManager();
    }
  }
}

/// Platform information and utilities
class PlatformInfo {
  /// Get detailed platform information
  static Map<String, dynamic> getDetailedInfo() {
    return {
      'platform': SingboxManagerFactory.getPlatformName(),
      'isSupported': SingboxManagerFactory.isPlatformSupported(),
      'capabilities': SingboxManagerFactory.getPlatformCapabilities(),
      'recommendations': SingboxManagerFactory.getPlatformRecommendations(),
      'operatingSystem': Platform.operatingSystem,
      'operatingSystemVersion': Platform.operatingSystemVersion,
      'numberOfProcessors': Platform.numberOfProcessors,
      'pathSeparator': Platform.pathSeparator,
      'environment': _getSafeEnvironmentInfo(),
    };
  }

  /// Get safe environment information (excluding sensitive data)
  static Map<String, String> _getSafeEnvironmentInfo() {
    final safeKeys = [
      'PATH',
      'HOME',
      'USER',
      'USERNAME',
      'COMPUTERNAME',
      'PROCESSOR_ARCHITECTURE',
      'NUMBER_OF_PROCESSORS',
    ];
    
    final safeEnv = <String, String>{};
    for (final key in safeKeys) {
      final value = Platform.environment[key];
      if (value != null) {
        safeEnv[key] = value;
      }
    }
    
    return safeEnv;
  }

  /// Check if running in debug mode
  static bool get isDebugMode {
    bool inDebugMode = false;
    assert(inDebugMode = true);
    return inDebugMode;
  }

  /// Get memory information if available
  static Map<String, dynamic> getMemoryInfo() {
    // This would need platform-specific implementation
    // For now, return basic info
    return {
      'available': true,
      'details': 'Platform-specific memory info not implemented',
    };
  }
}