import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';

import '../models/app_error.dart';
import '../models/notification_data.dart';
import '../services/error_handler_service.dart';
import '../services/notification_service.dart';
import '../services/user_feedback_service.dart';
import '../services/logs_service.dart';

/// Provider for the notification service
final notificationServiceProvider = Provider<NotificationService>((ref) {
  final logger = Logger();
  final service = NotificationService(logger: logger);
  
  // Initialize the service
  service.initialize().catchError((error) {
    logger.e('Failed to initialize notification service: $error');
  });
  
  ref.onDispose(() {
    service.dispose();
  });
  
  return service;
});

/// Provider for the error handler service
final errorHandlerServiceProvider = Provider<ErrorHandlerService>((ref) {
  final notificationService = ref.watch(notificationServiceProvider);
  final logsService = ref.watch(logsServiceProvider);
  final logger = Logger();
  
  final service = ErrorHandlerService(
    notificationService: notificationService,
    logsService: logsService,
    logger: logger,
  );
  
  ref.onDispose(() {
    service.dispose();
  });
  
  return service;
});

/// Provider for the user feedback service
final userFeedbackServiceProvider = Provider<UserFeedbackService>((ref) {
  final logsService = ref.watch(logsServiceProvider);
  final errorHandlerService = ref.watch(errorHandlerServiceProvider);
  final logger = Logger();
  
  final service = UserFeedbackService(
    logsService: logsService,
    errorHandlerService: errorHandlerService,
    logger: logger,
  );
  
  ref.onDispose(() {
    service.dispose();
  });
  
  return service;
});

/// Provider for logs service (assuming it exists)
final logsServiceProvider = Provider<LogsService>((ref) {
  return LogsService();
});

/// Provider for active notifications stream
final activeNotificationsProvider = StreamProvider<List<NotificationData>>((ref) {
  final notificationService = ref.watch(notificationServiceProvider);
  
  return notificationService.notificationStream.map((notification) {
    return notificationService.activeNotifications;
  });
});

/// Provider for error stream
final errorStreamProvider = StreamProvider<AppError>((ref) {
  final errorHandlerService = ref.watch(errorHandlerServiceProvider);
  return errorHandlerService.errorStream;
});

/// Provider for recent errors
final recentErrorsProvider = Provider<List<AppError>>((ref) {
  final errorHandlerService = ref.watch(errorHandlerServiceProvider);
  return errorHandlerService.recentErrors;
});

/// Provider for error statistics
final errorStatisticsProvider = Provider<Map<String, dynamic>>((ref) {
  final errorHandlerService = ref.watch(errorHandlerServiceProvider);
  return errorHandlerService.getErrorStatistics();
});

/// Provider for feedback history
final feedbackHistoryProvider = Provider<List<FeedbackReport>>((ref) {
  final userFeedbackService = ref.watch(userFeedbackServiceProvider);
  return userFeedbackService.feedbackHistory;
});

/// State notifier for managing error handling UI state
class ErrorHandlingNotifier extends StateNotifier<ErrorHandlingState> {
  final ErrorHandlerService _errorHandlerService;
  final NotificationService _notificationService;
  final UserFeedbackService _userFeedbackService;

  ErrorHandlingNotifier(
    this._errorHandlerService,
    this._notificationService,
    this._userFeedbackService,
  ) : super(const ErrorHandlingState());

  /// Handles an exception and shows appropriate UI feedback
  Future<void> handleException(
    dynamic exception, {
    StackTrace? stackTrace,
    String? context,
    bool showNotification = true,
    bool showSnackbar = false,
  }) async {
    try {
      state = state.copyWith(isHandlingError: true);
      
      final appError = await _errorHandlerService.handleException(
        exception,
        stackTrace: stackTrace,
        context: context,
        showNotification: showNotification,
      );
      
      state = state.copyWith(
        isHandlingError: false,
        lastError: appError,
        showSnackbar: showSnackbar,
      );
    } catch (e) {
      state = state.copyWith(
        isHandlingError: false,
        lastError: AppErrorFactory.systemError(
          technicalMessage: 'Failed to handle error: $e',
        ),
      );
    }
  }

  /// Dismisses a notification
  Future<void> dismissNotification(String notificationId) async {
    await _notificationService.dismissNotification(notificationId);
  }

  /// Dismisses all notifications
  Future<void> dismissAllNotifications() async {
    await _notificationService.dismissAllNotifications();
  }

  /// Shows a feedback dialog for an error
  Future<void> reportError(AppError error) async {
    try {
      await _userFeedbackService.createErrorFeedback(error: error);
    } catch (e) {
      // Handle feedback creation error
      await handleException(e, context: 'Creating error feedback');
    }
  }

  /// Clears the last error from state
  void clearLastError() {
    state = state.copyWith(lastError: null, showSnackbar: false);
  }

  /// Enables or disables system notifications
  Future<void> setSystemNotificationsEnabled(bool enabled) async {
    await _notificationService.setSystemNotificationsEnabled(enabled);
    state = state.copyWith(systemNotificationsEnabled: enabled);
  }

  /// Enables or disables in-app notifications
  void setInAppNotificationsEnabled(bool enabled) {
    _notificationService.setInAppNotificationsEnabled(enabled);
    state = state.copyWith(inAppNotificationsEnabled: enabled);
  }

  /// Exports diagnostic information
  Future<String?> exportDiagnosticInfo() async {
    try {
      return await _userFeedbackService.exportDiagnosticInfo();
    } catch (e) {
      await handleException(e, context: 'Exporting diagnostic info');
      return null;
    }
  }
}

/// State for error handling UI
class ErrorHandlingState {
  final bool isHandlingError;
  final AppError? lastError;
  final bool showSnackbar;
  final bool systemNotificationsEnabled;
  final bool inAppNotificationsEnabled;

  const ErrorHandlingState({
    this.isHandlingError = false,
    this.lastError,
    this.showSnackbar = false,
    this.systemNotificationsEnabled = true,
    this.inAppNotificationsEnabled = true,
  });

  ErrorHandlingState copyWith({
    bool? isHandlingError,
    AppError? lastError,
    bool? showSnackbar,
    bool? systemNotificationsEnabled,
    bool? inAppNotificationsEnabled,
  }) {
    return ErrorHandlingState(
      isHandlingError: isHandlingError ?? this.isHandlingError,
      lastError: lastError ?? this.lastError,
      showSnackbar: showSnackbar ?? this.showSnackbar,
      systemNotificationsEnabled: systemNotificationsEnabled ?? this.systemNotificationsEnabled,
      inAppNotificationsEnabled: inAppNotificationsEnabled ?? this.inAppNotificationsEnabled,
    );
  }
}

/// Provider for error handling state notifier
final errorHandlingProvider = StateNotifierProvider<ErrorHandlingNotifier, ErrorHandlingState>((ref) {
  final errorHandlerService = ref.watch(errorHandlerServiceProvider);
  final notificationService = ref.watch(notificationServiceProvider);
  final userFeedbackService = ref.watch(userFeedbackServiceProvider);
  
  return ErrorHandlingNotifier(
    errorHandlerService,
    notificationService,
    userFeedbackService,
  );
});

/// Helper provider for easy error handling in widgets
final errorHandlerProvider = Provider<ErrorHandlerService>((ref) {
  return ref.watch(errorHandlerServiceProvider);
});

/// Helper provider for easy notification access in widgets
final notificationProvider = Provider<NotificationService>((ref) {
  return ref.watch(notificationServiceProvider);
});

/// Helper provider for easy feedback access in widgets
final feedbackProvider = Provider<UserFeedbackService>((ref) {
  return ref.watch(userFeedbackServiceProvider);
});