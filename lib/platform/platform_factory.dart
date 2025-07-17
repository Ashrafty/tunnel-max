import 'dart:io';
import '../interfaces/vpn_control_interface.dart';
import '../interfaces/configuration_interface.dart';
import 'windows_vpn_control.dart';
import 'android_vpn_control.dart';
import 'windows_configuration.dart';
import 'android_configuration.dart';

/// Factory class for creating platform-specific implementations
/// 
/// This factory provides the appropriate VPN control and configuration
/// implementations based on the current platform.
class PlatformFactory {
  static VpnControlInterface? _vpnControlInstance;
  static ConfigurationInterface? _configurationInstance;

  /// Gets the platform-specific VPN control implementation
  static VpnControlInterface getVpnControl() {
    _vpnControlInstance ??= _createVpnControl();
    return _vpnControlInstance!;
  }

  /// Gets the platform-specific configuration implementation
  static ConfigurationInterface getConfiguration() {
    _configurationInstance ??= _createConfiguration();
    return _configurationInstance!;
  }

  /// Creates the appropriate VPN control implementation for the current platform
  static VpnControlInterface _createVpnControl() {
    if (Platform.isWindows) {
      return WindowsVpnControl();
    } else if (Platform.isAndroid) {
      return AndroidVpnControl();
    } else {
      throw UnsupportedError('Platform ${Platform.operatingSystem} is not supported');
    }
  }

  /// Creates the appropriate configuration implementation for the current platform
  static ConfigurationInterface _createConfiguration() {
    if (Platform.isWindows) {
      return WindowsConfiguration();
    } else if (Platform.isAndroid) {
      return AndroidConfiguration();
    } else {
      throw UnsupportedError('Platform ${Platform.operatingSystem} is not supported');
    }
  }

  /// Disposes platform-specific resources
  static void dispose() {
    if (_vpnControlInstance is WindowsVpnControl) {
      (_vpnControlInstance as WindowsVpnControl).dispose();
    } else if (_vpnControlInstance is AndroidVpnControl) {
      (_vpnControlInstance as AndroidVpnControl).dispose();
    }
    _vpnControlInstance = null;
    _configurationInstance = null;
  }

  /// Checks if the current platform is supported
  static bool get isSupported {
    return Platform.isWindows || Platform.isAndroid;
  }

  /// Gets the current platform name
  static String get platformName {
    if (Platform.isWindows) return 'Windows';
    if (Platform.isAndroid) return 'Android';
    return 'Unsupported';
  }
}