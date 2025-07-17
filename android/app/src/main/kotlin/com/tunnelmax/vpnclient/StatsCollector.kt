package com.tunnelmax.vpnclient

import android.util.Log
import kotlinx.coroutines.*
import kotlinx.coroutines.flow.*
import kotlinx.coroutines.channels.BufferOverflow
import java.time.LocalDateTime
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicLong
import java.util.concurrent.TimeoutException

/**
 * Statistics collector for real-time network statistics from sing-box
 */
class StatsCollector(private val singboxManager: SingboxManager) {
    
    companion object {
        private const val TAG = "StatsCollector"
        private const val DEFAULT_COLLECTION_INTERVAL_MS = 1000L
        private const val MAX_ERROR_COUNT = 10
    }
    
    // Collection state
    private val isCollecting = AtomicBoolean(false)
    private val collectionJob = AtomicReference<Job?>(null)
    private val errorCount = AtomicLong(0)
    
    // Statistics flows
    private val _statsFlow = MutableSharedFlow<NetworkStats>(
        replay = 1,
        onBufferOverflow = BufferOverflow.DROP_OLDEST
    )
    val statsFlow: SharedFlow<NetworkStats> = _statsFlow.asSharedFlow()
    
    private val _errorFlow = MutableSharedFlow<StatsError>(
        replay = 1,
        onBufferOverflow = BufferOverflow.DROP_OLDEST
    )
    val errorFlow: SharedFlow<StatsError> = _errorFlow.asSharedFlow()
    
    // Previous statistics for speed calculation
    private var previousStats: NetworkStats? = null
    private var previousUpdateTime: Long = 0
    
    /**
     * Start collecting statistics
     * @param intervalMs Collection interval in milliseconds
     * @return Flow of network statistics
     */
    fun start(intervalMs: Long = DEFAULT_COLLECTION_INTERVAL_MS): Flow<NetworkStats> {
        if (isCollecting.get()) {
            Log.d(TAG, "Statistics collection already running")
            return statsFlow
        }
        
        Log.i(TAG, "Starting statistics collection with interval: ${intervalMs}ms")
        
        isCollecting.set(true)
        errorCount.set(0)
        
        val job = CoroutineScope(Dispatchers.IO).launch {
            try {
                while (isCollecting.get() && isActive) {
                    try {
                        collectStatistics()
                        delay(intervalMs)
                    } catch (e: CancellationException) {
                        Log.d(TAG, "Statistics collection cancelled")
                        break
                    } catch (e: Exception) {
                        handleCollectionError(e)
                        
                        // If too many errors, stop collection
                        if (errorCount.incrementAndGet() >= MAX_ERROR_COUNT) {
                            Log.e(TAG, "Too many collection errors, stopping collection")
                            break
                        }
                        
                        // Wait before retrying
                        delay(intervalMs * 2)
                    }
                }
            } finally {
                isCollecting.set(false)
                Log.i(TAG, "Statistics collection stopped")
            }
        }
        
        collectionJob.set(job)
        return statsFlow
    }
    
    /**
     * Stop collecting statistics
     */
    fun stop() {
        if (!isCollecting.get()) {
            Log.d(TAG, "Statistics collection not running")
            return
        }
        
        Log.i(TAG, "Stopping statistics collection")
        
        isCollecting.set(false)
        collectionJob.get()?.cancel()
        collectionJob.set(null)
    }
    
    /**
     * Check if currently collecting statistics
     */
    fun isCollecting(): Boolean {
        return isCollecting.get()
    }
    
    /**
     * Reset statistics counters
     */
    fun resetStatistics(): Boolean {
        Log.i(TAG, "Resetting statistics")
        
        return try {
            val result = singboxManager.resetStatistics()
            if (result) {
                previousStats = null
                previousUpdateTime = 0
                errorCount.set(0)
                Log.i(TAG, "Statistics reset successfully")
            } else {
                Log.w(TAG, "Failed to reset statistics")
            }
            result
        } catch (e: Exception) {
            Log.e(TAG, "Exception resetting statistics", e)
            false
        }
    }
    
    /**
     * Get collection health information
     */
    fun getCollectionHealth(): Map<String, Any> {
        return mapOf(
            "isCollecting" to isCollecting.get(),
            "errorCount" to errorCount.get(),
            "hasJob" to (collectionJob.get() != null),
            "jobActive" to (collectionJob.get()?.isActive ?: false),
            "lastUpdateTime" to previousUpdateTime,
            "hasPreviousStats" to (previousStats != null)
        )
    }
    
    /**
     * Cleanup resources
     */
    fun cleanup() {
        Log.i(TAG, "Cleaning up StatsCollector")
        
        stop()
        previousStats = null
        previousUpdateTime = 0
        errorCount.set(0)
    }
    
    /**
     * Collect statistics from sing-box manager
     */
    private suspend fun collectStatistics() {
        if (!singboxManager.isRunning()) {
            // Don't collect if sing-box is not running
            return
        }
        
        val currentTime = System.currentTimeMillis()
        val stats = singboxManager.getStatistics()
        
        if (stats != null) {
            // Calculate speeds if we have previous data
            val enhancedStats = if (previousStats != null && previousUpdateTime > 0) {
                val timeDiff = (currentTime - previousUpdateTime) / 1000.0 // Convert to seconds
                if (timeDiff > 0) {
                    val downloadSpeedCalculated = (stats.bytesReceived - previousStats!!.bytesReceived) / timeDiff
                    val uploadSpeedCalculated = (stats.bytesSent - previousStats!!.bytesSent) / timeDiff
                    
                    stats.copy(
                        downloadSpeed = downloadSpeedCalculated,
                        uploadSpeed = uploadSpeedCalculated,
                        formattedDownloadSpeed = formatSpeed(downloadSpeedCalculated),
                        formattedUploadSpeed = formatSpeed(uploadSpeedCalculated)
                    )
                } else {
                    stats
                }
            } else {
                stats
            }
            
            // Emit the statistics
            _statsFlow.tryEmit(enhancedStats)
            
            // Store for next calculation
            previousStats = enhancedStats
            previousUpdateTime = currentTime
            
            // Reset error count on successful collection
            errorCount.set(0)
            
            Log.v(TAG, "Collected stats: ${enhancedStats.formattedDownloadSpeed} ↓ ${enhancedStats.formattedUploadSpeed} ↑")
        } else {
            Log.w(TAG, "Failed to get statistics from SingboxManager")
        }
    }
    
    /**
     * Handle collection errors
     */
    private fun handleCollectionError(error: Exception) {
        Log.w(TAG, "Error collecting statistics", error)
        
        val statsError = StatsError(
            message = error.message ?: "Unknown error",
            timestamp = LocalDateTime.now(),
            errorType = when (error) {
                is SecurityException -> StatsErrorType.PERMISSION_DENIED
                is IllegalStateException -> StatsErrorType.INVALID_STATE
                is TimeoutException -> StatsErrorType.TIMEOUT
                else -> StatsErrorType.UNKNOWN
            }
        )
        
        _errorFlow.tryEmit(statsError)
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
 * Statistics error data class
 */
data class StatsError(
    val message: String,
    val timestamp: LocalDateTime,
    val errorType: StatsErrorType
)

/**
 * Statistics error types
 */
enum class StatsErrorType {
    PERMISSION_DENIED,
    INVALID_STATE,
    TIMEOUT,
    NETWORK_ERROR,
    UNKNOWN
}

/**
 * Atomic reference helper for Job
 */
private class AtomicReference<T>(initialValue: T) {
    @Volatile
    private var value: T = initialValue
    
    fun get(): T = value
    
    fun set(newValue: T) {
        value = newValue
    }
    
    fun compareAndSet(expect: T, update: T): Boolean {
        return if (value == expect) {
            value = update
            true
        } else {
            false
        }
    }
}