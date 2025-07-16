import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';

import '../models/connection_history.dart';
import '../models/network_stats.dart';
import '../services/connection_history_service.dart';
import '../services/connection_monitor.dart';
import 'vpn_provider.dart';

/// Provider for the connection history service
final connectionHistoryServiceProvider = Provider<ConnectionHistoryService>((ref) {
  final service = ConnectionHistoryService(
    logger: Logger(),
  );
  
  // Initialize the service
  service.initialize().catchError((error) {
    Logger().e('Failed to initialize connection history service: $error');
  });
  
  ref.onDispose(() {
    service.dispose();
  });
  
  return service;
});

/// Provider for current network statistics
final currentNetworkStatsProvider = StreamProvider<NetworkStats?>((ref) {
  final connectionMonitor = ref.watch(connectionMonitorProvider);
  return connectionMonitor.statsStream;
});

/// Provider for connection history
final connectionHistoryProvider = StreamProvider<List<ConnectionHistoryEntry>>((ref) {
  final historyService = ref.watch(connectionHistoryServiceProvider);
  return historyService.historyStream;
});

/// Provider for usage summary with period parameter
final usageSummaryProvider = FutureProvider.family<DataUsageSummary, String>((ref, period) async {
  final historyService = ref.watch(connectionHistoryServiceProvider);
  
  DateTime? startDate;
  switch (period) {
    case 'Last 7 days':
      startDate = DateTime.now().subtract(const Duration(days: 7));
      break;
    case 'Last 30 days':
      startDate = DateTime.now().subtract(const Duration(days: 30));
      break;
    case 'Last 90 days':
      startDate = DateTime.now().subtract(const Duration(days: 90));
      break;
    case 'All time':
      startDate = null;
      break;
    default:
      startDate = DateTime.now().subtract(const Duration(days: 30));
  }
  
  return await historyService.getUsageSummary(
    startDate: startDate,
    period: period,
  );
});

/// Provider for daily usage data for charts
final dailyUsageProvider = FutureProvider<List<DailyUsage>>((ref) async {
  final historyService = ref.watch(connectionHistoryServiceProvider);
  return historyService.getDailyUsage(days: 30);
});

/// Provider for real-time statistics monitoring
final statisticsMonitorProvider = Provider<StatisticsMonitor>((ref) {
  final connectionMonitor = ref.watch(connectionMonitorProvider);
  final historyService = ref.watch(connectionHistoryServiceProvider);
  final vpnService = ref.watch(vpnServiceProvider);
  
  final monitor = StatisticsMonitor(
    connectionMonitor: connectionMonitor,
    historyService: historyService,
    vpnService: vpnService,
  );
  
  ref.onDispose(() {
    monitor.dispose();
  });
  
  return monitor;
});

/// Statistics monitor that coordinates between connection monitoring and history tracking
class StatisticsMonitor {
  final ConnectionMonitor _connectionMonitor;
  final ConnectionHistoryService _historyService;
  final Logger _logger = Logger();
  
  bool _isInitialized = false;
  String? _currentSessionId;

  StatisticsMonitor({
    required ConnectionMonitor connectionMonitor,
    required ConnectionHistoryService historyService,
    required dynamic vpnService,
  })  : _connectionMonitor = connectionMonitor,
        _historyService = historyService {
    _initialize();
  }

  void _initialize() {
    if (_isInitialized) return;
    
    try {
      _logger.d('Initializing statistics monitor');
      
      // Listen to VPN status changes to track sessions
      _connectionMonitor.statusStream.listen(_handleStatusChange);
      
      // Listen to network stats to update current session
      _connectionMonitor.statsStream.listen(_handleStatsUpdate);
      
      _isInitialized = true;
      _logger.d('Statistics monitor initialized');
    } catch (e) {
      _logger.e('Failed to initialize statistics monitor: $e');
    }
  }

  void _handleStatusChange(dynamic status) {
    try {
      final state = status.state;
      
      switch (state.toString()) {
        case 'VpnConnectionState.connecting':
          _handleConnectionStarted(status);
          break;
        case 'VpnConnectionState.connected':
          _handleConnectionEstablished(status);
          break;
        case 'VpnConnectionState.disconnected':
        case 'VpnConnectionState.error':
          _handleConnectionEnded(status);
          break;
      }
    } catch (e) {
      _logger.w('Error handling status change: $e');
    }
  }

  void _handleConnectionStarted(dynamic status) {
    try {
      // Get server information from current configuration
      final serverName = status.connectedServer ?? 'Unknown Server';
      
      _logger.d('Starting session tracking for server: $serverName');
      
      _historyService.startSession(
        serverName: serverName,
        serverLocation: null, // Could be extracted from configuration
      ).then((_) {
        _currentSessionId = _historyService.currentSession?.id;
        _logger.d('Session tracking started: $_currentSessionId');
      }).catchError((error) {
        _logger.e('Failed to start session tracking: $error');
      });
    } catch (e) {
      _logger.e('Error starting connection tracking: $e');
    }
  }

  void _handleConnectionEstablished(dynamic status) {
    try {
      _logger.d('Connection established, marking session as successful');
      
      _historyService.markSessionSuccessful().catchError((error) {
        _logger.e('Failed to mark session as successful: $error');
      });
    } catch (e) {
      _logger.e('Error handling connection establishment: $e');
    }
  }

  void _handleConnectionEnded(dynamic status) {
    try {
      if (_currentSessionId == null) {
        _logger.d('No active session to end');
        return;
      }
      
      _logger.d('Ending session tracking: $_currentSessionId');
      
      String? disconnectionReason;
      bool wasSuccessful = true;
      
      if (status.state.toString() == 'VpnConnectionState.error') {
        disconnectionReason = status.lastError ?? 'Connection error';
        wasSuccessful = false;
      } else {
        disconnectionReason = 'User disconnected';
      }
      
      _historyService.endSession(
        disconnectionReason: disconnectionReason,
        wasSuccessful: wasSuccessful,
        finalStats: _connectionMonitor.currentStats,
      ).then((_) {
        _currentSessionId = null;
        _logger.d('Session tracking ended');
      }).catchError((error) {
        _logger.e('Failed to end session tracking: $error');
      });
    } catch (e) {
      _logger.e('Error ending connection tracking: $e');
    }
  }

  void _handleStatsUpdate(NetworkStats? stats) {
    try {
      if (stats != null && _currentSessionId != null) {
        _historyService.updateSessionStats(stats).catchError((error) {
          _logger.w('Failed to update session stats: $error');
        });
      }
    } catch (e) {
      _logger.w('Error updating session stats: $e');
    }
  }

  void dispose() {
    _logger.d('Disposing statistics monitor');
    // Stream subscriptions are automatically cancelled when providers are disposed
  }
}

/// Provider for exporting statistics data
final statisticsExportProvider = FutureProvider<String>((ref) async {
  final historyService = ref.watch(connectionHistoryServiceProvider);
  return await historyService.exportHistory();
});

/// Provider for clearing statistics data
final clearStatisticsProvider = FutureProvider<void>((ref) async {
  final historyService = ref.watch(connectionHistoryServiceProvider);
  await historyService.clearHistory();
});