import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../models/network_stats.dart';
import '../../providers/statistics_provider.dart';
import '../theme/app_theme.dart';

/// Real-time statistics widget showing live network performance metrics
/// 
/// This widget displays:
/// - Current download/upload speeds with live charts
/// - Data usage counters
/// - Connection duration
/// - Performance indicators
class RealTimeStatsWidget extends ConsumerStatefulWidget {
  final bool showCharts;
  final bool compact;

  const RealTimeStatsWidget({
    super.key,
    this.showCharts = true,
    this.compact = false,
  });

  @override
  ConsumerState<RealTimeStatsWidget> createState() => _RealTimeStatsWidgetState();
}

class _RealTimeStatsWidgetState extends ConsumerState<RealTimeStatsWidget> {
  final List<FlSpot> _downloadSpeedHistory = [];
  final List<FlSpot> _uploadSpeedHistory = [];
  int _dataPointIndex = 0;
  static const int _maxDataPoints = 30;

  @override
  Widget build(BuildContext context) {
    final currentStatsAsync = ref.watch(currentNetworkStatsProvider);

    return currentStatsAsync.when(
      data: (stats) => _buildStatsContent(stats),
      loading: () => _buildLoadingState(),
      error: (error, stack) => _buildErrorState(error.toString()),
    );
  }

  Widget _buildStatsContent(NetworkStats? stats) {
    if (stats == null) {
      return _buildNoConnectionState();
    }

    // Update speed history for charts
    _updateSpeedHistory(stats);

    if (widget.compact) {
      return _buildCompactStats(stats);
    } else {
      return _buildFullStats(stats);
    }
  }

  Widget _buildCompactStats(NetworkStats stats) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Icon(
                  Icons.speed,
                  color: AppTheme.primaryBlue,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Live Stats',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Text(
                  _formatDuration(stats.connectionDuration),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildSpeedIndicator(
                    'Down',
                    stats.formattedDownloadSpeed,
                    AppTheme.primaryBlue,
                    Icons.download,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildSpeedIndicator(
                    'Up',
                    stats.formattedUploadSpeed,
                    AppTheme.accentGreen,
                    Icons.upload,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFullStats(NetworkStats stats) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.analytics,
                  color: AppTheme.primaryBlue,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  'Real-time Statistics',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Text(
                  _formatDuration(stats.connectionDuration),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Current speeds
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Download Speed',
                    stats.formattedDownloadSpeed,
                    AppTheme.primaryBlue,
                    Icons.download,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    'Upload Speed',
                    stats.formattedUploadSpeed,
                    AppTheme.accentGreen,
                    Icons.upload,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Data usage
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Downloaded',
                    stats.formattedBytesReceived,
                    AppTheme.primaryBlue,
                    Icons.cloud_download,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    'Uploaded',
                    stats.formattedBytesSent,
                    AppTheme.accentGreen,
                    Icons.cloud_upload,
                  ),
                ),
              ],
            ),
            
            if (widget.showCharts) ...[
              const SizedBox(height: 16),
              _buildSpeedChart(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSpeedChart() {
    if (_downloadSpeedHistory.isEmpty && _uploadSpeedHistory.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Speed History',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 120,
          child: LineChart(
            LineChartData(
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: null,
                getDrawingHorizontalLine: (value) {
                  return FlLine(
                    color: Colors.grey[300]!,
                    strokeWidth: 0.5,
                  );
                },
              ),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 40,
                    getTitlesWidget: (value, meta) {
                      return Text(
                        NetworkStats.formatSpeed(value),
                        style: const TextStyle(fontSize: 10),
                      );
                    },
                  ),
                ),
                bottomTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
              ),
              borderData: FlBorderData(show: false),
              lineBarsData: [
                if (_downloadSpeedHistory.isNotEmpty)
                  LineChartBarData(
                    spots: _downloadSpeedHistory,
                    isCurved: true,
                    color: AppTheme.primaryBlue,
                    barWidth: 2,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: AppTheme.primaryBlue.withOpacity(0.1),
                    ),
                  ),
                if (_uploadSpeedHistory.isNotEmpty)
                  LineChartBarData(
                    spots: _uploadSpeedHistory,
                    isCurved: true,
                    color: AppTheme.accentGreen,
                    barWidth: 2,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: AppTheme.accentGreen.withOpacity(0.1),
                    ),
                  ),
              ],
              minY: 0,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildLegendItem('Download', AppTheme.primaryBlue),
            const SizedBox(width: 16),
            _buildLegendItem('Upload', AppTheme.accentGreen),
          ],
        ),
      ],
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 2,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(1),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
              fontSize: 14,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpeedIndicator(String label, String value, Color color, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 4),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: color,
                fontSize: 12,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLoadingState() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const CircularProgressIndicator.adaptive(),
            const SizedBox(height: 8),
            Text(
              'Loading statistics...',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(
              Icons.error_outline,
              color: Colors.red[400],
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              'Statistics Error',
              style: TextStyle(
                color: Colors.red[700],
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              error,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoConnectionState() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(
              Icons.wifi_off,
              color: Colors.grey[400],
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              'No Active Connection',
              style: TextStyle(
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Connect to VPN to see statistics',
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _updateSpeedHistory(NetworkStats stats) {
    final downloadSpeed = stats.downloadSpeed;
    final uploadSpeed = stats.uploadSpeed;

    // Add new data points
    _downloadSpeedHistory.add(FlSpot(_dataPointIndex.toDouble(), downloadSpeed));
    _uploadSpeedHistory.add(FlSpot(_dataPointIndex.toDouble(), uploadSpeed));

    // Remove old data points to maintain max limit
    if (_downloadSpeedHistory.length > _maxDataPoints) {
      _downloadSpeedHistory.removeAt(0);
    }
    if (_uploadSpeedHistory.length > _maxDataPoints) {
      _uploadSpeedHistory.removeAt(0);
    }

    // Update x-axis values to maintain smooth scrolling
    if (_downloadSpeedHistory.length == _maxDataPoints) {
      for (int i = 0; i < _downloadSpeedHistory.length; i++) {
        _downloadSpeedHistory[i] = FlSpot(i.toDouble(), _downloadSpeedHistory[i].y);
        _uploadSpeedHistory[i] = FlSpot(i.toDouble(), _uploadSpeedHistory[i].y);
      }
    }

    _dataPointIndex++;
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    } else {
      return '${seconds}s';
    }
  }
}