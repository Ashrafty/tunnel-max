package com.example.tunnel_max.vpn

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.net.VpnService
import android.util.Log
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import kotlinx.coroutines.*
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import java.util.concurrent.atomic.AtomicReference

class VpnChannelHandler(
    private val context: Context,
    private val activity: Activity?
) : MethodCallHandler {
    
    companion object {
        private const val TAG = "VpnChannelHandler"
        private const val CHANNEL_NAME = "com.example.tunnel_max/vpn"
        private const val VPN_PERMISSION_REQUEST_CODE = 1001
        
        // Static reference to the method channel for callbacks
        private val methodChannel = AtomicReference<MethodChannel?>(null)
        
        fun setMethodChannel(channel: MethodChannel) {
            methodChannel.set(channel)
        }
        
        fun notifyConnectionStatus(status: VpnStatus, serverName: String?, error: String? = null) {
            val statusInfo = VpnStatusInfo(
                status = status,
                connectedServer = serverName,
                connectionStartTime = if (status == VpnStatus.CONNECTED) System.currentTimeMillis() else null,
                lastError = error
            )
            
            methodChannel.get()?.invokeMethod("onConnectionStatusChanged", Json.encodeToString(statusInfo))
        }
        
        fun notifyStatsUpdate(stats: NetworkStats) {
            methodChannel.get()?.invokeMethod("onStatsUpdate", Json.encodeToString(stats))
        }
    }
    
    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "connect" -> handleConnect(call, result)
            "disconnect" -> handleDisconnect(result)
            "getStatus" -> handleGetStatus(result)
            "getStats" -> handleGetStats(result)
            "requestVpnPermission" -> handleRequestVpnPermission(result)
            "checkVpnPermission" -> handleCheckVpnPermission(result)
            "validateConfiguration" -> handleValidateConfiguration(call, result)
            else -> result.notImplemented()
        }
    }
    
    private fun handleConnect(call: MethodCall, result: Result) {
        try {
            val configJson = call.argument<String>("config")
            if (configJson == null) {
                result.error("INVALID_ARGUMENT", "Configuration is required", null)
                return
            }
            
            // Parse and validate configuration
            val config = Json.decodeFromString<VpnConfiguration>(configJson)
            val validation = VpnUtils.validateConfiguration(config)
            if (!validation.isValid) {
                result.error("INVALID_CONFIGURATION", validation.errors.joinToString(", "), null)
                return
            }
            
            // Check VPN permission first
            val vpnIntent = VpnService.prepare(context)
            if (vpnIntent != null) {
                result.error("VPN_PERMISSION_REQUIRED", "VPN permission not granted", null)
                return
            }
            
            // Start VPN service
            val serviceIntent = Intent(context, TunnelMaxVpnService::class.java).apply {
                action = "com.example.tunnel_max.vpn.CONNECT"
                putExtra("config", configJson)
            }
            
            context.startForegroundService(serviceIntent)
            result.success(true)
            
        } catch (e: Exception) {
            Log.e(TAG, "Failed to connect VPN", e)
            result.error("CONNECTION_FAILED", e.message, null)
        }
    }
    
    private fun handleDisconnect(result: Result) {
        try {
            val serviceIntent = Intent(context, TunnelMaxVpnService::class.java).apply {
                action = "com.example.tunnel_max.vpn.DISCONNECT"
            }
            
            context.startService(serviceIntent)
            result.success(true)
            
        } catch (e: Exception) {
            Log.e(TAG, "Failed to disconnect VPN", e)
            result.error("DISCONNECTION_FAILED", e.message, null)
        }
    }
    
    private fun handleGetStatus(result: Result) {
        try {
            val isConnected = TunnelMaxVpnService.isConnected()
            val currentConfig = TunnelMaxVpnService.getCurrentConfig()
            
            val statusInfo = VpnStatusInfo(
                status = if (isConnected) VpnStatus.CONNECTED else VpnStatus.DISCONNECTED,
                connectedServer = currentConfig?.name,
                connectionStartTime = if (isConnected) System.currentTimeMillis() else null,
                currentStats = TunnelMaxVpnService.getConnectionStats()
            )
            
            result.success(Json.encodeToString(statusInfo))
            
        } catch (e: Exception) {
            Log.e(TAG, "Failed to get VPN status", e)
            result.error("STATUS_ERROR", e.message, null)
        }
    }
    
    private fun handleGetStats(result: Result) {
        try {
            val stats = TunnelMaxVpnService.getConnectionStats()
            if (stats != null) {
                result.success(Json.encodeToString(stats))
            } else {
                result.success(null)
            }
            
        } catch (e: Exception) {
            Log.e(TAG, "Failed to get VPN stats", e)
            result.error("STATS_ERROR", e.message, null)
        }
    }
    
    private fun handleRequestVpnPermission(result: Result) {
        try {
            val vpnIntent = VpnService.prepare(context)
            if (vpnIntent != null) {
                if (activity != null) {
                    activity.startActivityForResult(vpnIntent, VPN_PERMISSION_REQUEST_CODE)
                    result.success(false) // Permission not yet granted
                } else {
                    result.error("NO_ACTIVITY", "Activity context required for permission request", null)
                }
            } else {
                result.success(true) // Permission already granted
            }
            
        } catch (e: Exception) {
            Log.e(TAG, "Failed to request VPN permission", e)
            result.error("PERMISSION_ERROR", e.message, null)
        }
    }
    
    private fun handleCheckVpnPermission(result: Result) {
        try {
            val vpnIntent = VpnService.prepare(context)
            result.success(vpnIntent == null)
            
        } catch (e: Exception) {
            Log.e(TAG, "Failed to check VPN permission", e)
            result.error("PERMISSION_CHECK_ERROR", e.message, null)
        }
    }
    
    private fun handleValidateConfiguration(call: MethodCall, result: Result) {
        try {
            val configJson = call.argument<String>("config")
            if (configJson == null) {
                result.error("INVALID_ARGUMENT", "Configuration is required", null)
                return
            }
            
            val config = Json.decodeFromString<VpnConfiguration>(configJson)
            val validation = VpnUtils.validateConfiguration(config)
            
            val resultMap = mapOf(
                "isValid" to validation.isValid,
                "errors" to validation.errors
            )
            
            result.success(resultMap)
            
        } catch (e: Exception) {
            Log.e(TAG, "Failed to validate configuration", e)
            result.error("VALIDATION_ERROR", e.message, null)
        }
    }
    
    fun handleActivityResult(requestCode: Int, resultCode: Int) {
        if (requestCode == VPN_PERMISSION_REQUEST_CODE) {
            val granted = resultCode == Activity.RESULT_OK
            methodChannel.get()?.invokeMethod("onVpnPermissionResult", granted)
        }
    }
}