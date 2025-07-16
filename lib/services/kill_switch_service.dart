import 'dart:async';

import 'package:logger/logger.dart';
import 'package:flutter/services.dart';

import '../interfaces/platform_channels.dart';

/// Kill switch service for blocking network traffic when VPN disconnects
/// 
/// This service provides platform-specific implementation for blocking
/// all network traffic when the VPN connection is lost, preventing
/// data leaks and ensuring privacy protection.
class KillSwitchService {
  final MethodChannel _platformChannel;
  final Logger _logger;
  
  bool _isActive = false;
  bool _isEnabled = false;
  Timer? _monitoringTimer;
  KillSwitchStatus? _currentStatus;
  
  // Configuration
  static const Duration _monitoringInterval = Duration(seconds: 5);
  
  // Status stream
  final StreamController<KillSwitchStatus> _statusController = 
      StreamController<KillSwitchStatus>.broadcast();

  KillSwitchService({
    MethodChannel? platformChannel,
    Logger? logger,
  })  : _platformChannel = platformChannel ?? 
            const MethodChannel(PlatformChannels.vpnControl),
        _logger = logger ?? Logger();

  /// Whether the kill switch is currently enabled
  bool get isEnabled => _isEnabled;

  /// Whether the kill switch is currently active (blocking traffic)
  bool get isActive => _isActive;

  /// Stream of kill switch status updates
  Stream<KillSwitchStatus> get statusStream => _statusController.stream;

  /// Initializes the kill switch service
  Future<void> initialize() async {
    try {
      _logger.i('Initializing kill switch service');
      
      // Check if kill switch is supported on this platform
      final supported = await isSupported();
      if (!supported) {
        _logger.w('Kill switch is not supported on this platform');
        return;
      }
      
      // Get initial status
      final status = await getStatus();
      _isEnabled = status.isEnabled;
      _isActive = status.isActive;
      
      _logger.i('Kill switch service initialized');
    } catch (e) {
      _logger.e('Failed to initialize kill switch service: $e');
      rethrow;
    }
  }

  /// Gets the current kill switch status
  KillSwitchStatus? get currentStatus => _currentStatus;

  /// Enables the kill switch functionality
  Future<void> enable() async {
    if (_isEnabled) {
      _logger.d('Kill switch is already enabled');
      return;
    }

    try {
      _logger.i('Enabling kill switch functionality');
      
      // Call platform-specific enable method
      final result = await _platformChannel.invokeMethod('enableKillSwitch');
      
      if (result['success'] == true) {
        _isEnabled = true;
        _startMonitoring();
        _emitStatus(KillSwitchStatus.enabled());
        _logger.i('Kill switch enabled successfully');
      } else {
        throw Exception(result['error'] ?? 'Failed to enable kill switch');
      }
      
    } catch (e) {
      _logger.e('Failed to enable kill switch: $e');
      _emitStatus(KillSwitchStatus.error('Failed to enable: $e'));
      rethrow;
    }
  }

  /// Disables the kill switch functionality
  Future<void> disable() async {
    if (!_isEnabled) {
      _logger.d('Kill switch is already disabled');
      return;
    }

    try {
      _logger.i('Disabling kill switch functionality');
      
      // Deactivate if currently active
      if (_isActive) {
        await deactivate();
      }
      
      // Call platform-specific disable method
      final result = await _platformChannel.invokeMethod('disableKillSwitch');
      
      if (result['success'] == true) {
        _isEnabled = false;
        _stopMonitoring();
        _emitStatus(KillSwitchStatus.disabled());
        _logger.i('Kill switch disabled successfully');
      } else {
        throw Exception(result['error'] ?? 'Failed to disable kill switch');
      }
      
    } catch (e) {
      _logger.e('Failed to disable kill switch: $e');
      _emitStatus(KillSwitchStatus.error('Failed to disable: $e'));
      rethrow;
    }
  }

  /// Activates the kill switch (blocks all network traffic)
  Future<void> activate() async {
    if (!_isEnabled) {
      throw Exception('Kill switch must be enabled before activation');
    }

    if (_isActive) {
      _logger.d('Kill switch is already active');
      return;
    }

    try {
      _logger.w('Activating kill switch - blocking all network traffic');
      
      // Call platform-specific activation method
      final result = await _platformChannel.invokeMethod('activateKillSwitch');
      
      if (result['success'] == true) {
        _isActive = true;
        _emitStatus(KillSwitchStatus.activated());
        _logger.w('Kill switch activated - all traffic blocked');
      } else {
        throw Exception(result['error'] ?? 'Failed to activate kill switch');
      }
      
    } catch (e) {
      _logger.e('Failed to activate kill switch: $e');
      _emitStatus(KillSwitchStatus.error('Failed to activate: $e'));
      rethrow;
    }
  }

  /// Deactivates the kill switch (restores normal network traffic)
  Future<void> deactivate() async {
    if (!_isActive) {
      _logger.d('Kill switch is already inactive');
      return;
    }

    try {
      _logger.i('Deactivating kill switch - restoring network traffic');
      
      // Call platform-specific deactivation method
      final result = await _platformChannel.invokeMethod('deactivateKillSwitch');
      
      if (result['success'] == true) {
        _isActive = false;
        _emitStatus(KillSwitchStatus.deactivated());
        _logger.i('Kill switch deactivated - traffic restored');
      } else {
        throw Exception(result['error'] ?? 'Failed to deactivate kill switch');
      }
      
    } catch (e) {
      _logger.e('Failed to deactivate kill switch: $e');
      _emitStatus(KillSwitchStatus.error('Failed to deactivate: $e'));
      rethrow;
    }
  }

  /// Gets the current kill switch status from the platform
  Future<KillSwitchInfo> getStatus() async {
    try {
      final result = await _platformChannel.invokeMethod('getKillSwitchStatus');
      
      if (result['success'] == true) {
        final data = result['data'] as Map<String, dynamic>;
        return KillSwitchInfo.fromJson(data);
      } else {
        throw Exception(result['error'] ?? 'Failed to get kill switch status');
      }
      
    } catch (e) {
      _logger.e('Failed to get kill switch status: $e');
      rethrow;
    }
  }

  /// Checks if the kill switch is supported on the current platform
  Future<bool> isSupported() async {
    try {
      final result = await _platformChannel.invokeMethod('isKillSwitchSupported');
      return result['supported'] == true;
    } catch (e) {
      _logger.e('Failed to check kill switch support: $e');
      return false;
    }
  }

  /// Gets platform-specific kill switch capabilities
  Future<KillSwitchCapabilities> getCapabilities() async {
    try {
      final result = await _platformChannel.invokeMethod('getKillSwitchCapabilities');
      
      if (result['success'] == true) {
        final data = result['data'] as Map<String, dynamic>;
        return KillSwitchCapabilities.fromJson(data);
      } else {
        throw Exception(result['error'] ?? 'Failed to get capabilities');
      }
      
    } catch (e) {
      _logger.e('Failed to get kill switch capabilities: $e');
      rethrow;
    }
  }

  /// Disposes of the kill switch service
  void dispose() {
    _logger.d('Disposing kill switch service');
    
    _stopMonitoring();
    _statusController.close();
  }

  // Private helper methods

  void _startMonitoring() {
    _stopMonitoring();
    
    _monitoringTimer = Timer.periodic(_monitoringInterval, (_) {
      _performStatusCheck();
    });
  }

  void _stopMonitoring() {
    _monitoringTimer?.cancel();
    _monitoringTimer = null;
  }

  void _performStatusCheck() {
    getStatus().then((info) {
      // Update internal state based on platform status
      if (_isActive != info.isActive) {
        _isActive = info.isActive;
        if (info.isActive) {
          _emitStatus(KillSwitchStatus.activated());
        } else {
          _emitStatus(KillSwitchStatus.deactivated());
        }
      }
      
      if (_isEnabled != info.isEnabled) {
        _isEnabled = info.isEnabled;
        if (info.isEnabled) {
          _emitStatus(KillSwitchStatus.enabled());
        } else {
          _emitStatus(KillSwitchStatus.disabled());
        }
      }
    }).catchError((error) {
      _logger.w('Status check failed: $error');
    });
  }

  void _emitStatus(KillSwitchStatus status) {
    _currentStatus = status;
    _statusController.add(status);
  }
}

/// Kill switch status information
class KillSwitchStatus {
  final KillSwitchEventType type;
  final String message;
  final DateTime timestamp;
  final Map<String, dynamic>? data;

  KillSwitchStatus({
    required this.type,
    required this.message,
    DateTime? timestamp,
    this.data,
  }) : timestamp = timestamp ?? DateTime.now();

  factory KillSwitchStatus.enabled() {
    return KillSwitchStatus(
      type: KillSwitchEventType.enabled,
      message: 'Kill switch enabled',
    );
  }

  factory KillSwitchStatus.disabled() {
    return KillSwitchStatus(
      type: KillSwitchEventType.disabled,
      message: 'Kill switch disabled',
    );
  }

  factory KillSwitchStatus.activated() {
    return KillSwitchStatus(
      type: KillSwitchEventType.activated,
      message: 'Kill switch activated - traffic blocked',
    );
  }

  factory KillSwitchStatus.deactivated() {
    return KillSwitchStatus(
      type: KillSwitchEventType.deactivated,
      message: 'Kill switch deactivated - traffic restored',
    );
  }

  factory KillSwitchStatus.error(String error) {
    return KillSwitchStatus(
      type: KillSwitchEventType.error,
      message: error,
    );
  }

  @override
  String toString() {
    return 'KillSwitchStatus(type: $type, message: $message, timestamp: $timestamp)';
  }
}

/// Types of kill switch events
enum KillSwitchEventType {
  enabled,
  disabled,
  activated,
  deactivated,
  error,
}

/// Kill switch information from platform
class KillSwitchInfo {
  final bool isEnabled;
  final bool isActive;
  final bool isSupported;
  final String? lastError;
  final DateTime? lastActivated;
  final DateTime? lastDeactivated;
  final Map<String, dynamic>? platformData;

  const KillSwitchInfo({
    required this.isEnabled,
    required this.isActive,
    required this.isSupported,
    this.lastError,
    this.lastActivated,
    this.lastDeactivated,
    this.platformData,
  });

  factory KillSwitchInfo.fromJson(Map<String, dynamic> json) {
    return KillSwitchInfo(
      isEnabled: json['isEnabled'] ?? false,
      isActive: json['isActive'] ?? false,
      isSupported: json['isSupported'] ?? false,
      lastError: json['lastError'],
      lastActivated: json['lastActivated'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(json['lastActivated'])
          : null,
      lastDeactivated: json['lastDeactivated'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(json['lastDeactivated'])
          : null,
      platformData: json['platformData'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'isEnabled': isEnabled,
      'isActive': isActive,
      'isSupported': isSupported,
      'lastError': lastError,
      'lastActivated': lastActivated?.millisecondsSinceEpoch,
      'lastDeactivated': lastDeactivated?.millisecondsSinceEpoch,
      'platformData': platformData,
    };
  }

  @override
  String toString() {
    return 'KillSwitchInfo(isEnabled: $isEnabled, isActive: $isActive, '
           'isSupported: $isSupported, lastError: $lastError)';
  }
}

/// Kill switch platform capabilities
class KillSwitchCapabilities {
  final bool supportsFirewallRules;
  final bool supportsRoutingTable;
  final bool supportsNetworkInterface;
  final bool supportsApplicationLevel;
  final List<String> supportedMethods;
  final Map<String, dynamic>? platformSpecific;

  const KillSwitchCapabilities({
    required this.supportsFirewallRules,
    required this.supportsRoutingTable,
    required this.supportsNetworkInterface,
    required this.supportsApplicationLevel,
    required this.supportedMethods,
    this.platformSpecific,
  });

  factory KillSwitchCapabilities.fromJson(Map<String, dynamic> json) {
    return KillSwitchCapabilities(
      supportsFirewallRules: json['supportsFirewallRules'] ?? false,
      supportsRoutingTable: json['supportsRoutingTable'] ?? false,
      supportsNetworkInterface: json['supportsNetworkInterface'] ?? false,
      supportsApplicationLevel: json['supportsApplicationLevel'] ?? false,
      supportedMethods: List<String>.from(json['supportedMethods'] ?? []),
      platformSpecific: json['platformSpecific'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'supportsFirewallRules': supportsFirewallRules,
      'supportsRoutingTable': supportsRoutingTable,
      'supportsNetworkInterface': supportsNetworkInterface,
      'supportsApplicationLevel': supportsApplicationLevel,
      'supportedMethods': supportedMethods,
      'platformSpecific': platformSpecific,
    };
  }

  @override
  String toString() {
    return 'KillSwitchCapabilities(supportsFirewallRules: $supportsFirewallRules, '
           'supportsRoutingTable: $supportsRoutingTable, '
           'supportsNetworkInterface: $supportsNetworkInterface, '
           'supportsApplicationLevel: $supportsApplicationLevel, '
           'supportedMethods: $supportedMethods)';
  }
}