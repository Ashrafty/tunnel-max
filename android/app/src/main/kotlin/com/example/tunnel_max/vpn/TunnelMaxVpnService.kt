package com.example.tunnel_max.vpn

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.net.VpnService
import android.os.Build
import android.os.ParcelFileDescriptor
import android.util.Log
import androidx.core.app.NotificationCompat
import com.example.tunnel_max.MainActivity
import kotlinx.coroutines.*
import kotlinx.serialization.json.Json
import java.io.IOException
import java.net.InetSocketAddress
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicReference

class TunnelMaxVpnService : VpnService() {
    companion object {
        private const val TAG = "TunnelMaxVpnService"
        private const val NOTIFICATION_ID = 1001
        private const val NOTIFICATION_CHANNEL_ID = "vpn_service_channel"
        private const val ACTION_CONNECT = "com.example.tunnel_max.vpn.CONNECT"
        private const val ACTION_DISCONNECT = "com.example.tunnel_max.vpn.DISCONNECT"
        
        // Service state
        private val isConnected = AtomicBoolean(false)
        private val currentConfig = AtomicReference<VpnConfiguration?>(null)
        private val connectionStats = AtomicReference<NetworkStats?>(null)
        
        fun isConnected(): Boolean = isConnected.get()
        fun getCurrentConfig(): VpnConfiguration? = currentConfig.get()
        fun getConnectionStats(): NetworkStats? = connectionStats.get()
    }
    
    private var vpnInterface: ParcelFileDescriptor? = null
    private var serviceScope = CoroutineScope(Dispatchers.IO + SupervisorJob())
    private var singboxInstance: SingboxManager? = null
    private var statsCollector: StatsCollector? = null
    private var networkDetector: NetworkChangeDetector? = null
    private var reconnectJob: Job? = null
    private var reconnectAttempts = 0
    private val maxReconnectAttempts = 5
    
    override fun onCreate() {
        super.onCreate()
        Log.d(TAG, "VPN Service created")
        createNotificationChannel()
        singboxInstance = SingboxManager(this)
        networkDetector = NetworkChangeDetector(this)
    }
    
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_CONNECT -> {
                val configJson = intent.getStringExtra("config")
                if (configJson != null) {
                    try {
                        val config = Json.decodeFromString<VpnConfiguration>(configJson)
                        startVpn(config)
                    } catch (e: Exception) {
                        Log.e(TAG, "Failed to parse VPN configuration", e)
                        stopSelf()
                    }
                }
            }
            ACTION_DISCONNECT -> {
                stopVpn()
            }
        }
        return START_STICKY
    }
    
    override fun onDestroy() {
        super.onDestroy()
        Log.d(TAG, "VPN Service destroyed")
        stopVpn()
        serviceScope.cancel()
    }
    
    private fun startVpn(config: VpnConfiguration) {
        if (isConnected.get()) {
            Log.w(TAG, "VPN already connected")
            return
        }
        
        serviceScope.launch {
            try {
                Log.d(TAG, "Starting VPN connection")
                currentConfig.set(config)
                
                // Start foreground service
                startForeground(NOTIFICATION_ID, createNotification("Connecting...", false))
                
                // Initialize singbox
                singboxInstance?.initialize(config)
                
                // Create VPN interface
                vpnInterface = createVpnInterface(config)
                
                if (vpnInterface != null) {
                    // Start singbox with the VPN interface
                    singboxInstance?.start(vpnInterface!!.fd)
                    
                    // Start statistics collection
                    statsCollector = StatsCollector(singboxInstance!!)
                    statsCollector?.start()
                    
                    // Start network monitoring
                    startNetworkMonitoring()
                    
                    isConnected.set(true)
                    reconnectAttempts = 0
                    
                    // Update notification
                    val notification = createNotification("Connected to ${config.name}", true)
                    val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                    notificationManager.notify(NOTIFICATION_ID, notification)
                    
                    Log.d(TAG, "VPN connected successfully")
                    
                    // Notify Flutter about connection status
                    VpnChannelHandler.notifyConnectionStatus(VpnStatus.CONNECTED, config.name)
                } else {
                    throw IOException("Failed to create VPN interface")
                }
            } catch (e: Exception) {
                Log.e(TAG, "Failed to start VPN", e)
                stopVpn()
                VpnChannelHandler.notifyConnectionStatus(VpnStatus.DISCONNECTED, null, e.message)
            }
        }
    }
    
    private fun stopVpn() {
        serviceScope.launch {
            try {
                Log.d(TAG, "Stopping VPN connection")
                
                // Stop network monitoring
                stopNetworkMonitoring()
                
                // Cancel any reconnection attempts
                reconnectJob?.cancel()
                reconnectJob = null
                
                // Stop statistics collection
                statsCollector?.stop()
                statsCollector = null
                
                // Stop singbox
                singboxInstance?.stop()
                
                // Close VPN interface
                vpnInterface?.close()
                vpnInterface = null
                
                isConnected.set(false)
                currentConfig.set(null)
                connectionStats.set(null)
                
                // Notify Flutter about disconnection
                VpnChannelHandler.notifyConnectionStatus(VpnStatus.DISCONNECTED, null)
                
                Log.d(TAG, "VPN disconnected")
            } catch (e: Exception) {
                Log.e(TAG, "Error stopping VPN", e)
            } finally {
                stopForeground(STOP_FOREGROUND_REMOVE)
                stopSelf()
            }
        }
    }
    
    private fun createVpnInterface(config: VpnConfiguration): ParcelFileDescriptor? {
        return try {
            val builder = Builder()
                .setSession("TunnelMax VPN")
                .addAddress("10.0.0.2", 24)
                .addDnsServer("8.8.8.8")
                .addDnsServer("8.8.4.4")
                .addRoute("0.0.0.0", 0)
                .setMtu(1500)
                .setBlocking(true)
            
            // Add application bypass if needed
            try {
                builder.addDisallowedApplication(packageName)
            } catch (e: Exception) {
                Log.w(TAG, "Could not bypass own application", e)
            }
            
            builder.establish()
        } catch (e: Exception) {
            Log.e(TAG, "Failed to create VPN interface", e)
            null
        }
    }
    
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                NOTIFICATION_CHANNEL_ID,
                "VPN Service",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Persistent notification for VPN service"
                setShowBadge(false)
            }
            
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.createNotificationChannel(channel)
        }
    }
    
    private fun createNotification(text: String, isConnected: Boolean): Notification {
        val intent = Intent(this, MainActivity::class.java)
        val pendingIntent = PendingIntent.getActivity(
            this, 0, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        
        val disconnectIntent = Intent(this, TunnelMaxVpnService::class.java).apply {
            action = ACTION_DISCONNECT
        }
        val disconnectPendingIntent = PendingIntent.getService(
            this, 0, disconnectIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        
        val builder = NotificationCompat.Builder(this, NOTIFICATION_CHANNEL_ID)
            .setContentTitle("TunnelMax VPN")
            .setContentText(text)
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
        
        if (isConnected) {
            builder.addAction(
                android.R.drawable.ic_menu_close_clear_cancel,
                "Disconnect",
                disconnectPendingIntent
            )
        }
        
        return builder.build()
    }
    
    private fun startNetworkMonitoring() {
        networkDetector?.startMonitoring { isAvailable ->
            if (isConnected.get()) {
                if (isAvailable) {
                    Log.d(TAG, "Network available - VPN should be stable")
                    reconnectAttempts = 0 // Reset reconnect attempts on stable network
                } else {
                    Log.w(TAG, "Network lost - attempting reconnection")
                    attemptReconnection()
                }
            }
        }
    }
    
    private fun stopNetworkMonitoring() {
        networkDetector?.stopMonitoring()
    }
    
    private fun attemptReconnection() {
        if (reconnectAttempts >= maxReconnectAttempts) {
            Log.e(TAG, "Max reconnection attempts reached")
            VpnChannelHandler.notifyConnectionStatus(
                VpnStatus.ERROR, 
                null, 
                "Connection lost - max reconnection attempts reached"
            )
            return
        }
        
        reconnectJob?.cancel()
        reconnectJob = serviceScope.launch {
            try {
                reconnectAttempts++
                val delayMs = (reconnectAttempts * 2000L).coerceAtMost(30000L) // Exponential backoff, max 30s
                
                Log.d(TAG, "Reconnection attempt $reconnectAttempts in ${delayMs}ms")
                VpnChannelHandler.notifyConnectionStatus(VpnStatus.CONNECTING, null)
                
                delay(delayMs)
                
                // Check if we're still supposed to be connected
                val config = currentConfig.get()
                if (config != null && isConnected.get()) {
                    // Try to restart the connection
                    singboxInstance?.stop()
                    vpnInterface?.close()
                    
                    vpnInterface = createVpnInterface(config)
                    if (vpnInterface != null) {
                        singboxInstance?.start(vpnInterface!!.fd)
                        Log.d(TAG, "Reconnection attempt $reconnectAttempts successful")
                        VpnChannelHandler.notifyConnectionStatus(VpnStatus.CONNECTED, config.name)
                        reconnectAttempts = 0
                    } else {
                        throw IOException("Failed to recreate VPN interface")
                    }
                }
            } catch (e: Exception) {
                Log.e(TAG, "Reconnection attempt $reconnectAttempts failed", e)
                if (reconnectAttempts < maxReconnectAttempts) {
                    attemptReconnection() // Try again
                } else {
                    VpnChannelHandler.notifyConnectionStatus(
                        VpnStatus.ERROR, 
                        null, 
                        "Reconnection failed: ${e.message}"
                    )
                }
            }
        }
    }
}