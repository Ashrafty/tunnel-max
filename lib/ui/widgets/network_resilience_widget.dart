import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/network_resilience_provider.dart';
import '../../services/network_resilience_service.dart';
import '../../services/kill_switch_service.dart';

/// Widget that displays network resilience status and controls
class NetworkResilienceWidget extends ConsumerWidget {
  const NetworkResilienceWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coordinator = ref.watch(networkResilienceCoordinatorProvider);
    final resilienceStatus = ref.watch(networkResilienceStatusProvider);
    final killSwitchStatus = ref.watch(killSwitchStatusProvider);
    final autoReconnectionEnabled = ref.watch(autoReconnectionEnabledProvider);
    final killSwitchEnabled = ref.watch(killSwitchEnabledProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Network Resilience',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            
            // Auto-reconnection toggle
            SwitchListTile(
              title: const Text('Auto-reconnection'),
              subtitle: const Text('Automatically reconnect when VPN disconnects'),
              value: autoReconnectionEnabled,
              onChanged: (value) async {
                ref.read(autoReconnectionEnabledProvider.notifier).state = value;
                
                if (value) {
                  await coordinator.enableAutoReconnection();
                } else {
                  await coordinator.disableAutoReconnection();
                }
              },
            ),
            
            // Kill switch toggle
            SwitchListTile(
              title: const Text('Kill Switch'),
              subtitle: const Text('Block traffic when VPN disconnects'),
              value: killSwitchEnabled,
              onChanged: (value) async {
                ref.read(killSwitchEnabledProvider.notifier).state = value;
                
                if (value) {
                  await coordinator.enableKillSwitch();
                } else {
                  await coordinator.disableKillSwitch();
                }
              },
            ),
            
            const SizedBox(height: 16),
            
            // Status displays
            _buildStatusSection(
              context,
              'Network Resilience Status',
              resilienceStatus,
            ),
            
            const SizedBox(height: 8),
            
            _buildKillSwitchStatusSection(
              context,
              'Kill Switch Status',
              killSwitchStatus,
            ),
            
            const SizedBox(height: 16),
            
            // Manual reconnection button
            ElevatedButton(
              onPressed: () async {
                try {
                  await coordinator.triggerReconnection();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Reconnection triggered'),
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Failed to trigger reconnection: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              child: const Text('Trigger Reconnection'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusSection(
    BuildContext context,
    String title,
    AsyncValue<NetworkResilienceStatus> statusAsync,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 4),
        statusAsync.when(
          data: (status) => _buildResilienceStatusCard(context, status),
          loading: () => const CircularProgressIndicator(),
          error: (error, stack) => Text(
            'Error: $error',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
      ],
    );
  }

  Widget _buildKillSwitchStatusSection(
    BuildContext context,
    String title,
    AsyncValue<KillSwitchStatus> statusAsync,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 4),
        statusAsync.when(
          data: (status) => _buildKillSwitchStatusCard(context, status),
          loading: () => const CircularProgressIndicator(),
          error: (error, stack) => Text(
            'Error: $error',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
      ],
    );
  }

  Widget _buildResilienceStatusCard(BuildContext context, NetworkResilienceStatus status) {
    Color statusColor;
    IconData statusIcon;
    
    switch (status.type) {
      case NetworkResilienceEventType.started:
        statusColor = Colors.green;
        statusIcon = Icons.play_arrow;
        break;
      case NetworkResilienceEventType.stopped:
        statusColor = Colors.grey;
        statusIcon = Icons.stop;
        break;
      case NetworkResilienceEventType.networkChanged:
        statusColor = Colors.orange;
        statusIcon = Icons.network_check;
        break;
      case NetworkResilienceEventType.networkLost:
        statusColor = Colors.red;
        statusIcon = Icons.signal_wifi_off;
        break;
      case NetworkResilienceEventType.networkRestored:
        statusColor = Colors.green;
        statusIcon = Icons.wifi;
        break;
      case NetworkResilienceEventType.reconnectionAttempt:
        statusColor = Colors.blue;
        statusIcon = Icons.refresh;
        break;
      case NetworkResilienceEventType.reconnectionSuccess:
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case NetworkResilienceEventType.reconnectionFailed:
        statusColor = Colors.red;
        statusIcon = Icons.error;
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.info;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        border: Border.all(color: statusColor.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(statusIcon, color: statusColor, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  status.type.toString().split('.').last,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
                if (status.message.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    status.message,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
          Text(
            _formatTimestamp(status.timestamp),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _buildKillSwitchStatusCard(BuildContext context, KillSwitchStatus status) {
    Color statusColor;
    IconData statusIcon;
    
    switch (status.type) {
      case KillSwitchEventType.enabled:
        statusColor = Colors.green;
        statusIcon = Icons.security;
        break;
      case KillSwitchEventType.disabled:
        statusColor = Colors.grey;
        statusIcon = Icons.security_outlined;
        break;
      case KillSwitchEventType.activated:
        statusColor = Colors.red;
        statusIcon = Icons.block;
        break;
      case KillSwitchEventType.deactivated:
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case KillSwitchEventType.error:
        statusColor = Colors.red;
        statusIcon = Icons.error;
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.info;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        border: Border.all(color: statusColor.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(statusIcon, color: statusColor, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  status.type.toString().split('.').last,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
                if (status.message.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    status.message,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
          Text(
            _formatTimestamp(status.timestamp),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    
    if (difference.inSeconds < 60) {
      return '${difference.inSeconds}s ago';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }
}