// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'network_stats.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

NetworkStats _$NetworkStatsFromJson(Map<String, dynamic> json) => NetworkStats(
  bytesReceived: (json['bytesReceived'] as num).toInt(),
  bytesSent: (json['bytesSent'] as num).toInt(),
  connectionDuration: NetworkStats._durationFromJson(
    (json['connectionDuration'] as num).toInt(),
  ),
  downloadSpeed: (json['downloadSpeed'] as num).toDouble(),
  uploadSpeed: (json['uploadSpeed'] as num).toDouble(),
  packetsReceived: (json['packetsReceived'] as num).toInt(),
  packetsSent: (json['packetsSent'] as num).toInt(),
  lastUpdated: DateTime.parse(json['lastUpdated'] as String),
);

Map<String, dynamic> _$NetworkStatsToJson(NetworkStats instance) =>
    <String, dynamic>{
      'bytesReceived': instance.bytesReceived,
      'bytesSent': instance.bytesSent,
      'connectionDuration': NetworkStats._durationToJson(
        instance.connectionDuration,
      ),
      'downloadSpeed': instance.downloadSpeed,
      'uploadSpeed': instance.uploadSpeed,
      'packetsReceived': instance.packetsReceived,
      'packetsSent': instance.packetsSent,
      'lastUpdated': instance.lastUpdated.toIso8601String(),
    };
