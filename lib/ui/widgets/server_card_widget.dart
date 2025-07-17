import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/vpn_configuration.dart';
import '../../providers/vpn_service_provider.dart';

class ServerCardWidget extends ConsumerWidget {
  final VpnConfiguration configuration;
  final VoidCallback? onTap;
  final VoidCallback? onConnect;
  final VoidCallback? onDelete;
  final VoidCallback? onExport;

  const ServerCardWidget({
    super.key,
    required this.configuration,
    this.onTap,
    this.onConnect,
    this.onDelete,
    this.onExport,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _buildProtocolIcon(),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          configuration.name,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${configuration.serverAddress}:${configuration.serverPort}',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildStatusIndicator(ref),
                  PopupMenuButton<String>(
                    onSelected: _handleMenuAction,
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'connect',
                        child: Row(
                          children: [
                            Icon(Icons.play_arrow, color: Colors.green),
                            SizedBox(width: 8),
                            Text('Connect'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit),
                            SizedBox(width: 8),
                            Text('Edit'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'export',
                        child: Row(
                          children: [
                            Icon(Icons.share),
                            SizedBox(width: 8),
                            Text('Export'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Delete'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildInfoChip(
                    icon: Icons.security,
                    label: _getProtocolDisplayName(),
                    color: _getProtocolColor(),
                  ),
                  const SizedBox(width: 8),
                  _buildInfoChip(
                    icon: Icons.vpn_key,
                    label: _getAuthMethodDisplayName(),
                    color: Colors.blue,
                  ),
                  if (configuration.autoConnect) ...[
                    const SizedBox(width: 8),
                    _buildInfoChip(
                      icon: Icons.autorenew,
                      label: 'Auto',
                      color: Colors.orange,
                    ),
                  ],
                ],
              ),
              if (configuration.lastUsed != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Last used: ${_formatLastUsed(configuration.lastUsed!)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProtocolIcon() {
    IconData iconData;
    Color iconColor;

    switch (configuration.protocol) {
      case VpnProtocol.shadowsocks:
        iconData = Icons.shield;
        iconColor = Colors.purple;
        break;
      case VpnProtocol.vmess:
        iconData = Icons.flash_on;
        iconColor = Colors.blue;
        break;
      case VpnProtocol.vless:
        iconData = Icons.speed;
        iconColor = Colors.green;
        break;
      case VpnProtocol.trojan:
        iconData = Icons.security;
        iconColor = Colors.red;
        break;
      case VpnProtocol.hysteria:
      case VpnProtocol.hysteria2:
        iconData = Icons.rocket_launch;
        iconColor = Colors.orange;
        break;
      case VpnProtocol.tuic:
        iconData = Icons.tune;
        iconColor = Colors.teal;
        break;
      case VpnProtocol.wireguard:
        iconData = Icons.vpn_lock;
        iconColor = Colors.indigo;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: iconColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        iconData,
        color: iconColor,
        size: 24,
      ),
    );
  }

  Widget _buildStatusIndicator(WidgetRef ref) {
    final vpnActions = ref.watch(vpnServiceActionsProvider);
    final isConnected = ref.watch(isVpnConnectedProvider);
    final isConnecting = ref.watch(isVpnConnectingProvider);
    
    // Check if this server is the currently connected/connecting one
    final currentConfig = vpnActions.currentConfiguration;
    final isCurrentServer = currentConfig?.id == configuration.id;
    
    Color statusColor;
    Widget statusWidget;
    
    if (isCurrentServer && isConnected) {
      // Connected to this server
      statusColor = Colors.green;
      statusWidget = Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          color: statusColor,
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.check,
          size: 8,
          color: Colors.white,
        ),
      );
    } else if (isCurrentServer && isConnecting) {
      // Connecting to this server
      statusColor = Colors.orange;
      statusWidget = SizedBox(
        width: 12,
        height: 12,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(statusColor),
        ),
      );
    } else {
      // Not connected to this server
      statusColor = Colors.grey[400]!;
      statusWidget = Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: statusColor,
          shape: BoxShape.circle,
        ),
      );
    }
    
    return statusWidget;
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  String _getProtocolDisplayName() {
    switch (configuration.protocol) {
      case VpnProtocol.shadowsocks:
        return 'Shadowsocks';
      case VpnProtocol.vmess:
        return 'VMess';
      case VpnProtocol.vless:
        return 'VLESS';
      case VpnProtocol.trojan:
        return 'Trojan';
      case VpnProtocol.hysteria:
        return 'Hysteria';
      case VpnProtocol.hysteria2:
        return 'Hysteria2';
      case VpnProtocol.tuic:
        return 'TUIC';
      case VpnProtocol.wireguard:
        return 'WireGuard';
    }
  }

  String _getAuthMethodDisplayName() {
    switch (configuration.authMethod) {
      case AuthenticationMethod.password:
        return 'Password';
      case AuthenticationMethod.certificate:
        return 'Certificate';
      case AuthenticationMethod.token:
        return 'Token';
      case AuthenticationMethod.none:
        return 'None';
    }
  }

  Color _getProtocolColor() {
    switch (configuration.protocol) {
      case VpnProtocol.shadowsocks:
        return Colors.purple;
      case VpnProtocol.vmess:
        return Colors.blue;
      case VpnProtocol.vless:
        return Colors.green;
      case VpnProtocol.trojan:
        return Colors.red;
      case VpnProtocol.hysteria:
      case VpnProtocol.hysteria2:
        return Colors.orange;
      case VpnProtocol.tuic:
        return Colors.teal;
      case VpnProtocol.wireguard:
        return Colors.indigo;
    }
  }

  String _formatLastUsed(DateTime lastUsed) {
    final now = DateTime.now();
    final difference = now.difference(lastUsed);

    if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
    } else {
      return 'Just now';
    }
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'connect':
        onConnect?.call();
        break;
      case 'edit':
        onTap?.call();
        break;
      case 'export':
        onExport?.call();
        break;
      case 'delete':
        onDelete?.call();
        break;
    }
  }
}