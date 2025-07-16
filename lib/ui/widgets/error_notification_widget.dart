import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/app_error.dart';
import '../../models/notification_data.dart';
import '../theme/app_theme.dart';

/// Widget for displaying error notifications with user-friendly messages
class ErrorNotificationWidget extends ConsumerWidget {
  final NotificationData notification;
  final VoidCallback? onDismiss;
  final VoidCallback? onAction;

  const ErrorNotificationWidget({
    super.key,
    required this.notification,
    this.onDismiss,
    this.onAction,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      elevation: 4,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border(
            left: BorderSide(
              width: 4,
              color: _getNotificationColor(),
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(
                    _getNotificationIcon(),
                    color: _getNotificationColor(),
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          notification.title,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: _getNotificationColor(),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          notification.message,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (onDismiss != null)
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: onDismiss,
                      iconSize: 20,
                      color: Colors.grey[600],
                    ),
                ],
              ),
              if (notification.actionText != null) ...[
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: onAction,
                      child: Text(
                        notification.actionText!,
                        style: TextStyle(
                          color: _getNotificationColor(),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Color _getNotificationColor() {
    switch (notification.type) {
      case NotificationType.error:
        return AppTheme.errorRed;
      case NotificationType.warning:
        return AppTheme.warningOrange;
      case NotificationType.success:
        return AppTheme.accentGreen;
      case NotificationType.info:
      case NotificationType.connectionStatus:
        return AppTheme.primaryBlue;
    }
  }

  IconData _getNotificationIcon() {
    switch (notification.type) {
      case NotificationType.error:
        return Icons.error_outline;
      case NotificationType.warning:
        return Icons.warning_amber_outlined;
      case NotificationType.success:
        return Icons.check_circle_outline;
      case NotificationType.info:
        return Icons.info_outline;
      case NotificationType.connectionStatus:
        return Icons.vpn_key_outlined;
    }
  }
}

/// Widget for displaying detailed error information
class DetailedErrorWidget extends StatelessWidget {
  final AppError error;
  final VoidCallback? onRetry;
  final VoidCallback? onReport;
  final VoidCallback? onDismiss;

  const DetailedErrorWidget({
    super.key,
    required this.error,
    this.onRetry,
    this.onReport,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 6,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              children: [
                Icon(
                  _getErrorIcon(),
                  color: _getErrorColor(),
                  size: 32,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _getErrorTitle(),
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: _getErrorColor(),
                        ),
                      ),
                      Text(
                        _getSeverityText(),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                if (onDismiss != null)
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: onDismiss,
                    color: Colors.grey[600],
                  ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Error message
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _getErrorColor().withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                error.userMessage,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            
            // Recovery actions
            if (error.recoveryActions != null && error.recoveryActions!.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                'Suggested Actions:',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              ...error.recoveryActions!.map((action) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.arrow_right,
                      size: 16,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        action,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              )),
            ],
            
            const SizedBox(height: 20),
            
            // Action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (onReport != null)
                  TextButton.icon(
                    onPressed: onReport,
                    icon: const Icon(Icons.bug_report),
                    label: const Text('Report Issue'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.grey[700],
                    ),
                  ),
                if (onRetry != null && error.isRetryable) ...[
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _getErrorColor(),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ],
            ),
            
            // Technical details (expandable)
            const SizedBox(height: 12),
            ExpansionTile(
              title: Text(
                'Technical Details',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[600],
                ),
              ),
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildTechnicalDetail('Error ID', error.id),
                      _buildTechnicalDetail('Category', error.category.toString().split('.').last),
                      if (error.errorCode != null)
                        _buildTechnicalDetail('Error Code', error.errorCode!),
                      _buildTechnicalDetail('Timestamp', error.timestamp.toString()),
                      _buildTechnicalDetail('Technical Message', error.technicalMessage),
                      if (error.context != null && error.context!.isNotEmpty)
                        _buildTechnicalDetail('Context', error.context.toString()),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTechnicalDetail(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label:',
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }

  String _getErrorTitle() {
    switch (error.category) {
      case ErrorCategory.network:
        return 'Network Error';
      case ErrorCategory.configuration:
        return 'Configuration Error';
      case ErrorCategory.permission:
        return 'Permission Error';
      case ErrorCategory.platform:
        return 'System Error';
      case ErrorCategory.authentication:
        return 'Authentication Error';
      case ErrorCategory.system:
        return 'System Error';
      case ErrorCategory.unknown:
        return 'Unexpected Error';
    }
  }

  String _getSeverityText() {
    switch (error.severity) {
      case ErrorSeverity.critical:
        return 'Critical Issue';
      case ErrorSeverity.high:
        return 'High Priority';
      case ErrorSeverity.medium:
        return 'Medium Priority';
      case ErrorSeverity.low:
        return 'Low Priority';
    }
  }

  Color _getErrorColor() {
    switch (error.severity) {
      case ErrorSeverity.critical:
        return Colors.red[800]!;
      case ErrorSeverity.high:
        return AppTheme.errorRed;
      case ErrorSeverity.medium:
        return AppTheme.warningOrange;
      case ErrorSeverity.low:
        return Colors.blue[600]!;
    }
  }

  IconData _getErrorIcon() {
    switch (error.category) {
      case ErrorCategory.network:
        return Icons.wifi_off;
      case ErrorCategory.configuration:
        return Icons.settings_outlined;
      case ErrorCategory.permission:
        return Icons.security_outlined;
      case ErrorCategory.platform:
        return Icons.computer_outlined;
      case ErrorCategory.authentication:
        return Icons.lock_outline;
      case ErrorCategory.system:
        return Icons.error_outline;
      case ErrorCategory.unknown:
        return Icons.help_outline;
    }
  }
}

/// Snackbar-style error notification
class ErrorSnackBar extends SnackBar {
  ErrorSnackBar({
    super.key,
    required AppError error,
    VoidCallback? onRetry,
    VoidCallback? onReport,
  }) : super(
          content: Row(
            children: [
              Icon(
                Icons.error_outline,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  error.userMessage,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
          backgroundColor: _getSnackBarColor(error.severity),
          duration: _getSnackBarDuration(error.severity),
          action: error.isRetryable && onRetry != null
              ? SnackBarAction(
                  label: 'Retry',
                  textColor: Colors.white,
                  onPressed: onRetry,
                )
              : onReport != null
                  ? SnackBarAction(
                      label: 'Report',
                      textColor: Colors.white,
                      onPressed: onReport,
                    )
                  : null,
        );

  static Color _getSnackBarColor(ErrorSeverity severity) {
    switch (severity) {
      case ErrorSeverity.critical:
        return Colors.red[800]!;
      case ErrorSeverity.high:
        return AppTheme.errorRed;
      case ErrorSeverity.medium:
        return AppTheme.warningOrange;
      case ErrorSeverity.low:
        return Colors.blue[600]!;
    }
  }

  static Duration _getSnackBarDuration(ErrorSeverity severity) {
    switch (severity) {
      case ErrorSeverity.critical:
        return const Duration(seconds: 8);
      case ErrorSeverity.high:
        return const Duration(seconds: 6);
      case ErrorSeverity.medium:
        return const Duration(seconds: 4);
      case ErrorSeverity.low:
        return const Duration(seconds: 3);
    }
  }
}