package com.tunnelmax.vpnclient

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.net.VpnService
import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry
import kotlinx.coroutines.*
import kotlinx.serialization.json.*
import java.time.LocalDateTime
import java.util.concurrent.atomic.AtomicBoolean

class VpnPlugin : FlutterPlugin, MethodCallHandler, ActivityAware, PluginRegistry.ActivityResultListener {
    private lateinit var channel: MethodChannel
    private lateinit var statusChannel: EventChannel
    private lateinit var statsChannel: EventChannel
    private var statusSink: EventChannel.EventSink? = null
    private var statsSink: EventChannel.EventSink? = null
    private var activity: Activity? = null
    private var context: Context? = null
    
    private val isConnected = AtomicBoolean(false)
    private val isConnecting = AtomicBoolean(false)
    private var currentConfig: Map<String, Any>? = null
    private var singboxConfig: JsonObject? = null
    
    // Real sing-box integration
    private var singboxManager: SingboxManager? = null
    private var statsCollector: StatsCollector? = null
    private var statsCollectionJob: Job? = null
    
    private val handler = Handler(Looper.getMainLooper())
    private val scope = CoroutineScope(Dispatchers.Main + SupervisorJob())
    
    companion object {
        private const val VPN_REQUEST_CODE = 1001
        private const val CHANNEL_NAME = "vpn_control"
        private const val STATUS_CHANNEL_NAME = "vpn_status"
        private const val STATS_CHANNEL_NAME = "vpn_stats"
    }

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        context = flutterPluginBinding.applicationContext
        
        // Initialize sing-box manager
        context?.let { ctx ->
            singboxManager = SingboxManager(ctx).apply {
                if (!initialize()) {
                    Log.e("VpnPlugin", "Failed to initialize SingboxManager")
                }
            }
            
            // Initialize stats collector
            singboxManager?.let { manager ->
                statsCollector = StatsCollector(manager)
            }
        }
        
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, CHANNEL_NAME)
        channel.setMethodCallHandler(this)
        
        statusChannel = EventChannel(flutterPluginBinding.binaryMessenger, STATUS_CHANNEL_NAME)
        statusChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                statusSink = events
                // Send initial status
                sendStatusUpdate(createStatusMap())
            }

            override fun onCancel(arguments: Any?) {
                statusSink = null
            }
        })
        
        statsChannel = EventChannel(flutterPluginBinding.binaryMessenger, STATS_CHANNEL_NAME)
        statsChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                statsSink = events
                // Start statistics streaming if VPN is connected
                if (isConnected.get()) {
                    startStatsStreaming()
                }
            }

            override fun onCancel(arguments: Any?) {
                statsSink = null
                stopStatsStreaming()
            }
        })
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        statusChannel.setStreamHandler(null)
        
        // Cleanup sing-box resources
        stopStatsStreaming()
        statsCollector?.cleanup()
        singboxManager?.cleanup()
        
        scope.cancel()
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        binding.addActivityResultListener(this)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
        binding.addActivityResultListener(this)
    }

    override fun onDetachedFromActivity() {
        activity = null
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "connect" -> handleConnect(call, result)
            "disconnect" -> handleDisconnect(result)
            "getStatus" -> handleGetStatus(result)
            "getNetworkStats" -> handleGetNetworkStats(result)
            "hasVpnPermission" -> handleHasVpnPermission(result)
            "requestVpnPermission" -> handleRequestVpnPermission(result)
            "getSingboxStatus" -> handleGetSingboxStatus(result)
            "resetStatistics" -> handleResetStatistics(result)
            "getLastError" -> handleGetLastError(result)
            else -> result.notImplemented()
        }
    }

    private fun handleConnect(call: MethodCall, result: Result) {
        if (isConnected.get() || isConnecting.get()) {
            result.error("ALREADY_CONNECTED", "VPN is already connected or connecting", null)
            return
        }

        val config = call.argument<Map<String, Any>>("config")
        val singboxConfigMap = call.argument<Map<String, Any>>("singboxConfig")
        
        if (config == null || singboxConfigMap == null) {
            result.error("INVALID_ARGUMENTS", "Configuration and singbox config are required", null)
            return
        }

        try {
            // Parse singbox configuration
            val configJson = Json.encodeToString(JsonObject.serializer(), JsonObject(
                singboxConfigMap.mapValues { entry ->
                    when (val value = entry.value) {
                        is String -> JsonPrimitive(value)
                        is Number -> JsonPrimitive(value)
                        is Boolean -> JsonPrimitive(value)
                        is Map<*, *> -> JsonObject(
                            (value as Map<String, Any>).mapValues { subEntry ->
                                when (val subValue = subEntry.value) {
                                    is String -> JsonPrimitive(subValue)
                                    is Number -> JsonPrimitive(subValue)
                                    is Boolean -> JsonPrimitive(subValue)
                                    else -> JsonPrimitive(subValue.toString())
                                }
                            }
                        )
                        else -> JsonPrimitive(value.toString())
                    }
                }
            ))
            
            singboxConfig = Json.parseToJsonElement(configJson).jsonObject
            currentConfig = config
            
            // Start VPN connection
            scope.launch {
                try {
                    connectVpn(result)
                } catch (e: Exception) {
                    isConnecting.set(false)
                    result.error("CONNECTION_FAILED", "Failed to connect: ${e.message}", null)
                    sendStatusUpdate(createErrorStatusMap("Connection failed: ${e.message}"))
                }
            }
        } catch (e: Exception) {
            result.error("CONFIG_PARSE_ERROR", "Failed to parse configuration: ${e.message}", null)
        }
    }

    private suspend fun connectVpn(result: Result) = withContext(Dispatchers.Main) {
        isConnecting.set(true)
        sendStatusUpdate(createConnectingStatusMap())
        
        // Check VPN permission
        if (!hasVpnPermission()) {
            val intent = VpnService.prepare(context)
            if (intent != null) {
                activity?.startActivityForResult(intent, VPN_REQUEST_CODE)
                // Result will be handled in onActivityResult
                return@withContext
            }
        }
        
        // Start VPN service with singbox configuration
        val success = startVpnService()
        
        if (success) {
            isConnected.set(true)
            isConnecting.set(false)
            result.success(true)
            sendStatusUpdate(createConnectedStatusMap())
            // Start statistics streaming if sink is available
            if (statsSink != null) {
                startStatsStreaming()
            }
        } else {
            isConnecting.set(false)
            result.error("CONNECTION_FAILED", "Failed to start VPN service", null)
            sendStatusUpdate(createErrorStatusMap("Failed to start VPN service"))
        }
    }

    private fun handleDisconnect(result: Result) {
        if (!isConnected.get() && !isConnecting.get()) {
            result.success(true)
            return
        }

        scope.launch {
            try {
                // Stop statistics streaming
                stopStatsStreaming()
                
                val success = stopVpnService()
                isConnected.set(false)
                isConnecting.set(false)
                currentConfig = null
                singboxConfig = null
                
                result.success(success)
                sendStatusUpdate(createDisconnectedStatusMap())
            } catch (e: Exception) {
                result.error("DISCONNECTION_FAILED", "Failed to disconnect: ${e.message}", null)
            }
        }
    }

    private fun handleGetStatus(result: Result) {
        result.success(createStatusMap())
    }

    private fun handleGetNetworkStats(result: Result) {
        if (!isConnected.get()) {
            result.success(null)
            return
        }
        
        // Get network statistics from singbox
        val stats = getNetworkStatistics()
        result.success(stats)
    }

    private fun handleHasVpnPermission(result: Result) {
        result.success(hasVpnPermission())
    }

    private fun handleRequestVpnPermission(result: Result) {
        if (hasVpnPermission()) {
            result.success(true)
            return
        }
        
        val intent = VpnService.prepare(context)
        if (intent != null) {
            activity?.startActivityForResult(intent, VPN_REQUEST_CODE)
            // Store result callback for later use
            // This is a simplified implementation
            result.success(false)
        } else {
            result.success(true)
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode == VPN_REQUEST_CODE) {
            if (resultCode == Activity.RESULT_OK) {
                // Permission granted, continue with connection
                scope.launch {
                    try {
                        val success = startVpnService()
                        if (success) {
                            isConnected.set(true)
                            isConnecting.set(false)
                            sendStatusUpdate(createConnectedStatusMap())
                        } else {
                            isConnecting.set(false)
                            sendStatusUpdate(createErrorStatusMap("Failed to start VPN service"))
                        }
                    } catch (e: Exception) {
                        isConnecting.set(false)
                        sendStatusUpdate(createErrorStatusMap("Connection failed: ${e.message}"))
                    }
                }
            } else {
                // Permission denied
                isConnecting.set(false)
                sendStatusUpdate(createErrorStatusMap("VPN permission denied"))
            }
            return true
        }
        return false
    }

    private fun hasVpnPermission(): Boolean {
        return VpnService.prepare(context) == null
    }

    private fun startVpnService(): Boolean {
        return try {
            // Convert current config to VPN configuration JSON
            val vpnConfigJson = createVpnConfigurationJson()
            if (vpnConfigJson == null) {
                Log.e("VpnPlugin", "Failed to create VPN configuration JSON")
                return false
            }
            
            val intent = Intent(context, TunnelMaxVpnService::class.java).apply {
                action = TunnelMaxVpnService.ACTION_START
                putExtra("vpn_config", vpnConfigJson)
                putExtra("server_address", currentConfig?.get("serverAddress") as? String ?: "")
                putExtra("server_port", currentConfig?.get("serverPort") as? Int ?: 0)
            }
            context?.startForegroundService(intent)
            true
        } catch (e: Exception) {
            Log.e("VpnPlugin", "Failed to start VPN service", e)
            false
        }
    }

    private fun stopVpnService(): Boolean {
        return try {
            val intent = Intent(context, TunnelMaxVpnService::class.java).apply {
                action = TunnelMaxVpnService.ACTION_STOP
            }
            context?.startService(intent)
            true
        } catch (e: Exception) {
            false
        }
    }

    private fun getNetworkStatistics(): Map<String, Any>? {
        return try {
            val stats = singboxManager?.getStatistics() ?: return null
            
            mapOf(
                "bytesReceived" to stats.bytesReceived,
                "bytesSent" to stats.bytesSent,
                "downloadSpeed" to stats.downloadSpeed,
                "uploadSpeed" to stats.uploadSpeed,
                "packetsReceived" to stats.packetsReceived,
                "packetsSent" to stats.packetsSent,
                "connectionDuration" to stats.connectionDuration.toMillis(),
                "lastUpdated" to stats.lastUpdated.toString(),
                "formattedDownloadSpeed" to stats.formattedDownloadSpeed,
                "formattedUploadSpeed" to stats.formattedUploadSpeed
            )
        } catch (e: Exception) {
            Log.e("VpnPlugin", "Error getting network statistics", e)
            null
        }
    }
    
    /**
     * Start streaming statistics to Flutter using real StatsCollector
     */
    private fun startStatsStreaming() {
        if (statsSink == null || !isConnected.get()) {
            Log.d("VpnPlugin", "Cannot start stats streaming: sink=${statsSink != null}, connected=${isConnected.get()}")
            return
        }
        
        val collector = statsCollector
        if (collector == null) {
            Log.e("VpnPlugin", "StatsCollector not initialized")
            return
        }
        
        // Stop any existing collection
        stopStatsStreaming()
        
        Log.i("VpnPlugin", "Starting real-time statistics streaming")
        
        statsCollectionJob = scope.launch {
            try {
                // Start collecting statistics and observe the flow
                collector.start(1000L).collect { stats ->
                    try {
                        val statsMap = mapOf(
                            "bytesReceived" to stats.bytesReceived,
                            "bytesSent" to stats.bytesSent,
                            "downloadSpeed" to stats.downloadSpeed,
                            "uploadSpeed" to stats.uploadSpeed,
                            "packetsReceived" to stats.packetsReceived,
                            "packetsSent" to stats.packetsSent,
                            "connectionDuration" to stats.connectionDuration.toMillis(),
                            "lastUpdated" to stats.lastUpdated.toString(),
                            "formattedDownloadSpeed" to stats.formattedDownloadSpeed,
                            "formattedUploadSpeed" to stats.formattedUploadSpeed
                        )
                        
                        // Send to Flutter on main thread
                        handler.post {
                            statsSink?.success(statsMap)
                        }
                        
                        Log.v("VpnPlugin", "Streamed stats: ${stats.formattedDownloadSpeed} ↓ ${stats.formattedUploadSpeed} ↑")
                        
                    } catch (e: Exception) {
                        Log.e("VpnPlugin", "Error processing statistics for Flutter", e)
                    }
                }
            } catch (e: CancellationException) {
                Log.d("VpnPlugin", "Statistics streaming cancelled")
            } catch (e: Exception) {
                Log.e("VpnPlugin", "Error in statistics streaming", e)
                // Send error status to Flutter
                handler.post {
                    sendStatusUpdate(createErrorStatusMap("Statistics collection failed: ${e.message}"))
                }
            }
        }
        
        // Also observe error flow for proper error handling
        scope.launch {
            try {
                collector.errorFlow.collect { error ->
                    Log.w("VpnPlugin", "Statistics collection error: ${error.message}")
                    
                    // Send error information to Flutter via status channel
                    handler.post {
                        val errorStatus = createStatusMap().toMutableMap().apply {
                            put("statsError", error.message)
                            put("statsErrorTimestamp", error.timestamp.toString())
                        }
                        sendStatusUpdate(errorStatus)
                    }
                }
            } catch (e: CancellationException) {
                Log.d("VpnPlugin", "Error flow observation cancelled")
            } catch (e: Exception) {
                Log.e("VpnPlugin", "Error observing statistics errors", e)
            }
        }
    }
    
    /**
     * Stop streaming statistics to Flutter
     */
    private fun stopStatsStreaming() {
        Log.d("VpnPlugin", "Stopping statistics streaming")
        
        // Cancel the collection job
        statsCollectionJob?.cancel()
        statsCollectionJob = null
        
        // Stop the stats collector
        statsCollector?.stop()
    }

    private fun createStatusMap(): Map<String, Any> {
        return when {
            isConnecting.get() -> createConnectingStatusMap()
            isConnected.get() -> createConnectedStatusMap()
            else -> createDisconnectedStatusMap()
        }
    }

    private fun createConnectedStatusMap(): Map<String, Any> {
        val baseStatus = mapOf(
            "state" to "connected",
            "serverAddress" to (currentConfig?.get("serverAddress") as? String ?: ""),
            "serverPort" to (currentConfig?.get("serverPort") as? Int ?: 0),
            "protocol" to (currentConfig?.get("protocol") as? String ?: ""),
            "connectedAt" to System.currentTimeMillis(),
            "hasActiveConnection" to true,
            "error" to ""
        )
        
        // Add sing-box specific status information
        val singboxStatus = try {
            val manager = singboxManager
            if (manager != null) {
                mapOf(
                    "singboxRunning" to manager.isRunning(),
                    "singboxError" to manager.getLastError(),
                    "hasConfiguration" to (manager.getCurrentConfiguration() != null),
                    "statsCollecting" to (statsCollector?.isCollecting() ?: false)
                )
            } else {
                mapOf(
                    "singboxRunning" to false,
                    "singboxError" to "SingboxManager not initialized",
                    "hasConfiguration" to false,
                    "statsCollecting" to false
                )
            }
        } catch (e: Exception) {
            mapOf(
                "singboxRunning" to false,
                "singboxError" to "Error getting status: ${e.message}",
                "hasConfiguration" to false,
                "statsCollecting" to false
            )
        }
        
        return (baseStatus + singboxStatus) as Map<String, Any>
    }

    private fun createConnectingStatusMap(): Map<String, Any> {
        return mapOf(
            "state" to "connecting",
            "serverAddress" to (currentConfig?.get("serverAddress") as? String ?: ""),
            "serverPort" to (currentConfig?.get("serverPort") as? Int ?: 0),
            "protocol" to (currentConfig?.get("protocol") as? String ?: ""),
            "connectedAt" to 0L,
            "hasActiveConnection" to false,
            "error" to ""
        )
    }

    private fun createDisconnectedStatusMap(): Map<String, Any> {
        return mapOf(
            "state" to "disconnected",
            "serverAddress" to "",
            "serverPort" to 0,
            "protocol" to "",
            "connectedAt" to 0L,
            "hasActiveConnection" to false,
            "error" to ""
        )
    }

    private fun createErrorStatusMap(error: String): Map<String, Any> {
        return mapOf(
            "state" to "error",
            "serverAddress" to (currentConfig?.get("serverAddress") as? String ?: ""),
            "serverPort" to (currentConfig?.get("serverPort") as? Int ?: 0),
            "protocol" to (currentConfig?.get("protocol") as? String ?: ""),
            "connectedAt" to 0L,
            "hasActiveConnection" to false,
            "error" to error
        )
    }

    private fun sendStatusUpdate(status: Map<String, Any>) {
        handler.post {
            statusSink?.success(status)
        }
    }
    
    /**
     * Handle getSingboxStatus method call
     */
    private fun handleGetSingboxStatus(result: Result) {
        try {
            val manager = singboxManager
            if (manager == null) {
                result.success(mapOf(
                    "initialized" to false,
                    "running" to false,
                    "error" to "SingboxManager not initialized"
                ))
                return
            }
            
            val status = mapOf(
                "initialized" to true,
                "running" to manager.isRunning(),
                "hasConfiguration" to (manager.getCurrentConfiguration() != null),
                "lastError" to manager.getLastError(),
                "collectorHealth" to (statsCollector?.getCollectionHealth() ?: emptyMap<String, Any>())
            )
            
            result.success(status)
        } catch (e: Exception) {
            Log.e("VpnPlugin", "Error getting sing-box status", e)
            result.error("SINGBOX_STATUS_ERROR", "Failed to get sing-box status: ${e.message}", null)
        }
    }
    
    /**
     * Handle resetStatistics method call
     */
    private fun handleResetStatistics(result: Result) {
        try {
            val success = statsCollector?.resetStatistics() ?: false
            result.success(success)
            
            if (success) {
                Log.i("VpnPlugin", "Statistics reset successfully")
            } else {
                Log.w("VpnPlugin", "Failed to reset statistics")
            }
        } catch (e: Exception) {
            Log.e("VpnPlugin", "Error resetting statistics", e)
            result.error("RESET_STATS_ERROR", "Failed to reset statistics: ${e.message}", null)
        }
    }
    
    /**
     * Handle getLastError method call
     */
    private fun handleGetLastError(result: Result) {
        try {
            val lastError = singboxManager?.getLastError()
            result.success(mapOf(
                "error" to lastError,
                "timestamp" to System.currentTimeMillis(),
                "hasError" to (lastError != null)
            ))
        } catch (e: Exception) {
            Log.e("VpnPlugin", "Error getting last error", e)
            result.error("GET_ERROR_FAILED", "Failed to get last error: ${e.message}", null)
        }
    }
    
    /**
     * Create VPN configuration JSON from current config and singbox config
     */
    private fun createVpnConfigurationJson(): String? {
        val config = currentConfig ?: return null
        
        return try {
            val vpnConfigJson = buildJsonObject {
                put("id", config["id"] as? String ?: "default")
                put("name", config["name"] as? String ?: "VPN Connection")
                put("serverAddress", config["serverAddress"] as? String ?: "")
                put("serverPort", config["serverPort"] as? Int ?: 0)
                put("protocol", config["protocol"] as? String ?: "vless")
                put("authMethod", config["authMethod"] as? String ?: "none")
                put("protocolSpecificConfig", JsonObject(
                    (config["protocolSpecificConfig"] as? Map<String, Any>)?.mapValues { 
                        when (val value = it.value) {
                            is String -> JsonPrimitive(value)
                            is Number -> JsonPrimitive(value)
                            is Boolean -> JsonPrimitive(value)
                            else -> JsonPrimitive(value.toString())
                        }
                    } ?: emptyMap()
                ))
                put("autoConnect", config["autoConnect"] as? Boolean ?: false)
                put("createdAt", LocalDateTime.now().toString())
                put("lastUsed", LocalDateTime.now().toString())
            }
            
            vpnConfigJson.toString()
        } catch (e: Exception) {
            Log.e("VpnPlugin", "Failed to create VPN configuration JSON", e)
            null
        }
    }
}