import 'package:json_annotation/json_annotation.dart';
import 'network_stats.dart';

part 'vpn_status.g.dart';

/// Enum representing the current state of the VPN connection
enum VpnConnectionState {
  @JsonValue('disconnected')
  disconnected,
  @JsonValue('connecting')
  connecting,
  @JsonValue('connected')
  connected,
  @JsonValue('disconnecting')
  disconnecting,
  @JsonValue('reconnecting')
  reconnecting,
  @JsonValue('error')
  error,
}

/// VPN Status model class with JSON serialization support
/// 
/// This class represents the current status of the VPN connection,
/// including connection state, server information, and network statistics.
@JsonSerializable()
class VpnStatus {
  /// Current connection state
  final VpnConnectionState state;
  
  /// Name or address of the currently connected server (null if disconnected)
  final String? connectedServer;
  
  /// Timestamp when the current connection was established (null if disconnected)
  final DateTime? connectionStartTime;
  
  /// Local IP address assigned by the VPN (null if disconnected)
  final String? localIpAddress;
  
  /// Public IP address as seen by external services (null if disconnected)
  final String? publicIpAddress;
  
  /// Current network statistics (null if disconnected)
  @JsonKey(fromJson: _networkStatsFromJson, toJson: _networkStatsToJson)
  final NetworkStats? currentStats;
  
  /// Last error message if connection failed (null if no error)
  final String? lastError;

  const VpnStatus({
    required this.state,
    this.connectedServer,
    this.connectionStartTime,
    this.localIpAddress,
    this.publicIpAddress,
    this.currentStats,
    this.lastError,
  });

  /// Creates a VpnStatus from JSON map
  factory VpnStatus.fromJson(Map<String, dynamic> json) =>
      _$VpnStatusFromJson(json);

  /// Converts this VpnStatus to JSON map
  Map<String, dynamic> toJson() => _$VpnStatusToJson(this);

  /// Creates a copy of this status with updated fields
  VpnStatus copyWith({
    VpnConnectionState? state,
    String? connectedServer,
    DateTime? connectionStartTime,
    String? localIpAddress,
    String? publicIpAddress,
    NetworkStats? currentStats,
    String? lastError,
  }) {
    return VpnStatus(
      state: state ?? this.state,
      connectedServer: connectedServer ?? this.connectedServer,
      connectionStartTime: connectionStartTime ?? this.connectionStartTime,
      localIpAddress: localIpAddress ?? this.localIpAddress,
      publicIpAddress: publicIpAddress ?? this.publicIpAddress,
      currentStats: currentStats ?? this.currentStats,
      lastError: lastError ?? this.lastError,
    );
  }

  /// Factory constructor for disconnected state
  factory VpnStatus.disconnected({String? lastError}) {
    return VpnStatus(
      state: VpnConnectionState.disconnected,
      lastError: lastError,
    );
  }

  /// Factory constructor for connecting state
  factory VpnStatus.connecting({required String server}) {
    return VpnStatus(
      state: VpnConnectionState.connecting,
      connectedServer: server,
    );
  }

  /// Factory constructor for connected state
  factory VpnStatus.connected({
    required String server,
    required DateTime connectionStartTime,
    String? localIpAddress,
    String? publicIpAddress,
    NetworkStats? stats,
  }) {
    return VpnStatus(
      state: VpnConnectionState.connected,
      connectedServer: server,
      connectionStartTime: connectionStartTime,
      localIpAddress: localIpAddress,
      publicIpAddress: publicIpAddress,
      currentStats: stats,
    );
  }

  /// Factory constructor for error state
  factory VpnStatus.error({required String error}) {
    return VpnStatus(
      state: VpnConnectionState.error,
      lastError: error,
    );
  }

  /// Returns true if the VPN is currently connected
  bool get isConnected => state == VpnConnectionState.connected;

  /// Returns true if the VPN is in a transitional state (connecting/disconnecting/reconnecting)
  bool get isTransitioning => 
      state == VpnConnectionState.connecting ||
      state == VpnConnectionState.disconnecting ||
      state == VpnConnectionState.reconnecting;

  /// Returns true if there's an active connection or connection attempt
  bool get hasActiveConnection => 
      state != VpnConnectionState.disconnected && 
      state != VpnConnectionState.error;

  /// Returns the duration of the current connection (null if not connected)
  Duration? get connectionDuration {
    if (connectionStartTime == null || !isConnected) {
      return null;
    }
    return DateTime.now().difference(connectionStartTime!);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is VpnStatus &&
        other.state == state &&
        other.connectedServer == connectedServer &&
        other.connectionStartTime == connectionStartTime &&
        other.localIpAddress == localIpAddress &&
        other.publicIpAddress == publicIpAddress &&
        other.currentStats == currentStats &&
        other.lastError == lastError;
  }

  @override
  int get hashCode {
    return Object.hash(
      state,
      connectedServer,
      connectionStartTime,
      localIpAddress,
      publicIpAddress,
      currentStats,
      lastError,
    );
  }

  @override
  String toString() {
    return 'VpnStatus(state: $state, connectedServer: $connectedServer, '
           'connectionStartTime: $connectionStartTime, localIpAddress: $localIpAddress, '
           'publicIpAddress: $publicIpAddress, currentStats: $currentStats, '
           'lastError: $lastError)';
  }

  /// Helper function to convert NetworkStats to JSON
  static Map<String, dynamic>? _networkStatsToJson(NetworkStats? stats) {
    return stats?.toJson();
  }

  /// Helper function to convert JSON to NetworkStats
  static NetworkStats? _networkStatsFromJson(Map<String, dynamic>? json) {
    return json != null ? NetworkStats.fromJson(json) : null;
  }
}