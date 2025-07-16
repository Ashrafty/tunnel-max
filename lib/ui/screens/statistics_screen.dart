import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

import '../../models/connection_history.dart';
import '../../models/network_stats.dart';
import '../../providers/statistics_provider.dart';
import '../../services/connection_history_service.dart';
import '../theme/app_theme.dart';
import '../widgets/loading_widget.dart';
import '../widgets/error_widget.dart';

/// Statistics screen displaying VPN usage analytics and performance metrics
/// 
/// This screen provides:
/// - Real-time network statistics with charts
/// - Connection history and session details
/// - Data usage monitoring and reporting
/// - Performance metrics and analytics
class StatisticsScreen extends ConsumerStatefulWidget {
  const StatisticsScreen({super.key});

  @override
  ConsumerState<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends ConsumerState<StatisticsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedPeriod = 'Last 30 days';
  
  final List<String> _periods = [
    'Last 7 days',
    'Last 30 days',
    'Last 90 days',
    'All time',
  ];

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
        title: const Text('Statistics'),
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.date_range),
            onSelected: (period) {
              setState(() {
                _selectedPeriod = period;
              });
            },
            itemBuilder: (context) => _periods
                .map((period) => PopupMenuItem(
                      value: period,
                      child: Text(period),
                    ))
                .toList(),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.refresh(usageSummaryProvider(_selectedPeriod));
              ref.refresh(dailyUsageProvider);
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Overview', icon: Icon(Icons.dashboard)),
            Tab(text: 'Usage', icon: Icon(Icons.data_usage)),
            Tab(text: 'History', icon: Icon(Icons.history)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOverviewTab(),
          _buildUsageTab(),
          _buildHistoryTab(),
        ],
      ),
    );
  }

  Widget _buildOverviewTab() {
    final currentStatsAsync = ref.watch(currentNetworkStatsProvider);
    final usageSummaryAsync = ref.watch(usageSummaryProvider(_selectedPeriod));

    return RefreshIndicator(
      onRefresh: () async {
        ref.refresh(currentNetworkStatsProvider);
        ref.refresh(usageSummaryProvider(_selectedPeriod));
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Current Session Stats
            _buildSectionHeader('Current Session'),
            const SizedBox(height: 12),
            currentStatsAsync.when(
              data: (stats) => _buildCurrentSessionCard(stats),
              loading: () => const LoadingWidget(),
              error: (error, stack) => ErrorDisplayWidget(
                error: error.toString(),
                onRetry: () => ref.refresh(currentNetworkStatsProvider),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Usage Summary
            _buildSectionHeader('Usage Summary - $_selectedPeriod'),
            const SizedBox(height: 12),
            usageSummaryAsync.when(
              data: (summary) => _buildUsageSummaryCard(summary),
              loading: () => const LoadingWidget(),
              error: (error, stack) => ErrorDisplayWidget(
                error: error.toString(),
                onRetry: () => ref.refresh(usageSummaryProvider(_selectedPeriod)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUsageTab() {
    final dailyUsageAsync = ref.watch(dailyUsageProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.refresh(dailyUsageProvider);
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader('Daily Data Usage'),
            const SizedBox(height: 12),
            dailyUsageAsync.when(
              data: (dailyUsage) => _buildDataUsageChart(dailyUsage),
              loading: () => const LoadingWidget(),
              error: (error, stack) => ErrorDisplayWidget(
                error: error.toString(),
                onRetry: () => ref.refresh(dailyUsageProvider),
              ),
            ),
            
            const SizedBox(height: 24),
            
            _buildSectionHeader('Connection Time'),
            const SizedBox(height: 12),
            dailyUsageAsync.when(
              data: (dailyUsage) => _buildConnectionTimeChart(dailyUsage),
              loading: () => const LoadingWidget(),
              error: (error, stack) => ErrorDisplayWidget(
                error: error.toString(),
                onRetry: () => ref.refresh(dailyUsageProvider),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryTab() {
    final historyAsync = ref.watch(connectionHistoryProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.refresh(connectionHistoryProvider);
      },
      child: historyAsync.when(
        data: (history) => _buildHistoryList(history),
        loading: () => const LoadingWidget(),
        error: (error, stack) => ErrorDisplayWidget(
          error: error.toString(),
          onRetry: () => ref.refresh(connectionHistoryProvider),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.bold,
        color: AppTheme.primaryBlue,
      ),
    );
  }

  Widget _buildCurrentSessionCard(NetworkStats? stats) {
    if (stats == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(
                Icons.wifi_off,
                size: 48,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 8),
              Text(
                'No Active Connection',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Icon(
                  Icons.wifi,
                  color: AppTheme.accentGreen,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  'Connected',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppTheme.accentGreen,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Text(
                  _formatDuration(stats.connectionDuration),
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    icon: Icons.download,
                    label: 'Downloaded',
                    value: stats.formattedBytesReceived,
                    color: AppTheme.primaryBlue,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatItem(
                    icon: Icons.upload,
                    label: 'Uploaded',
                    value: stats.formattedBytesSent,
                    color: AppTheme.accentGreen,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    icon: Icons.speed,
                    label: 'Download Speed',
                    value: stats.formattedDownloadSpeed,
                    color: AppTheme.primaryBlue,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatItem(
                    icon: Icons.speed,
                    label: 'Upload Speed',
                    value: stats.formattedUploadSpeed,
                    color: AppTheme.accentGreen,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUsageSummaryCard(DataUsageSummary summary) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _buildSummaryItem(
                    'Total Data',
                    summary.formattedTotalData,
                    Icons.data_usage,
                    AppTheme.primaryBlue,
                  ),
                ),
                Expanded(
                  child: _buildSummaryItem(
                    'Connections',
                    '${summary.totalConnections}',
                    Icons.link,
                    AppTheme.accentGreen,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            Row(
              children: [
                Expanded(
                  child: _buildSummaryItem(
                    'Success Rate',
                    '${summary.successRate.toStringAsFixed(1)}%',
                    Icons.check_circle,
                    summary.successRate > 90 ? AppTheme.accentGreen : Colors.orange,
                  ),
                ),
                Expanded(
                  child: _buildSummaryItem(
                    'Total Time',
                    _formatDuration(summary.totalConnectionTime),
                    Icons.timer,
                    AppTheme.primaryBlue,
                  ),
                ),
              ],
            ),
            
            if (summary.mostUsedServer != null) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(Icons.star, color: Colors.amber, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Most Used Server: ${summary.mostUsedServer}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDataUsageChart(List<DailyUsage> dailyUsage) {
    if (dailyUsage.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Center(
            child: Text('No usage data available'),
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(show: true),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            NetworkStats.formatBytes(value.toInt()),
                            style: const TextStyle(fontSize: 10),
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index >= 0 && index < dailyUsage.length) {
                            return Text(
                              DateFormat('M/d').format(dailyUsage[index].date),
                              style: const TextStyle(fontSize: 10),
                            );
                          }
                          return const Text('');
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: true),
                  lineBarsData: [
                    LineChartBarData(
                      spots: dailyUsage.asMap().entries.map((entry) {
                        return FlSpot(entry.key.toDouble(), entry.value.totalBytes.toDouble());
                      }).toList(),
                      isCurved: true,
                      color: AppTheme.primaryBlue,
                      barWidth: 3,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: AppTheme.primaryBlue.withOpacity(0.1),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryBlue,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                const Text('Daily Data Usage'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionTimeChart(List<DailyUsage> dailyUsage) {
    if (dailyUsage.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Center(
            child: Text('No connection time data available'),
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  gridData: FlGridData(show: true),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final hours = value / 3600;
                          return Text(
                            '${hours.toStringAsFixed(0)}h',
                            style: const TextStyle(fontSize: 10),
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index >= 0 && index < dailyUsage.length) {
                            return Text(
                              DateFormat('M/d').format(dailyUsage[index].date),
                              style: const TextStyle(fontSize: 10),
                            );
                          }
                          return const Text('');
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: true),
                  barGroups: dailyUsage.asMap().entries.map((entry) {
                    return BarChartGroupData(
                      x: entry.key,
                      barRods: [
                        BarChartRodData(
                          toY: entry.value.connectionTime.inSeconds.toDouble(),
                          color: AppTheme.accentGreen,
                          width: 16,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: AppTheme.accentGreen,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                const Text('Daily Connection Time'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryList(List<ConnectionHistoryEntry> history) {
    if (history.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No connection history available',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: history.length,
      itemBuilder: (context, index) {
        final entry = history[index];
        return _buildHistoryItem(entry);
      },
    );
  }

  Widget _buildHistoryItem(ConnectionHistoryEntry entry) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: entry.wasSuccessful 
              ? AppTheme.accentGreen 
              : Colors.red,
          child: Icon(
            entry.wasSuccessful ? Icons.check : Icons.close,
            color: Colors.white,
            size: 20,
          ),
        ),
        title: Text(
          entry.serverName,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(DateFormat('MMM d, y - HH:mm').format(entry.startTime)),
            Text(
              'Duration: ${_formatDuration(entry.duration)}',
              style: TextStyle(color: Colors.grey[600]),
            ),
            if (entry.finalStats != null)
              Text(
                'Data: ${entry.finalStats!.formattedTotalBytes}',
                style: TextStyle(color: Colors.grey[600]),
              ),
          ],
        ),
        trailing: entry.isActive
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.accentGreen,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Active',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
            : null,
        onTap: () => _showHistoryDetails(entry),
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 32),
        const SizedBox(height: 8),
        Text(
          value,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  void _showHistoryDetails(ConnectionHistoryEntry entry) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(entry.serverName),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('Status', entry.wasSuccessful ? 'Successful' : 'Failed'),
            _buildDetailRow('Start Time', DateFormat('MMM d, y - HH:mm:ss').format(entry.startTime)),
            if (entry.endTime != null)
              _buildDetailRow('End Time', DateFormat('MMM d, y - HH:mm:ss').format(entry.endTime!)),
            _buildDetailRow('Duration', _formatDuration(entry.duration)),
            if (entry.serverLocation != null)
              _buildDetailRow('Location', entry.serverLocation!),
            if (entry.finalStats != null) ...[
              const Divider(),
              _buildDetailRow('Downloaded', entry.finalStats!.formattedBytesReceived),
              _buildDetailRow('Uploaded', entry.finalStats!.formattedBytesSent),
              _buildDetailRow('Total Data', entry.finalStats!.formattedTotalBytes),
            ],
            if (entry.disconnectionReason != null)
              _buildDetailRow('Disconnection Reason', entry.disconnectionReason!),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours}h ${minutes}m ${seconds}s';
    } else if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    } else {
      return '${seconds}s';
    }
  }
}