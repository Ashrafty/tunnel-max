package com.example.tunnel_max.vpn.mock

import android.util.Log

/**
 * Mock implementation of Singbox library classes
 * This should be replaced with actual singbox library integration
 */

object Libcore {
    private const val TAG = "MockLibcore"
    
    fun setup(filesDir: String, cacheDir: String, debug: Boolean) {
        Log.d(TAG, "Mock Libcore setup - filesDir: $filesDir, cacheDir: $cacheDir, debug: $debug")
        // Mock implementation - replace with actual libcore setup
    }
}

class BoxService(
    private val configPath: String,
    private val vpnFd: Int,
    private val isTest: Boolean
) {
    private val TAG = "MockBoxService"
    private var isRunning = false
    private var mockUplink = 0L
    private var mockDownlink = 0L
    
    fun start() {
        Log.d(TAG, "Mock BoxService start - config: $configPath, fd: $vpnFd")
        isRunning = true
        // Mock implementation - replace with actual singbox service start
        
        // Simulate some traffic for testing
        Thread {
            while (isRunning) {
                mockUplink += (Math.random() * 1000).toLong()
                mockDownlink += (Math.random() * 5000).toLong()
                Thread.sleep(1000)
            }
        }.start()
    }
    
    fun stop() {
        Log.d(TAG, "Mock BoxService stop")
        isRunning = false
        // Mock implementation - replace with actual singbox service stop
    }
    
    val uplinkTotal: Long
        get() = mockUplink
    
    val downlinkTotal: Long
        get() = mockDownlink
}

class Box {
    private val TAG = "MockBox"
    
    fun start() {
        Log.d(TAG, "Mock Box start")
        // Mock implementation
    }
    
    fun stop() {
        Log.d(TAG, "Mock Box stop")
        // Mock implementation
    }
}