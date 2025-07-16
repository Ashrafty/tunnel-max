// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'vpn_status.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

VpnStatus _$VpnStatusFromJson(Map<String, dynamic> json) => VpnStatus(
  state: $enumDecode(_$VpnConnectionStateEnumMap, json['state']),
  connectedServer: json['connectedServer'] as String?,
  connectionStartTime: json['connectionStartTime'] == null
      ? null
      : DateTime.parse(json['connectionStartTime'] as String),
  localIpAddress: json['localIpAddress'] as String?,
  publicIpAddress: json['publicIpAddress'] as String?,
  currentStats: VpnStatus._networkStatsFromJson(
    json['currentStats'] as Map<String, dynamic>?,
  ),
  lastError: json['lastError'] as String?,
);

Map<String, dynamic> _$VpnStatusToJson(VpnStatus instance) => <String, dynamic>{
  'state': _$VpnConnectionStateEnumMap[instance.state]!,
  'connectedServer': instance.connectedServer,
  'connectionStartTime': instance.connectionStartTime?.toIso8601String(),
  'localIpAddress': instance.localIpAddress,
  'publicIpAddress': instance.publicIpAddress,
  'currentStats': VpnStatus._networkStatsToJson(instance.currentStats),
  'lastError': instance.lastError,
};

const _$VpnConnectionStateEnumMap = {
  VpnConnectionState.disconnected: 'disconnected',
  VpnConnectionState.connecting: 'connecting',
  VpnConnectionState.connected: 'connected',
  VpnConnectionState.disconnecting: 'disconnecting',
  VpnConnectionState.reconnecting: 'reconnecting',
  VpnConnectionState.error: 'error',
};
