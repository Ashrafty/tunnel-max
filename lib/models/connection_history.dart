import 'package:json_annotation/json_annotation.dart';
import 'network_stats.dart';

part 'connection_history.g.dart';

/// Connection history entry model for tracking VPN connection sessions
/// 
/// This class represents a single VPN connection session with
/// start/end times, server information, and final statistics.
@JsonSerializable()
class ConnectionHistoryEntry {
  /// Unique identifier for this connection session
  final String id;
  
  /// Server name or address that was connected to
  final String serverName;
  
  /// Server location or region
  final String? serverLocation;
  
  /// When the connection was established
  final DateTime startTime;
  
  /// When the connection was terminated (null if still active)
  final DateTime? endTime;
  
  /// Final network statistics for this session
  @JsonKey(fromJson: _networkStatsFromJson, toJson: _networkStatsToJson)
  final NetworkStats? finalStats;
  
  /// Reason for disconnection (user, error, network change, etc.)
  final String? disconnectionReason;
  
  /// Whether the connection was successful
  final bool wasSuccessful;

  const ConnectionHistoryEntry({
    required this.id,
    required this.serverName,
    this.serverLocation,
    required this.startTime,
    this.endTime,
    this.finalStats,
    this.disconnectionReason,
    required this.wasSuccessful,
  });

  /// Creates a ConnectionHistoryEntry from JSON map
  factory ConnectionHistoryEntry.fromJson(Map<String, dynamic> json) =>
      _$ConnectionHistoryEntryFromJson(json);

  /// Converts this ConnectionHistoryEntry to JSON map
  Map<String, dynamic> toJson() => _$ConnectionHistoryEntryToJson(this);

  /// Duration of the connection session
  Duration get duration {
    final end = endTime ?? DateTime.now();
    return end.difference(startTime);
  }

  /// Whether this connection session is still active
  bool get isActive => endTime == null;

  /// Total data transferred during this session
  int get totalDataTransferred {
    return finalStats?.totalBytes ?? 0;
  }

  /// Creates a copy of this entry with updated fields
  ConnectionHistoryEntry copyWith({
    String? id,
    String? serverName,
    String? serverLocation,
    DateTime? startTime,
    DateTime? endTime,
    NetworkStats? finalStats,
    String? disconnectionReason,
    bool? wasSuccessful,
  }) {
    return ConnectionHistoryEntry(
      id: id ?? this.id,
      serverName: serverName ?? this.serverName,
      serverLocation: serverLocation ?? this.serverLocation,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      finalStats: finalStats ?? this.finalStats,
      disconnectionReason: disconnectionReason ?? this.disconnectionReason,
      wasSuccessful: wasSuccessful ?? this.wasSuccessful,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ConnectionHistoryEntry &&
        other.id == id &&
        other.serverName == serverName &&
        other.serverLocation == serverLocation &&
        other.startTime == startTime &&
        other.endTime == endTime &&
        other.finalStats == finalStats &&
        other.disconnectionReason == disconnectionReason &&
        other.wasSuccessful == wasSuccessful;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      serverName,
      serverLocation,
      startTime,
      endTime,
      finalStats,
      disconnectionReason,
      wasSuccessful,
    );
  }

  /// Helper function to convert NetworkStats to JSON
  static Map<String, dynamic>? _networkStatsToJson(NetworkStats? stats) => 
      stats?.toJson();

  /// Helper function to convert JSON to NetworkStats
  static NetworkStats? _networkStatsFromJson(Map<String, dynamic>? json) => 
      json != null ? NetworkStats.fromJson(json) : null;

  @override
  String toString() {
    return 'ConnectionHistoryEntry(id: $id, serverName: $serverName, '
           'startTime: $startTime, endTime: $endTime, '
           'wasSuccessful: $wasSuccessful)';
  }
}

/// Data usage summary for reporting and analytics
@JsonSerializable()
class DataUsageSummary {
  /// Total bytes downloaded across all sessions
  final int totalBytesDownloaded;
  
  /// Total bytes uploaded across all sessions
  final int totalBytesUploaded;
  
  /// Total connection time across all sessions
  @JsonKey(fromJson: _durationFromJson, toJson: _durationToJson)
  final Duration totalConnectionTime;
  
  /// Number of successful connections
  final int successfulConnections;
  
  /// Number of failed connections
  final int failedConnections;
  
  /// Average session duration
  @JsonKey(fromJson: _durationFromJson, toJson: _durationToJson)
  final Duration averageSessionDuration;
  
  /// Most used server
  final String? mostUsedServer;
  
  /// Period this summary covers (e.g., "Last 30 days")
  final String period;
  
  /// When this summary was generated
  final DateTime generatedAt;

  const DataUsageSummary({
    required this.totalBytesDownloaded,
    required this.totalBytesUploaded,
    required this.totalConnectionTime,
    required this.successfulConnections,
    required this.failedConnections,
    required this.averageSessionDuration,
    this.mostUsedServer,
    required this.period,
    required this.generatedAt,
  });

  /// Creates a DataUsageSummary from JSON map
  factory DataUsageSummary.fromJson(Map<String, dynamic> json) =>
      _$DataUsageSummaryFromJson(json);

  /// Converts this DataUsageSummary to JSON map
  Map<String, dynamic> toJson() => _$DataUsageSummaryToJson(this);

  /// Total data transferred (uploaded + downloaded)
  int get totalDataTransferred => totalBytesDownloaded + totalBytesUploaded;

  /// Total number of connection attempts
  int get totalConnections => successfulConnections + failedConnections;

  /// Connection success rate as a percentage
  double get successRate {
    if (totalConnections == 0) return 0.0;
    return (successfulConnections / totalConnections) * 100;
  }

  /// Human-readable total data transferred
  String get formattedTotalData => NetworkStats.formatBytes(totalDataTransferred);

  /// Human-readable total downloaded
  String get formattedTotalDownloaded => NetworkStats.formatBytes(totalBytesDownloaded);

  /// Human-readable total uploaded
  String get formattedTotalUploaded => NetworkStats.formatBytes(totalBytesUploaded);

  /// Helper function to convert Duration to JSON (milliseconds)
  static int _durationToJson(Duration duration) => duration.inMilliseconds;

  /// Helper function to convert JSON (milliseconds) to Duration
  static Duration _durationFromJson(int milliseconds) => 
      Duration(milliseconds: milliseconds);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DataUsageSummary &&
        other.totalBytesDownloaded == totalBytesDownloaded &&
        other.totalBytesUploaded == totalBytesUploaded &&
        other.totalConnectionTime == totalConnectionTime &&
        other.successfulConnections == successfulConnections &&
        other.failedConnections == failedConnections &&
        other.averageSessionDuration == averageSessionDuration &&
        other.mostUsedServer == mostUsedServer &&
        other.period == period &&
        other.generatedAt == generatedAt;
  }

  @override
  int get hashCode {
    return Object.hash(
      totalBytesDownloaded,
      totalBytesUploaded,
      totalConnectionTime,
      successfulConnections,
      failedConnections,
      averageSessionDuration,
      mostUsedServer,
      period,
      generatedAt,
    );
  }

  @override
  String toString() {
    return 'DataUsageSummary(totalData: $formattedTotalData, '
           'connections: $totalConnections, successRate: ${successRate.toStringAsFixed(1)}%)';
  }
}