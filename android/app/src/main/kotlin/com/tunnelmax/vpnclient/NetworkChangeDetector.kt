package com.tunnelmax.vpnclient

import android.content.Context
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.os.Build
import android.util.Log
import kotlinx.coroutines.*
import kotlinx.coroutines.flow.*
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicInteger
import kotlin.math.min
import kotlin.math.pow

/**
 * NetworkChangeDetector monitors network connectivity changes and handles
 * automatic VPN reconnection with exponential backoff strategy.
 * 
 * Features:
 * - Network availability detection
 * - Connection quality monitoring
 * - Automatic reconnection with exponential backoff
 * - Network interface change handling
 * - Connection health monitoring
 */
class NetworkChangeDetector(
    private val context: Context,
    private val singboxManager: SingboxManager
) {
    
    companion object {
        private const val TAG = "NetworkChangeDetector"
        
        // Reconnection parameters
        private const val INITIAL_RETRY_DELAY_MS = 1000L // 1 second
        private const val MAX_RETRY_DELAY_MS = 60000L // 1 minute
        private const val MAX_RETRY_ATTEMPTS = 10
        private const val BACKOFF_MULTIPLIER = 2.0
        
        // Health check parameters
        private const val HEALTH_CHECK_INTERVAL_MS = 30000L // 30 seconds
        private const val CONNECTION_TIMEOUT_MS = 10000L // 10 seconds
    }
    
    private val connectivityManager = context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
    
    // State management
    private val isMonitoring = AtomicBoolean(false)
    private val isReconnecting = AtomicBoolean(false)
    private val retryAttempts = AtomicInteger(0)
    private var currentVpnConfig: VpnConfiguration? = null
    private var tunFileDescriptor: Int = -1
    
    // Coroutine scope for async operations
    private val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())
    
    // Network state flows
    private val _networkState = MutableStateFlow(NetworkState.UNKNOWN)
    val networkState: StateFlow<NetworkState> = _networkState.asStateFlow()
    
    private val _connectionHealth = MutableStateFlow(ConnectionHealth.UNKNOWN)
    val connectionHealth: StateFlow<ConnectionHealth> = _connectionHealth.asStateFlow()
    
    private val _reconnectionStatus = MutableStateFlow(ReconnectionStatus.IDLE)
    val reconnectionStatus: StateFlow<ReconnectionStatus> = _reconnectionStatus.asStateFlow()
    
    // Network callback for monitoring connectivity changes
    private val networkCallback = object : ConnectivityManager.NetworkCallback() {
        override fun onAvailable(network: Network) {
            Log.d(TAG, "Network available: $network")
            handleNetworkAvailable(network)
        }
        
        override fun onLost(network: Network) {
            Log.d(TAG, "Network lost: $network")
            handleNetworkLost(network)
        }
        
        override fun onCapabilitiesChanged(network: Network, networkCapabilities: NetworkCapabilities) {
            Log.d(TAG, "Network capabilities changed: $network")
            handleNetworkCapabilitiesChanged(network, networkCapabilities)
        }
        
        override fun onLinkPropertiesChanged(network: Network, linkProperties: android.net.LinkProperties) {
            Log.d(TAG, "Network link properties changed: $network")
            handleNetworkPropertiesChanged(network, linkProperties)
        }
    }
    
    /**
     * Start monitoring network changes and connection health
     * 
     * @param vpnConfig Current VPN configuration for reconnection
     * @param tunFd TUN file descriptor for VPN connection
     */
    fun startMonitoring(vpnConfig: VpnConfiguration, tunFd: Int) {
        if (isMonitoring.get()) {
            Log.d(TAG, "Network monitoring already started")
            return
        }
        
        currentVpnConfig = vpnConfig
        tunFileDescriptor = tunFd
        
        try {
            // Register network callback
            val networkRequest = NetworkRequest.Builder()
                .addCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
                .addCapability(NetworkCapabilities.NET_CAPABILITY_VALIDATED)
                .build()
            
            connectivityManager.registerNetworkCallback(networkRequest, networkCallback)
            
            // Start health monitoring
            startHealthMonitoring()
            
            // Update initial network state
            updateNetworkState()
            
            isMonitoring.set(true)
            Log.i(TAG, "Network monitoring started")
            
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start network monitoring", e)
        }
    }
    
    /**
     * Stop monitoring network changes
     */
    fun stopMonitoring() {
        if (!isMonitoring.get()) {
            Log.d(TAG, "Network monitoring not started")
            return
        }
        
        try {
            // Unregister network callback
            connectivityManager.unregisterNetworkCallback(networkCallback)
            
            // Cancel all coroutines
            scope.coroutineContext.cancelChildren()
            
            // Reset state
            isMonitoring.set(false)
            isReconnecting.set(false)
            retryAttempts.set(0)
            currentVpnConfig = null
            tunFileDescriptor = -1
            
            _networkState.value = NetworkState.UNKNOWN
            _connectionHealth.value = ConnectionHealth.UNKNOWN
            _reconnectionStatus.value = ReconnectionStatus.IDLE
            
            Log.i(TAG, "Network monitoring stopped")
            
        } catch (e: Exception) {
            Log.e(TAG, "Failed to stop network monitoring", e)
        }
    }
    
    /**
     * Manually trigger reconnection attempt
     */
    fun triggerReconnection() {
        if (!isMonitoring.get()) {
            Log.w(TAG, "Cannot trigger reconnection - monitoring not started")
            return
        }
        
        val config = currentVpnConfig
        if (config == null) {
            Log.w(TAG, "Cannot trigger reconnection - no VPN configuration")
            return
        }
        
        Log.i(TAG, "Manual reconnection triggered")
        scope.launch {
            attemptReconnection(config, "Manual trigger")
        }
    }
    
    /**
     * Get current network information
     */
    fun getCurrentNetworkInfo(): NetworkInfo? {
        return try {
            val activeNetwork = connectivityManager.activeNetwork
            val networkCapabilities = connectivityManager.getNetworkCapabilities(activeNetwork)
            
            if (activeNetwork != null && networkCapabilities != null) {
                NetworkInfo(
                    networkId = activeNetwork.toString(),
                    isConnected = networkCapabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_VALIDATED),
                    isWifi = networkCapabilities.hasTransport(NetworkCapabilities.TRANSPORT_WIFI),
                    isCellular = networkCapabilities.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR),
                    isVpn = networkCapabilities.hasTransport(NetworkCapabilities.TRANSPORT_VPN),
                    hasInternet = networkCapabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET),
                    linkDownstreamBandwidthKbps = networkCapabilities.linkDownstreamBandwidthKbps,
                    linkUpstreamBandwidthKbps = networkCapabilities.linkUpstreamBandwidthKbps
                )
            } else {
                null
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to get network info", e)
            null
        }
    }
    
    /**
     * Handle network becoming available
     */
    private fun handleNetworkAvailable(network: Network) {
        scope.launch {
            updateNetworkState()
            
            // If VPN was disconnected due to network issues, attempt reconnection
            val config = currentVpnConfig
            if (config != null && !singboxManager.isRunning()) {
                Log.i(TAG, "Network available - attempting VPN reconnection")
                attemptReconnection(config, "Network available")
            }
        }
    }
    
    /**
     * Handle network being lost
     */
    private fun handleNetworkLost(network: Network) {
        scope.launch {
            updateNetworkState()
            _connectionHealth.value = ConnectionHealth.DISCONNECTED
            
            Log.w(TAG, "Network lost - VPN connection may be affected")
        }
    }
    
    /**
     * Handle network capabilities changes
     */
    private fun handleNetworkCapabilitiesChanged(network: Network, capabilities: NetworkCapabilities) {
        scope.launch {
            updateNetworkState()
            
            // Check if network quality changed significantly
            val hasInternet = capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_VALIDATED)
            if (!hasInternet && singboxManager.isRunning()) {
                Log.w(TAG, "Network lost internet capability - monitoring for reconnection")
                _connectionHealth.value = ConnectionHealth.POOR
            }
        }
    }
    
    /**
     * Handle network properties changes
     */
    private fun handleNetworkPropertiesChanged(network: Network, linkProperties: android.net.LinkProperties) {
        scope.launch {
            Log.d(TAG, "Network properties changed - checking connection health")
            checkConnectionHealth()
        }
    }
    
    /**
     * Start health monitoring coroutine
     */
    private fun startHealthMonitoring() {
        scope.launch {
            while (isMonitoring.get()) {
                try {
                    checkConnectionHealth()
                    delay(HEALTH_CHECK_INTERVAL_MS)
                } catch (e: CancellationException) {
                    break
                } catch (e: Exception) {
                    Log.e(TAG, "Error in health monitoring", e)
                    delay(HEALTH_CHECK_INTERVAL_MS)
                }
            }
        }
    }
    
    /**
     * Check VPN connection health
     */
    private suspend fun checkConnectionHealth() {
        if (!singboxManager.isRunning()) {
            _connectionHealth.value = ConnectionHealth.DISCONNECTED
            return
        }
        
        try {
            // Get statistics to check if connection is active
            val stats = singboxManager.getStatistics()
            val networkInfo = getCurrentNetworkInfo()
            
            when {
                networkInfo == null || !networkInfo.isConnected -> {
                    _connectionHealth.value = ConnectionHealth.DISCONNECTED
                    Log.w(TAG, "No network connectivity detected")
                    
                    // Attempt reconnection if we have a config
                    currentVpnConfig?.let { config ->
                        attemptReconnection(config, "Network disconnected")
                    }
                }
                
                stats == null -> {
                    _connectionHealth.value = ConnectionHealth.POOR
                    Log.w(TAG, "Unable to get VPN statistics - connection may be poor")
                }
                
                else -> {
                    // Connection appears healthy
                    _connectionHealth.value = ConnectionHealth.GOOD
                    retryAttempts.set(0) // Reset retry counter on successful health check
                }
            }
            
        } catch (e: Exception) {
            Log.e(TAG, "Error checking connection health", e)
            _connectionHealth.value = ConnectionHealth.POOR
        }
    }
    
    /**
     * Update network state based on current connectivity
     */
    private fun updateNetworkState() {
        try {
            val networkInfo = getCurrentNetworkInfo()
            
            _networkState.value = when {
                networkInfo == null -> NetworkState.DISCONNECTED
                !networkInfo.isConnected -> NetworkState.DISCONNECTED
                !networkInfo.hasInternet -> NetworkState.CONNECTED_NO_INTERNET
                networkInfo.isWifi -> NetworkState.CONNECTED_WIFI
                networkInfo.isCellular -> NetworkState.CONNECTED_CELLULAR
                else -> NetworkState.CONNECTED_OTHER
            }
            
        } catch (e: Exception) {
            Log.e(TAG, "Error updating network state", e)
            _networkState.value = NetworkState.UNKNOWN
        }
    }
    
    /**
     * Attempt VPN reconnection with exponential backoff
     */
    private suspend fun attemptReconnection(config: VpnConfiguration, reason: String) {
        if (isReconnecting.get()) {
            Log.d(TAG, "Reconnection already in progress")
            return
        }
        
        if (retryAttempts.get() >= MAX_RETRY_ATTEMPTS) {
            Log.w(TAG, "Maximum retry attempts reached - stopping reconnection")
            _reconnectionStatus.value = ReconnectionStatus.FAILED
            return
        }
        
        isReconnecting.set(true)
        _reconnectionStatus.value = ReconnectionStatus.ATTEMPTING
        
        try {
            val currentAttempt = retryAttempts.incrementAndGet()
            Log.i(TAG, "Attempting reconnection #$currentAttempt (reason: $reason)")
            
            // Calculate delay with exponential backoff
            val delay = min(
                INITIAL_RETRY_DELAY_MS * BACKOFF_MULTIPLIER.pow(currentAttempt - 1).toLong(),
                MAX_RETRY_DELAY_MS
            )
            
            Log.d(TAG, "Waiting ${delay}ms before reconnection attempt")
            delay(delay)
            
            // Check if we still need to reconnect
            if (!isMonitoring.get() || singboxManager.isRunning()) {
                Log.d(TAG, "Reconnection no longer needed")
                _reconnectionStatus.value = ReconnectionStatus.IDLE
                return
            }
            
            // Attempt to restart VPN
            val success = singboxManager.start(config, tunFileDescriptor)
            
            if (success) {
                Log.i(TAG, "Reconnection successful after $currentAttempt attempts")
                retryAttempts.set(0)
                _reconnectionStatus.value = ReconnectionStatus.SUCCESS
                _connectionHealth.value = ConnectionHealth.GOOD
                
                // Reset to idle after a short delay
                delay(2000)
                _reconnectionStatus.value = ReconnectionStatus.IDLE
            } else {
                Log.w(TAG, "Reconnection attempt #$currentAttempt failed")
                
                if (currentAttempt >= MAX_RETRY_ATTEMPTS) {
                    Log.e(TAG, "All reconnection attempts failed")
                    _reconnectionStatus.value = ReconnectionStatus.FAILED
                } else {
                    // Schedule next attempt
                    scope.launch {
                        attemptReconnection(config, "Retry after failure")
                    }
                }
            }
            
        } catch (e: CancellationException) {
            Log.d(TAG, "Reconnection cancelled")
            _reconnectionStatus.value = ReconnectionStatus.IDLE
        } catch (e: Exception) {
            Log.e(TAG, "Error during reconnection attempt", e)
            _reconnectionStatus.value = ReconnectionStatus.FAILED
        } finally {
            isReconnecting.set(false)
        }
    }
    
    /**
     * Cleanup resources
     */
    fun cleanup() {
        try {
            stopMonitoring()
            scope.cancel()
            Log.i(TAG, "NetworkChangeDetector cleanup completed")
        } catch (e: Exception) {
            Log.e(TAG, "Error during cleanup", e)
        }
    }
}

/**
 * Network state enumeration
 */
enum class NetworkState {
    UNKNOWN,
    DISCONNECTED,
    CONNECTED_NO_INTERNET,
    CONNECTED_WIFI,
    CONNECTED_CELLULAR,
    CONNECTED_OTHER
}

/**
 * Connection health enumeration
 */
enum class ConnectionHealth {
    UNKNOWN,
    GOOD,
    POOR,
    DISCONNECTED
}

/**
 * Reconnection status enumeration
 */
enum class ReconnectionStatus {
    IDLE,
    ATTEMPTING,
    SUCCESS,
    FAILED
}

/**
 * Network information data class
 */
data class NetworkInfo(
    val networkId: String,
    val isConnected: Boolean,
    val isWifi: Boolean,
    val isCellular: Boolean,
    val isVpn: Boolean,
    val hasInternet: Boolean,
    val linkDownstreamBandwidthKbps: Int,
    val linkUpstreamBandwidthKbps: Int
)