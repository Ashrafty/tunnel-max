package com.tunnelmax.vpnclient

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Register VPN plugin
        flutterEngine.plugins.add(VpnPlugin())
        
        // Register Configuration plugin
        flutterEngine.plugins.add(ConfigurationPlugin())
    }
}
