package com.example.tunnel_max.vpn

import android.content.Context
import android.util.Log
import com.example.tunnel_max.vpn.mock.Libcore
import com.example.tunnel_max.vpn.mock.Box
import com.example.tunnel_max.vpn.mock.BoxService
import kotlinx.coroutines.*
import kotlinx.serialization.json.*
import java.io.File
import java.util.concurrent.atomic.AtomicReference

class SingboxManager(private val context: Context) {
    companion object {
        private const val TAG = "SingboxManager"
        private const val CONFIG_FILE_NAME = "config.json"
    }
    
    private var boxService: BoxService? = null
    private val currentBox = AtomicReference<Box?>(null)
    private var isInitialized = false
    
    fun initialize(config: VpnConfiguration) {
        try {
            Log.d(TAG, "Initializing Singbox with configuration: ${config.name}")
            
            // Generate singbox configuration
            val singboxConfig = generateSingboxConfig(config)
            
            // Write configuration to file
            val configFile = File(context.filesDir, CONFIG_FILE_NAME)
            configFile.writeText(singboxConfig)
            
            // Initialize libcore
            if (!isInitialized) {
                Libcore.setup(context.filesDir.absolutePath, context.cacheDir.absolutePath, true)
                isInitialized = true
            }
            
            Log.d(TAG, "Singbox initialized successfully")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to initialize Singbox", e)
            throw e
        }
    }
    
    fun start(vpnFd: Int) {
        try {
            Log.d(TAG, "Starting Singbox service")
            
            val configFile = File(context.filesDir, CONFIG_FILE_NAME)
            if (!configFile.exists()) {
                throw IllegalStateException("Configuration file not found")
            }
            
            // Create box service
            boxService = BoxService(
                configFile.absolutePath,
                vpnFd,
                false // not for test
            )
            
            // Start the service
            boxService?.start()
            
            Log.d(TAG, "Singbox service started successfully")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start Singbox service", e)
            throw e
        }
    }
    
    fun stop() {
        try {
            Log.d(TAG, "Stopping Singbox service")
            
            boxService?.stop()
            boxService = null
            currentBox.set(null)
            
            Log.d(TAG, "Singbox service stopped")
        } catch (e: Exception) {
            Log.e(TAG, "Error stopping Singbox service", e)
        }
    }
    
    fun getStats(): NetworkStats? {
        return try {
            boxService?.let { service ->
                // Get traffic statistics from singbox
                val uplink = service.uplinkTotal
                val downlink = service.downlinkTotal
                
                NetworkStats(
                    bytesReceived = downlink,
                    bytesSent = uplink,
                    connectionDuration = System.currentTimeMillis(),
                    downloadSpeed = 0.0, // Will be calculated by StatsCollector
                    uploadSpeed = 0.0,   // Will be calculated by StatsCollector
                    packetsReceived = 0, // Not available from singbox
                    packetsSent = 0      // Not available from singbox
                )
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to get statistics", e)
            null
        }
    }
    
    private fun generateSingboxConfig(config: VpnConfiguration): String {
        val configJson = buildJsonObject {
            put("log", buildJsonObject {
                put("level", "info")
                put("timestamp", true)
            })
            
            put("dns", buildJsonObject {
                putJsonArray("servers") {
                    add(buildJsonObject {
                        put("tag", "google")
                        put("address", "8.8.8.8")
                    })
                    add(buildJsonObject {
                        put("tag", "cloudflare")
                        put("address", "1.1.1.1")
                    })
                }
                putJsonArray("rules") {
                    add(buildJsonObject {
                        put("server", "google")
                    })
                }
            })
            
            putJsonArray("inbounds") {
                add(buildJsonObject {
                    put("type", "tun")
                    put("tag", "tun-in")
                    put("interface_name", "tun0")
                    put("inet4_address", "172.19.0.1/30")
                    put("mtu", 1500)
                    put("auto_route", true)
                    put("strict_route", true)
                    put("stack", "system")
                })
            }
            
            putJsonArray("outbounds") {
                add(generateOutboundConfig(config))
                add(buildJsonObject {
                    put("type", "direct")
                    put("tag", "direct")
                })
                add(buildJsonObject {
                    put("type", "block")
                    put("tag", "block")
                })
            }
            
            put("route", buildJsonObject {
                putJsonArray("rules") {
                    add(buildJsonObject {
                        put("protocol", "dns")
                        put("outbound", "dns-out")
                    })
                }
                put("auto_detect_interface", true)
            })
        }
        
        return configJson.toString()
    }
    
    private fun generateOutboundConfig(config: VpnConfiguration): JsonObject {
        return when (config.protocol) {
            VpnProtocol.SHADOWSOCKS -> buildJsonObject {
                put("type", "shadowsocks")
                put("tag", "proxy")
                put("server", config.serverAddress)
                put("server_port", config.serverPort)
                put("method", config.protocolSpecificConfig["method"] ?: "aes-256-gcm")
                put("password", config.protocolSpecificConfig["password"] ?: "")
            }
            
            VpnProtocol.VMESS -> buildJsonObject {
                put("type", "vmess")
                put("tag", "proxy")
                put("server", config.serverAddress)
                put("server_port", config.serverPort)
                put("uuid", config.protocolSpecificConfig["uuid"] ?: "")
                put("security", config.protocolSpecificConfig["security"] ?: "auto")
                put("alter_id", config.protocolSpecificConfig["alter_id"]?.toIntOrNull() ?: 0)
            }
            
            VpnProtocol.VLESS -> buildJsonObject {
                put("type", "vless")
                put("tag", "proxy")
                put("server", config.serverAddress)
                put("server_port", config.serverPort)
                put("uuid", config.protocolSpecificConfig["uuid"] ?: "")
                put("flow", config.protocolSpecificConfig["flow"] ?: "")
            }
            
            VpnProtocol.TROJAN -> buildJsonObject {
                put("type", "trojan")
                put("tag", "proxy")
                put("server", config.serverAddress)
                put("server_port", config.serverPort)
                put("password", config.protocolSpecificConfig["password"] ?: "")
            }
            
            VpnProtocol.HYSTERIA -> buildJsonObject {
                put("type", "hysteria")
                put("tag", "proxy")
                put("server", config.serverAddress)
                put("server_port", config.serverPort)
                put("auth_str", config.protocolSpecificConfig["auth"] ?: "")
                put("up_mbps", config.protocolSpecificConfig["up_mbps"]?.toIntOrNull() ?: 10)
                put("down_mbps", config.protocolSpecificConfig["down_mbps"]?.toIntOrNull() ?: 50)
            }
            
            VpnProtocol.HYSTERIA2 -> buildJsonObject {
                put("type", "hysteria2")
                put("tag", "proxy")
                put("server", config.serverAddress)
                put("server_port", config.serverPort)
                put("password", config.protocolSpecificConfig["password"] ?: "")
            }
            
            VpnProtocol.TUIC -> buildJsonObject {
                put("type", "tuic")
                put("tag", "proxy")
                put("server", config.serverAddress)
                put("server_port", config.serverPort)
                put("uuid", config.protocolSpecificConfig["uuid"] ?: "")
                put("password", config.protocolSpecificConfig["password"] ?: "")
            }
            
            VpnProtocol.SSH -> buildJsonObject {
                put("type", "ssh")
                put("tag", "proxy")
                put("server", config.serverAddress)
                put("server_port", config.serverPort)
                put("user", config.protocolSpecificConfig["user"] ?: "")
                put("password", config.protocolSpecificConfig["password"] ?: "")
            }
            
            VpnProtocol.WIREGUARD -> buildJsonObject {
                put("type", "wireguard")
                put("tag", "proxy")
                put("server", config.serverAddress)
                put("server_port", config.serverPort)
                put("private_key", config.protocolSpecificConfig["private_key"] ?: "")
                put("public_key", config.protocolSpecificConfig["public_key"] ?: "")
                put("pre_shared_key", config.protocolSpecificConfig["pre_shared_key"] ?: "")
                putJsonArray("local_address") {
                    add(config.protocolSpecificConfig["local_address"] ?: "10.0.0.2/32")
                }
            }
        }
    }
}