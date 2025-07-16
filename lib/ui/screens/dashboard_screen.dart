import 'package:flutter/material.dart';
import '../widgets/connection_status_widget.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('TunnelMax VPN'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              // TODO: Show app info - will be implemented in later tasks
            },
          ),
        ],
      ),
      body: const Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Connection status widget - basic implementation for this task
            ConnectionStatusWidget(),
            SizedBox(height: 24),
            // Placeholder for additional dashboard content
            Expanded(
              child: Center(
                child: Text(
                  'VPN Dashboard',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}