import 'dart:async';
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:logger/logger.dart';
import 'package:uuid/uuid.dart';

import '../models/connection_history.dart';
import '../models/network_stats.dart';


/// Service for managing VPN connection history and data usage tracking
/// 
/// This service provides:
/// - Connection session tracking and storage
/// - Data usage monitoring and reporting
/// - Historical statistics and analytics
/// - Secure storage of connection history
class ConnectionHistoryService {
  final FlutterSecureStorage _secureStorage;
  final Logger _logger;
  final Uuid _uuid;

  // Storage keys
  static const String _historyKey = 'vpn_connection_history';
  static const String _currentSessionKey = 'vpn_current_session';

  // In-memory cache
  List<ConnectionHistoryEntry> _history = [];
  ConnectionHistoryEntry? _currentSession;
  
  // Stream controllers
  final StreamController<List<ConnectionHistoryEntry>> _historyController = 
      StreamController<List<ConnectionHistoryEntry>>.broadcast();
  final StreamController<DataUsageSummary> _usageSummaryController = 
      StreamController<DataUsageSummary>.broadcast();

  // Configuration
  static const int _maxHistoryEntries = 1000;
  static const Duration _historyRetentionPeriod = Duration(days: 90);

  ConnectionHistoryService({
    FlutterSecureStorage? secureStorage,
    Logger? logger,
    Uuid? uuid,
  })  : _secureStorage = secureStorage ?? const FlutterSecureStorage(),
        _logger = logger ?? Logger(),
        _uuid = uuid ?? const Uuid();

  /// Stream of connection history updates
  Stream<List<ConnectionHistoryEntry>> get historyStream => _historyController.stream;

  /// Stream of data usage summary updates
  Stream<DataUsageSummary> get usageSummaryStream => _usageSummaryController.stream;

  /// Current connection history
  List<ConnectionHistoryEntry> get history => List.unmodifiable(_history);

  /// Current active session (if any)
  ConnectionHistoryEntry? get currentSession => _currentSession;

  /// Initializes the service and loads stored history
  Future<void> initialize() async {
    try {
      _logger.i('Initializing connection history service');
      
      await _loadHistory();
      await _loadCurrentSession();
      await _cleanupOldEntries();
      
      _logger.i('Connection history service initialized with ${_history.length} entries');
    } catch (e) {
      _logger.e('Failed to initialize connection history service: $e');
      rethrow;
    }
  }

  /// Starts tracking a new connection session
  Future<void> startSession({
    required String serverName,
    String? serverLocation,
  }) async {
    try {
      _logger.d('Starting new connection session for server: $serverName');
      
      // End any existing session first
      if (_currentSession != null) {
        await endSession(
          disconnectionReason: 'New session started',
          wasSuccessful: false,
        );
      }

      _currentSession = ConnectionHistoryEntry(
        id: _uuid.v4(),
        serverName: serverName,
        serverLocation: serverLocation,
        startTime: DateTime.now(),
        wasSuccessful: false, // Will be updated when connection succeeds
      );

      await _saveCurrentSession();
      _logger.d('Started session: ${_currentSession!.id}');
    } catch (e) {
      _logger.e('Failed to start connection session: $e');
      rethrow;
    }
  }

  /// Updates the current session with connection success
  Future<void> markSessionSuccessful() async {
    if (_currentSession == null) {
      _logger.w('No current session to mark as successful');
      return;
    }

    try {
      _currentSession = _currentSession!.copyWith(wasSuccessful: true);
      await _saveCurrentSession();
      _logger.d('Marked session ${_currentSession!.id} as successful');
    } catch (e) {
      _logger.e('Failed to mark session as successful: $e');
    }
  }

  /// Updates the current session with network statistics
  Future<void> updateSessionStats(NetworkStats stats) async {
    if (_currentSession == null) {
      return;
    }

    try {
      _currentSession = _currentSession!.copyWith(finalStats: stats);
      await _saveCurrentSession();
    } catch (e) {
      _logger.w('Failed to update session stats: $e');
    }
  }

  /// Ends the current connection session
  Future<void> endSession({
    String? disconnectionReason,
    bool? wasSuccessful,
    NetworkStats? finalStats,
  }) async {
    if (_currentSession == null) {
      _logger.d('No current session to end');
      return;
    }

    try {
      _logger.d('Ending session: ${_currentSession!.id}');

      final endedSession = _currentSession!.copyWith(
        endTime: DateTime.now(),
        disconnectionReason: disconnectionReason,
        wasSuccessful: wasSuccessful ?? _currentSession!.wasSuccessful,
        finalStats: finalStats ?? _currentSession!.finalStats,
      );

      // Add to history
      _history.insert(0, endedSession); // Insert at beginning for chronological order
      
      // Limit history size
      if (_history.length > _maxHistoryEntries) {
        _history = _history.take(_maxHistoryEntries).toList();
      }

      // Clear current session
      _currentSession = null;

      // Save changes
      await _saveHistory();
      await _clearCurrentSession();

      // Notify listeners
      _historyController.add(_history);
      await _updateUsageSummary();

      _logger.d('Session ended and saved to history');
    } catch (e) {
      _logger.e('Failed to end connection session: $e');
    }
  }

  /// Gets connection history for a specific time period
  List<ConnectionHistoryEntry> getHistoryForPeriod({
    DateTime? startDate,
    DateTime? endDate,
  }) {
    final start = startDate ?? DateTime.now().subtract(const Duration(days: 30));
    final end = endDate ?? DateTime.now();

    return _history.where((entry) {
      return entry.startTime.isAfter(start) && entry.startTime.isBefore(end);
    }).toList();
  }

  /// Gets data usage summary for a specific period
  Future<DataUsageSummary> getUsageSummary({
    DateTime? startDate,
    DateTime? endDate,
    String? period,
  }) async {
    final start = startDate ?? DateTime.now().subtract(const Duration(days: 30));
    final end = endDate ?? DateTime.now();
    final periodName = period ?? 'Last 30 days';

    final periodHistory = getHistoryForPeriod(startDate: start, endDate: end);

    // Calculate totals
    int totalDownloaded = 0;
    int totalUploaded = 0;
    Duration totalConnectionTime = Duration.zero;
    int successful = 0;
    int failed = 0;
    Map<String, int> serverUsage = {};

    for (final entry in periodHistory) {
      if (entry.finalStats != null) {
        totalDownloaded += entry.finalStats!.bytesReceived;
        totalUploaded += entry.finalStats!.bytesSent;
      }
      
      totalConnectionTime += entry.duration;
      
      if (entry.wasSuccessful) {
        successful++;
      } else {
        failed++;
      }

      // Track server usage
      serverUsage[entry.serverName] = (serverUsage[entry.serverName] ?? 0) + 1;
    }

    // Find most used server
    String? mostUsedServer;
    int maxUsage = 0;
    serverUsage.forEach((server, usage) {
      if (usage > maxUsage) {
        maxUsage = usage;
        mostUsedServer = server;
      }
    });

    // Calculate average session duration
    final averageDuration = periodHistory.isNotEmpty
        ? Duration(milliseconds: totalConnectionTime.inMilliseconds ~/ periodHistory.length)
        : Duration.zero;

    return DataUsageSummary(
      totalBytesDownloaded: totalDownloaded,
      totalBytesUploaded: totalUploaded,
      totalConnectionTime: totalConnectionTime,
      successfulConnections: successful,
      failedConnections: failed,
      averageSessionDuration: averageDuration,
      mostUsedServer: mostUsedServer,
      period: periodName,
      generatedAt: DateTime.now(),
    );
  }

  /// Gets daily data usage for the last N days (for charts)
  List<DailyUsage> getDailyUsage({int days = 30}) {
    final now = DateTime.now();
    final dailyUsage = <DateTime, DailyUsage>{};

    // Initialize all days with zero usage
    for (int i = 0; i < days; i++) {
      final date = DateTime(now.year, now.month, now.day).subtract(Duration(days: i));
      dailyUsage[date] = DailyUsage(
        date: date,
        bytesDownloaded: 0,
        bytesUploaded: 0,
        connectionTime: Duration.zero,
        sessionCount: 0,
      );
    }

    // Aggregate usage by day
    for (final entry in _history) {
      final entryDate = DateTime(
        entry.startTime.year,
        entry.startTime.month,
        entry.startTime.day,
      );

      if (dailyUsage.containsKey(entryDate)) {
        final existing = dailyUsage[entryDate]!;
        dailyUsage[entryDate] = DailyUsage(
          date: entryDate,
          bytesDownloaded: existing.bytesDownloaded + (entry.finalStats?.bytesReceived ?? 0),
          bytesUploaded: existing.bytesUploaded + (entry.finalStats?.bytesSent ?? 0),
          connectionTime: existing.connectionTime + entry.duration,
          sessionCount: existing.sessionCount + 1,
        );
      }
    }

    return dailyUsage.values.toList()..sort((a, b) => a.date.compareTo(b.date));
  }

  /// Clears all connection history
  Future<void> clearHistory() async {
    try {
      _logger.i('Clearing all connection history');
      
      _history.clear();
      await _saveHistory();
      
      _historyController.add(_history);
      await _updateUsageSummary();
      
      _logger.i('Connection history cleared');
    } catch (e) {
      _logger.e('Failed to clear connection history: $e');
      rethrow;
    }
  }

  /// Exports connection history as JSON
  Future<String> exportHistory() async {
    try {
      final exportData = {
        'exportedAt': DateTime.now().toIso8601String(),
        'version': '1.0',
        'history': _history.map((entry) => entry.toJson()).toList(),
      };

      return jsonEncode(exportData);
    } catch (e) {
      _logger.e('Failed to export connection history: $e');
      rethrow;
    }
  }

  /// Disposes of the service and releases resources
  void dispose() {
    _logger.d('Disposing connection history service');
    _historyController.close();
    _usageSummaryController.close();
  }

  // Private helper methods

  Future<void> _loadHistory() async {
    try {
      final historyJson = await _secureStorage.read(key: _historyKey);
      if (historyJson != null) {
        final List<dynamic> historyList = jsonDecode(historyJson);
        _history = historyList
            .map((json) => ConnectionHistoryEntry.fromJson(json))
            .toList();
        _logger.d('Loaded ${_history.length} history entries');
      }
    } catch (e) {
      _logger.w('Failed to load connection history: $e');
      _history = [];
    }
  }

  Future<void> _saveHistory() async {
    try {
      final historyJson = jsonEncode(_history.map((entry) => entry.toJson()).toList());
      await _secureStorage.write(key: _historyKey, value: historyJson);
    } catch (e) {
      _logger.e('Failed to save connection history: $e');
    }
  }

  Future<void> _loadCurrentSession() async {
    try {
      final sessionJson = await _secureStorage.read(key: _currentSessionKey);
      if (sessionJson != null) {
        _currentSession = ConnectionHistoryEntry.fromJson(jsonDecode(sessionJson));
        _logger.d('Loaded current session: ${_currentSession!.id}');
      }
    } catch (e) {
      _logger.w('Failed to load current session: $e');
      _currentSession = null;
    }
  }

  Future<void> _saveCurrentSession() async {
    try {
      if (_currentSession != null) {
        final sessionJson = jsonEncode(_currentSession!.toJson());
        await _secureStorage.write(key: _currentSessionKey, value: sessionJson);
      }
    } catch (e) {
      _logger.e('Failed to save current session: $e');
    }
  }

  Future<void> _clearCurrentSession() async {
    try {
      await _secureStorage.delete(key: _currentSessionKey);
    } catch (e) {
      _logger.e('Failed to clear current session: $e');
    }
  }

  Future<void> _cleanupOldEntries() async {
    try {
      final cutoffDate = DateTime.now().subtract(_historyRetentionPeriod);
      final originalCount = _history.length;
      
      _history.removeWhere((entry) => entry.startTime.isBefore(cutoffDate));
      
      if (_history.length != originalCount) {
        await _saveHistory();
        _logger.i('Cleaned up ${originalCount - _history.length} old history entries');
      }
    } catch (e) {
      _logger.e('Failed to cleanup old entries: $e');
    }
  }

  Future<void> _updateUsageSummary() async {
    try {
      final summary = await getUsageSummary();
      _usageSummaryController.add(summary);
    } catch (e) {
      _logger.w('Failed to update usage summary: $e');
    }
  }
}

/// Daily usage data for charts and analytics
class DailyUsage {
  final DateTime date;
  final int bytesDownloaded;
  final int bytesUploaded;
  final Duration connectionTime;
  final int sessionCount;

  const DailyUsage({
    required this.date,
    required this.bytesDownloaded,
    required this.bytesUploaded,
    required this.connectionTime,
    required this.sessionCount,
  });

  int get totalBytes => bytesDownloaded + bytesUploaded;
  String get formattedTotalBytes => NetworkStats.formatBytes(totalBytes);
  String get formattedDownloaded => NetworkStats.formatBytes(bytesDownloaded);
  String get formattedUploaded => NetworkStats.formatBytes(bytesUploaded);
}