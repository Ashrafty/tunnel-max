import 'dart:async';
import '../models/vpn_configuration.dart';
import '../models/network_stats.dart';

/// Abstract interface for sing-box manager operations across platforms
/// 
/// This interface defines the contract for platform-specific sing-box manager
/// implementations. It provides methods for lifecycle management, configuration,
/// statistics collection, and advanced features like network change handling.
abstract class SingboxManagerInterface {
  // Core lifecycle methods
  
  /// Initialize the sing-box manager
  /// 
  /// Must be called before any other operations.
  /// Returns true if initialization was successful.
  Future<bool> initialize();

  /// Start sing-box with the provided configuration
  /// 
  /// [config] - The VPN configuration to use
  /// [tunFileDescriptor] - Platform-specific TUN interface descriptor (Android only)
  /// 
  /// Returns true if sing-box started successfully.
  /// Throws [SingboxException] if start fails.
  Future<bool> start(VpnConfiguration config, {int? tunFileDescriptor});

  /// Stop the running sing-box instance
  /// 
  /// Returns true if sing-box stopped successfully.
  /// Throws [SingboxException] if stop fails.
  Future<bool> stop();

  /// Restart sing-box with current or new configuration
  /// 
  /// [config] - Optional new configuration. If null, uses current configuration.
  /// 
  /// Returns true if restart was successful.
  Future<bool> restart({VpnConfiguration? config});

  /// Check if sing-box is currently running
  /// 
  /// Returns true if sing-box process is active and healthy.
  Future<bool> isRunning();

  /// Clean up all resources and stop sing-box
  /// 
  /// Should be called when the manager is no longer needed.
  Future<void> cleanup();

  // Configuration management
  
  /// Validate a configuration without starting sing-box
  /// 
  /// [configJson] - The configuration in JSON format
  /// 
  /// Returns true if the configuration is valid.
  Future<bool> validateConfiguration(String configJson);

  /// Update configuration while sing-box is running (hot reload)
  /// 
  /// [config] - The new configuration to apply
  /// 
  /// Returns true if configuration was updated successfully.
  /// Only works if sing-box supports hot configuration reloading.
  Future<bool> updateConfiguration(VpnConfiguration config);

  /// Get the current active configuration
  /// 
  /// Returns the configuration JSON string, or null if not running.
  Future<String?> getCurrentConfiguration();

  // Statistics and monitoring
  
  /// Get current network statistics
  /// 
  /// Returns [NetworkStats] with current performance metrics,
  /// or null if not running or stats unavailable.
  Future<NetworkStats?> getStatistics();

  /// Get detailed network statistics with additional metrics
  /// 
  /// Returns [DetailedNetworkStats] with comprehensive metrics,
  /// or null if not running or detailed stats unavailable.
  Future<DetailedNetworkStats?> getDetailedStatistics();

  /// Reset statistics counters to zero
  /// 
  /// Returns true if statistics were reset successfully.
  Future<bool> resetStatistics();

  /// Stream of real-time network statistics
  /// 
  /// Emits [NetworkStats] objects at regular intervals while running.
  /// The stream automatically stops when sing-box is stopped.
  Stream<NetworkStats> get statisticsStream;

  // Advanced features
  
  /// Set the logging level for sing-box
  /// 
  /// [level] - Log level (0=TRACE, 1=DEBUG, 2=INFO, 3=WARN, 4=ERROR, 5=FATAL)
  /// 
  /// Returns true if log level was set successfully.
  Future<bool> setLogLevel(LogLevel level);

  /// Get recent log entries from sing-box
  /// 
  /// Returns a list of log entries, or empty list if logs unavailable.
  Future<List<String>> getLogs();

  /// Get connection information
  /// 
  /// Returns [ConnectionInfo] with current connection details,
  /// or null if not connected.
  Future<ConnectionInfo?> getConnectionInfo();

  /// Get memory usage statistics
  /// 
  /// Returns [MemoryStats] with memory usage information,
  /// or null if not available.
  Future<MemoryStats?> getMemoryUsage();

  /// Optimize performance settings
  /// 
  /// Applies platform-specific performance optimizations.
  /// Returns true if optimizations were applied successfully.
  Future<bool> optimizePerformance();

  /// Handle network change events
  /// 
  /// [networkInfo] - Information about the new network state
  /// 
  /// Returns true if network change was handled successfully.
  Future<bool> handleNetworkChange(NetworkInfo networkInfo);

  /// Get sing-box version information
  /// 
  /// Returns version string, or null if unavailable.
  Future<String?> getVersion();

  /// Get supported protocols
  /// 
  /// Returns list of protocol names supported by this sing-box build.
  Future<List<String>> getSupportedProtocols();

  // Error handling
  
  /// Get the last error that occurred
  /// 
  /// Returns [SingboxError] with error details, or null if no error.
  Future<SingboxError?> getLastError();

  /// Clear the last error
  /// 
  /// Resets the error state to no error.
  Future<void> clearError();

  /// Stream of error events
  /// 
  /// Emits [SingboxError] objects when errors occur.
  Stream<SingboxError> get errorStream;

  // Diagnostic and debugging
  
  /// Get error history
  /// 
  /// Returns list of recent error messages for debugging.
  Future<List<String>> getErrorHistory();

  /// Get operation timing statistics
  /// 
  /// Returns map of operation names to timing data in milliseconds.
  Future<Map<String, int>> getOperationTimings();

  /// Clear diagnostic data
  /// 
  /// Clears error history and timing statistics.
  Future<void> clearDiagnosticData();

  /// Generate diagnostic report
  /// 
  /// Returns comprehensive diagnostic information as key-value pairs.
  Future<Map<String, String>> generateDiagnosticReport();

  /// Export diagnostic logs in JSON format
  /// 
  /// Returns JSON string with all diagnostic information.
  Future<String> exportDiagnosticLogs();
}

/// Log levels for sing-box logging
enum LogLevel {
  trace,    // 0 - Most verbose
  debug,    // 1 - Debug information
  info,     // 2 - General information
  warn,     // 3 - Warning messages
  error,    // 4 - Error messages
  fatal,    // 5 - Fatal errors only
}

/// Detailed network statistics with additional metrics
class DetailedNetworkStats {
  final NetworkStats basicStats;
  final Duration latency;
  final Duration jitter;
  final double packetLossRate;
  final int retransmissions;
  final ConnectionQuality quality;

  const DetailedNetworkStats({
    required this.basicStats,
    required this.latency,
    required this.jitter,
    required this.packetLossRate,
    required this.retransmissions,
    required this.quality,
  });

  Map<String, dynamic> toJson() {
    return {
      'basicStats': basicStats.toJson(),
      'latency': latency.inMilliseconds,
      'jitter': jitter.inMilliseconds,
      'packetLossRate': packetLossRate,
      'retransmissions': retransmissions,
      'quality': quality.name,
    };
  }

  factory DetailedNetworkStats.fromJson(Map<String, dynamic> json) {
    return DetailedNetworkStats(
      basicStats: NetworkStats.fromJson(json['basicStats']),
      latency: Duration(milliseconds: json['latency'] ?? 0),
      jitter: Duration(milliseconds: json['jitter'] ?? 0),
      packetLossRate: (json['packetLossRate'] ?? 0.0).toDouble(),
      retransmissions: json['retransmissions'] ?? 0,
      quality: ConnectionQuality.values.firstWhere(
        (q) => q.name == json['quality'],
        orElse: () => ConnectionQuality.unknown,
      ),
    );
  }
}

/// Connection quality assessment
enum ConnectionQuality {
  excellent,  // < 50ms latency, < 1% packet loss
  good,       // < 100ms latency, < 5% packet loss
  fair,       // < 200ms latency, < 10% packet loss
  poor,       // > 200ms latency or > 10% packet loss
  unknown,    // Cannot determine quality
}

/// Connection information
class ConnectionInfo {
  final String serverAddress;
  final int serverPort;
  final String protocol;
  final String? localAddress;
  final String? remoteAddress;
  final DateTime connectionTime;
  final bool isConnected;
  final Duration? lastPingTime;
  final Map<String, dynamic> protocolSpecificInfo;

  const ConnectionInfo({
    required this.serverAddress,
    required this.serverPort,
    required this.protocol,
    this.localAddress,
    this.remoteAddress,
    required this.connectionTime,
    required this.isConnected,
    this.lastPingTime,
    this.protocolSpecificInfo = const {},
  });

  Map<String, dynamic> toJson() {
    return {
      'serverAddress': serverAddress,
      'serverPort': serverPort,
      'protocol': protocol,
      'localAddress': localAddress,
      'remoteAddress': remoteAddress,
      'connectionTime': connectionTime.toIso8601String(),
      'isConnected': isConnected,
      'lastPingTime': lastPingTime?.inMilliseconds,
      'protocolSpecificInfo': protocolSpecificInfo,
    };
  }

  factory ConnectionInfo.fromJson(Map<String, dynamic> json) {
    return ConnectionInfo(
      serverAddress: json['serverAddress'] ?? '',
      serverPort: json['serverPort'] ?? 0,
      protocol: json['protocol'] ?? '',
      localAddress: json['localAddress'],
      remoteAddress: json['remoteAddress'],
      connectionTime: DateTime.parse(json['connectionTime'] ?? DateTime.now().toIso8601String()),
      isConnected: json['isConnected'] ?? false,
      lastPingTime: json['lastPingTime'] != null 
          ? Duration(milliseconds: json['lastPingTime']) 
          : null,
      protocolSpecificInfo: json['protocolSpecificInfo'] ?? {},
    );
  }
}

/// Memory usage statistics
class MemoryStats {
  final int totalMemoryMB;
  final int usedMemoryMB;
  final double cpuUsagePercent;
  final int openFileDescriptors;
  final Map<String, int> platformSpecificStats;

  const MemoryStats({
    required this.totalMemoryMB,
    required this.usedMemoryMB,
    required this.cpuUsagePercent,
    required this.openFileDescriptors,
    this.platformSpecificStats = const {},
  });

  double get memoryUsagePercent => 
      totalMemoryMB > 0 ? (usedMemoryMB / totalMemoryMB) * 100 : 0.0;

  Map<String, dynamic> toJson() {
    return {
      'totalMemoryMB': totalMemoryMB,
      'usedMemoryMB': usedMemoryMB,
      'cpuUsagePercent': cpuUsagePercent,
      'openFileDescriptors': openFileDescriptors,
      'memoryUsagePercent': memoryUsagePercent,
      'platformSpecificStats': platformSpecificStats,
    };
  }

  factory MemoryStats.fromJson(Map<String, dynamic> json) {
    return MemoryStats(
      totalMemoryMB: json['totalMemoryMB'] ?? 0,
      usedMemoryMB: json['usedMemoryMB'] ?? 0,
      cpuUsagePercent: (json['cpuUsagePercent'] ?? 0.0).toDouble(),
      openFileDescriptors: json['openFileDescriptors'] ?? 0,
      platformSpecificStats: Map<String, int>.from(json['platformSpecificStats'] ?? {}),
    );
  }
}

/// Network information for network change handling
class NetworkInfo {
  final String networkType;
  final bool isConnected;
  final bool isWifi;
  final bool isMobile;
  final bool isEthernet;
  final String? networkName;
  final String? ipAddress;
  final int? mtu;
  final Map<String, dynamic> platformSpecificInfo;

  const NetworkInfo({
    required this.networkType,
    required this.isConnected,
    required this.isWifi,
    required this.isMobile,
    required this.isEthernet,
    this.networkName,
    this.ipAddress,
    this.mtu,
    this.platformSpecificInfo = const {},
  });

  Map<String, dynamic> toJson() {
    return {
      'networkType': networkType,
      'isConnected': isConnected,
      'isWifi': isWifi,
      'isMobile': isMobile,
      'isEthernet': isEthernet,
      'networkName': networkName,
      'ipAddress': ipAddress,
      'mtu': mtu,
      'platformSpecificInfo': platformSpecificInfo,
    };
  }

  factory NetworkInfo.fromJson(Map<String, dynamic> json) {
    return NetworkInfo(
      networkType: json['networkType'] ?? 'unknown',
      isConnected: json['isConnected'] ?? false,
      isWifi: json['isWifi'] ?? false,
      isMobile: json['isMobile'] ?? false,
      isEthernet: json['isEthernet'] ?? false,
      networkName: json['networkName'],
      ipAddress: json['ipAddress'],
      mtu: json['mtu'],
      platformSpecificInfo: json['platformSpecificInfo'] ?? {},
    );
  }
}

/// Sing-box specific error information
class SingboxError {
  final SingboxErrorCode code;
  final String message;
  final String? nativeMessage;
  final Map<String, dynamic> context;
  final DateTime timestamp;

  const SingboxError({
    required this.code,
    required this.message,
    this.nativeMessage,
    this.context = const {},
    required this.timestamp,
  });

  /// Get user-friendly error message
  String get userFriendlyMessage {
    switch (code) {
      case SingboxErrorCode.configurationInvalid:
        return 'Configuration is invalid. Please check your server settings.';
      case SingboxErrorCode.networkUnreachable:
        return 'Cannot reach the VPN server. Please check your internet connection.';
      case SingboxErrorCode.authenticationFailed:
        return 'Authentication failed. Please verify your credentials.';
      case SingboxErrorCode.tlsHandshakeFailed:
        return 'Secure connection failed. The server certificate may be invalid.';
      case SingboxErrorCode.tunInterfaceError:
        return 'Failed to create VPN interface. Please check app permissions.';
      case SingboxErrorCode.permissionDenied:
        return 'Permission denied. Please grant VPN permissions to the app.';
      case SingboxErrorCode.processTerminated:
        return 'VPN process was terminated unexpectedly.';
      case SingboxErrorCode.memoryExhausted:
        return 'Insufficient memory to run VPN. Please close other apps.';
      case SingboxErrorCode.timeout:
        return 'Operation timed out. Please try again.';
      default:
        return 'An unexpected error occurred: $message';
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'code': code.name,
      'message': message,
      'nativeMessage': nativeMessage,
      'context': context,
      'timestamp': timestamp.toIso8601String(),
      'userFriendlyMessage': userFriendlyMessage,
    };
  }

  factory SingboxError.fromJson(Map<String, dynamic> json) {
    return SingboxError(
      code: SingboxErrorCode.values.firstWhere(
        (c) => c.name == json['code'],
        orElse: () => SingboxErrorCode.unknown,
      ),
      message: json['message'] ?? '',
      nativeMessage: json['nativeMessage'],
      context: json['context'] ?? {},
      timestamp: DateTime.parse(json['timestamp'] ?? DateTime.now().toIso8601String()),
    );
  }

  @override
  String toString() {
    return 'SingboxError(${code.name}): $message';
  }
}

/// Error codes for sing-box operations
enum SingboxErrorCode {
  none,
  configurationInvalid,
  networkUnreachable,
  authenticationFailed,
  tlsHandshakeFailed,
  tunInterfaceError,
  memoryExhausted,
  processTerminated,
  permissionDenied,
  resourceBusy,
  timeout,
  initializationFailed,
  processCrashed,
  networkError,
  unknown,
}

/// Exception thrown by sing-box manager operations
class SingboxException implements Exception {
  final SingboxError error;

  const SingboxException(this.error);

  @override
  String toString() {
    return 'SingboxException: ${error.toString()}';
  }
}