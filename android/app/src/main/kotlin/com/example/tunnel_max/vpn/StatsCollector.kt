package com.example.tunnel_max.vpn

import android.util.Log
import kotlinx.coroutines.*
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicReference

class StatsCollector(private val singboxManager: SingboxManager) {
    companion object {
        private const val TAG = "StatsCollector"
        private const val STATS_INTERVAL_MS = 1000L // 1 second
    }
    
    private val isRunning = AtomicBoolean(false)
    private val currentStats = AtomicReference<NetworkStats?>(null)
    private var collectorJob: Job? = null
    private var previousStats: NetworkStats? = null
    
    fun start() {
        if (isRunning.get()) {
            Log.w(TAG, "Stats collector already running")
            return
        }
        
        Log.d(TAG, "Starting stats collector")
        isRunning.set(true)
        
        collectorJob = CoroutineScope(Dispatchers.IO).launch {
            while (isRunning.get()) {
                try {
                    collectStats()
                    delay(STATS_INTERVAL_MS)
                } catch (e: Exception) {
                    Log.e(TAG, "Error collecting stats", e)
                    delay(STATS_INTERVAL_MS)
                }
            }
        }
    }
    
    fun stop() {
        Log.d(TAG, "Stopping stats collector")
        isRunning.set(false)
        collectorJob?.cancel()
        collectorJob = null
        currentStats.set(null)
        previousStats = null
    }
    
    fun getCurrentStats(): NetworkStats? {
        return currentStats.get()
    }
    
    private fun collectStats() {
        val rawStats = singboxManager.getStats()
        if (rawStats != null) {
            val now = System.currentTimeMillis()
            val previous = previousStats
            
            val processedStats = if (previous != null) {
                val timeDiff = (now - previous.timestamp) / 1000.0 // seconds
                val downloadSpeed = if (timeDiff > 0) {
                    (rawStats.bytesReceived - previous.bytesReceived) / timeDiff
                } else 0.0
                
                val uploadSpeed = if (timeDiff > 0) {
                    (rawStats.bytesSent - previous.bytesSent) / timeDiff
                } else 0.0
                
                rawStats.copy(
                    downloadSpeed = downloadSpeed,
                    uploadSpeed = uploadSpeed,
                    timestamp = now
                )
            } else {
                rawStats.copy(timestamp = now)
            }
            
            currentStats.set(processedStats)
            previousStats = processedStats
            
            // Notify Flutter about updated stats
            VpnChannelHandler.notifyStatsUpdate(processedStats)
        }
    }
}