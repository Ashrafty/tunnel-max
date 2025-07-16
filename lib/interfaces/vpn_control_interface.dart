import '../models/vpn_configuration.dart';
import '../models/vpn_status.dart';
import '../models/network_stats.dart';

/// Abstract interface for VPN control operations
/// 
/// This interface defines the contract for platform-specific VPN control
/// implementations. It provides methods for connecting, disconnecting,
/// and monitoring VPN connections through platform channels.
abstract class VpnControlInterface {
  /// Establishes a VPN connection using the provided configuration
  /// 
  /// Returns true if the connection was successfully initiated.
  /// The actual connection status should be monitored through [statusStream].
  /// 
  /// Throws [VpnException] if the connection cannot be initiated.
  Future<bool> connect(VpnConfiguration config);

  /// Disconnects the current VPN connection
  /// 
  /// Returns true if the disconnection was successfully initiated.
  /// The actual disconnection status should be monitored through [statusStream].
  /// 
  /// Throws [VpnException] if the disconnection cannot be initiated.
  Future<bool> disconnect();

  /// Gets the current VPN connection status
  /// 
  /// Returns the current [VpnStatus] including connection state,
  /// server information, and network statistics.
  Future<VpnStatus> getStatus();

  /// Stream of VPN status updates
  /// 
  /// Provides real-time updates of VPN connection status changes.
  /// The stream emits [VpnStatus] objects whenever the connection
  /// state changes or statistics are updated.
  Stream<VpnStatus> statusStream();

  /// Gets current network statistics for the VPN connection
  /// 
  /// Returns [NetworkStats] with current performance metrics
  /// including data usage, connection speed, and packet counts.
  /// 
  /// Returns null if no active connection exists.
  Future<NetworkStats?> getNetworkStats();

  /// Validates if VPN permissions are granted
  /// 
  /// Returns true if the application has the necessary permissions
  /// to create VPN connections on the current platform.
  Future<bool> hasVpnPermission();

  /// Requests VPN permissions from the user
  /// 
  /// On Android, this will show the VPN permission dialog.
  /// On Windows, this may require administrator privileges.
  /// 
  /// Returns true if permissions were granted.
  Future<bool> requestVpnPermission();
}

/// Exception thrown by VPN control operations
class VpnException implements Exception {
  final String message;
  final String? code;
  final dynamic details;

  const VpnException(this.message, {this.code, this.details});

  @override
  String toString() {
    if (code != null) {
      return 'VpnException($code): $message';
    }
    return 'VpnException: $message';
  }
}