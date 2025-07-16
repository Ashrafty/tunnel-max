import 'dart:async';
import 'dart:math';

import '../interfaces/vpn_control_interface.dart';
import '../models/vpn_configuration.dart';
import '../models/vpn_status.dart';
import '../models/network_stats.dart';

/// Mock implementation of VPN control interface for development and testing
/// 
/// This implementation simulates VPN operations without actual platform integration.
/// It will be replaced with real platform implementations in later tasks.
class VpnControlPlatform implements VpnControlInterface {
  VpnStatus _currentStatus = VpnStatus.disconnected();
  StreamController<VpnStatus>? _statusController;
  Timer? _connectionTimer;
  Timer? _statsTimer;
  NetworkStats? _currentStats;
  final Random _random = Random();

  VpnControlPlatform() {
    _statusController = StreamController<VpnStatus>.broadcast();
  }

  @override
  Future<bool> connect(VpnConfiguration config) async {
    if (_currentStatus.isConnected) {
      return false;
    }

    _currentStatus = VpnStatus.connecting(server: config.name);
    _statusController?.add(_currentStatus);

    // Simulate connection process
    _connectionTimer = Timer(const Duration(seconds: 2), () {
      _currentStatus = VpnStatus.connected(
        server: config.name,
        connectionStartTime: DateTime.now(),
        localIpAddress: '10.0.0.${_random.nextInt(255)}',
        publicIpAddress: '${_random.nextInt(255)}.${_random.nextInt(255)}.${_random.nextInt(255)}.${_random.nextInt(255)}',
        stats: NetworkStats.zero(),
      );
      _statusController?.add(_currentStatus);
      _startStatsSimulation();
    });

    return true;
  }

  @override
  Future<bool> disconnect() async {
    if (!_currentStatus.hasActiveConnection) {
      return false;
    }

    _currentStatus = _currentStatus.copyWith(state: VpnConnectionState.disconnecting);
    _statusController?.add(_currentStatus);

    _connectionTimer?.cancel();
    _statsTimer?.cancel();

    // Simulate disconnection process
    Timer(const Duration(seconds: 1), () {
      _currentStatus = VpnStatus.disconnected();
      _currentStats = null;
      _statusController?.add(_currentStatus);
    });

    return true;
  }

  @override
  Future<VpnStatus> getStatus() async {
    return _currentStatus;
  }

  @override
  Stream<VpnStatus> statusStream() {
    return _statusController!.stream;
  }

  @override
  Future<NetworkStats?> getNetworkStats() async {
    return _currentStats;
  }

  @override
  Future<bool> hasVpnPermission() async {
    return true; // Mock always has permission
  }

  @override
  Future<bool> requestVpnPermission() async {
    return true; // Mock always grants permission
  }

  void _startStatsSimulation() {
    _currentStats = NetworkStats.zero();
    
    _statsTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (!_currentStatus.isConnected) {
        timer.cancel();
        return;
      }

      final now = DateTime.now();
      final connectionDuration = now.difference(_currentStatus.connectionStartTime!);
      
      // Simulate increasing data usage
      final bytesReceived = _currentStats!.bytesReceived + _random.nextInt(1024 * 100);
      final bytesSent = _currentStats!.bytesSent + _random.nextInt(1024 * 50);
      
      // Simulate varying speeds
      final downloadSpeed = 50000 + _random.nextDouble() * 100000; // 50KB/s to 150KB/s
      final uploadSpeed = 20000 + _random.nextDouble() * 50000;    // 20KB/s to 70KB/s

      _currentStats = NetworkStats(
        bytesReceived: bytesReceived,
        bytesSent: bytesSent,
        connectionDuration: connectionDuration,
        downloadSpeed: downloadSpeed,
        uploadSpeed: uploadSpeed,
        packetsReceived: _currentStats!.packetsReceived + _random.nextInt(100),
        packetsSent: _currentStats!.packetsSent + _random.nextInt(50),
        lastUpdated: now,
      );

      // Update status with new stats
      _currentStatus = _currentStatus.copyWith(currentStats: _currentStats);
      _statusController?.add(_currentStatus);
    });
  }

  void dispose() {
    _connectionTimer?.cancel();
    _statsTimer?.cancel();
    _statusController?.close();
  }
}