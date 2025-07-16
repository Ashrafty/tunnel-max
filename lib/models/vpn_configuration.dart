import 'package:json_annotation/json_annotation.dart';

part 'vpn_configuration.g.dart';

/// Enum representing different VPN protocols supported by the client
enum VpnProtocol {
  @JsonValue('shadowsocks')
  shadowsocks,
  @JsonValue('vmess')
  vmess,
  @JsonValue('vless')
  vless,
  @JsonValue('trojan')
  trojan,
  @JsonValue('hysteria')
  hysteria,
  @JsonValue('hysteria2')
  hysteria2,
  @JsonValue('tuic')
  tuic,
  @JsonValue('wireguard')
  wireguard,
}

/// Enum representing different authentication methods
enum AuthenticationMethod {
  @JsonValue('password')
  password,
  @JsonValue('certificate')
  certificate,
  @JsonValue('token')
  token,
  @JsonValue('none')
  none,
}

/// VPN Configuration model class with JSON serialization support
/// 
/// This class represents a complete VPN server configuration that can be
/// used to establish a VPN connection through the singbox core.
@JsonSerializable()
class VpnConfiguration {
  /// Unique identifier for this configuration
  final String id;
  
  /// User-friendly name for this configuration
  final String name;
  
  /// Server address (IP or hostname)
  final String serverAddress;
  
  /// Server port number
  final int serverPort;
  
  /// VPN protocol to use for this configuration
  final VpnProtocol protocol;
  
  /// Authentication method for this configuration
  final AuthenticationMethod authMethod;
  
  /// Protocol-specific configuration parameters
  /// This map contains additional settings specific to the chosen protocol
  final Map<String, dynamic> protocolSpecificConfig;
  
  /// Whether this configuration should auto-connect on app start
  final bool autoConnect;
  
  /// Timestamp when this configuration was created
  final DateTime createdAt;
  
  /// Timestamp when this configuration was last used for connection
  final DateTime? lastUsed;

  const VpnConfiguration({
    required this.id,
    required this.name,
    required this.serverAddress,
    required this.serverPort,
    required this.protocol,
    required this.authMethod,
    required this.protocolSpecificConfig,
    this.autoConnect = false,
    required this.createdAt,
    this.lastUsed,
  });

  /// Creates a VpnConfiguration from JSON map
  factory VpnConfiguration.fromJson(Map<String, dynamic> json) =>
      _$VpnConfigurationFromJson(json);

  /// Converts this VpnConfiguration to JSON map
  Map<String, dynamic> toJson() => _$VpnConfigurationToJson(this);

  /// Creates a copy of this configuration with updated fields
  VpnConfiguration copyWith({
    String? id,
    String? name,
    String? serverAddress,
    int? serverPort,
    VpnProtocol? protocol,
    AuthenticationMethod? authMethod,
    Map<String, dynamic>? protocolSpecificConfig,
    bool? autoConnect,
    DateTime? createdAt,
    DateTime? lastUsed,
  }) {
    return VpnConfiguration(
      id: id ?? this.id,
      name: name ?? this.name,
      serverAddress: serverAddress ?? this.serverAddress,
      serverPort: serverPort ?? this.serverPort,
      protocol: protocol ?? this.protocol,
      authMethod: authMethod ?? this.authMethod,
      protocolSpecificConfig: protocolSpecificConfig ?? this.protocolSpecificConfig,
      autoConnect: autoConnect ?? this.autoConnect,
      createdAt: createdAt ?? this.createdAt,
      lastUsed: lastUsed ?? this.lastUsed,
    );
  }

  /// Validates this configuration for basic correctness
  bool isValid() {
    // Check required fields
    if (id.isEmpty || name.isEmpty || serverAddress.isEmpty) {
      return false;
    }
    
    // Check port range
    if (serverPort < 1 || serverPort > 65535) {
      return false;
    }
    
    // Protocol-specific validation could be added here
    return true;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is VpnConfiguration &&
        other.id == id &&
        other.name == name &&
        other.serverAddress == serverAddress &&
        other.serverPort == serverPort &&
        other.protocol == protocol &&
        other.authMethod == authMethod &&
        other.autoConnect == autoConnect &&
        other.createdAt == createdAt &&
        other.lastUsed == lastUsed;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      name,
      serverAddress,
      serverPort,
      protocol,
      authMethod,
      autoConnect,
      createdAt,
      lastUsed,
    );
  }

  @override
  String toString() {
    return 'VpnConfiguration(id: $id, name: $name, serverAddress: $serverAddress, '
           'serverPort: $serverPort, protocol: $protocol, authMethod: $authMethod, '
           'autoConnect: $autoConnect, createdAt: $createdAt, lastUsed: $lastUsed)';
  }
}