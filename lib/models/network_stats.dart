import 'package:json_annotation/json_annotation.dart';

part 'network_stats.g.dart';

/// Network Statistics model class with JSON serialization support
/// 
/// This class represents network performance metrics and statistics
/// for monitoring VPN connection performance and data usage.
@JsonSerializable()
class NetworkStats {
  /// Total bytes received through the VPN connection
  final int bytesReceived;
  
  /// Total bytes sent through the VPN connection
  final int bytesSent;
  
  /// Duration of the current connection session
  @JsonKey(fromJson: _durationFromJson, toJson: _durationToJson)
  final Duration connectionDuration;
  
  /// Current download speed in bytes per second
  final double downloadSpeed;
  
  /// Current upload speed in bytes per second
  final double uploadSpeed;
  
  /// Total packets received
  final int packetsReceived;
  
  /// Total packets sent
  final int packetsSent;
  
  /// Timestamp when these statistics were last updated
  final DateTime lastUpdated;

  const NetworkStats({
    required this.bytesReceived,
    required this.bytesSent,
    required this.connectionDuration,
    required this.downloadSpeed,
    required this.uploadSpeed,
    required this.packetsReceived,
    required this.packetsSent,
    required this.lastUpdated,
  });

  /// Creates a NetworkStats from JSON map
  factory NetworkStats.fromJson(Map<String, dynamic> json) =>
      _$NetworkStatsFromJson(json);

  /// Converts this NetworkStats to JSON map
  Map<String, dynamic> toJson() => _$NetworkStatsToJson(this);

  /// Creates a copy of this stats with updated fields
  NetworkStats copyWith({
    int? bytesReceived,
    int? bytesSent,
    Duration? connectionDuration,
    double? downloadSpeed,
    double? uploadSpeed,
    int? packetsReceived,
    int? packetsSent,
    DateTime? lastUpdated,
  }) {
    return NetworkStats(
      bytesReceived: bytesReceived ?? this.bytesReceived,
      bytesSent: bytesSent ?? this.bytesSent,
      connectionDuration: connectionDuration ?? this.connectionDuration,
      downloadSpeed: downloadSpeed ?? this.downloadSpeed,
      uploadSpeed: uploadSpeed ?? this.uploadSpeed,
      packetsReceived: packetsReceived ?? this.packetsReceived,
      packetsSent: packetsSent ?? this.packetsSent,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  /// Factory constructor for initial/zero stats
  factory NetworkStats.zero() {
    return NetworkStats(
      bytesReceived: 0,
      bytesSent: 0,
      connectionDuration: Duration.zero,
      downloadSpeed: 0.0,
      uploadSpeed: 0.0,
      packetsReceived: 0,
      packetsSent: 0,
      lastUpdated: DateTime.now(),
    );
  }

  /// Total bytes transferred (sent + received)
  int get totalBytes => bytesReceived + bytesSent;

  /// Total packets transferred (sent + received)
  int get totalPackets => packetsReceived + packetsSent;

  /// Average download speed over the connection duration
  double get averageDownloadSpeed {
    if (connectionDuration.inSeconds == 0) return 0.0;
    return bytesReceived / connectionDuration.inSeconds;
  }

  /// Average upload speed over the connection duration
  double get averageUploadSpeed {
    if (connectionDuration.inSeconds == 0) return 0.0;
    return bytesSent / connectionDuration.inSeconds;
  }

  /// Formats bytes to human-readable string (KB, MB, GB)
  static String formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  /// Formats speed to human-readable string (KB/s, MB/s)
  static String formatSpeed(double bytesPerSecond) {
    if (bytesPerSecond < 1024) return '${bytesPerSecond.toStringAsFixed(1)} B/s';
    if (bytesPerSecond < 1024 * 1024) return '${(bytesPerSecond / 1024).toStringAsFixed(1)} KB/s';
    return '${(bytesPerSecond / (1024 * 1024)).toStringAsFixed(1)} MB/s';
  }

  /// Human-readable total bytes received
  String get formattedBytesReceived => formatBytes(bytesReceived);

  /// Human-readable total bytes sent
  String get formattedBytesSent => formatBytes(bytesSent);

  /// Human-readable total bytes transferred
  String get formattedTotalBytes => formatBytes(totalBytes);

  /// Human-readable current download speed
  String get formattedDownloadSpeed => formatSpeed(downloadSpeed);

  /// Human-readable current upload speed
  String get formattedUploadSpeed => formatSpeed(uploadSpeed);

  /// Creates updated stats by calculating differences from previous stats
  NetworkStats updateFrom(NetworkStats previous) {
    final timeDiff = lastUpdated.difference(previous.lastUpdated);
    final bytesDiff = bytesReceived - previous.bytesReceived;
    final sentDiff = bytesSent - previous.bytesSent;
    
    // Calculate current speeds based on the difference
    final currentDownloadSpeed = timeDiff.inSeconds > 0 
        ? bytesDiff / timeDiff.inSeconds 
        : 0.0;
    final currentUploadSpeed = timeDiff.inSeconds > 0 
        ? sentDiff / timeDiff.inSeconds 
        : 0.0;

    return copyWith(
      downloadSpeed: currentDownloadSpeed,
      uploadSpeed: currentUploadSpeed,
    );
  }

  /// Helper function to convert Duration to JSON (milliseconds)
  static int _durationToJson(Duration duration) => duration.inMilliseconds;

  /// Helper function to convert JSON (milliseconds) to Duration
  static Duration _durationFromJson(int milliseconds) => 
      Duration(milliseconds: milliseconds);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is NetworkStats &&
        other.bytesReceived == bytesReceived &&
        other.bytesSent == bytesSent &&
        other.connectionDuration == connectionDuration &&
        other.downloadSpeed == downloadSpeed &&
        other.uploadSpeed == uploadSpeed &&
        other.packetsReceived == packetsReceived &&
        other.packetsSent == packetsSent &&
        other.lastUpdated == lastUpdated;
  }

  @override
  int get hashCode {
    return Object.hash(
      bytesReceived,
      bytesSent,
      connectionDuration,
      downloadSpeed,
      uploadSpeed,
      packetsReceived,
      packetsSent,
      lastUpdated,
    );
  }

  @override
  String toString() {
    return 'NetworkStats(bytesReceived: $bytesReceived, bytesSent: $bytesSent, '
           'connectionDuration: $connectionDuration, downloadSpeed: $downloadSpeed, '
           'uploadSpeed: $uploadSpeed, packetsReceived: $packetsReceived, '
           'packetsSent: $packetsSent, lastUpdated: $lastUpdated)';
  }
}