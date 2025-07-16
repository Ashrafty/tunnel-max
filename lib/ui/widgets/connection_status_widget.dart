import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/vpn_status.dart';
import '../../models/network_stats.dart';
import '../../models/vpn_configuration.dart';
import '../../providers/vpn_provider.dart';
import '../../providers/configuration_provider.dart';
import '../theme/app_theme.dart';

class ConnectionStatusWidget extends ConsumerWidget {
  const ConnectionStatusWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vpnStatusAsync = ref.watch(vpnStatusProvider);
    final networkStatsAsync = ref.watch(networkStatsProvider);
    final connectionState = ref.watch(vpnConnectionProvider);
    final selectedConfig = ref.watch(selectedConfigurationProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            // Connection status indicator
            _buildStatusIndicator(context, vpnStatusAsync, connectionState),
            const SizedBox(height: 16),
            
            // Status text and server info
            _buildStatusText(context, vpnStatusAsync, selectedConfig),
            const SizedBox(height: 16),
            
            // Connection timer and statistics
            _buildConnectionInfo(context, vpnStatusAsync, networkStatsAsync),
            const SizedBox(height: 20),
            
            // Connect/Disconnect button
            _buildActionButton(context, ref, vpnStatusAsync, connectionState, selectedConfig),
            
            // Error message if any
            if (connectionState.error != null) ...[
              const SizedBox(height: 12),
              _buildErrorMessage(context, connectionState.error!),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIndicator(
    BuildContext context,
    AsyncValue<VpnStatus> vpnStatusAsync,
    VpnConnectionUIState connectionState,
  ) {
    return vpnStatusAsync.when(
      data: (status) => _StatusIndicator(
        status: status,
        isConnecting: connectionState.isConnecting,
        isDisconnecting: connectionState.isDisconnecting,
      ),
      loading: () => _StatusIndicator(
        status: VpnStatus.disconnected(),
        isConnecting: false,
        isDisconnecting: false,
      ),
      error: (_, __) => _StatusIndicator(
        status: VpnStatus.error(error: 'Status unavailable'),
        isConnecting: false,
        isDisconnecting: false,
      ),
    );
  }

  Widget _buildStatusText(
    BuildContext context,
    AsyncValue<VpnStatus> vpnStatusAsync,
    VpnConfiguration? selectedConfig,
  ) {
    return vpnStatusAsync.when(
      data: (status) {
        String statusText;
        String subtitleText;
        Color textColor;

        switch (status.state) {
          case VpnConnectionState.connected:
            statusText = 'Connected';
            subtitleText = status.connectedServer ?? 'Unknown Server';
            textColor = Theme.of(context).colorScheme.secondary;
            break;
          case VpnConnectionState.connecting:
            statusText = 'Connecting';
            subtitleText = 'Establishing connection...';
            textColor = AppTheme.warningOrange;
            break;
          case VpnConnectionState.disconnecting:
            statusText = 'Disconnecting';
            subtitleText = 'Closing connection...';
            textColor = AppTheme.warningOrange;
            break;
          case VpnConnectionState.reconnecting:
            statusText = 'Reconnecting';
            subtitleText = 'Attempting to reconnect...';
            textColor = AppTheme.warningOrange;
            break;
          case VpnConnectionState.error:
            statusText = 'Error';
            subtitleText = status.lastError ?? 'Connection failed';
            textColor = AppTheme.errorRed;
            break;
          case VpnConnectionState.disconnected:
            statusText = 'Disconnected';
            subtitleText = selectedConfig != null 
                ? 'Ready to connect to ${selectedConfig.name}'
                : 'No server selected';
            textColor = Colors.grey.shade700;
            break;
        }

        return Column(
          children: [
            Text(
              statusText,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitleText,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        );
      },
      loading: () => Column(
        children: [
          Text(
            'Loading...',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Getting connection status',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
      error: (_, __) => Column(
        children: [
          Text(
            'Error',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: AppTheme.errorRed,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Unable to get status',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionInfo(
    BuildContext context,
    AsyncValue<VpnStatus> vpnStatusAsync,
    AsyncValue<NetworkStats?> networkStatsAsync,
  ) {
    return vpnStatusAsync.when(
      data: (status) {
        if (!status.isConnected) {
          return const SizedBox.shrink();
        }

        return Column(
          children: [
            // Connection timer
            if (status.connectionStartTime != null)
              _ConnectionTimer(startTime: status.connectionStartTime!),
            
            const SizedBox(height: 12),
            
            // Network statistics
            networkStatsAsync.when(
              data: (stats) => stats != null 
                  ? _NetworkStatsDisplay(stats: stats)
                  : const SizedBox.shrink(),
              loading: () => const CircularProgressIndicator.adaptive(),
              error: (_, __) => const SizedBox.shrink(),
            ),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildActionButton(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<VpnStatus> vpnStatusAsync,
    VpnConnectionUIState connectionState,
    VpnConfiguration? selectedConfig,
  ) {
    return vpnStatusAsync.when(
      data: (status) {
        final isLoading = connectionState.isConnecting || connectionState.isDisconnecting;
        final canConnect = !status.hasActiveConnection && selectedConfig != null && !isLoading;
        final canDisconnect = status.hasActiveConnection && !isLoading;

        String buttonText;
        VoidCallback? onPressed;
        Color? backgroundColor;

        if (connectionState.isConnecting) {
          buttonText = 'Connecting...';
          backgroundColor = AppTheme.warningOrange;
        } else if (connectionState.isDisconnecting) {
          buttonText = 'Disconnecting...';
          backgroundColor = AppTheme.warningOrange;
        } else if (status.isConnected) {
          buttonText = 'Disconnect';
          backgroundColor = AppTheme.errorRed;
          onPressed = canDisconnect ? () => _disconnect(ref) : null;
        } else {
          buttonText = 'Connect';
          backgroundColor = Theme.of(context).colorScheme.secondary;
          onPressed = canConnect ? () => _connect(ref, selectedConfig) : null;
        }

        return SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: backgroundColor,
              disabledBackgroundColor: Colors.grey.shade300,
            ),
            child: isLoading
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(buttonText),
                    ],
                  )
                : Text(buttonText),
          ),
        );
      },
      loading: () => SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: null,
          child: const Text('Loading...'),
        ),
      ),
      error: (_, __) => SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: null,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.errorRed,
          ),
          child: const Text('Error'),
        ),
      ),
    );
  }

  Widget _buildErrorMessage(BuildContext context, String error) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.errorRed.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.errorRed.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            color: AppTheme.errorRed,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              error,
              style: TextStyle(
                color: AppTheme.errorRed,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _connect(WidgetRef ref, VpnConfiguration config) {
    ref.read(vpnConnectionProvider.notifier).connect(config);
  }

  void _disconnect(WidgetRef ref) {
    ref.read(vpnConnectionProvider.notifier).disconnect();
  }
}

class _StatusIndicator extends StatelessWidget {
  final VpnStatus status;
  final bool isConnecting;
  final bool isDisconnecting;

  const _StatusIndicator({
    required this.status,
    required this.isConnecting,
    required this.isDisconnecting,
  });

  @override
  Widget build(BuildContext context) {
    Color indicatorColor;
    Color borderColor;
    IconData iconData;
    bool showPulse = false;

    switch (status.state) {
      case VpnConnectionState.connected:
        indicatorColor = AppTheme.successGreen;
        borderColor = AppTheme.successGreen;
        iconData = Icons.vpn_lock;
        break;
      case VpnConnectionState.connecting:
      case VpnConnectionState.reconnecting:
        indicatorColor = AppTheme.warningOrange;
        borderColor = AppTheme.warningOrange;
        iconData = Icons.vpn_lock_outlined;
        showPulse = true;
        break;
      case VpnConnectionState.disconnecting:
        indicatorColor = AppTheme.warningOrange;
        borderColor = AppTheme.warningOrange;
        iconData = Icons.vpn_lock_outlined;
        showPulse = true;
        break;
      case VpnConnectionState.error:
        indicatorColor = AppTheme.errorRed;
        borderColor = AppTheme.errorRed;
        iconData = Icons.error_outline;
        break;
      case VpnConnectionState.disconnected:
        indicatorColor = Colors.grey.shade300;
        borderColor = Colors.grey.shade400;
        iconData = Icons.vpn_lock_outlined;
        break;
    }

    Widget indicator = Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: indicatorColor,
        border: Border.all(
          color: borderColor,
          width: 3,
        ),
      ),
      child: Icon(
        iconData,
        size: 40,
        color: status.state == VpnConnectionState.disconnected 
            ? Colors.grey.shade600 
            : Colors.white,
      ),
    );

    if (showPulse || isConnecting || isDisconnecting) {
      return _PulsingWidget(child: indicator);
    }

    return indicator;
  }
}

class _PulsingWidget extends StatefulWidget {
  final Widget child;

  const _PulsingWidget({required this.child});

  @override
  State<_PulsingWidget> createState() => _PulsingWidgetState();
}

class _PulsingWidgetState extends State<_PulsingWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Transform.scale(
          scale: _animation.value,
          child: widget.child,
        );
      },
    );
  }
}

class _ConnectionTimer extends StatefulWidget {
  final DateTime startTime;

  const _ConnectionTimer({required this.startTime});

  @override
  State<_ConnectionTimer> createState() => _ConnectionTimerState();
}

class _ConnectionTimerState extends State<_ConnectionTimer> {
  late Timer _timer;
  Duration _elapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    _updateElapsed();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _updateElapsed();
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  void _updateElapsed() {
    setState(() {
      _elapsed = DateTime.now().difference(widget.startTime);
    });
  }

  @override
  Widget build(BuildContext context) {
    final hours = _elapsed.inHours;
    final minutes = _elapsed.inMinutes % 60;
    final seconds = _elapsed.inSeconds % 60;

    String timeText;
    if (hours > 0) {
      timeText = '${hours.toString().padLeft(2, '0')}:'
                 '${minutes.toString().padLeft(2, '0')}:'
                 '${seconds.toString().padLeft(2, '0')}';
    } else {
      timeText = '${minutes.toString().padLeft(2, '0')}:'
                 '${seconds.toString().padLeft(2, '0')}';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.successGreen.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.successGreen.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.timer,
            size: 16,
            color: AppTheme.accentGreen,
          ),
          const SizedBox(width: 4),
          Text(
            timeText,
            style: TextStyle(
              color: AppTheme.accentGreen,
              fontWeight: FontWeight.w600,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _NetworkStatsDisplay extends StatelessWidget {
  final NetworkStats stats;

  const _NetworkStatsDisplay({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          // Data usage row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _StatItem(
                icon: Icons.download,
                label: 'Downloaded',
                value: stats.formattedBytesReceived,
                color: AppTheme.primaryBlue,
              ),
              _StatItem(
                icon: Icons.upload,
                label: 'Uploaded',
                value: stats.formattedBytesSent,
                color: AppTheme.accentGreen,
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Speed row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _StatItem(
                icon: Icons.speed,
                label: 'Download',
                value: stats.formattedDownloadSpeed,
                color: AppTheme.primaryBlue,
              ),
              _StatItem(
                icon: Icons.speed,
                label: 'Upload',
                value: stats.formattedUploadSpeed,
                color: AppTheme.accentGreen,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(
          icon,
          size: 20,
          color: color,
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}