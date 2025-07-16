package com.example.tunnel_max.vpn

import kotlinx.serialization.Serializable

@Serializable
data class VpnConfiguration(
    val id: String,
    val name: String,
    val serverAddress: String,
    val serverPort: Int,
    val protocol: VpnProtocol,
    val authMethod: AuthenticationMethod,
    val protocolSpecificConfig: Map<String, String> = emptyMap(),
    val autoConnect: Boolean = false,
    val createdAt: Long = System.currentTimeMillis(),
    val lastUsed: Long? = null
)

@Serializable
enum class VpnProtocol {
    SHADOWSOCKS,
    VMESS,
    VLESS,
    TROJAN,
    HYSTERIA,
    HYSTERIA2,
    TUIC,
    SSH,
    WIREGUARD
}

@Serializable
enum class AuthenticationMethod {
    PASSWORD,
    PRIVATE_KEY,
    CERTIFICATE,
    TOKEN,
    NONE
}

@Serializable
data class NetworkStats(
    val bytesReceived: Long,
    val bytesSent: Long,
    val connectionDuration: Long,
    val downloadSpeed: Double,
    val uploadSpeed: Double,
    val packetsReceived: Long,
    val packetsSent: Long,
    val timestamp: Long = System.currentTimeMillis()
)

@Serializable
enum class VpnStatus {
    DISCONNECTED,
    CONNECTING,
    CONNECTED,
    DISCONNECTING,
    ERROR
}

@Serializable
data class VpnStatusInfo(
    val status: VpnStatus,
    val connectedServer: String? = null,
    val connectionStartTime: Long? = null,
    val localIpAddress: String? = null,
    val publicIpAddress: String? = null,
    val currentStats: NetworkStats? = null,
    val lastError: String? = null
)