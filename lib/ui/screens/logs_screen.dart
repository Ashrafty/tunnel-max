import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../../services/logs_service.dart';

/// Provider for logs service
final logsServiceProvider = Provider<LogsService>((ref) {
  return LogsService();
});

/// Provider for log entries
final logEntriesProvider = FutureProvider<List<String>>((ref) async {
  final logsService = ref.watch(logsServiceProvider);
  return await logsService.getRecentLogs(count: 500);
});

/// Screen for viewing application logs
class LogsScreen extends ConsumerStatefulWidget {
  const LogsScreen({super.key});

  @override
  ConsumerState<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends ConsumerState<LogsScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _autoScroll = true;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final logEntriesAsync = ref.watch(logEntriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Application Logs'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(logEntriesProvider);
            },
            tooltip: 'Refresh logs',
          ),
          PopupMenuButton<String>(
            onSelected: (value) async {
              switch (value) {
                case 'export':
                  await _exportLogs();
                  break;
                case 'clear':
                  await _clearLogs();
                  break;
                case 'copy':
                  await _copyAllLogs();
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'export',
                child: ListTile(
                  leading: Icon(Icons.share),
                  title: Text('Export Logs'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'copy',
                child: ListTile(
                  leading: Icon(Icons.copy),
                  title: Text('Copy All'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'clear',
                child: ListTile(
                  leading: Icon(Icons.clear_all),
                  title: Text('Clear Logs'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Controls
          Container(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Showing recent log entries',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                Row(
                  children: [
                    Text(
                      'Auto-scroll',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(width: 8),
                    Switch(
                      value: _autoScroll,
                      onChanged: (value) {
                        setState(() {
                          _autoScroll = value;
                        });
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          
          // Log entries
          Expanded(
            child: logEntriesAsync.when(
              data: (logEntries) {
                if (logEntries.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.description_outlined,
                          size: 64,
                          color: Colors.grey,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'No logs available',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Application logs will appear here',
                          style: TextStyle(
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                // Auto-scroll to bottom when new logs are added
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_autoScroll && _scrollController.hasClients) {
                    _scrollController.animateTo(
                      _scrollController.position.maxScrollExtent,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOut,
                    );
                  }
                });

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(8.0),
                  itemCount: logEntries.length,
                  itemBuilder: (context, index) {
                    final logEntry = logEntries[index];
                    return _buildLogEntry(logEntry, index);
                  },
                );
              },
              loading: () => const Center(
                child: CircularProgressIndicator(),
              ),
              error: (error, stackTrace) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 64,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Failed to load logs',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      error.toString(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        ref.invalidate(logEntriesProvider);
                      },
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogEntry(String logEntry, int index) {
    // Parse log entry to extract timestamp, level, and message
    final parts = logEntry.split('] ');
    if (parts.length < 3) {
      return _buildSimpleLogEntry(logEntry, index);
    }

    final timestamp = parts[0].substring(1); // Remove leading '['
    final level = parts[1].substring(1); // Remove leading '['
    final message = parts.sublist(2).join('] ');

    Color levelColor = Colors.grey;
    IconData levelIcon = Icons.info_outline;

    switch (level.toUpperCase()) {
      case 'ERROR':
      case 'E':
        levelColor = Colors.red;
        levelIcon = Icons.error_outline;
        break;
      case 'WARNING':
      case 'W':
        levelColor = Colors.orange;
        levelIcon = Icons.warning_outlined;
        break;
      case 'INFO':
      case 'I':
        levelColor = Colors.blue;
        levelIcon = Icons.info_outline;
        break;
      case 'DEBUG':
      case 'D':
        levelColor = Colors.green;
        levelIcon = Icons.bug_report_outlined;
        break;
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 2.0),
      child: InkWell(
        onTap: () => _showLogDetails(logEntry),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                levelIcon,
                size: 16,
                color: levelColor,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: levelColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            level.toUpperCase(),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: levelColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _formatTimestamp(timestamp),
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      message,
                      style: const TextStyle(fontFamily: 'monospace'),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSimpleLogEntry(String logEntry, int index) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 2.0),
      child: InkWell(
        onTap: () => _showLogDetails(logEntry),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Text(
            logEntry,
            style: const TextStyle(fontFamily: 'monospace'),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }

  String _formatTimestamp(String timestamp) {
    try {
      final dateTime = DateTime.parse(timestamp);
      return '${dateTime.hour.toString().padLeft(2, '0')}:'
             '${dateTime.minute.toString().padLeft(2, '0')}:'
             '${dateTime.second.toString().padLeft(2, '0')}';
    } catch (e) {
      return timestamp;
    }
  }

  void _showLogDetails(String logEntry) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log Details'),
        content: SingleChildScrollView(
          child: SelectableText(
            logEntry,
            style: const TextStyle(fontFamily: 'monospace'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: logEntry));
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Log entry copied to clipboard')),
              );
            },
            child: const Text('Copy'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _exportLogs() async {
    try {
      final logsService = ref.read(logsServiceProvider);
      final exportFile = await logsService.exportLogs();
      
      if (exportFile != null) {
        await Share.shareXFiles(
          [XFile(exportFile.path)],
          text: 'TunnelMax VPN Application Logs',
        );
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No logs to export')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to export logs: $e')),
        );
      }
    }
  }

  Future<void> _copyAllLogs() async {
    try {
      final logEntries = await ref.read(logEntriesProvider.future);
      final allLogsText = logEntries.join('\n');
      
      await Clipboard.setData(ClipboardData(text: allLogsText));
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All logs copied to clipboard')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to copy logs: $e')),
        );
      }
    }
  }

  Future<void> _clearLogs() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Logs'),
        content: const Text(
          'Are you sure you want to clear all application logs? '
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final logsService = ref.read(logsServiceProvider);
        await logsService.clearLogs();
        
        // Refresh the logs list
        ref.invalidate(logEntriesProvider);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Logs cleared successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to clear logs: $e')),
          );
        }
      }
    }
  }
}