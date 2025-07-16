import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/app_error.dart';
import '../models/vpn_status.dart';
import '../models/network_stats.dart';
import 'logs_service.dart';
import 'error_handler_service.dart';

/// Model for user feedback reports
class FeedbackReport {
  final String id;
  final String title;
  final String description;
  final FeedbackCategory category;
  final FeedbackSeverity severity;
  final Map<String, dynamic> systemInfo;
  final Map<String, dynamic> diagnosticData;
  final List<String> attachedLogs;
  final DateTime timestamp;
  final String? userEmail;
  final String? userContact;

  const FeedbackReport({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.severity,
    required this.systemInfo,
    required this.diagnosticData,
    required this.attachedLogs,
    required this.timestamp,
    this.userEmail,
    this.userContact,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'category': category.toString().split('.').last,
      'severity': severity.toString().split('.').last,
      'system_info': systemInfo,
      'diagnostic_data': diagnosticData,
      'attached_logs': attachedLogs,
      'timestamp': timestamp.toIso8601String(),
      'user_email': userEmail,
      'user_contact': userContact,
    };
  }
}

/// Enum for feedback categories
enum FeedbackCategory {
  connectionIssue,
  performanceIssue,
  configurationProblem,
  uiProblem,
  featureRequest,
  bug,
  other,
}

/// Enum for feedback severity levels
enum FeedbackSeverity { low, medium, high, critical }

/// Service for collecting and managing user feedback
///
/// This service provides functionality for:
/// - Collecting user feedback and bug reports
/// - Gathering diagnostic information automatically
/// - Exporting logs and system information
/// - Sharing feedback reports with support
class UserFeedbackService {
  final LogsService _logsService;
  final ErrorHandlerService _errorHandlerService;
  final Logger _logger;

  // Feedback storage
  final List<FeedbackReport> _feedbackHistory = [];
  final StreamController<FeedbackReport> _feedbackController =
      StreamController<FeedbackReport>.broadcast();

  UserFeedbackService({
    required LogsService logsService,
    required ErrorHandlerService errorHandlerService,
    Logger? logger,
  }) : _logsService = logsService,
       _errorHandlerService = errorHandlerService,
       _logger = logger ?? Logger();

  /// Stream of new feedback reports
  Stream<FeedbackReport> get feedbackStream => _feedbackController.stream;

  /// List of feedback history
  List<FeedbackReport> get feedbackHistory =>
      List.unmodifiable(_feedbackHistory);

  /// Creates a feedback report for connection issues
  Future<FeedbackReport> createConnectionIssueFeedback({
    required String title,
    required String description,
    required FeedbackSeverity severity,
    VpnStatus? currentStatus,
    NetworkStats? networkStats,
    List<AppError>? relatedErrors,
    String? userEmail,
    String? userContact,
  }) async {
    try {
      _logger.i('Creating connection issue feedback report');

      final diagnosticData = await _gatherConnectionDiagnostics(
        currentStatus: currentStatus,
        networkStats: networkStats,
        relatedErrors: relatedErrors,
      );

      final systemInfo = await _gatherSystemInfo();
      final attachedLogs = await _gatherRelevantLogs(
        category: FeedbackCategory.connectionIssue,
      );

      final report = FeedbackReport(
        id: _generateReportId(),
        title: title,
        description: description,
        category: FeedbackCategory.connectionIssue,
        severity: severity,
        systemInfo: systemInfo,
        diagnosticData: diagnosticData,
        attachedLogs: attachedLogs,
        timestamp: DateTime.now(),
        userEmail: userEmail,
        userContact: userContact,
      );

      await _saveFeedbackReport(report);
      _feedbackHistory.insert(0, report);
      _feedbackController.add(report);

      _logger.i('Connection issue feedback report created: ${report.id}');
      return report;
    } catch (e) {
      _logger.e('Failed to create connection issue feedback: $e');
      rethrow;
    }
  }

  /// Creates a general feedback report
  Future<FeedbackReport> createGeneralFeedback({
    required String title,
    required String description,
    required FeedbackCategory category,
    required FeedbackSeverity severity,
    String? userEmail,
    String? userContact,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      _logger.i('Creating general feedback report');

      final diagnosticData = <String, dynamic>{
        'app_version': await _getAppVersion(),
        'timestamp': DateTime.now().toIso8601String(),
        if (additionalData != null) ...additionalData,
      };

      final systemInfo = await _gatherSystemInfo();
      final attachedLogs = await _gatherRelevantLogs(category: category);

      final report = FeedbackReport(
        id: _generateReportId(),
        title: title,
        description: description,
        category: category,
        severity: severity,
        systemInfo: systemInfo,
        diagnosticData: diagnosticData,
        attachedLogs: attachedLogs,
        timestamp: DateTime.now(),
        userEmail: userEmail,
        userContact: userContact,
      );

      await _saveFeedbackReport(report);
      _feedbackHistory.insert(0, report);
      _feedbackController.add(report);

      _logger.i('General feedback report created: ${report.id}');
      return report;
    } catch (e) {
      _logger.e('Failed to create general feedback: $e');
      rethrow;
    }
  }

  /// Creates a feedback report from an error
  Future<FeedbackReport> createErrorFeedback({
    required AppError error,
    String? additionalDescription,
    String? userEmail,
    String? userContact,
  }) async {
    try {
      _logger.i('Creating error feedback report for error: ${error.id}');

      final title =
          'Error Report: ${error.category.toString().split('.').last}';
      final description = [
        if (additionalDescription != null) additionalDescription,
        '',
        'Error Details:',
        'User Message: ${error.userMessage}',
        'Technical Message: ${error.technicalMessage}',
        if (error.errorCode != null) 'Error Code: ${error.errorCode}',
      ].join('\n');

      final diagnosticData = <String, dynamic>{
        'error_id': error.id,
        'error_category': error.category.toString(),
        'error_severity': error.severity.toString(),
        'error_code': error.errorCode,
        'error_timestamp': error.timestamp.toIso8601String(),
        'is_retryable': error.isRetryable,
        'recovery_actions': error.recoveryActions,
        if (error.context != null) 'error_context': error.context,
        if (error.stackTrace != null) 'stack_trace': error.stackTrace,
      };

      final systemInfo = await _gatherSystemInfo();
      final attachedLogs = await _gatherRelevantLogs(
        category: FeedbackCategory.bug,
        errorId: error.id,
      );

      final report = FeedbackReport(
        id: _generateReportId(),
        title: title,
        description: description,
        category: FeedbackCategory.bug,
        severity: _mapErrorSeverityToFeedbackSeverity(error.severity),
        systemInfo: systemInfo,
        diagnosticData: diagnosticData,
        attachedLogs: attachedLogs,
        timestamp: DateTime.now(),
        userEmail: userEmail,
        userContact: userContact,
      );

      await _saveFeedbackReport(report);
      _feedbackHistory.insert(0, report);
      _feedbackController.add(report);

      _logger.i('Error feedback report created: ${report.id}');
      return report;
    } catch (e) {
      _logger.e('Failed to create error feedback: $e');
      rethrow;
    }
  }

  /// Exports a feedback report as a shareable file
  Future<String> exportFeedbackReport(String reportId) async {
    try {
      _logger.i('Exporting feedback report: $reportId');

      final report = _feedbackHistory.firstWhere(
        (r) => r.id == reportId,
        orElse: () =>
            throw ArgumentError('Feedback report not found: $reportId'),
      );

      final exportData = {
        'report': report.toJson(),
        'export_timestamp': DateTime.now().toIso8601String(),
        'export_version': '1.0',
      };

      final jsonString = const JsonEncoder.withIndent('  ').convert(exportData);

      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/feedback_report_${report.id}.json');
      await file.writeAsString(jsonString);

      _logger.i('Feedback report exported to: ${file.path}');
      return file.path;
    } catch (e) {
      _logger.e('Failed to export feedback report: $e');
      rethrow;
    }
  }

  /// Shares a feedback report using the system share dialog
  Future<void> shareFeedbackReport(String reportId) async {
    try {
      _logger.i('Sharing feedback report: $reportId');

      final filePath = await exportFeedbackReport(reportId);
      final report = _feedbackHistory.firstWhere((r) => r.id == reportId);

      await Share.shareXFiles(
        [XFile(filePath)],
        subject: 'VPN Client Feedback Report: ${report.title}',
        text:
            'Please find attached the feedback report for the VPN client issue.',
      );

      _logger.i('Feedback report shared successfully');
    } catch (e) {
      _logger.e('Failed to share feedback report: $e');
      rethrow;
    }
  }

  /// Exports diagnostic information as a text file
  Future<String> exportDiagnosticInfo() async {
    try {
      _logger.i('Exporting diagnostic information');

      final systemInfo = await _gatherSystemInfo();
      final errorStats = _errorHandlerService.getErrorStatistics();
      final recentLogs = await _logsService.getRecentLogs(count: 100);

      final diagnosticText = [
        'VPN Client Diagnostic Information',
        '=' * 40,
        '',
        'Generated: ${DateTime.now().toIso8601String()}',
        '',
        'System Information:',
        '-' * 20,
        ...systemInfo.entries.map((e) => '${e.key}: ${e.value}'),
        '',
        'Error Statistics:',
        '-' * 20,
        ...errorStats.entries.map((e) => '${e.key}: ${e.value}'),
        '',
        'Recent Logs:',
        '-' * 20,
        ...recentLogs,
      ].join('\n');

      final directory = await getApplicationDocumentsDirectory();
      final file = File(
        '${directory.path}/vpn_diagnostic_${DateTime.now().millisecondsSinceEpoch}.txt',
      );
      await file.writeAsString(diagnosticText);

      _logger.i('Diagnostic information exported to: ${file.path}');
      return file.path;
    } catch (e) {
      _logger.e('Failed to export diagnostic information: $e');
      rethrow;
    }
  }

  /// Clears feedback history
  void clearFeedbackHistory() {
    _feedbackHistory.clear();
    _logger.i('Feedback history cleared');
  }

  /// Disposes of the service and releases resources
  void dispose() {
    _feedbackController.close();
    _feedbackHistory.clear();
  }

  // Private helper methods

  Future<Map<String, dynamic>> _gatherConnectionDiagnostics({
    VpnStatus? currentStatus,
    NetworkStats? networkStats,
    List<AppError>? relatedErrors,
  }) async {
    final diagnostics = <String, dynamic>{
      'timestamp': DateTime.now().toIso8601String(),
    };

    if (currentStatus != null) {
      diagnostics['vpn_status'] = {
        'state': currentStatus.state.toString(),
        'connected_server': currentStatus.connectedServer,
        'connection_start_time': currentStatus.connectionStartTime
            ?.toIso8601String(),
        'local_ip': currentStatus.localIpAddress,
        'public_ip': currentStatus.publicIpAddress,
        'last_error': currentStatus.lastError,
      };
    }

    if (networkStats != null) {
      diagnostics['network_stats'] = {
        'bytes_received': networkStats.bytesReceived,
        'bytes_sent': networkStats.bytesSent,
        'connection_duration': networkStats.connectionDuration.inSeconds,
        'download_speed': networkStats.downloadSpeed,
        'upload_speed': networkStats.uploadSpeed,
        'packets_received': networkStats.packetsReceived,
        'packets_sent': networkStats.packetsSent,
      };
    }

    if (relatedErrors != null && relatedErrors.isNotEmpty) {
      diagnostics['related_errors'] = relatedErrors
          .map(
            (error) => {
              'id': error.id,
              'category': error.category.toString(),
              'severity': error.severity.toString(),
              'user_message': error.userMessage,
              'technical_message': error.technicalMessage,
              'error_code': error.errorCode,
              'timestamp': error.timestamp.toIso8601String(),
            },
          )
          .toList();
    }

    return diagnostics;
  }

  Future<Map<String, dynamic>> _gatherSystemInfo() async {
    final systemInfo = <String, dynamic>{
      'platform': Platform.operatingSystem,
      'platform_version': Platform.operatingSystemVersion,
      'app_version': await _getAppVersion(),
      'dart_version': Platform.version,
      'timestamp': DateTime.now().toIso8601String(),
    };

    // Add platform-specific information
    if (Platform.isAndroid) {
      systemInfo['android_info'] = await _getAndroidInfo();
    } else if (Platform.isWindows) {
      systemInfo['windows_info'] = await _getWindowsInfo();
    }

    return systemInfo;
  }

  Future<List<String>> _gatherRelevantLogs({
    required FeedbackCategory category,
    String? errorId,
  }) async {
    try {
      final logs = await _logsService.getRecentLogs(count: 50);

      // Filter logs based on category and error ID
      final relevantLogs = logs.where((log) {
        final logLower = log.toLowerCase();

        // Include error logs for bug reports
        if (category == FeedbackCategory.bug && logLower.contains('error')) {
          return true;
        }

        // Include connection-related logs for connection issues
        if (category == FeedbackCategory.connectionIssue &&
            (logLower.contains('connection') || logLower.contains('vpn'))) {
          return true;
        }

        // Include logs with specific error ID
        if (errorId != null && logLower.contains(errorId.toLowerCase())) {
          return true;
        }

        return false;
      }).toList();

      return relevantLogs;
    } catch (e) {
      _logger.e('Failed to gather relevant logs: $e');
      return [];
    }
  }

  Future<void> _saveFeedbackReport(FeedbackReport report) async {
    try {
      // In a real implementation, this would save to persistent storage
      // For now, we'll just log that it would be saved
      _logger.d('Feedback report saved: ${report.id}');
    } catch (e) {
      _logger.e('Failed to save feedback report: $e');
    }
  }

  String _generateReportId() {
    return 'feedback_${DateTime.now().millisecondsSinceEpoch}';
  }

  Future<String> _getAppVersion() async {
    // In a real implementation, this would get the actual app version
    return '1.0.0';
  }

  Future<Map<String, dynamic>> _getAndroidInfo() async {
    // In a real implementation, this would gather Android-specific info
    return {
      'sdk_version': 'Unknown',
      'device_model': 'Unknown',
      'manufacturer': 'Unknown',
    };
  }

  Future<Map<String, dynamic>> _getWindowsInfo() async {
    // In a real implementation, this would gather Windows-specific info
    return {
      'windows_version': Platform.operatingSystemVersion,
      'architecture': 'Unknown',
    };
  }

  FeedbackSeverity _mapErrorSeverityToFeedbackSeverity(
    ErrorSeverity errorSeverity,
  ) {
    switch (errorSeverity) {
      case ErrorSeverity.critical:
        return FeedbackSeverity.critical;
      case ErrorSeverity.high:
        return FeedbackSeverity.high;
      case ErrorSeverity.medium:
        return FeedbackSeverity.medium;
      case ErrorSeverity.low:
        return FeedbackSeverity.low;
    }
  }
}
