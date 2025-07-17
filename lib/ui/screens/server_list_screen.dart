import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';

import '../widgets/server_card_widget.dart';
import '../../providers/configuration_provider.dart';
import '../../providers/vpn_service_provider.dart';
import '../../models/vpn_configuration.dart';
import '../../models/vpn_status.dart';
import '../../services/configuration_manager.dart';
import '../../services/vpn_service_manager.dart';
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
    final configurationsAsync = ref.watch(refreshableConfigurationsProvider);

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
                    Text('Import from File'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'paste',
                child: Row(
                  children: [
                    Icon(Icons.content_paste),
                    SizedBox(width: 8),
                    Text('Paste Configuration'),
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
          : configurationsAsync.when(
              data: (configurations) => configurations.isEmpty
                  ? _buildEmptyState()
                  : _buildConfigurationList(configurations),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error, size: 64, color: Colors.red),
                    const SizedBox(height: 16),
                    Text('Error loading configurations: $error'),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => _refreshConfigurations(),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
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
      case 'paste':
        _pasteConfiguration();
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

  Future<void> _connectToServer(VpnConfiguration config) async {
    try {
      // Update selected configuration
      ref.read(selectedConfigurationProvider.notifier).state = config;
      
      // Get VPN service actions
      final vpnActions = ref.read(vpnServiceActionsProvider);
      
      // Check current connection state
      final isConnected = ref.read(isVpnConnectedProvider);
      final isConnecting = ref.read(isVpnConnectingProvider);
      
      if (isConnecting) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Connection already in progress...'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
      
      if (isConnected) {
        // Ask user if they want to disconnect and connect to new server
        final shouldReconnect = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Switch Server'),
            content: Text('You are currently connected. Do you want to disconnect and connect to "${config.name}"?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Switch'),
              ),
            ],
          ),
        );
        
        if (shouldReconnect != true) return;
      }
      
      // Show connecting snackbar
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Connecting to ${config.name}...'),
          duration: const Duration(seconds: 30), // Longer duration for connection process
          action: SnackBarAction(
            label: 'Cancel',
            onPressed: () {
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
              // TODO: Cancel connection attempt
            },
          ),
        ),
      );
      
      // Attempt to connect
      final success = await vpnActions.connect(config);
      
      // Hide the connecting snackbar
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      
      if (success) {
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Connected to ${config.name}'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      } else {
        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to connect to ${config.name}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: () => _connectToServer(config),
            ),
          ),
        );
      }
    } catch (e) {
      // Hide any existing snackbars
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Connection error: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'Retry',
            textColor: Colors.white,
            onPressed: () => _connectToServer(config),
          ),
        ),
      );
    }
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
        String content;
        
        if (file.bytes != null) {
          // Use bytes if available (web platform)
          content = String.fromCharCodes(file.bytes!);
        } else if (file.path != null) {
          // Use file path for mobile platforms
          final fileContent = await File(file.path!).readAsString();
          content = fileContent;
        } else {
          throw Exception('Unable to read file content');
        }
        
        final importedConfigs = await _configManager.importFromJson(content);
        
        // Trigger UI refresh to show imported configurations
        _refreshConfigurations();
        
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

  Future<void> _pasteConfiguration() async {
    final TextEditingController textController = TextEditingController();
    
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Paste Configuration'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Paste your VPN configuration below. Supported formats:',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 8),
              const Text(
                '• JSON configuration files\n'
                '• V2Ray/Xray share links (vmess://, vless://)\n'
                '• Shadowsocks links (ss://)\n'
                '• Trojan links (trojan://)\n'
                '• Subscription URLs',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: textController,
                maxLines: 8,
                decoration: const InputDecoration(
                  hintText: 'Paste configuration here...',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final text = textController.text.trim();
              if (text.isNotEmpty) {
                Navigator.of(context).pop(text);
              }
            },
            child: const Text('Import'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      await _processConfigurationText(result);
    }
  }

  Future<void> _processConfigurationText(String text) async {
    try {
      setState(() => _isLoading = true);
      
      List<VpnConfiguration> importedConfigs = [];
      
      // Detect configuration format and process accordingly
      if (text.startsWith('{') || text.startsWith('[')) {
        // JSON format
        importedConfigs = await _configManager.importFromJson(text);
      } else if (text.startsWith('vmess://')) {
        // VMess share link
        final config = await _parseVMessLink(text);
        await _configManager.saveConfiguration(config);
        importedConfigs = [config];
      } else if (text.startsWith('vless://')) {
        // VLESS share link
        final config = await _parseVLessLink(text);
        await _configManager.saveConfiguration(config);
        importedConfigs = [config];
      } else if (text.startsWith('ss://')) {
        // Shadowsocks link
        final config = await _parseShadowsocksLink(text);
        await _configManager.saveConfiguration(config);
        importedConfigs = [config];
      } else if (text.startsWith('trojan://')) {
        // Trojan link
        final config = await _parseTrojanLink(text);
        await _configManager.saveConfiguration(config);
        importedConfigs = [config];
      } else if (text.startsWith('http://') || text.startsWith('https://')) {
        // Subscription URL
        importedConfigs = await _fetchSubscription(text);
      } else {
        // Try to parse as base64 encoded content
        try {
          final decoded = String.fromCharCodes(base64Decode(text));
          if (decoded.startsWith('{') || decoded.startsWith('[')) {
            importedConfigs = await _configManager.importFromJson(decoded);
          } else {
            throw Exception('Unrecognized configuration format');
          }
        } catch (e) {
          throw Exception('Unrecognized configuration format. Please check your input.');
        }
      }
      
      if (importedConfigs.isNotEmpty) {
        // Configurations are already saved by importFromJson method
        // Just trigger UI refresh to show imported configurations
        _refreshConfigurations();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Successfully imported ${importedConfigs.length} configuration(s)'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        throw Exception('No valid configurations found');
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

  Future<VpnConfiguration> _parseVMessLink(String link) async {
    // Remove vmess:// prefix and decode base64
    final encoded = link.substring(8);
    final decoded = String.fromCharCodes(base64Decode(encoded));
    final json = jsonDecode(decoded) as Map<String, dynamic>;
    
    return VpnConfiguration(
      id: const Uuid().v4(),
      name: json['ps'] ?? 'VMess Server',
      serverAddress: json['add'] ?? '',
      serverPort: int.tryParse(json['port']?.toString() ?? '0') ?? 0,
      protocol: VpnProtocol.vmess,
      authMethod: AuthenticationMethod.password,
      protocolSpecificConfig: {
        'uuid': json['id'] ?? '',
        'alterId': int.tryParse(json['aid']?.toString() ?? '0') ?? 0,
        'security': json['scy'] ?? 'auto',
        'network': json['net'] ?? 'tcp',
        'path': json['path'] ?? '/',
        'host': json['host'] ?? '',
        'tls': json['tls'] == 'tls',
        'sni': json['sni'] ?? '',
      },
      createdAt: DateTime.now(),
    );
  }

  Future<VpnConfiguration> _parseVLessLink(String link) async {
    final uri = Uri.parse(link);
    final params = uri.queryParameters;
    
    return VpnConfiguration(
      id: const Uuid().v4(),
      name: Uri.decodeComponent(params['remarks'] ?? params['ps'] ?? 'VLESS Server'),
      serverAddress: uri.host,
      serverPort: uri.port,
      protocol: VpnProtocol.vless,
      authMethod: AuthenticationMethod.password,
      protocolSpecificConfig: {
        'uuid': uri.userInfo,
        'flow': params['flow'] ?? '',
        'network': params['type'] ?? 'tcp',
        'path': params['path'] ?? '/',
        'host': params['host'] ?? '',
        'tls': params['security'] == 'tls',
        'sni': params['sni'] ?? '',
      },
      createdAt: DateTime.now(),
    );
  }

  Future<VpnConfiguration> _parseShadowsocksLink(String link) async {
    // Remove ss:// prefix
    final encoded = link.substring(5);
    String decoded;
    
    if (encoded.contains('@')) {
      // New format: ss://base64(method:password)@server:port#tag
      final parts = encoded.split('@');
      final methodPassword = String.fromCharCodes(base64Decode(parts[0]));
      final serverPart = parts[1];
      
      final methodPasswordParts = methodPassword.split(':');
      final method = methodPasswordParts[0];
      final password = methodPasswordParts.sublist(1).join(':');
      
      final serverPortParts = serverPart.split('#')[0].split(':');
      final server = serverPortParts[0];
      final port = int.tryParse(serverPortParts[1]) ?? 0;
      
      final name = serverPart.contains('#') 
          ? Uri.decodeComponent(serverPart.split('#')[1])
          : 'Shadowsocks Server';
      
      return VpnConfiguration(
        id: const Uuid().v4(),
        name: name,
        serverAddress: server,
        serverPort: port,
        protocol: VpnProtocol.shadowsocks,
        authMethod: AuthenticationMethod.password,
        protocolSpecificConfig: {
          'method': method,
          'password': password,
        },
        createdAt: DateTime.now(),
      );
    } else {
      // Old format: ss://base64(method:password@server:port)#tag
      decoded = String.fromCharCodes(base64Decode(encoded.split('#')[0]));
      final parts = decoded.split('@');
      final methodPassword = parts[0].split(':');
      final serverPort = parts[1].split(':');
      
      final name = encoded.contains('#') 
          ? Uri.decodeComponent(encoded.split('#')[1])
          : 'Shadowsocks Server';
      
      return VpnConfiguration(
        id: const Uuid().v4(),
        name: name,
        serverAddress: serverPort[0],
        serverPort: int.tryParse(serverPort[1]) ?? 0,
        protocol: VpnProtocol.shadowsocks,
        authMethod: AuthenticationMethod.password,
        protocolSpecificConfig: {
          'method': methodPassword[0],
          'password': methodPassword.sublist(1).join(':'),
        },
        createdAt: DateTime.now(),
      );
    }
  }

  Future<VpnConfiguration> _parseTrojanLink(String link) async {
    final uri = Uri.parse(link);
    final params = uri.queryParameters;
    
    return VpnConfiguration(
      id: const Uuid().v4(),
      name: Uri.decodeComponent(params['remarks'] ?? params['ps'] ?? 'Trojan Server'),
      serverAddress: uri.host,
      serverPort: uri.port,
      protocol: VpnProtocol.trojan,
      authMethod: AuthenticationMethod.password,
      protocolSpecificConfig: {
        'password': uri.userInfo,
        'sni': params['sni'] ?? uri.host,
        'allowInsecure': params['allowInsecure'] == '1',
      },
      createdAt: DateTime.now(),
    );
  }

  Future<List<VpnConfiguration>> _fetchSubscription(String url) async {
    // This would typically make an HTTP request to fetch the subscription
    // For now, we'll throw an exception to indicate it's not implemented
    throw Exception('Subscription URL import is not yet implemented. Please paste the configuration content directly.');
  }

  Future<void> _refreshConfigurations() async {
    // Trigger a refresh of the configuration provider
    ref.read(configurationRefreshProvider.notifier).state++;
  }
}