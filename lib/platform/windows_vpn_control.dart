import 'dart:async';
import 'package:flutter/services.dart';
import '../interfaces/vpn_control_interface.dart';
import '../models/vpn_configuration.dart';
import '../models/vpn_status.dart';
import '../models/network_stats.dart';

/// Windows-specific implementation of VPN control interface
/// 
/// This class communicates with the native Windows VPN plugin through
/// platform channels to provide VPN functionality on Windows.
class WindowsVpnControl implements VpnControlInterface {
  static const MethodChannel _channel = MethodChannel('vpn_control');
  static const EventChannel _statusChannel = EventChannel('vpn_status');
  
  StreamController<VpnStatus>? _statusController;
  StreamSubscription? _statusSubscription;

  WindowsVpnControl() {
    _initializeStatusStream();
  }

  void _initializeStatusStream() {
    _statusController = StreamController<VpnStatus>.broadcast();
    
    // Listen to native status updates
    _statusSubscription = _statusChannel.receiveBroadcastStream().listen(
      (dynamic event) {
        if (event is Map<String, dynamic>) {
          try {
            final status = VpnStatus.fromJson(Map<String, dynamic>.from(event));
            _statusController?.add(status);
          } catch (e) {
            // Handle parsing errors gracefully
            _statusController?.add(VpnStatus.error(error: 'Status parsing error: $e'));
          }
        }
      },
      onError: (error) {
        _statusController?.add(VpnStatus.error(error: 'Status stream error: $error'));
      },
    );
  }

  @override
  Future<bool> connect(VpnConfiguration config) async {
    try {
      final configMap = config.toJson();
      final result = await _channel.invokeMethod('connect', configMap);
      return result == true;
    } on PlatformException catch (e) {
      throw VpnException(
        e.message ?? 'Connection failed',
        code: e.code,
        details: e.details,
      );
    } catch (e) {
      throw VpnException('Unexpected error during connection: $e');
    }
  }

  @override
  Future<bool> disconnect() async {
    try {
      final result = await _channel.invokeMethod('disconnect');
      return result == true;
    } on PlatformException catch (e) {
      throw VpnException(
        e.message ?? 'Disconnection failed',
        code: e.code,
        details: e.details,
      );
    } catch (e) {
      throw VpnException('Unexpected error during disconnection: $e');
    }
  }

  @override
  Future<VpnStatus> getStatus() async {
    try {
      final result = await _channel.invokeMethod('getStatus');
      if (result is Map<String, dynamic>) {
        return VpnStatus.fromJson(result);
      }
      return VpnStatus.disconnected();
    } on PlatformException catch (e) {
      throw VpnException(
        e.message ?? 'Failed to get status',
        code: e.code,
        details: e.details,
      );
    } catch (e) {
      throw VpnException('Unexpected error getting status: $e');
    }
  }

  @override
  Stream<VpnStatus> statusStream() {
    return _statusController?.stream ?? Stream.empty();
  }

  @override
  Future<NetworkStats?> getNetworkStats() async {
    try {
      final result = await _channel.invokeMethod('getNetworkStats');
      if (result is Map<String, dynamic>) {
        return NetworkStats.fromJson(result);
      }
      return null;
    } on PlatformException catch (e) {
      throw VpnException(
        e.message ?? 'Failed to get network stats',
        code: e.code,
        details: e.details,
      );
    } catch (e) {
      throw VpnException('Unexpected error getting network stats: $e');
    }
  }

  @override
  Future<bool> hasVpnPermission() async {
    try {
      final result = await _channel.invokeMethod('hasVpnPermission');
      return result == true;
    } on PlatformException catch (e) {
      throw VpnException(
        e.message ?? 'Failed to check VPN permission',
        code: e.code,
        details: e.details,
      );
    } catch (e) {
      throw VpnException('Unexpected error checking VPN permission: $e');
    }
  }

  @override
  Future<bool> requestVpnPermission() async {
    try {
      final result = await _channel.invokeMethod('requestVpnPermission');
      return result == true;
    } on PlatformException catch (e) {
      throw VpnException(
        e.message ?? 'Failed to request VPN permission',
        code: e.code,
        details: e.details,
      );
    } catch (e) {
      throw VpnException('Unexpected error requesting VPN permission: $e');
    }
  }

  /// Dispose resources when no longer needed
  void dispose() {
    _statusSubscription?.cancel();
    _statusController?.close();
  }
}