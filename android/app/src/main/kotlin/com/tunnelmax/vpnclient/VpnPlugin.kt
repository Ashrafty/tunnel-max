package com.tunnelmax.vpnclient

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.net.VpnService
import android.util.Log
import androidx.annotation.NonNull
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry
import java.io.File

class VpnPlugin : FlutterPlugin, MethodCallHandler, ActivityAware, PluginRegistry.ActivityResultListener {
    private val TAG = "VpnPlugin"
    private lateinit var channel: MethodChannel
    private lateinit var context: Context
    private var activity: Activity? = null
    private var pendingResult: Result? = null
    private val REQUEST_VPN_PERMISSION = 1001

    private val singboxManager: SingboxManager? by lazy {
        if (SingboxManager.isLibraryLoaded) {
            SingboxManager(context)
        } else {
            Log.e(TAG, "Native libraries not loaded, SingboxManager will be null")
            null
        }
    }

    override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        Log.i(TAG, "VPN Plugin attached to engine")
        
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "com.tunnelmax.vpnclient/vpn")
        channel.setMethodCallHandler(this)
        context = flutterPluginBinding.applicationContext
        
        // Check if native libraries are loaded
        if (!SingboxManager.isLibraryLoaded) {
            Log.e(TAG, "Native libraries not loaded, some features will be disabled")
        } else {
            Log.i(TAG, "Native libraries loaded successfully")
        }
    }

    override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
        when (call.method) {
            "getPlatformVersion" -> {
                result.success("Android ${android.os.Build.VERSION.RELEASE}")
            }
            "hasVpnPermission" -> {
                hasVpnPermission(result)
            }
            "requestVpnPermission" -> {
                requestVpnPermission(result)
            }
            "connect" -> {
                val configJson = call.argument<String>("config")
                if (configJson == null) {
                    result.error("INVALID_ARGUMENT", "Config JSON is required", null)
                    return
                }
                connect(configJson, result)
            }
            "disconnect" -> {
                disconnect(result)
            }
            "getStatus" -> {
                getStatus(result)
            }
            "getNetworkStats" -> {
                getNetworkStats(result)
            }
            "isRunning" -> {
                isRunning(result)
            }
            "initSingbox" -> {
                initSingbox(result)
            }
            "setSingboxLogLevel" -> {
                val level = call.argument<Int>("level") ?: 1
                setSingboxLogLevel(level, result)
            }
            else -> {
                result.notImplemented()
            }
        }
    }

    private fun hasVpnPermission(result: Result) {
        val intent = VpnService.prepare(context)
        result.success(intent == null)
    }

    private fun requestVpnPermission(result: Result) {
        val intent = VpnService.prepare(context)
        if (intent != null) {
            pendingResult = result
            activity?.startActivityForResult(intent, REQUEST_VPN_PERMISSION)
        } else {
            // VPN permission already granted
            result.success(true)
        }
    }

    private fun connect(configJson: String, result: Result) {
        try {
            // Check VPN permission first
            val intent = VpnService.prepare(context)
            if (intent != null) {
                result.error("PERMISSION_DENIED", "VPN permission not granted", null)
                return
            }

            // Check if native libraries are loaded
            if (singboxManager == null) {
                result.error("NATIVE_LIBRARY_ERROR", "Native libraries not loaded", null)
                return
            }
            
            // Save config to temporary file
            val configFile = File(context.cacheDir, "singbox_config.json")
            configFile.writeText(configJson)
            
            val serviceIntent = Intent(context, TunnelMaxVpnService::class.java)
            serviceIntent.action = TunnelMaxVpnService.ACTION_START
            serviceIntent.putExtra(TunnelMaxVpnService.EXTRA_CONFIG_PATH, configFile.absolutePath)
            context.startService(serviceIntent)
            
            result.success(true)
        } catch (e: Exception) {
            Log.e(TAG, "Error connecting VPN", e)
            result.error("CONNECT_ERROR", e.message, null)
        }
    }

    private fun disconnect(result: Result) {
        try {
            val intent = Intent(context, TunnelMaxVpnService::class.java)
            intent.action = TunnelMaxVpnService.ACTION_STOP
            context.startService(intent)
            result.success(true)
        } catch (e: Exception) {
            Log.e(TAG, "Error disconnecting VPN", e)
            result.error("DISCONNECT_ERROR", e.message, null)
        }
    }

    private fun getStatus(result: Result) {
        try {
            val status = mapOf(
                "state" to if (TunnelMaxVpnService.isRunning) "connected" else "disconnected",
                "isConnected" to TunnelMaxVpnService.isRunning,
                "connectionTime" to if (TunnelMaxVpnService.isRunning) System.currentTimeMillis() else null
            )
            result.success(status)
        } catch (e: Exception) {
            Log.e(TAG, "Error getting status", e)
            result.error("STATUS_ERROR", e.message, null)
        }
    }

    private fun getNetworkStats(result: Result) {
        try {
            if (!TunnelMaxVpnService.isRunning) {
                result.success(null)
                return
            }
            
            // Mock network stats for now - in a real implementation, 
            // you would get these from the SingBox manager
            val stats = mapOf(
                "bytesReceived" to 1024L * 1024L, // 1MB
                "bytesSent" to 512L * 1024L,      // 512KB
                "packetsReceived" to 1000L,
                "packetsSent" to 800L,
                "connectionDuration" to 60000L,   // 1 minute
                "downloadSpeed" to 1000000.0,     // 1 Mbps
                "uploadSpeed" to 500000.0         // 0.5 Mbps
            )
            result.success(stats)
        } catch (e: Exception) {
            Log.e(TAG, "Error getting network stats", e)
            result.error("STATS_ERROR", e.message, null)
        }
    }

    private fun isRunning(result: Result) {
        result.success(TunnelMaxVpnService.isRunning)
    }

    private fun initSingbox(result: Result) {
        try {
            val manager = singboxManager
            if (manager == null) {
                result.error("NATIVE_LIBRARY_ERROR", "Native libraries not loaded", null)
                return
            }
            
            val success = manager.nativeInit()
            if (success) {
                result.success(true)
            } else {
                result.error("INIT_ERROR", "Failed to initialize sing-box", null)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error initializing sing-box", e)
            result.error("INIT_ERROR", e.message, null)
        }
    }

    private fun setSingboxLogLevel(level: Int, result: Result) {
        try {
            val manager = singboxManager
            if (manager == null) {
                result.error("NATIVE_LIBRARY_ERROR", "Native libraries not loaded", null)
                return
            }
            
            val success = manager.nativeSetLogLevel(level)
            if (success) {
                result.success(true)
            } else {
                result.error("SET_LOG_LEVEL_ERROR", "Failed to set log level", null)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error setting log level", e)
            result.error("SET_LOG_LEVEL_ERROR", e.message, null)
        }
    }

    override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
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

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode == REQUEST_VPN_PERMISSION) {
            if (resultCode == Activity.RESULT_OK) {
                pendingResult?.success(true)
            } else {
                pendingResult?.success(false)
            }
            pendingResult = null
            return true
        }
        return false
    }
}