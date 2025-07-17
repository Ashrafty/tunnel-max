package com.tunnelmax.vpnclient

import android.content.Context
import android.util.Log
import kotlinx.coroutines.*
import kotlinx.serialization.json.*
import java.time.Duration
import java.time.LocalDateTime
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicReference

/**
 * Native sing-box manager for Android platform
 * Provides JNI interface to sing-box core library
 */
class SingboxManager(private val context: Context) {
    
    companion object {
        private const val TAG = "SingboxManager"
        private var isLibraryLoaded = false
        
        // Load native library
        init {
            try {
                System.loadLibrary("sing_box_jni")
                isLibraryLoaded = true
                Log.i(TAG, "Native sing-box JNI library loaded successfully")
            } catch (e: UnsatisfiedLinkError) {
                Log.e(TAG, "Failed to load native sing-box JNI library: ${e.message}")
                Log.w(TAG, "SingboxManager will operate in fallback mode without native features")
                isLibraryLoaded = false
            }
        }
        
        fun isNativeLibraryAvailable(): Boolean = isLibraryLoaded
    }
    
    // Native method declarations
    private external fun nativeInit(): Boolean
    private external fun nativeStart(configJson: String, tunFd: Int): Boolean
    private external fun nativeStop(): Boolean
    private external fun nativeGetStats(): String?
    private external fun nativeIsRunning(): Boolean
    private external fun nativeCleanup(): Unit
    private external fun nativeValidateConfig(configJson: String): Boolean
    private external fun nativeGetVersion(): String?
    private external fun nativeGetLastError(): String?
    private external fun nativeGetDetailedStats(): String?
    private external fun nativeResetStats(): Boolean
    private external fun nativeSetStatsCallback(callback: Long): Boolean
    private external fun nativeSetLogLevel(level: Int): Boolean
    private external fun nativeGetLogs(): String?
    private external fun nativeGetMemoryUsage(): String?
    private external fun nativeOptimizePerformance(): Boolean
    private external fun nativeHandleNetworkChange(networkInfo: String): Boolean
    private external fun nativeUpdateConfiguration(configJson: String): Boolean
    private external fun nativeGetConnectionInfo(): String?
    
    // State management
    private val isInitialized = AtomicBoolean(false)
    private val isRunning = AtomicBoolean(false)
    private val currentConfiguration = AtomicReference<String?>(null)
    private val lastError = AtomicReference<String?>(null)
    
    // Statistics tracking
    private var startTime: LocalDateTime? = null
    private val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())
    
    /**
     * Initialize the sing-box manager
     * Must be called before any other operations
     */
    fun initialize(): Boolean {
        if (isInitialized.get()) {
            Log.d(TAG, "SingboxManager already initialized")
            return true
        }
        
        Log.i(TAG, "Initializing SingboxManager")
        
        if (!isNativeLibraryAvailable()) {
            Log.w(TAG, "Native library not available, using fallback mode")
            isInitialized.set(true) // Allow initialization in fallback mode
            return true
        }
        
        return try {
            val result = nativeInit()
            if (result) {
                isInitialized.set(true)
                Log.i(TAG, "SingboxManager initialized successfully")
            } else {
                Log.e(TAG, "Failed to initialize SingboxManager")
                lastError.set("Native initialization failed")
            }
            result
        } catch (e: Exception) {
            Log.e(TAG, "Exception during SingboxManager initialization", e)
            lastError.set("Initialization exception: ${e.message}")
            false
        }
    }
    
    /**
     * Start sing-box with the provided configuration
     */
    fun start(config: VpnConfiguration, tunFileDescriptor: Int): Boolean {
        if (!isInitialized.get()) {
            Log.e(TAG, "SingboxManager not initialized")
            lastError.set("Manager not initialized")
            return false
        }
        
        if (!isNativeLibraryAvailable()) {
            Log.w(TAG, "Native library not available, cannot start sing-box")
            lastError.set("Native library not available")
            return false
        }
        
        if (isRunning.get()) {
            Log.w(TAG, "SingboxManager already running")
            return true
        }
        
        Log.i(TAG, "Starting sing-box with config: ${config.name}")
        
        return try {
            // Convert configuration to JSON
            val configJson = convertConfigurationToJson(config)
            if (configJson == null) {
                Log.e(TAG, "Failed to convert configuration to JSON")
                lastError.set("Configuration conversion failed")
                return false
            }
            
            // Validate configuration
            if (!nativeValidateConfig(configJson)) {
                Log.e(TAG, "Configuration validation failed")
                lastError.set("Invalid configuration")
                return false
            }
            
            // Start native sing-box
            val result = nativeStart(configJson, tunFileDescriptor)
            if (result) {
                isRunning.set(true)
                currentConfiguration.set(configJson)
                startTime = LocalDateTime.now()
                Log.i(TAG, "Sing-box started successfully")
            } else {
                Log.e(TAG, "Failed to start sing-box")
                val nativeError = nativeGetLastError()
                lastError.set("Start failed: $nativeError")
            }
            result
        } catch (e: Exception) {
            Log.e(TAG, "Exception during sing-box start", e)
            lastError.set("Start exception: ${e.message}")
            false
        }
    }
    
    /**
     * Stop sing-box
     */
    fun stop(): Boolean {
        if (!isRunning.get()) {
            Log.d(TAG, "SingboxManager not running")
            return true
        }
        
        if (!isNativeLibraryAvailable()) {
            Log.w(TAG, "Native library not available, marking as stopped")
            isRunning.set(false)
            currentConfiguration.set(null)
            startTime = null
            return true
        }
        
        Log.i(TAG, "Stopping sing-box")
        
        return try {
            val result = nativeStop()
            if (result) {
                isRunning.set(false)
                currentConfiguration.set(null)
                startTime = null
                Log.i(TAG, "Sing-box stopped successfully")
            } else {
                Log.e(TAG, "Failed to stop sing-box")
                val nativeError = nativeGetLastError()
                lastError.set("Stop failed: $nativeError")
            }
            result
        } catch (e: Exception) {
            Log.e(TAG, "Exception during sing-box stop", e)
            lastError.set("Stop exception: ${e.message}")
            false
        }
    }
    
    /**
     * Restart sing-box with current configuration
     */
    fun restart(): Boolean {
        Log.i(TAG, "Restarting sing-box")
        
        if (!stop()) {
            Log.e(TAG, "Failed to stop sing-box for restart")
            return false
        }
        
        // Wait a moment for cleanup
        Thread.sleep(500)
        
        val config = currentConfiguration.get()
        if (config == null) {
            Log.e(TAG, "No configuration available for restart")
            lastError.set("No configuration for restart")
            return false
        }
        
        // For restart, we need the original VpnConfiguration object
        // This is a limitation - in a full implementation, we'd store the original config
        Log.w(TAG, "Restart requires original configuration object - not fully implemented")
        return false
    }
    
    /**
     * Get current network statistics
     */
    fun getStatistics(): NetworkStats? {
        if (!isRunning.get()) {
            return null
        }
        
        if (!isNativeLibraryAvailable()) {
            return null
        }
        
        return try {
            val statsJson = nativeGetStats()
            if (statsJson != null) {
                parseNetworkStats(statsJson)
            } else {
                null
            }
        } catch (e: Exception) {
            Log.e(TAG, "Exception getting statistics", e)
            null
        }
    }
    
    /**
     * Get detailed network statistics
     */
    fun getDetailedStatistics(): DetailedNetworkStats? {
        if (!isRunning.get()) {
            return null
        }
        
        if (!isNativeLibraryAvailable()) {
            return null
        }
        
        return try {
            val statsJson = nativeGetDetailedStats()
            if (statsJson != null) {
                parseDetailedNetworkStats(statsJson)
            } else {
                null
            }
        } catch (e: Exception) {
            Log.e(TAG, "Exception getting detailed statistics", e)
            null
        }
    }
    
    /**
     * Check if sing-box is currently running
     */
    fun isRunning(): Boolean {
        if (!isNativeLibraryAvailable()) {
            return isRunning.get()
        }
        
        return try {
            val nativeRunning = nativeIsRunning()
            // Update our state to match native state
            if (isRunning.get() != nativeRunning) {
                isRunning.set(nativeRunning)
                if (!nativeRunning) {
                    currentConfiguration.set(null)
                    startTime = null
                }
            }
            nativeRunning
        } catch (e: Exception) {
            Log.e(TAG, "Exception checking running state", e)
            false
        }
    }
    
    /**
     * Get sing-box version information
     */
    fun getVersion(): String? {
        if (!isNativeLibraryAvailable()) {
            return null
        }
        
        return try {
            nativeGetVersion()
        } catch (e: Exception) {
            Log.e(TAG, "Exception getting version", e)
            null
        }
    }
    
    /**
     * Validate a configuration without starting
     */
    fun validateConfiguration(configJson: String): Boolean {
        if (!isInitialized.get()) {
            return false
        }
        
        if (!isNativeLibraryAvailable()) {
            // Basic fallback validation
            return configJson.isNotEmpty() && 
                   configJson.contains("{") && 
                   configJson.contains("}")
        }
        
        return try {
            nativeValidateConfig(configJson)
        } catch (e: Exception) {
            Log.e(TAG, "Exception validating configuration", e)
            false
        }
    }
    
    /**
     * Get the last error message
     */
    fun getLastError(): String? {
        return lastError.get() ?: if (isNativeLibraryAvailable()) {
            try {
                nativeGetLastError()
            } catch (e: Exception) {
                Log.e(TAG, "Exception getting last error", e)
                null
            }
        } else {
            null
        }
    }
    
    /**
     * Get current configuration JSON
     */
    fun getCurrentConfiguration(): String? {
        return currentConfiguration.get()
    }
    
    /**
     * Reset statistics counters
     */
    fun resetStatistics(): Boolean {
        if (!isNativeLibraryAvailable()) {
            return false
        }
        
        return try {
            nativeResetStats()
        } catch (e: Exception) {
            Log.e(TAG, "Exception resetting statistics", e)
            false
        }
    }
    
    /**
     * Set log level for sing-box
     */
    fun setLogLevel(level: LogLevel): Boolean {
        if (!isInitialized.get()) {
            return false
        }
        
        if (!isNativeLibraryAvailable()) {
            return false
        }
        
        return try {
            nativeSetLogLevel(level.ordinal)
        } catch (e: Exception) {
            Log.e(TAG, "Exception setting log level", e)
            false
        }
    }
    
    /**
     * Get logs from sing-box
     */
    fun getLogs(): List<String> {
        if (!isNativeLibraryAvailable()) {
            return emptyList()
        }
        
        return try {
            val logsJson = nativeGetLogs()
            if (logsJson != null) {
                parseLogs(logsJson)
            } else {
                emptyList()
            }
        } catch (e: Exception) {
            Log.e(TAG, "Exception getting logs", e)
            emptyList()
        }
    }
    
    /**
     * Get connection information
     */
    fun getConnectionInfo(): ConnectionInfo? {
        if (!isRunning.get()) {
            return null
        }
        
        if (!isNativeLibraryAvailable()) {
            return null
        }
        
        return try {
            val infoJson = nativeGetConnectionInfo()
            if (infoJson != null) {
                parseConnectionInfo(infoJson)
            } else {
                null
            }
        } catch (e: Exception) {
            Log.e(TAG, "Exception getting connection info", e)
            null
        }
    }
    
    /**
     * Update configuration while running
     */
    fun updateConfiguration(config: VpnConfiguration): Boolean {
        if (!isRunning.get()) {
            Log.e(TAG, "Cannot update configuration - not running")
            return false
        }
        
        if (!isNativeLibraryAvailable()) {
            Log.w(TAG, "Native library not available, cannot update configuration")
            return false
        }
        
        return try {
            val configJson = convertConfigurationToJson(config)
            if (configJson == null) {
                Log.e(TAG, "Failed to convert configuration to JSON")
                return false
            }
            
            val result = nativeUpdateConfiguration(configJson)
            if (result) {
                currentConfiguration.set(configJson)
                Log.i(TAG, "Configuration updated successfully")
            } else {
                Log.e(TAG, "Failed to update configuration")
            }
            result
        } catch (e: Exception) {
            Log.e(TAG, "Exception updating configuration", e)
            false
        }
    }
    
    /**
     * Get memory usage statistics
     */
    fun getMemoryUsage(): MemoryStats? {
        if (!isNativeLibraryAvailable()) {
            return null
        }
        
        return try {
            val memoryJson = nativeGetMemoryUsage()
            if (memoryJson != null) {
                parseMemoryStats(memoryJson)
            } else {
                null
            }
        } catch (e: Exception) {
            Log.e(TAG, "Exception getting memory usage", e)
            null
        }
    }
    
    /**
     * Optimize performance
     */
    fun optimizePerformance(): Boolean {
        if (!isNativeLibraryAvailable()) {
            return false
        }
        
        return try {
            nativeOptimizePerformance()
        } catch (e: Exception) {
            Log.e(TAG, "Exception optimizing performance", e)
            false
        }
    }
    
    /**
     * Handle network change
     */
    fun handleNetworkChange(networkInfo: SingboxNetworkInfo): Boolean {
        if (!isNativeLibraryAvailable()) {
            return false
        }
        
        return try {
            val networkJson = convertNetworkInfoToJson(networkInfo)
            nativeHandleNetworkChange(networkJson)
        } catch (e: Exception) {
            Log.e(TAG, "Exception handling network change", e)
            false
        }
    }
    
    /**
     * Cleanup resources
     */
    fun cleanup() {
        Log.i(TAG, "Cleaning up SingboxManager")
        
        try {
            if (isRunning.get()) {
                stop()
            }
            
            if (isNativeLibraryAvailable()) {
                nativeCleanup()
            }
            
            isInitialized.set(false)
            isRunning.set(false)
            currentConfiguration.set(null)
            startTime = null
            lastError.set(null)
            
            // Cancel coroutine scope
            scope.cancel()
            
            Log.i(TAG, "SingboxManager cleanup completed")
        } catch (e: Exception) {
            Log.e(TAG, "Exception during cleanup", e)
        }
    }
    
    /**
     * Convert VpnConfiguration to sing-box JSON format
     */
    private fun convertConfigurationToJson(config: VpnConfiguration): String? {
        return try {
            // This is a simplified conversion - in a full implementation,
            // you'd use the AdvancedSingboxConfigurationConverter from the design
            val singboxConfig = buildJsonObject {
                put("log", buildJsonObject {
                    put("level", "info")
                    put("timestamp", true)
                })
                
                put("inbounds", buildJsonArray {
                    add(buildJsonObject {
                        put("type", "tun")
                        put("tag", "tun-in")
                        put("interface_name", "tun0")
                        put("inet4_address", "172.19.0.1/30")
                        put("mtu", 9000)
                        put("auto_route", true)
                        put("strict_route", true)
                        put("stack", "system")
                        put("sniff", true)
                    })
                })
                
                put("outbounds", buildJsonArray {
                    add(buildJsonObject {
                        put("type", config.protocol.lowercase())
                        put("tag", "proxy")
                        put("server", config.serverAddress)
                        put("server_port", config.serverPort)
                        
                        // Add protocol-specific configuration
                        when (config.protocol.lowercase()) {
                            "vless" -> {
                                put("uuid", config.protocolSpecificConfig["uuid"]?.toString() ?: "")
                                put("flow", config.protocolSpecificConfig["flow"]?.toString() ?: "")
                                config.protocolSpecificConfig["transport"]?.let { transport ->
                                    put("transport", buildJsonObject {
                                        put("type", transport.toString())
                                    })
                                }
                            }
                            "vmess" -> {
                                put("uuid", config.protocolSpecificConfig["uuid"]?.toString() ?: "")
                                put("alter_id", config.protocolSpecificConfig["alterId"]?.toString()?.toIntOrNull() ?: 0)
                                put("security", config.protocolSpecificConfig["security"]?.toString() ?: "auto")
                            }
                            "trojan" -> {
                                put("password", config.protocolSpecificConfig["password"]?.toString() ?: "")
                            }
                            "shadowsocks" -> {
                                put("method", config.protocolSpecificConfig["method"]?.toString() ?: "aes-256-gcm")
                                put("password", config.protocolSpecificConfig["password"]?.toString() ?: "")
                            }
                        }
                    })
                    
                    // Add direct outbound
                    add(buildJsonObject {
                        put("type", "direct")
                        put("tag", "direct")
                    })
                })
                
                put("route", buildJsonObject {
                    put("final", "proxy")
                    put("auto_detect_interface", true)
                })
            }
            
            singboxConfig.toString()
        } catch (e: Exception) {
            Log.e(TAG, "Exception converting configuration to JSON", e)
            null
        }
    }
    
    /**
     * Parse network statistics from JSON
     */
    private fun parseNetworkStats(statsJson: String): NetworkStats? {
        return try {
            val json = Json.parseToJsonElement(statsJson).jsonObject
            
            val bytesReceived = json["download_bytes"]?.jsonPrimitive?.longOrNull ?: 0L
            val bytesSent = json["upload_bytes"]?.jsonPrimitive?.longOrNull ?: 0L
            val downloadSpeed = json["download_speed"]?.jsonPrimitive?.doubleOrNull ?: 0.0
            val uploadSpeed = json["upload_speed"]?.jsonPrimitive?.doubleOrNull ?: 0.0
            val packetsReceived = json["packets_received"]?.jsonPrimitive?.intOrNull ?: 0
            val packetsSent = json["packets_sent"]?.jsonPrimitive?.intOrNull ?: 0
            val connectionTime = json["connection_time"]?.jsonPrimitive?.longOrNull ?: 0L
            
            val connectionDuration = if (startTime != null) {
                Duration.between(startTime, LocalDateTime.now())
            } else {
                Duration.ofSeconds(connectionTime)
            }
            
            NetworkStats(
                bytesReceived = bytesReceived,
                bytesSent = bytesSent,
                downloadSpeed = downloadSpeed,
                uploadSpeed = uploadSpeed,
                packetsReceived = packetsReceived,
                packetsSent = packetsSent,
                connectionDuration = connectionDuration,
                lastUpdated = LocalDateTime.now(),
                formattedDownloadSpeed = formatSpeed(downloadSpeed),
                formattedUploadSpeed = formatSpeed(uploadSpeed)
            )
        } catch (e: Exception) {
            Log.e(TAG, "Exception parsing network stats", e)
            null
        }
    }
    
    /**
     * Parse detailed network statistics from JSON
     */
    private fun parseDetailedNetworkStats(statsJson: String): DetailedNetworkStats? {
        return try {
            val json = Json.parseToJsonElement(statsJson).jsonObject
            
            val basicStats = parseNetworkStats(statsJson) ?: return null
            
            val latency = json["latency"]?.jsonPrimitive?.intOrNull ?: 0
            val jitter = json["jitter"]?.jsonPrimitive?.intOrNull ?: 0
            val packetLoss = json["packetLoss"]?.jsonPrimitive?.doubleOrNull ?: 0.0
            
            DetailedNetworkStats(
                basicStats = basicStats,
                latency = Duration.ofMillis(latency.toLong()),
                jitter = Duration.ofMillis(jitter.toLong()),
                packetLossRate = packetLoss
            )
        } catch (e: Exception) {
            Log.e(TAG, "Exception parsing detailed network stats", e)
            null
        }
    }
    
    /**
     * Parse logs from JSON
     */
    private fun parseLogs(logsJson: String): List<String> {
        return try {
            val json = Json.parseToJsonElement(logsJson).jsonObject
            val logsArray = json["logs"]?.jsonArray
            logsArray?.map { it.jsonPrimitive.content } ?: emptyList()
        } catch (e: Exception) {
            Log.e(TAG, "Exception parsing logs", e)
            emptyList()
        }
    }
    
    /**
     * Parse connection info from JSON
     */
    private fun parseConnectionInfo(infoJson: String): ConnectionInfo? {
        return try {
            val json = Json.parseToJsonElement(infoJson).jsonObject
            
            ConnectionInfo(
                serverAddress = json["server_address"]?.jsonPrimitive?.content ?: "",
                serverPort = json["server_port"]?.jsonPrimitive?.intOrNull ?: 0,
                protocol = json["protocol"]?.jsonPrimitive?.content ?: "",
                localAddress = json["local_address"]?.jsonPrimitive?.contentOrNull,
                remoteAddress = json["remote_address"]?.jsonPrimitive?.contentOrNull,
                connectionTime = LocalDateTime.now(), // Simplified
                isConnected = json["is_connected"]?.jsonPrimitive?.booleanOrNull ?: false,
                lastPingTime = json["last_ping_ms"]?.jsonPrimitive?.longOrNull?.let { Duration.ofMillis(it) }
            )
        } catch (e: Exception) {
            Log.e(TAG, "Exception parsing connection info", e)
            null
        }
    }
    
    /**
     * Parse memory stats from JSON
     */
    private fun parseMemoryStats(memoryJson: String): MemoryStats? {
        return try {
            val json = Json.parseToJsonElement(memoryJson).jsonObject
            
            MemoryStats(
                totalMemoryMB = json["total_memory_mb"]?.jsonPrimitive?.intOrNull ?: 0,
                usedMemoryMB = json["used_memory_mb"]?.jsonPrimitive?.intOrNull ?: 0,
                cpuUsagePercent = json["cpu_usage_percent"]?.jsonPrimitive?.doubleOrNull ?: 0.0,
                openFileDescriptors = json["open_file_descriptors"]?.jsonPrimitive?.intOrNull ?: 0
            )
        } catch (e: Exception) {
            Log.e(TAG, "Exception parsing memory stats", e)
            null
        }
    }
    
    /**
     * Convert network info to JSON
     */
    private fun convertNetworkInfoToJson(networkInfo: SingboxNetworkInfo): String {
        return buildJsonObject {
            put("network_type", networkInfo.networkType)
            put("is_connected", networkInfo.isConnected)
            put("is_wifi", networkInfo.isWifi)
            put("is_mobile", networkInfo.isMobile)
            networkInfo.networkName?.let { put("network_name", it) }
            networkInfo.ipAddress?.let { put("ip_address", it) }
            networkInfo.mtu?.let { put("mtu", it) }
        }.toString()
    }
    
    /**
     * Format speed in human-readable format
     */
    private fun formatSpeed(bytesPerSecond: Double): String {
        return when {
            bytesPerSecond < 1024 -> "${bytesPerSecond.toInt()} B/s"
            bytesPerSecond < 1024 * 1024 -> "${(bytesPerSecond / 1024).toInt()} KB/s"
            bytesPerSecond < 1024 * 1024 * 1024 -> "${(bytesPerSecond / (1024 * 1024)).toInt()} MB/s"
            else -> "${(bytesPerSecond / (1024 * 1024 * 1024)).toInt()} GB/s"
        }
    }
}

/**
 * Network information data class for SingboxManager
 */
data class SingboxNetworkInfo(
    val networkType: String,
    val isConnected: Boolean,
    val isWifi: Boolean,
    val isMobile: Boolean,
    val networkName: String?,
    val ipAddress: String?,
    val mtu: Int?
)

/**
 * Network statistics data class
 */
data class NetworkStats(
    val bytesReceived: Long,
    val bytesSent: Long,
    val downloadSpeed: Double,
    val uploadSpeed: Double,
    val packetsReceived: Int,
    val packetsSent: Int,
    val connectionDuration: Duration,
    val lastUpdated: LocalDateTime,
    val formattedDownloadSpeed: String,
    val formattedUploadSpeed: String
)

/**
 * Detailed network statistics data class
 */
data class DetailedNetworkStats(
    val basicStats: NetworkStats,
    val latency: Duration,
    val jitter: Duration,
    val packetLossRate: Double
)

/**
 * VPN Configuration data class
 */
data class VpnConfiguration(
    val id: String,
    val name: String,
    val serverAddress: String,
    val serverPort: Int,
    val protocol: String,
    val authMethod: String,
    val protocolSpecificConfig: Map<String, Any>,
    val autoConnect: Boolean,
    val createdAt: LocalDateTime,
    val lastUsed: LocalDateTime?
)

/**
 * Log level enumeration
 */
enum class LogLevel {
    TRACE,
    DEBUG,
    INFO,
    WARN,
    ERROR,
    FATAL
}

/**
 * Connection information data class
 */
data class ConnectionInfo(
    val serverAddress: String,
    val serverPort: Int,
    val protocol: String,
    val localAddress: String?,
    val remoteAddress: String?,
    val connectionTime: LocalDateTime,
    val isConnected: Boolean,
    val lastPingTime: Duration?
)

/**
 * Memory statistics data class
 */
data class MemoryStats(
    val totalMemoryMB: Int,
    val usedMemoryMB: Int,
    val cpuUsagePercent: Double,
    val openFileDescriptors: Int
)

