package com.example.tunnel_max

import android.content.Intent
import android.os.Bundle
import com.example.tunnel_max.vpn.VpnChannelHandler
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private lateinit var vpnChannelHandler: VpnChannelHandler
    
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Set up VPN channel
        vpnChannelHandler = VpnChannelHandler(this, this)
        val vpnChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.example.tunnel_max/vpn")
        vpnChannel.setMethodCallHandler(vpnChannelHandler)
        
        // Set the static reference for callbacks
        VpnChannelHandler.setMethodChannel(vpnChannel)
    }
    
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        vpnChannelHandler.handleActivityResult(requestCode, resultCode)
    }
}
