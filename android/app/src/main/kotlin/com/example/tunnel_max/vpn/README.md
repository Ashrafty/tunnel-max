# Android VPN Integration

This directory contains the Android native VPN integration for TunnelMax VPN client.

## Architecture

The Android VPN implementation consists of several key components:

### Core Components

1. **TunnelMaxVpnService** - Main VPN service that extends Android's VpnService
   - Manages VPN connection lifecycle
   - Handles foreground service notifications
   - Integrates with singbox core library
   - Provides automatic reconnection on network changes

2. **VpnChannelHandler** - Platform channel handler for Flutter communication
   - Handles method calls from Flutter
   - Provides callbacks for connection status updates
   - Manages VPN permission requests

3. **SingboxManager** - Wrapper for singbox library integration
   - Generates singbox configuration from VPN settings
   - Manages singbox service lifecycle
   - Provides network statistics

4. **NetworkChangeDetector** - Monitors network connectivity changes
   - Detects network transitions (WiFi to cellular, etc.)
   - Triggers automatic reconnection when needed
   - Provides network type information

5. **StatsCollector** - Collects and processes network statistics
   - Real-time traffic monitoring
   - Speed calculations
   - Statistics reporting to Flutter

### Data Models

- **VpnConfiguration** - Configuration data for VPN connections
- **VpnStatus** - Connection status information
- **NetworkStats** - Network traffic statistics
- **VpnStatusInfo** - Complete status information for Flutter

### Utilities

- **VpnUtils** - Utility functions for validation and formatting
- **ValidationResult** - Configuration validation results

## Features

### VPN Protocols Supported
- Shadowsocks
- VMess
- VLESS
- Trojan
- Hysteria/Hysteria2
- TUIC
- SSH
- WireGuard

### Key Features
- ✅ VPN Service implementation with proper Android lifecycle
- ✅ Foreground service with persistent notification
- ✅ Platform channel communication with Flutter
- ✅ Configuration validation and error handling
- ✅ Network change detection and automatic reconnection
- ✅ Real-time statistics collection
- ✅ VPN permission management
- ✅ Multiple VPN protocol support
- ✅ Secure configuration storage integration

### Network Resilience
- Automatic reconnection on network changes
- Exponential backoff retry strategy
- Network type detection (WiFi, Cellular, Ethernet)
- Connection stability monitoring

## Usage

### From Flutter

```dart
// Connect to VPN
await vpnChannel.invokeMethod('connect', {
  'config': jsonEncode(vpnConfiguration)
});

// Disconnect VPN
await vpnChannel.invokeMethod('disconnect');

// Get connection status
String statusJson = await vpnChannel.invokeMethod('getStatus');
VpnStatusInfo status = VpnStatusInfo.fromJson(jsonDecode(statusJson));

// Get network statistics
String statsJson = await vpnChannel.invokeMethod('getStats');
NetworkStats stats = NetworkStats.fromJson(jsonDecode(statsJson));

// Request VPN permission
bool hasPermission = await vpnChannel.invokeMethod('requestVpnPermission');
```

### Configuration Example

```json
{
  "id": "server-1",
  "name": "My VPN Server",
  "serverAddress": "vpn.example.com",
  "serverPort": 443,
  "protocol": "SHADOWSOCKS",
  "authMethod": "PASSWORD",
  "protocolSpecificConfig": {
    "method": "aes-256-gcm",
    "password": "your-password"
  },
  "autoConnect": false
}
```

## Permissions Required

The following permissions are declared in AndroidManifest.xml:

```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_SPECIAL_USE" />
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
<uses-permission android:name="android.permission.WAKE_LOCK" />
```

## Singbox Integration

Currently using mock implementation for development. To integrate with actual singbox library:

1. Add the singbox Android library dependency
2. Replace mock classes in `mock/MockSingboxLibrary.kt` with actual imports
3. Update `SingboxManager.kt` to use real singbox classes

```kotlin
// Replace these imports:
import com.example.tunnel_max.vpn.mock.Libcore
import com.example.tunnel_max.vpn.mock.BoxService

// With actual singbox imports:
import io.github.sagernet.libcore.Libcore
import io.github.sagernet.libcore.BoxService
```

## Testing

The implementation includes comprehensive error handling and logging for debugging:

- All major operations are logged with appropriate log levels
- Network errors are handled gracefully with user-friendly messages
- Configuration validation prevents invalid connections
- Mock implementation allows testing without actual singbox library

## Security Considerations

- VPN configurations are validated before use
- Sensitive data should be encrypted when stored
- VPN traffic is properly isolated through Android VPN APIs
- Kill switch functionality prevents traffic leaks
- Proper permission handling for VPN access

## Future Enhancements

- Integration with actual singbox library
- Enhanced kill switch implementation
- Custom DNS configuration
- Split tunneling support
- Advanced routing rules
- Performance optimizations