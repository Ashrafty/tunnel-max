import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';

import '../widgets/server_card_widget.dart';
import '../../providers/configuration_provider.dart';
import '../../models/vpn_configuration.dart';
import '../../services/configuration_manager.dart';
import 'add_edit_configuration_screen.dart';

class ServerListScreen extends ConsumerStatefulWidget {
  const ServerListScreen({super.key});

  @override
  ConsumerState<ServerListScreen> createState() => _ServerListScreenState();
}

class _ServerListScreenState extends ConsumerState<ServerListScreen> {
  final ConfigurationManager _configManager = ConfigurationManager();
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final configurations = ref.watch(sampleConfigurationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('VPN Servers'),
        actions: [
          PopupMenuButton<String>(
            onSelected: _handleMenuAction,
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'import',
                child: Row(
                  children: [
                    Icon(Icons.file_upload),
                    SizedBox(width: 8),
                    Text('Import Configuration'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'export_all',
                child: Row(
                  children: [
                    Icon(Icons.file_download),
                    SizedBox(width: 8),
                    Text('Export All'),
                  ],
                ),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _navigateToAddConfiguration(),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : configurations.isEmpty
              ? _buildEmptyState()
              : _buildConfigurationList(configurations),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.dns_outlined,
            size: 64,
            color: Colors.grey,
          ),
          const SizedBox(height: 16),
          const Text(
            'No servers configured',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Add a server configuration to get started',
            style: TextStyle(
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: () => _navigateToAddConfiguration(),
                icon: const Icon(Icons.add),
                label: const Text('Add Server'),
              ),
              const SizedBox(width: 16),
              OutlinedButton.icon(
                onPressed: () => _importConfiguration(),
                icon: const Icon(Icons.file_upload),
                label: const Text('Import'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildConfigurationList(List<VpnConfiguration> configurations) {
    return RefreshIndicator(
      onRefresh: _refreshConfigurations,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: configurations.length,
        itemBuilder: (context, index) {
          final config = configurations[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: ServerCardWidget(
              configuration: config,
              onTap: () => _navigateToEditConfiguration(config),
              onConnect: () => _connectToServer(config),
              onDelete: () => _deleteConfiguration(config),
              onExport: () => _exportConfiguration(config),
            ),
          );
        },
      ),
    );
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'import':
        _importConfiguration();
        break;
      case 'export_all':
        _exportAllConfigurations();
        break;
    }
  }

  void _navigateToAddConfiguration() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const AddEditConfigurationScreen(),
      ),
    );
  }

  void _navigateToEditConfiguration(VpnConfiguration config) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AddEditConfigurationScreen(
          configuration: config,
        ),
      ),
    );
  }

  void _connectToServer(VpnConfiguration config) {
    // Update selected configuration
    ref.read(selectedConfigurationProvider.notifier).state = config;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Connecting to ${config.name}...'),
        action: SnackBarAction(
          label: 'Cancel',
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  Future<void> _deleteConfiguration(VpnConfiguration config) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Configuration'),
        content: Text('Are you sure you want to delete "${config.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        setState(() => _isLoading = true);
        await _configManager.deleteConfiguration(config.id);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Deleted "${config.name}"')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete configuration: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  Future<void> _exportConfiguration(VpnConfiguration config) async {
    try {
      setState(() => _isLoading = true);
      
      final jsonString = await _configManager.exportToJson(
        configurationIds: [config.id],
        includeSensitiveData: false,
      );

      await Share.share(
        jsonString,
        subject: 'VPN Configuration: ${config.name}',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to export configuration: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _exportAllConfigurations() async {
    try {
      setState(() => _isLoading = true);
      
      final jsonString = await _configManager.exportToJson(
        includeSensitiveData: false,
      );

      await Share.share(
        jsonString,
        subject: 'VPN Configurations Export',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to export configurations: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _importConfiguration() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json', 'txt'],
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        setState(() => _isLoading = true);
        
        final file = result.files.single;
        final content = String.fromCharCodes(file.bytes!);
        
        final importedConfigs = await _configManager.importFromJson(content);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Imported ${importedConfigs.length} configuration(s)'),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to import configuration: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _refreshConfigurations() async {
    // In a real implementation, this would reload configurations from storage
    await Future.delayed(const Duration(seconds: 1));
  }
}