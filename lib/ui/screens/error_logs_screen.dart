import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/app_error.dart';
import '../../providers/error_handling_provider.dart';
import '../../services/user_feedback_service.dart';
import '../theme/app_theme.dart';
import '../widgets/feedback_dialog.dart';

/// Screen for viewing error logs and diagnostic information
class ErrorLogsScreen extends ConsumerStatefulWidget {
  const ErrorLogsScreen({super.key});

  @override
  ConsumerState<ErrorLogsScreen> createState() => _ErrorLogsScreenState();
}

class _ErrorLogsScreenState extends ConsumerState<ErrorLogsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _searchQuery = '';
  ErrorCategory? _filterCategory;
  ErrorSeverity? _filterSeverity;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Error Logs & Diagnostics'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Recent Errors', icon: Icon(Icons.error_outline)),
            Tab(text: 'Statistics', icon: Icon(Icons.analytics_outlined)),
            Tab(text: 'Feedback', icon: Icon(Icons.feedback_outlined)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _exportDiagnostics,
            tooltip: 'Export Diagnostics',
          ),
          PopupMenuButton<String>(
            onSelected: _handleMenuAction,
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'clear_errors',
                child: Row(
                  children: [
                    Icon(Icons.clear_all),
                    SizedBox(width: 8),
                    Text('Clear Error History'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'export_logs',
                child: Row(
                  children: [
                    Icon(Icons.download),
                    SizedBox(width: 8),
                    Text('Export Logs'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'report_issue',
                child: Row(
                  children: [
                    Icon(Icons.bug_report),
                    SizedBox(width: 8),
                    Text('Report Issue'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildErrorsTab(),
          _buildStatisticsTab(),
          _buildFeedbackTab(),
        ],
      ),
    );
  }

  Widget _buildErrorsTab() {
    final recentErrors = ref.watch(recentErrorsProvider);
    final filteredErrors = _filterErrors(recentErrors);

    return Column(
      children: [
        // Search and filter bar
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.grey[50],
          child: Column(
            children: [
              // Search field
              TextField(
                decoration: const InputDecoration(
                  hintText: 'Search errors...',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value.toLowerCase();
                  });
                },
              ),
              const SizedBox(height: 8),
              // Filter chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    // Category filter
                    FilterChip(
                      label: Text(_filterCategory?.toString().split('.').last ?? 'All Categories'),
                      selected: _filterCategory != null,
                      onSelected: (selected) {
                        _showCategoryFilter();
                      },
                    ),
                    const SizedBox(width: 8),
                    // Severity filter
                    FilterChip(
                      label: Text(_filterSeverity?.toString().split('.').last ?? 'All Severities'),
                      selected: _filterSeverity != null,
                      onSelected: (selected) {
                        _showSeverityFilter();
                      },
                    ),
                    const SizedBox(width: 8),
                    // Clear filters
                    if (_filterCategory != null || _filterSeverity != null)
                      ActionChip(
                        label: const Text('Clear Filters'),
                        onPressed: () {
                          setState(() {
                            _filterCategory = null;
                            _filterSeverity = null;
                          });
                        },
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        
        // Error list
        Expanded(
          child: filteredErrors.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  itemCount: filteredErrors.length,
                  itemBuilder: (context, index) {
                    final error = filteredErrors[index];
                    return _buildErrorListItem(error);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildStatisticsTab() {
    final errorStats = ref.watch(errorStatisticsProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Overview cards
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Total Errors',
                  errorStats['total_errors']?.toString() ?? '0',
                  Icons.error_outline,
                  AppTheme.errorRed,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatCard(
                  'Error Rate',
                  '${(errorStats['recent_error_rate'] ?? 0.0).toStringAsFixed(1)}/min',
                  Icons.trending_up,
                  AppTheme.warningOrange,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Category breakdown
          Text(
            'Errors by Category',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          _buildCategoryChart(errorStats['by_category'] ?? {}),
          
          const SizedBox(height: 24),
          
          // Severity breakdown
          Text(
            'Errors by Severity',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          _buildSeverityChart(errorStats['by_severity'] ?? {}),
        ],
      ),
    );
  }

  Widget _buildFeedbackTab() {
    final feedbackHistory = ref.watch(feedbackHistoryProvider);

    return feedbackHistory.isEmpty
        ? _buildEmptyFeedbackState()
        : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: feedbackHistory.length,
            itemBuilder: (context, index) {
              final feedback = feedbackHistory[index];
              return _buildFeedbackListItem(feedback);
            },
          );
  }

  Widget _buildErrorListItem(AppError error) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ExpansionTile(
        leading: Icon(
          _getErrorIcon(error.category),
          color: _getErrorColor(error.severity),
        ),
        title: Text(
          error.userMessage,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${error.category.toString().split('.').last} • ${error.severity.toString().split('.').last}',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
            ),
            Text(
              error.timestamp.toString(),
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 11,
              ),
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Technical details
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Technical Details:',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        error.technicalMessage,
                        style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                      ),
                      if (error.errorCode != null) ...[
                        const SizedBox(height: 8),
                        Text('Error Code: ${error.errorCode}'),
                      ],
                    ],
                  ),
                ),
                
                // Recovery actions
                if (error.recoveryActions != null && error.recoveryActions!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Suggested Actions:',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  ...error.recoveryActions!.map((action) => Padding(
                    padding: const EdgeInsets.only(left: 16, bottom: 2),
                    child: Text('• $action'),
                  )),
                ],
                
                // Action buttons
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: () => _reportError(error),
                      icon: const Icon(Icons.bug_report),
                      label: const Text('Report'),
                    ),
                    if (error.isRetryable)
                      TextButton.icon(
                        onPressed: () => _retryError(error),
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 24),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryChart(Map<String, dynamic> categoryData) {
    if (categoryData.isEmpty) {
      return const Text('No error data available');
    }

    return Column(
      children: categoryData.entries.map((entry) {
        final category = entry.key;
        final count = entry.value as int;
        final total = categoryData.values.fold<int>(0, (sum, value) => sum + (value as int));
        final percentage = total > 0 ? (count / total * 100) : 0.0;

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              SizedBox(
                width: 100,
                child: Text(category, style: const TextStyle(fontSize: 12)),
              ),
              Expanded(
                child: LinearProgressIndicator(
                  value: percentage / 100,
                  backgroundColor: Colors.grey[300],
                  valueColor: AlwaysStoppedAnimation<Color>(
                    _getCategoryColor(category),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$count (${percentage.toStringAsFixed(1)}%)',
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSeverityChart(Map<String, dynamic> severityData) {
    if (severityData.isEmpty) {
      return const Text('No error data available');
    }

    return Column(
      children: severityData.entries.map((entry) {
        final severity = entry.key;
        final count = entry.value as int;
        final total = severityData.values.fold<int>(0, (sum, value) => sum + (value as int));
        final percentage = total > 0 ? (count / total * 100) : 0.0;

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              SizedBox(
                width: 100,
                child: Text(severity, style: const TextStyle(fontSize: 12)),
              ),
              Expanded(
                child: LinearProgressIndicator(
                  value: percentage / 100,
                  backgroundColor: Colors.grey[300],
                  valueColor: AlwaysStoppedAnimation<Color>(
                    _getSeverityColor(severity),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$count (${percentage.toStringAsFixed(1)}%)',
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildFeedbackListItem(FeedbackReport feedback) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(
          _getFeedbackIcon(feedback.category),
          color: _getFeedbackSeverityColor(feedback.severity),
        ),
        title: Text(feedback.title),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${_getFeedbackCategoryName(feedback.category)} • ${_getFeedbackSeverityName(feedback.severity)}',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
            Text(
              feedback.timestamp.toString(),
              style: TextStyle(color: Colors.grey[500], fontSize: 11),
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (action) => _handleFeedbackAction(action, feedback),
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'view',
              child: Text('View Details'),
            ),
            const PopupMenuItem(
              value: 'share',
              child: Text('Share Report'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 64,
            color: AppTheme.successGreen,
          ),
          const SizedBox(height: 16),
          Text(
            'No Errors Found',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: AppTheme.successGreen,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your VPN client is running smoothly!',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyFeedbackState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.feedback_outlined,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No Feedback Reports',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Submit feedback to help us improve the app',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey[500],
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _showFeedbackDialog,
            icon: const Icon(Icons.add),
            label: const Text('Submit Feedback'),
          ),
        ],
      ),
    );
  }

  List<AppError> _filterErrors(List<AppError> errors) {
    return errors.where((error) {
      // Search filter
      if (_searchQuery.isNotEmpty) {
        final searchMatch = error.userMessage.toLowerCase().contains(_searchQuery) ||
            error.technicalMessage.toLowerCase().contains(_searchQuery) ||
            (error.errorCode?.toLowerCase().contains(_searchQuery) ?? false);
        if (!searchMatch) return false;
      }

      // Category filter
      if (_filterCategory != null && error.category != _filterCategory) {
        return false;
      }

      // Severity filter
      if (_filterSeverity != null && error.severity != _filterSeverity) {
        return false;
      }

      return true;
    }).toList();
  }

  void _showCategoryFilter() {
    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Filter by Category'),
        children: [
          SimpleDialogOption(
            onPressed: () {
              setState(() => _filterCategory = null);
              Navigator.pop(context);
            },
            child: const Text('All Categories'),
          ),
          ...ErrorCategory.values.map((category) => SimpleDialogOption(
            onPressed: () {
              setState(() => _filterCategory = category);
              Navigator.pop(context);
            },
            child: Text(category.toString().split('.').last),
          )),
        ],
      ),
    );
  }

  void _showSeverityFilter() {
    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Filter by Severity'),
        children: [
          SimpleDialogOption(
            onPressed: () {
              setState(() => _filterSeverity = null);
              Navigator.pop(context);
            },
            child: const Text('All Severities'),
          ),
          ...ErrorSeverity.values.map((severity) => SimpleDialogOption(
            onPressed: () {
              setState(() => _filterSeverity = severity);
              Navigator.pop(context);
            },
            child: Text(severity.toString().split('.').last),
          )),
        ],
      ),
    );
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'clear_errors':
        _clearErrorHistory();
        break;
      case 'export_logs':
        _exportDiagnostics();
        break;
      case 'report_issue':
        _showFeedbackDialog();
        break;
    }
  }

  void _clearErrorHistory() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Error History'),
        content: const Text('Are you sure you want to clear all error history? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              ref.read(errorHandlerServiceProvider).clearRecentErrors();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Error history cleared')),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorRed),
            child: const Text('Clear', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _exportDiagnostics() async {
    try {
      final errorHandling = ref.read(errorHandlingProvider.notifier);
      final filePath = await errorHandling.exportDiagnosticInfo();
      
      if (filePath != null) {
        await Share.shareXFiles(
          [XFile(filePath)],
          subject: 'VPN Client Diagnostic Information',
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to export diagnostics: $e')),
      );
    }
  }

  void _showFeedbackDialog() {
    showDialog(
      context: context,
      builder: (context) => const FeedbackDialog(),
    );
  }

  void _reportError(AppError error) {
    showDialog(
      context: context,
      builder: (context) => FeedbackDialog(relatedError: error),
    );
  }

  void _retryError(AppError error) {
    // Implement retry logic based on error type
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Retry functionality not implemented yet')),
    );
  }

  void _handleFeedbackAction(String action, FeedbackReport feedback) {
    switch (action) {
      case 'view':
        _viewFeedbackDetails(feedback);
        break;
      case 'share':
        _shareFeedbackReport(feedback);
        break;
    }
  }

  void _viewFeedbackDetails(FeedbackReport feedback) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(feedback.title),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Category: ${_getFeedbackCategoryName(feedback.category)}'),
              Text('Severity: ${_getFeedbackSeverityName(feedback.severity)}'),
              Text('Date: ${feedback.timestamp}'),
              const SizedBox(height: 16),
              const Text('Description:', style: TextStyle(fontWeight: FontWeight.bold)),
              Text(feedback.description),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _shareFeedbackReport(FeedbackReport feedback) async {
    try {
      final userFeedbackService = ref.read(userFeedbackServiceProvider);
      await userFeedbackService.shareFeedbackReport(feedback.id);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to share feedback: $e')),
      );
    }
  }

  // Helper methods for icons and colors
  IconData _getErrorIcon(ErrorCategory category) {
    switch (category) {
      case ErrorCategory.network:
        return Icons.wifi_off;
      case ErrorCategory.configuration:
        return Icons.settings;
      case ErrorCategory.permission:
        return Icons.security;
      case ErrorCategory.platform:
        return Icons.computer;
      case ErrorCategory.authentication:
        return Icons.lock;
      case ErrorCategory.system:
        return Icons.error;
      case ErrorCategory.unknown:
        return Icons.help;
    }
  }

  Color _getErrorColor(ErrorSeverity severity) {
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

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'network':
        return Colors.blue;
      case 'configuration':
        return Colors.orange;
      case 'permission':
        return Colors.red;
      case 'platform':
        return Colors.purple;
      case 'authentication':
        return Colors.green;
      case 'system':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  Color _getSeverityColor(String severity) {
    switch (severity.toLowerCase()) {
      case 'critical':
        return Colors.red[800]!;
      case 'high':
        return AppTheme.errorRed;
      case 'medium':
        return AppTheme.warningOrange;
      case 'low':
        return Colors.blue[600]!;
      default:
        return Colors.grey;
    }
  }

  IconData _getFeedbackIcon(FeedbackCategory category) {
    switch (category) {
      case FeedbackCategory.connectionIssue:
        return Icons.wifi_off;
      case FeedbackCategory.performanceIssue:
        return Icons.speed;
      case FeedbackCategory.configurationProblem:
        return Icons.settings;
      case FeedbackCategory.uiProblem:
        return Icons.design_services;
      case FeedbackCategory.featureRequest:
        return Icons.lightbulb;
      case FeedbackCategory.bug:
        return Icons.bug_report;
      case FeedbackCategory.other:
        return Icons.help;
    }
  }

  Color _getFeedbackSeverityColor(FeedbackSeverity severity) {
    switch (severity) {
      case FeedbackSeverity.critical:
        return Colors.red[800]!;
      case FeedbackSeverity.high:
        return AppTheme.errorRed;
      case FeedbackSeverity.medium:
        return AppTheme.warningOrange;
      case FeedbackSeverity.low:
        return Colors.blue[600]!;
    }
  }

  String _getFeedbackCategoryName(FeedbackCategory category) {
    switch (category) {
      case FeedbackCategory.connectionIssue:
        return 'Connection Issue';
      case FeedbackCategory.performanceIssue:
        return 'Performance Issue';
      case FeedbackCategory.configurationProblem:
        return 'Configuration Problem';
      case FeedbackCategory.uiProblem:
        return 'UI Problem';
      case FeedbackCategory.featureRequest:
        return 'Feature Request';
      case FeedbackCategory.bug:
        return 'Bug Report';
      case FeedbackCategory.other:
        return 'Other';
    }
  }

  String _getFeedbackSeverityName(FeedbackSeverity severity) {
    switch (severity) {
      case FeedbackSeverity.critical:
        return 'Critical';
      case FeedbackSeverity.high:
        return 'High';
      case FeedbackSeverity.medium:
        return 'Medium';
      case FeedbackSeverity.low:
        return 'Low';
    }
  }
}