package com.tunnelmax.vpnclient

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
import java.io.IOException
import java.net.InetSocketAddress
import java.nio.ByteBuffer
import java.nio.channels.DatagramChannel
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicReference

class TunnelMaxVpnService : VpnService() {
    companion object {
        private const val TAG = "TunnelMaxVpnService"
        private const val NOTIFICATION_ID = 1001
        private const val CHANNEL_ID = "vpn_service_channel"
        
        const val ACTION_START = "com.tunnelmax.vpnclient.START_VPN"
        const val ACTION_STOP = "com.tunnelmax.vpnclient.STOP_VPN"
        const val EXTRA_CONFIG_PATH = "config_path"
        
        @Volatile
        var isRunning = false
            private set
    }

    private var vpnInterface: ParcelFileDescriptor? = null
    private var vpnThread: Thread? = null
    private val isConnected = AtomicBoolean(false)
    private val configPath = AtomicReference<String>()
    private var singboxManager: SingboxManager? = null

    override fun onCreate() {
        super.onCreate()
        Log.d(TAG, "VPN Service created")
        createNotificationChannel()
        
        // Initialize SingboxManager
        if (SingboxManager.isLibraryLoaded) {
            singboxManager = SingboxManager()
        } else {
            Log.e(TAG, "SingBox native libraries not loaded")
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START -> {
                val configPath = intent.getStringExtra(EXTRA_CONFIG_PATH)
                if (configPath != null) {
                    startVpn(configPath)
                } else {
                    Log.e(TAG, "No configuration path provided")
                    stopSelf()
                }
            }
            ACTION_STOP -> {
                stopVpn()
            }
            else -> {
                Log.w(TAG, "Unknown action: ${intent?.action}")
                stopSelf()
            }
        }
        
        return START_STICKY
    }

    private fun startVpn(configPath: String) {
        if (isConnected.get()) {
            Log.w(TAG, "VPN already running")
            return
        }

        Log.i(TAG, "Starting VPN with config: $configPath")
        this.configPath.set(configPath)

        try {
            // Start foreground service
            startForeground(NOTIFICATION_ID, createNotification("Connecting...", false))

            // Initialize SingBox if available
            singboxManager?.let { manager ->
                if (!manager.nativeInit()) {
                    Log.e(TAG, "Failed to initialize SingBox")
                    stopVpn()
                    return
                }
            }

            // Create VPN interface
            val builder = Builder()
                .setSession("TunnelMax VPN")
                .addAddress("10.0.0.2", 24)
                .addDnsServer("1.1.1.1")
                .addDnsServer("8.8.8.8")
                .addRoute("0.0.0.0", 0)
                .setMtu(1500)
                .setBlocking(true)

            vpnInterface = builder.establish()
            
            if (vpnInterface == null) {
                Log.e(TAG, "Failed to establish VPN interface")
                stopVpn()
                return
            }

            // Start SingBox with TUN file descriptor
            singboxManager?.let { manager ->
                val tunFd = vpnInterface!!.fd
                if (!manager.nativeStart(configPath)) {
                    Log.e(TAG, "Failed to start SingBox")
                    stopVpn()
                    return
                }
            }

            // Start VPN thread
            isConnected.set(true)
            isRunning = true
            
            vpnThread = Thread {
                runVpnLoop()
            }.apply {
                name = "VPN-Thread"
                start()
            }

            // Update notification
            updateNotification("Connected", true)
            Log.i(TAG, "VPN started successfully")

        } catch (e: Exception) {
            Log.e(TAG, "Failed to start VPN", e)
            stopVpn()
        }
    }

    private fun stopVpn() {
        Log.i(TAG, "Stopping VPN")
        
        isConnected.set(false)
        isRunning = false

        // Stop SingBox
        singboxManager?.nativeStop()

        // Close VPN interface
        try {
            vpnInterface?.close()
        } catch (e: IOException) {
            Log.w(TAG, "Error closing VPN interface", e)
        }
        vpnInterface = null

        // Wait for VPN thread to finish
        vpnThread?.let { thread ->
            try {
                thread.interrupt()
                thread.join(5000) // Wait up to 5 seconds
            } catch (e: InterruptedException) {
                Log.w(TAG, "Interrupted while waiting for VPN thread to finish")
            }
        }
        vpnThread = null

        // Stop foreground service
        stopForeground(true)
        stopSelf()
        
        Log.i(TAG, "VPN stopped")
    }

    private fun runVpnLoop() {
        Log.d(TAG, "VPN loop started")
        
        try {
            val vpnInput = vpnInterface!!.fileDescriptor
            val buffer = ByteBuffer.allocate(32767)
            
            while (isConnected.get() && !Thread.currentThread().isInterrupted) {
                // This is a simplified VPN loop
                // In a real implementation, you would:
                // 1. Read packets from the TUN interface
                // 2. Process them through SingBox
                // 3. Handle the routing and forwarding
                
                try {
                    Thread.sleep(100) // Prevent busy waiting
                } catch (e: InterruptedException) {
                    break
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error in VPN loop", e)
        } finally {
            Log.d(TAG, "VPN loop ended")
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "VPN Service",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "TunnelMax VPN Service notifications"
                setShowBadge(false)
            }
            
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.createNotificationChannel(channel)
        }
    }

    private fun createNotification(status: String, isConnected: Boolean): Notification {
        val intent = packageManager.getLaunchIntentForPackage(packageName)
        val pendingIntent = PendingIntent.getActivity(
            this, 0, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val disconnectIntent = Intent(this, TunnelMaxVpnService::class.java).apply {
            action = ACTION_STOP
        }
        val disconnectPendingIntent = PendingIntent.getService(
            this, 0, disconnectIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("TunnelMax VPN")
            .setContentText(status)
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .apply {
                if (isConnected) {
                    addAction(
                        android.R.drawable.ic_menu_close_clear_cancel,
                        "Disconnect",
                        disconnectPendingIntent
                    )
                }
            }
            .build()
    }

    private fun updateNotification(status: String, isConnected: Boolean) {
        val notification = createNotification(status, isConnected)
        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.notify(NOTIFICATION_ID, notification)
    }

    override fun onDestroy() {
        super.onDestroy()
        Log.d(TAG, "VPN Service destroyed")
        stopVpn()
    }
}