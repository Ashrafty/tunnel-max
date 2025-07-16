import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/connection_history.dart';
import '../../models/network_stats.dart';
import '../../providers/statistics_provider.dart';
import '../theme/app_theme.dart';

/// Data usage monitoring widget with alerts and limits
/// 
/// This widget provides:
/// - Current session data usage
/// - Daily/monthly usage tracking
/// - Usage alerts and warnings
/// - Data limit monitoring
class DataUsageMonitorWidget extends ConsumerStatefulWidget {
  final int? dailyLimitMB;
  final int? monthlyLimitMB;
  final bool showAlerts;

  const DataUsageMonitorWidget({
    super.key,
    this.dailyLimitMB,
    this.monthlyLimitMB,
    this.showAlerts = true,
  });

  @override
  ConsumerState<DataUsageMonitorWidget> createState() => _DataUsageMonitorWidgetState();
}

class _DataUsageMonitorWidgetState extends ConsumerState<DataUsageMonitorWidget> {
  @override
  Widget build(BuildContext context) {
    final currentStatsAsync = ref.watch(currentNetworkStatsProvider);
    final dailyUsageSummaryAsync = ref.watch(usageSummaryProvider('Last 7 days'));
    final monthlyUsageSummaryAsync = ref.watch(usageSummaryProvider('Last 30 days'));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.data_usage,
                  color: AppTheme.primaryBlue,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  'Data Usage Monitor',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Current session usage
            currentStatsAsync.when(
              data: (stats) => _buildCurrentSessionUsage(stats),
              loading: () => const SizedBox.shrink(),
              error: (error, stack) => const SizedBox.shrink(),
            ),
            
            const SizedBox(height: 12),
            
            // Daily usage
            dailyUsageSummaryAsync.when(
              data: (summary) => _buildDailyUsage(summary),
              loading: () => _buildUsageLoadingState('Daily Usage'),
              error: (error, stack) => _buildUsageErrorState('Daily Usage'),
            ),
            
            const SizedBox(height: 12),
            
            // Monthly usage
            monthlyUsageSummaryAsync.when(
              data: (summary) => _buildMonthlyUsage(summary),
              loading: () => _buildUsageLoadingState('Monthly Usage'),
              error: (error, stack) => _buildUsageErrorState('Monthly Usage'),
            ),
            
            if (widget.showAlerts) ...[
              const SizedBox(height: 12),
              _buildUsageAlerts(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentSessionUsage(NetworkStats? stats) {
    if (stats == null) {
      return _buildUsageItem(
        'Current Session',
        '0 B',
        0.0,
        Colors.grey,
        subtitle: 'No active connection',
      );
    }

    return _buildUsageItem(
      'Current Session',
      stats.formattedTotalBytes,
      0.0, // No limit for current session
      AppTheme.primaryBlue,
      subtitle: 'Since connection started',
    );
  }

  Widget _buildDailyUsage(DataUsageSummary summary) {
    final totalMB = summary.totalDataTransferred / (1024 * 1024);
    final limitMB = widget.dailyLimitMB?.toDouble();
    final percentage = limitMB != null ? (totalMB / limitMB).clamp(0.0, 1.0) : 0.0;
    
    Color color = AppTheme.accentGreen;
    if (limitMB != null) {
      if (percentage > 0.9) {
        color = Colors.red;
      } else if (percentage > 0.7) {
        color = Colors.orange;
      }
    }

    return _buildUsageItem(
      'Today',
      summary.formattedTotalData,
      percentage,
      color,
      subtitle: limitMB != null 
          ? 'Limit: ${NetworkStats.formatBytes((limitMB * 1024 * 1024).toInt())}'
          : 'No limit set',
    );
  }

  Widget _buildMonthlyUsage(DataUsageSummary summary) {
    final totalMB = summary.totalDataTransferred / (1024 * 1024);
    final limitMB = widget.monthlyLimitMB?.toDouble();
    final percentage = limitMB != null ? (totalMB / limitMB).clamp(0.0, 1.0) : 0.0;
    
    Color color = AppTheme.accentGreen;
    if (limitMB != null) {
      if (percentage > 0.9) {
        color = Colors.red;
      } else if (percentage > 0.7) {
        color = Colors.orange;
      }
    }

    return _buildUsageItem(
      'This Month',
      summary.formattedTotalData,
      percentage,
      color,
      subtitle: limitMB != null 
          ? 'Limit: ${NetworkStats.formatBytes((limitMB * 1024 * 1024).toInt())}'
          : 'No limit set',
    );
  }

  Widget _buildUsageItem(
    String title,
    String usage,
    double percentage,
    Color color, {
    String? subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                usage,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
              ),
            ),
          ],
          
          if (percentage > 0) ...[
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: percentage,
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
            const SizedBox(height: 4),
            Text(
              '${(percentage * 100).toStringAsFixed(1)}% of limit',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildUsageLoadingState(String title) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator.adaptive(strokeWidth: 2),
          ),
        ],
      ),
    );
  }

  Widget _buildUsageErrorState(String title) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red[200]!),
      ),
      child: Row(
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          Icon(
            Icons.error_outline,
            color: Colors.red[400],
            size: 16,
          ),
        ],
      ),
    );
  }

  Widget _buildUsageAlerts() {
    final dailyUsageSummaryAsync = ref.watch(usageSummaryProvider('Last 7 days'));
    final monthlyUsageSummaryAsync = ref.watch(usageSummaryProvider('Last 30 days'));

    final alerts = <Widget>[];

    // Check daily limit alerts
    dailyUsageSummaryAsync.whenData((summary) {
      if (widget.dailyLimitMB != null) {
        final totalMB = summary.totalDataTransferred / (1024 * 1024);
        final percentage = totalMB / widget.dailyLimitMB!;
        
        if (percentage > 0.9) {
          alerts.add(_buildAlert(
            'Daily limit almost reached',
            'You have used ${(percentage * 100).toStringAsFixed(1)}% of your daily data limit.',
            Colors.red,
            Icons.warning,
          ));
        } else if (percentage > 0.7) {
          alerts.add(_buildAlert(
            'Daily usage warning',
            'You have used ${(percentage * 100).toStringAsFixed(1)}% of your daily data limit.',
            Colors.orange,
            Icons.info,
          ));
        }
      }
    });

    // Check monthly limit alerts
    monthlyUsageSummaryAsync.whenData((summary) {
      if (widget.monthlyLimitMB != null) {
        final totalMB = summary.totalDataTransferred / (1024 * 1024);
        final percentage = totalMB / widget.monthlyLimitMB!;
        
        if (percentage > 0.9) {
          alerts.add(_buildAlert(
            'Monthly limit almost reached',
            'You have used ${(percentage * 100).toStringAsFixed(1)}% of your monthly data limit.',
            Colors.red,
            Icons.warning,
          ));
        } else if (percentage > 0.7) {
          alerts.add(_buildAlert(
            'Monthly usage warning',
            'You have used ${(percentage * 100).toStringAsFixed(1)}% of your monthly data limit.',
            Colors.orange,
            Icons.info,
          ));
        }
      }
    });

    if (alerts.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Alerts',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        ...alerts,
      ],
    );
  }

  Widget _buildAlert(String title, String message, Color color, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  message,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}