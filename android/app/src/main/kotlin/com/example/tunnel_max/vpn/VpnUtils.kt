package com.example.tunnel_max.vpn

import android.content.Context
import android.net.VpnService
import android.util.Log
import java.net.InetAddress
import java.net.UnknownHostException

object VpnUtils {
    private const val TAG = "VpnUtils"
    
    /**
     * Check if VPN permission is granted
     */
    fun hasVpnPermission(context: Context): Boolean {
        return VpnService.prepare(context) == null
    }
    
    /**
     * Validate server address (IP or hostname)
     */
    fun isValidServerAddress(address: String): Boolean {
        if (address.isBlank()) return false
        
        return try {
            // Try to resolve the address
            InetAddress.getByName(address)
            true
        } catch (e: UnknownHostException) {
            Log.w(TAG, "Invalid server address: $address", e)
            false
        } catch (e: Exception) {
            Log.w(TAG, "Error validating server address: $address", e)
            false
        }
    }
    
    /**
     * Validate port number
     */
    fun isValidPort(port: Int): Boolean {
        return port in 1..65535
    }
    
    /**
     * Validate VPN configuration
     */
    fun validateConfiguration(config: VpnConfiguration): ValidationResult {
        val errors = mutableListOf<String>()
        
        // Validate basic fields
        if (config.name.isBlank()) {
            errors.add("Configuration name cannot be empty")
        }
        
        if (config.serverAddress.isBlank()) {
            errors.add("Server address cannot be empty")
        } else if (!isValidServerAddress(config.serverAddress)) {
            errors.add("Invalid server address format")
        }
        
        if (!isValidPort(config.serverPort)) {
            errors.add("Invalid port number (must be 1-65535)")
        }
        
        // Validate protocol-specific configuration
        when (config.protocol) {
            VpnProtocol.SHADOWSOCKS -> {
                if (config.protocolSpecificConfig["password"].isNullOrBlank()) {
                    errors.add("Shadowsocks password is required")
                }
                val method = config.protocolSpecificConfig["method"]
                if (method.isNullOrBlank()) {
                    errors.add("Shadowsocks encryption method is required")
                }
            }
            
            VpnProtocol.VMESS, VpnProtocol.VLESS -> {
                if (config.protocolSpecificConfig["uuid"].isNullOrBlank()) {
                    errors.add("UUID is required for ${config.protocol}")
                }
            }
            
            VpnProtocol.TROJAN -> {
                if (config.protocolSpecificConfig["password"].isNullOrBlank()) {
                    errors.add("Trojan password is required")
                }
            }
            
            VpnProtocol.HYSTERIA, VpnProtocol.HYSTERIA2 -> {
                val auth = config.protocolSpecificConfig["password"] ?: config.protocolSpecificConfig["auth"]
                if (auth.isNullOrBlank()) {
                    errors.add("Authentication is required for ${config.protocol}")
                }
            }
            
            VpnProtocol.TUIC -> {
                if (config.protocolSpecificConfig["uuid"].isNullOrBlank()) {
                    errors.add("UUID is required for TUIC")
                }
                if (config.protocolSpecificConfig["password"].isNullOrBlank()) {
                    errors.add("Password is required for TUIC")
                }
            }
            
            VpnProtocol.SSH -> {
                if (config.protocolSpecificConfig["user"].isNullOrBlank()) {
                    errors.add("Username is required for SSH")
                }
                if (config.protocolSpecificConfig["password"].isNullOrBlank()) {
                    errors.add("Password is required for SSH")
                }
            }
            
            VpnProtocol.WIREGUARD -> {
                if (config.protocolSpecificConfig["private_key"].isNullOrBlank()) {
                    errors.add("Private key is required for WireGuard")
                }
                if (config.protocolSpecificConfig["public_key"].isNullOrBlank()) {
                    errors.add("Public key is required for WireGuard")
                }
            }
        }
        
        return ValidationResult(errors.isEmpty(), errors)
    }
    
    /**
     * Get human-readable protocol name
     */
    fun getProtocolDisplayName(protocol: VpnProtocol): String {
        return when (protocol) {
            VpnProtocol.SHADOWSOCKS -> "Shadowsocks"
            VpnProtocol.VMESS -> "VMess"
            VpnProtocol.VLESS -> "VLESS"
            VpnProtocol.TROJAN -> "Trojan"
            VpnProtocol.HYSTERIA -> "Hysteria"
            VpnProtocol.HYSTERIA2 -> "Hysteria2"
            VpnProtocol.TUIC -> "TUIC"
            VpnProtocol.SSH -> "SSH"
            VpnProtocol.WIREGUARD -> "WireGuard"
        }
    }
    
    /**
     * Format bytes to human-readable string
     */
    fun formatBytes(bytes: Long): String {
        val units = arrayOf("B", "KB", "MB", "GB", "TB")
        var size = bytes.toDouble()
        var unitIndex = 0
        
        while (size >= 1024 && unitIndex < units.size - 1) {
            size /= 1024
            unitIndex++
        }
        
        return String.format("%.2f %s", size, units[unitIndex])
    }
    
    /**
     * Format speed to human-readable string
     */
    fun formatSpeed(bytesPerSecond: Double): String {
        return "${formatBytes(bytesPerSecond.toLong())}/s"
    }
    
    /**
     * Format duration to human-readable string
     */
    fun formatDuration(milliseconds: Long): String {
        val seconds = milliseconds / 1000
        val minutes = seconds / 60
        val hours = minutes / 60
        val days = hours / 24
        
        return when {
            days > 0 -> "${days}d ${hours % 24}h ${minutes % 60}m"
            hours > 0 -> "${hours}h ${minutes % 60}m ${seconds % 60}s"
            minutes > 0 -> "${minutes}m ${seconds % 60}s"
            else -> "${seconds}s"
        }
    }
}

data class ValidationResult(
    val isValid: Boolean,
    val errors: List<String>
)