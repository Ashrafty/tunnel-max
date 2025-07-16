// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'connection_history.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ConnectionHistoryEntry _$ConnectionHistoryEntryFromJson(
  Map<String, dynamic> json,
) => ConnectionHistoryEntry(
  id: json['id'] as String,
  serverName: json['serverName'] as String,
  serverLocation: json['serverLocation'] as String?,
  startTime: DateTime.parse(json['startTime'] as String),
  endTime: json['endTime'] == null
      ? null
      : DateTime.parse(json['endTime'] as String),
  finalStats: ConnectionHistoryEntry._networkStatsFromJson(
    json['finalStats'] as Map<String, dynamic>?,
  ),
  disconnectionReason: json['disconnectionReason'] as String?,
  wasSuccessful: json['wasSuccessful'] as bool,
);

Map<String, dynamic> _$ConnectionHistoryEntryToJson(
  ConnectionHistoryEntry instance,
) => <String, dynamic>{
  'id': instance.id,
  'serverName': instance.serverName,
  'serverLocation': instance.serverLocation,
  'startTime': instance.startTime.toIso8601String(),
  'endTime': instance.endTime?.toIso8601String(),
  'finalStats': ConnectionHistoryEntry._networkStatsToJson(instance.finalStats),
  'disconnectionReason': instance.disconnectionReason,
  'wasSuccessful': instance.wasSuccessful,
};

DataUsageSummary _$DataUsageSummaryFromJson(Map<String, dynamic> json) =>
    DataUsageSummary(
      totalBytesDownloaded: (json['totalBytesDownloaded'] as num).toInt(),
      totalBytesUploaded: (json['totalBytesUploaded'] as num).toInt(),
      totalConnectionTime: DataUsageSummary._durationFromJson(
        (json['totalConnectionTime'] as num).toInt(),
      ),
      successfulConnections: (json['successfulConnections'] as num).toInt(),
      failedConnections: (json['failedConnections'] as num).toInt(),
      averageSessionDuration: DataUsageSummary._durationFromJson(
        (json['averageSessionDuration'] as num).toInt(),
      ),
      mostUsedServer: json['mostUsedServer'] as String?,
      period: json['period'] as String,
      generatedAt: DateTime.parse(json['generatedAt'] as String),
    );

Map<String, dynamic> _$DataUsageSummaryToJson(DataUsageSummary instance) =>
    <String, dynamic>{
      'totalBytesDownloaded': instance.totalBytesDownloaded,
      'totalBytesUploaded': instance.totalBytesUploaded,
      'totalConnectionTime': DataUsageSummary._durationToJson(
        instance.totalConnectionTime,
      ),
      'successfulConnections': instance.successfulConnections,
      'failedConnections': instance.failedConnections,
      'averageSessionDuration': DataUsageSummary._durationToJson(
        instance.averageSessionDuration,
      ),
      'mostUsedServer': instance.mostUsedServer,
      'period': instance.period,
      'generatedAt': instance.generatedAt.toIso8601String(),
    };
