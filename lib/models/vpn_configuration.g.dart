// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'vpn_configuration.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

VpnConfiguration _$VpnConfigurationFromJson(Map<String, dynamic> json) =>
    VpnConfiguration(
      id: json['id'] as String,
      name: json['name'] as String,
      serverAddress: json['serverAddress'] as String,
      serverPort: (json['serverPort'] as num).toInt(),
      protocol: $enumDecode(_$VpnProtocolEnumMap, json['protocol']),
      authMethod: $enumDecode(
        _$AuthenticationMethodEnumMap,
        json['authMethod'],
      ),
      protocolSpecificConfig:
          json['protocolSpecificConfig'] as Map<String, dynamic>,
      autoConnect: json['autoConnect'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
      lastUsed: json['lastUsed'] == null
          ? null
          : DateTime.parse(json['lastUsed'] as String),
    );

Map<String, dynamic> _$VpnConfigurationToJson(VpnConfiguration instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'serverAddress': instance.serverAddress,
      'serverPort': instance.serverPort,
      'protocol': _$VpnProtocolEnumMap[instance.protocol]!,
      'authMethod': _$AuthenticationMethodEnumMap[instance.authMethod]!,
      'protocolSpecificConfig': instance.protocolSpecificConfig,
      'autoConnect': instance.autoConnect,
      'createdAt': instance.createdAt.toIso8601String(),
      'lastUsed': instance.lastUsed?.toIso8601String(),
    };

const _$VpnProtocolEnumMap = {
  VpnProtocol.shadowsocks: 'shadowsocks',
  VpnProtocol.vmess: 'vmess',
  VpnProtocol.vless: 'vless',
  VpnProtocol.trojan: 'trojan',
  VpnProtocol.hysteria: 'hysteria',
  VpnProtocol.hysteria2: 'hysteria2',
  VpnProtocol.tuic: 'tuic',
  VpnProtocol.wireguard: 'wireguard',
};

const _$AuthenticationMethodEnumMap = {
  AuthenticationMethod.password: 'password',
  AuthenticationMethod.certificate: 'certificate',
  AuthenticationMethod.token: 'token',
  AuthenticationMethod.none: 'none',
};
