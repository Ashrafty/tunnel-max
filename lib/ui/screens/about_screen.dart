import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'logs_screen.dart';

/// Screen displaying application information and version details
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('About'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // App Icon and Name
          Center(
            child: Column(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.vpn_lock,
                    size: 40,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'TunnelMax VPN',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Secure VPN Client powered by sing-box',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 32),
          
          // Version Information
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: const Text('Version'),
                  subtitle: const Text('1.0.0+1'),
                  trailing: IconButton(
                    icon: const Icon(Icons.copy),
                    onPressed: () {
                      Clipboard.setData(const ClipboardData(text: '1.0.0+1'));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Version copied to clipboard')),
                      );
                    },
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.build_outlined),
                  title: const Text('Build Number'),
                  subtitle: const Text('1'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.flutter_dash),
                  title: const Text('Flutter Version'),
                  subtitle: const Text('3.8.1'),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // System Information
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.phone_android),
                  title: const Text('Platform'),
                  subtitle: Text(_getPlatformName()),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.memory),
                  title: const Text('Architecture'),
                  subtitle: const Text('ARM64 / x64'),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Features and Links
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.description_outlined),
                  title: const Text('View Logs'),
                  subtitle: const Text('Application logs and diagnostics'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const LogsScreen(),
                      ),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.code),
                  title: const Text('Source Code'),
                  subtitle: const Text('View on GitHub'),
                  trailing: const Icon(Icons.open_in_new),
                  onTap: () => _launchUrl('https://github.com/Ashrafty/tunnel-max'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.bug_report_outlined),
                  title: const Text('Report Issue'),
                  subtitle: const Text('Report bugs or request features'),
                  trailing: const Icon(Icons.open_in_new),
                  onTap: () => _launchUrl('https://github.com/Ashrafty/tunnel-max/issues'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.privacy_tip_outlined),
                  title: const Text('Privacy Policy'),
                  trailing: const Icon(Icons.open_in_new),
                  onTap: () => _launchUrl('https://github.com/Ashrafty/tunnel-max'),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Credits and Acknowledgments
          Card(
            child: Column(
              children: [
                const ListTile(
                  leading: Icon(Icons.favorite_outline),
                  title: Text('Powered by'),
                  subtitle: Text('sing-box core for VPN functionality'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.code_outlined),
                  title: const Text('Built with Flutter'),
                  subtitle: const Text('Cross-platform UI framework'),
                  onTap: () => _launchUrl('https://flutter.dev'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.security),
                  title: const Text('sing-box'),
                  subtitle: const Text('Universal proxy platform'),
                  onTap: () => _launchUrl('https://sing-box.sagernet.org'),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 32),
          
          // Copyright and Legal
          Center(
            child: Column(
              children: [
                Text(
                  '© 2024 TunnelMax VPN',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Licensed under MIT License',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'This application is provided as-is without any warranties. '
                  'Use at your own risk.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[500],
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  String _getPlatformName() {
    // This would normally use Platform.operatingSystem
    // but for this example, we'll return a generic name
    return 'Android / Windows';
  }

  Future<void> _launchUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      // Handle error silently or show a snackbar
      debugPrint('Failed to launch URL: $url, Error: $e');
    }
  }
}