import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tunnel_max/models/vpn_configuration.dart';
import '../../models/user_preferences.dart';
import '../../providers/preferences_provider.dart';
import '../../providers/configuration_provider.dart';
import 'logs_screen.dart';
import 'about_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preferencesAsync = ref.watch(userPreferencesProvider);
    final configurations = ref.watch(sampleConfigurationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: preferencesAsync.when(
        data: (preferences) => _buildSettingsContent(context, ref, preferences, configurations),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text('Failed to load settings: $error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.invalidate(userPreferencesProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsContent(
    BuildContext context,
    WidgetRef ref,
    UserPreferences preferences,
    List<VpnConfiguration> configurations,
  ) {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        // Connection Settings Section
        _buildSectionHeader('Connection'),
        const SizedBox(height: 12),
        Card(
          child: Column(
            children: [
              SwitchListTile(
                secondary: const Icon(Icons.auto_awesome),
                title: const Text('Auto Connect'),
                subtitle: const Text('Automatically connect on app start'),
                value: preferences.autoConnect,
                onChanged: (value) {
                  ref.read(userPreferencesProvider.notifier).updateAutoConnect(value);
                },
              ),
              if (preferences.autoConnect) ...[
                const Divider(height: 1),
                _buildAutoConnectConfigSelector(context, ref, preferences, configurations),
              ],
              const Divider(height: 1),
              SwitchListTile(
                secondary: const Icon(Icons.refresh),
                title: const Text('Auto Reconnect'),
                subtitle: const Text('Reconnect when connection is lost'),
                value: preferences.autoReconnect,
                onChanged: (value) {
                  ref.read(userPreferencesProvider.notifier).updateAutoReconnect(value);
                },
              ),
              if (preferences.autoReconnect) ...[
                const Divider(height: 1),
                _buildReconnectionSettings(context, ref, preferences),
              ],
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Appearance Settings Section
        _buildSectionHeader('Appearance'),
        const SizedBox(height: 12),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.palette_outlined),
                title: const Text('Theme'),
                subtitle: Text('Current: ${preferences.themeMode.displayName}'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showThemeSelector(context, ref, preferences),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Notification Settings Section
        _buildSectionHeader('Notifications'),
        const SizedBox(height: 12),
        Card(
          child: Column(
            children: [
              SwitchListTile(
                secondary: const Icon(Icons.notifications_outlined),
                title: const Text('Show Notifications'),
                subtitle: const Text('Enable connection status notifications'),
                value: preferences.showNotifications,
                onChanged: (value) {
                  ref.read(userPreferencesProvider.notifier).updateShowNotifications(value);
                },
              ),
              if (preferences.showNotifications) ...[
                const Divider(height: 1),
                SwitchListTile(
                  secondary: const Icon(Icons.wifi_protected_setup),
                  title: const Text('Notify on Connect'),
                  subtitle: const Text('Show notification when VPN connects'),
                  value: preferences.notifyOnConnect,
                  onChanged: (value) {
                    ref.read(userPreferencesProvider.notifier).updateNotifyOnConnect(value);
                  },
                ),
                const Divider(height: 1),
                SwitchListTile(
                  secondary: const Icon(Icons.wifi_off),
                  title: const Text('Notify on Disconnect'),
                  subtitle: const Text('Show notification when VPN disconnects'),
                  value: preferences.notifyOnDisconnect,
                  onChanged: (value) {
                    ref.read(userPreferencesProvider.notifier).updateNotifyOnDisconnect(value);
                  },
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Advanced Settings Section
        _buildSectionHeader('Advanced'),
        const SizedBox(height: 12),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.restore),
                title: const Text('Reset Settings'),
                subtitle: const Text('Reset all settings to defaults'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showResetConfirmation(context, ref),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Information Section
        _buildSectionHeader('Information'),
        const SizedBox(height: 12),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('About'),
                subtitle: const Text('Version and app information'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const AboutScreen(),
                    ),
                  );
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.description_outlined),
                title: const Text('Logs'),
                subtitle: const Text('View application logs'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const LogsScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
        ),

        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildAutoConnectConfigSelector(
    BuildContext context,
    WidgetRef ref,
    UserPreferences preferences,
    List<VpnConfiguration> configurations,
  ) {
    if (configurations.isEmpty) {
      return const ListTile(
        leading: Icon(Icons.warning_outlined),
        title: Text('No Configurations'),
        subtitle: Text('Add a server configuration to enable auto-connect'),
      );
    }

    final selectedConfig = configurations.firstWhere(
      (config) => config.id == preferences.autoConnectConfigId,
      orElse: () => configurations.first,
    );

    return ListTile(
      leading: const Icon(Icons.dns_outlined),
      title: const Text('Auto-Connect Server'),
      subtitle: Text(selectedConfig.name),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => _showConfigSelector(context, ref, configurations, preferences),
    );
  }

  Widget _buildReconnectionSettings(
    BuildContext context,
    WidgetRef ref,
    UserPreferences preferences,
  ) {
    return Column(
      children: [
        ListTile(
          leading: const Icon(Icons.repeat),
          title: const Text('Retry Attempts'),
          subtitle: Text('${preferences.reconnectionRetries} attempts'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _showRetryAttemptsSelector(context, ref, preferences),
        ),
        const Divider(height: 1),
        ListTile(
          leading: const Icon(Icons.timer_outlined),
          title: const Text('Retry Delay'),
          subtitle: Text('${preferences.reconnectionDelay} seconds'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _showRetryDelaySelector(context, ref, preferences),
        ),
      ],
    );
  }

  void _showThemeSelector(BuildContext context, WidgetRef ref, UserPreferences preferences) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Theme'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: AppThemeMode.values.map((mode) {
            return RadioListTile<AppThemeMode>(
              title: Text(mode.displayName),
              value: mode,
              groupValue: preferences.themeMode,
              onChanged: (value) {
                if (value != null) {
                  ref.read(userPreferencesProvider.notifier).updateThemeMode(value);
                  Navigator.of(context).pop();
                }
              },
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _showConfigSelector(
    BuildContext context,
    WidgetRef ref,
    List<VpnConfiguration> configurations,
    UserPreferences preferences,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Auto-Connect Server'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: configurations.length,
            itemBuilder: (context, index) {
              final config = configurations[index];
              return RadioListTile(
                title: Text(config.name),
                subtitle: Text('${config.serverAddress}:${config.serverPort}'),
                value: config.id,
                groupValue: preferences.autoConnectConfigId,
                onChanged: (value) {
                  if (value != null) {
                    ref.read(userPreferencesProvider.notifier).updateAutoConnectConfigId(value);
                    Navigator.of(context).pop();
                  }
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _showRetryAttemptsSelector(BuildContext context, WidgetRef ref, UserPreferences preferences) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Retry Attempts'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [1, 3, 5, 10, 15].map((attempts) {
            return RadioListTile<int>(
              title: Text('$attempts attempts'),
              value: attempts,
              groupValue: preferences.reconnectionRetries,
              onChanged: (value) {
                if (value != null) {
                  ref.read(userPreferencesProvider.notifier).updateReconnectionRetries(value);
                  Navigator.of(context).pop();
                }
              },
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _showRetryDelaySelector(BuildContext context, WidgetRef ref, UserPreferences preferences) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Retry Delay'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [2, 5, 10, 15, 30].map((delay) {
            return RadioListTile<int>(
              title: Text('$delay seconds'),
              value: delay,
              groupValue: preferences.reconnectionDelay,
              onChanged: (value) {
                if (value != null) {
                  ref.read(userPreferencesProvider.notifier).updateReconnectionDelay(value);
                  Navigator.of(context).pop();
                }
              },
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _showResetConfirmation(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Settings'),
        content: const Text(
          'Are you sure you want to reset all settings to their default values? '
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              ref.read(userPreferencesProvider.notifier).resetToDefaults();
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Settings reset to defaults')),
              );
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }
}