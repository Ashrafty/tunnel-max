package com.example.tunnel_max.vpn

import android.content.Context
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.os.Build
import android.util.Log
import java.util.concurrent.atomic.AtomicBoolean

class NetworkChangeDetector(private val context: Context) {
    companion object {
        private const val TAG = "NetworkChangeDetector"
    }
    
    private val connectivityManager = context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
    private val isMonitoring = AtomicBoolean(false)
    private var networkCallback: ConnectivityManager.NetworkCallback? = null
    private var onNetworkChanged: ((Boolean) -> Unit)? = null
    
    fun startMonitoring(onNetworkChanged: (Boolean) -> Unit) {
        if (isMonitoring.get()) {
            Log.w(TAG, "Network monitoring already started")
            return
        }
        
        this.onNetworkChanged = onNetworkChanged
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            networkCallback = object : ConnectivityManager.NetworkCallback() {
                override fun onAvailable(network: Network) {
                    super.onAvailable(network)
                    Log.d(TAG, "Network available: $network")
                    onNetworkChanged(true)
                }
                
                override fun onLost(network: Network) {
                    super.onLost(network)
                    Log.d(TAG, "Network lost: $network")
                    onNetworkChanged(false)
                }
                
                override fun onCapabilitiesChanged(network: Network, networkCapabilities: NetworkCapabilities) {
                    super.onCapabilitiesChanged(network, networkCapabilities)
                    Log.d(TAG, "Network capabilities changed: $network")
                    
                    val hasInternet = networkCapabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
                    val isValidated = networkCapabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_VALIDATED)
                    
                    onNetworkChanged(hasInternet && isValidated)
                }
            }
            
            val networkRequest = NetworkRequest.Builder()
                .addCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
                .build()
            
            connectivityManager.registerNetworkCallback(networkRequest, networkCallback!!)
            isMonitoring.set(true)
            
            Log.d(TAG, "Network monitoring started")
        } else {
            Log.w(TAG, "Network monitoring not supported on this Android version")
        }
    }
    
    fun stopMonitoring() {
        if (!isMonitoring.get()) {
            return
        }
        
        networkCallback?.let { callback ->
            try {
                connectivityManager.unregisterNetworkCallback(callback)
            } catch (e: Exception) {
                Log.e(TAG, "Error unregistering network callback", e)
            }
        }
        
        networkCallback = null
        onNetworkChanged = null
        isMonitoring.set(false)
        
        Log.d(TAG, "Network monitoring stopped")
    }
    
    fun isNetworkAvailable(): Boolean {
        return try {
            val activeNetwork = connectivityManager.activeNetwork
            val networkCapabilities = connectivityManager.getNetworkCapabilities(activeNetwork)
            
            networkCapabilities?.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET) == true &&
            networkCapabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_VALIDATED)
        } catch (e: Exception) {
            Log.e(TAG, "Error checking network availability", e)
            false
        }
    }
    
    fun getNetworkType(): String {
        return try {
            val activeNetwork = connectivityManager.activeNetwork
            val networkCapabilities = connectivityManager.getNetworkCapabilities(activeNetwork)
            
            when {
                networkCapabilities?.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) == true -> "WiFi"
                networkCapabilities?.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR) == true -> "Cellular"
                networkCapabilities?.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET) == true -> "Ethernet"
                else -> "Unknown"
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error getting network type", e)
            "Unknown"
        }
    }
}