import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

import '../../models/vpn_configuration.dart';
import '../../services/configuration_manager.dart';

class AddEditConfigurationScreen extends StatefulWidget {
  final VpnConfiguration? configuration;

  const AddEditConfigurationScreen({
    super.key,
    this.configuration,
  });

  @override
  State<AddEditConfigurationScreen> createState() => _AddEditConfigurationScreenState();
}

class _AddEditConfigurationScreenState extends State<AddEditConfigurationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _configManager = ConfigurationManager();
  
  // Form controllers
  late final TextEditingController _nameController;
  late final TextEditingController _serverAddressController;
  late final TextEditingController _serverPortController;
  
  // Protocol-specific controllers
  final Map<String, TextEditingController> _protocolControllers = {};
  
  // Form state
  late VpnProtocol _selectedProtocol;
  late AuthenticationMethod _selectedAuthMethod;
  bool _autoConnect = false;
  bool _isLoading = false;
  
  // Validation errors
  String? _nameError;
  String? _serverAddressError;
  String? _serverPortError;
  Map<String, String> _protocolErrors = {};

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _initializeFormState();
  }

  void _initializeControllers() {
    final config = widget.configuration;
    
    _nameController = TextEditingController(text: config?.name ?? '');
    _serverAddressController = TextEditingController(text: config?.serverAddress ?? '');
    _serverPortController = TextEditingController(text: config?.serverPort.toString() ?? '');
    
    // Initialize protocol-specific controllers
    _initializeProtocolControllers();
  }

  void _initializeFormState() {
    final config = widget.configuration;
    
    _selectedProtocol = config?.protocol ?? VpnProtocol.shadowsocks;
    _selectedAuthMethod = config?.authMethod ?? AuthenticationMethod.password;
    _autoConnect = config?.autoConnect ?? false;
  }

  void _initializeProtocolControllers() {
    final config = widget.configuration;
    final protocolConfig = config?.protocolSpecificConfig ?? {};
    
    // Common protocol fields
    _protocolControllers['password'] = TextEditingController(text: protocolConfig['password'] ?? '');
    _protocolControllers['uuid'] = TextEditingController(text: protocolConfig['uuid'] ?? '');
    _protocolControllers['method'] = TextEditingController(text: protocolConfig['method'] ?? 'aes-256-gcm');
    _protocolControllers['alterId'] = TextEditingController(text: protocolConfig['alterId']?.toString() ?? '0');
    _protocolControllers['security'] = TextEditingController(text: protocolConfig['security'] ?? 'auto');
    _protocolControllers['sni'] = TextEditingController(text: protocolConfig['sni'] ?? '');
    _protocolControllers['auth'] = TextEditingController(text: protocolConfig['auth'] ?? '');
    _protocolControllers['privateKey'] = TextEditingController(text: protocolConfig['privateKey'] ?? '');
    _protocolControllers['publicKey'] = TextEditingController(text: protocolConfig['publicKey'] ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _serverAddressController.dispose();
    _serverPortController.dispose();
    
    for (final controller in _protocolControllers.values) {
      controller.dispose();
    }
    
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.configuration != null;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Configuration' : 'Add Configuration'),
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            TextButton(
              onPressed: _saveConfiguration,
              child: const Text('Save'),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildBasicConfigurationSection(),
            const SizedBox(height: 24),
            _buildProtocolSection(),
            const SizedBox(height: 24),
            _buildProtocolSpecificSection(),
            const SizedBox(height: 24),
            _buildAdvancedOptionsSection(),
            const SizedBox(height: 32),
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildBasicConfigurationSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Basic Configuration',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Configuration Name',
                hintText: 'Enter a name for this configuration',
                errorText: _nameError,
                prefixIcon: const Icon(Icons.label),
              ),
              validator: _validateName,
              onChanged: (_) => setState(() => _nameError = null),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _serverAddressController,
              decoration: InputDecoration(
                labelText: 'Server Address',
                hintText: 'example.com or 192.168.1.1',
                errorText: _serverAddressError,
                prefixIcon: const Icon(Icons.dns),
              ),
              validator: _validateServerAddress,
              onChanged: (_) => setState(() => _serverAddressError = null),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _serverPortController,
              decoration: InputDecoration(
                labelText: 'Server Port',
                hintText: '1-65535',
                errorText: _serverPortError,
                prefixIcon: const Icon(Icons.numbers),
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(5),
              ],
              validator: _validateServerPort,
              onChanged: (_) => setState(() => _serverPortError = null),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProtocolSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Protocol Configuration',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<VpnProtocol>(
              value: _selectedProtocol,
              decoration: const InputDecoration(
                labelText: 'VPN Protocol',
                prefixIcon: Icon(Icons.security),
              ),
              items: VpnProtocol.values.map((protocol) {
                return DropdownMenuItem(
                  value: protocol,
                  child: Text(_getProtocolDisplayName(protocol)),
                );
              }).toList(),
              onChanged: (protocol) {
                if (protocol != null) {
                  setState(() {
                    _selectedProtocol = protocol;
                    _protocolErrors.clear();
                  });
                }
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<AuthenticationMethod>(
              value: _selectedAuthMethod,
              decoration: const InputDecoration(
                labelText: 'Authentication Method',
                prefixIcon: Icon(Icons.vpn_key),
              ),
              items: AuthenticationMethod.values.map((method) {
                return DropdownMenuItem(
                  value: method,
                  child: Text(_getAuthMethodDisplayName(method)),
                );
              }).toList(),
              onChanged: (method) {
                if (method != null) {
                  setState(() => _selectedAuthMethod = method);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProtocolSpecificSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${_getProtocolDisplayName(_selectedProtocol)} Settings',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ..._buildProtocolSpecificFields(),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildProtocolSpecificFields() {
    switch (_selectedProtocol) {
      case VpnProtocol.shadowsocks:
        return _buildShadowsocksFields();
      case VpnProtocol.vmess:
        return _buildVmessFields();
      case VpnProtocol.vless:
        return _buildVlessFields();
      case VpnProtocol.trojan:
        return _buildTrojanFields();
      case VpnProtocol.hysteria:
      case VpnProtocol.hysteria2:
        return _buildHysteriaFields();
      case VpnProtocol.tuic:
        return _buildTuicFields();
      case VpnProtocol.wireguard:
        return _buildWireguardFields();
    }
  }

  List<Widget> _buildShadowsocksFields() {
    return [
      DropdownButtonFormField<String>(
        value: _protocolControllers['method']!.text.isEmpty ? 'aes-256-gcm' : _protocolControllers['method']!.text,
        decoration: InputDecoration(
          labelText: 'Encryption Method',
          errorText: _protocolErrors['method'],
        ),
        items: const [
          DropdownMenuItem(value: 'aes-256-gcm', child: Text('AES-256-GCM')),
          DropdownMenuItem(value: 'aes-128-gcm', child: Text('AES-128-GCM')),
          DropdownMenuItem(value: 'chacha20-poly1305', child: Text('ChaCha20-Poly1305')),
        ],
        onChanged: (value) {
          if (value != null) {
            _protocolControllers['method']!.text = value;
            setState(() => _protocolErrors.remove('method'));
          }
        },
      ),
      const SizedBox(height: 16),
      TextFormField(
        controller: _protocolControllers['password'],
        decoration: InputDecoration(
          labelText: 'Password',
          errorText: _protocolErrors['password'],
          prefixIcon: const Icon(Icons.lock),
        ),
        obscureText: true,
        validator: (value) => _validateRequired(value, 'Password'),
        onChanged: (_) => setState(() => _protocolErrors.remove('password')),
      ),
    ];
  }

  List<Widget> _buildVmessFields() {
    return [
      TextFormField(
        controller: _protocolControllers['uuid'],
        decoration: InputDecoration(
          labelText: 'UUID',
          errorText: _protocolErrors['uuid'],
          prefixIcon: const Icon(Icons.fingerprint),
          suffixIcon: IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _protocolControllers['uuid']!.text = const Uuid().v4();
              setState(() => _protocolErrors.remove('uuid'));
            },
          ),
        ),
        validator: (value) => _validateRequired(value, 'UUID'),
        onChanged: (_) => setState(() => _protocolErrors.remove('uuid')),
      ),
      const SizedBox(height: 16),
      TextFormField(
        controller: _protocolControllers['alterId'],
        decoration: InputDecoration(
          labelText: 'Alter ID',
          errorText: _protocolErrors['alterId'],
          prefixIcon: const Icon(Icons.numbers),
        ),
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        validator: (value) => _validateRequired(value, 'Alter ID'),
        onChanged: (_) => setState(() => _protocolErrors.remove('alterId')),
      ),
      const SizedBox(height: 16),
      DropdownButtonFormField<String>(
        value: _protocolControllers['security']!.text.isEmpty ? 'auto' : _protocolControllers['security']!.text,
        decoration: const InputDecoration(
          labelText: 'Security',
        ),
        items: const [
          DropdownMenuItem(value: 'auto', child: Text('Auto')),
          DropdownMenuItem(value: 'aes-128-gcm', child: Text('AES-128-GCM')),
          DropdownMenuItem(value: 'chacha20-poly1305', child: Text('ChaCha20-Poly1305')),
          DropdownMenuItem(value: 'none', child: Text('None')),
        ],
        onChanged: (value) {
          if (value != null) {
            _protocolControllers['security']!.text = value;
          }
        },
      ),
    ];
  }

  List<Widget> _buildVlessFields() {
    return [
      TextFormField(
        controller: _protocolControllers['uuid'],
        decoration: InputDecoration(
          labelText: 'UUID',
          errorText: _protocolErrors['uuid'],
          prefixIcon: const Icon(Icons.fingerprint),
          suffixIcon: IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _protocolControllers['uuid']!.text = const Uuid().v4();
              setState(() => _protocolErrors.remove('uuid'));
            },
          ),
        ),
        validator: (value) => _validateRequired(value, 'UUID'),
        onChanged: (_) => setState(() => _protocolErrors.remove('uuid')),
      ),
    ];
  }

  List<Widget> _buildTrojanFields() {
    return [
      TextFormField(
        controller: _protocolControllers['password'],
        decoration: InputDecoration(
          labelText: 'Password',
          errorText: _protocolErrors['password'],
          prefixIcon: const Icon(Icons.lock),
        ),
        obscureText: true,
        validator: (value) => _validateRequired(value, 'Password'),
        onChanged: (_) => setState(() => _protocolErrors.remove('password')),
      ),
      const SizedBox(height: 16),
      TextFormField(
        controller: _protocolControllers['sni'],
        decoration: const InputDecoration(
          labelText: 'SNI (Optional)',
          hintText: 'Server Name Indication',
          prefixIcon: Icon(Icons.dns),
        ),
      ),
    ];
  }

  List<Widget> _buildHysteriaFields() {
    return [
      TextFormField(
        controller: _protocolControllers['auth'],
        decoration: InputDecoration(
          labelText: 'Auth String',
          errorText: _protocolErrors['auth'],
          prefixIcon: const Icon(Icons.key),
        ),
        validator: (value) => _validateRequired(value, 'Auth String'),
        onChanged: (_) => setState(() => _protocolErrors.remove('auth')),
      ),
    ];
  }

  List<Widget> _buildTuicFields() {
    return [
      TextFormField(
        controller: _protocolControllers['uuid'],
        decoration: InputDecoration(
          labelText: 'UUID',
          errorText: _protocolErrors['uuid'],
          prefixIcon: const Icon(Icons.fingerprint),
          suffixIcon: IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _protocolControllers['uuid']!.text = const Uuid().v4();
              setState(() => _protocolErrors.remove('uuid'));
            },
          ),
        ),
        validator: (value) => _validateRequired(value, 'UUID'),
        onChanged: (_) => setState(() => _protocolErrors.remove('uuid')),
      ),
      const SizedBox(height: 16),
      TextFormField(
        controller: _protocolControllers['password'],
        decoration: InputDecoration(
          labelText: 'Password',
          errorText: _protocolErrors['password'],
          prefixIcon: const Icon(Icons.lock),
        ),
        obscureText: true,
        validator: (value) => _validateRequired(value, 'Password'),
        onChanged: (_) => setState(() => _protocolErrors.remove('password')),
      ),
    ];
  }

  List<Widget> _buildWireguardFields() {
    return [
      TextFormField(
        controller: _protocolControllers['privateKey'],
        decoration: InputDecoration(
          labelText: 'Private Key',
          errorText: _protocolErrors['privateKey'],
          prefixIcon: const Icon(Icons.vpn_key),
        ),
        obscureText: true,
        validator: (value) => _validateRequired(value, 'Private Key'),
        onChanged: (_) => setState(() => _protocolErrors.remove('privateKey')),
      ),
      const SizedBox(height: 16),
      TextFormField(
        controller: _protocolControllers['publicKey'],
        decoration: InputDecoration(
          labelText: 'Public Key',
          errorText: _protocolErrors['publicKey'],
          prefixIcon: const Icon(Icons.key),
        ),
        validator: (value) => _validateRequired(value, 'Public Key'),
        onChanged: (_) => setState(() => _protocolErrors.remove('publicKey')),
      ),
    ];
  }

  Widget _buildAdvancedOptionsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Advanced Options',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Auto Connect'),
              subtitle: const Text('Automatically connect when app starts'),
              value: _autoConnect,
              onChanged: (value) => setState(() => _autoConnect = value),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: ElevatedButton(
            onPressed: _isLoading ? null : _saveConfiguration,
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(widget.configuration != null ? 'Update' : 'Save'),
          ),
        ),
      ],
    );
  }

  // Validation methods
  String? _validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Configuration name is required';
    }
    if (value.trim().length < 3) {
      return 'Name must be at least 3 characters';
    }
    return null;
  }

  String? _validateServerAddress(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Server address is required';
    }
    // Basic validation - could be enhanced with regex for IP/domain validation
    if (value.trim().length < 3) {
      return 'Invalid server address';
    }
    return null;
  }

  String? _validateServerPort(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Server port is required';
    }
    final port = int.tryParse(value.trim());
    if (port == null || port < 1 || port > 65535) {
      return 'Port must be between 1 and 65535';
    }
    return null;
  }

  String? _validateRequired(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    return null;
  }

  // Helper methods
  String _getProtocolDisplayName(VpnProtocol protocol) {
    switch (protocol) {
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

  String _getAuthMethodDisplayName(AuthenticationMethod method) {
    switch (method) {
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

  Map<String, dynamic> _buildProtocolSpecificConfig() {
    final config = <String, dynamic>{};
    
    switch (_selectedProtocol) {
      case VpnProtocol.shadowsocks:
        config['method'] = _protocolControllers['method']!.text;
        config['password'] = _protocolControllers['password']!.text;
        break;
      case VpnProtocol.vmess:
        config['uuid'] = _protocolControllers['uuid']!.text;
        config['alterId'] = int.tryParse(_protocolControllers['alterId']!.text) ?? 0;
        config['security'] = _protocolControllers['security']!.text;
        break;
      case VpnProtocol.vless:
        config['uuid'] = _protocolControllers['uuid']!.text;
        break;
      case VpnProtocol.trojan:
        config['password'] = _protocolControllers['password']!.text;
        if (_protocolControllers['sni']!.text.isNotEmpty) {
          config['sni'] = _protocolControllers['sni']!.text;
        }
        break;
      case VpnProtocol.hysteria:
      case VpnProtocol.hysteria2:
        config['auth'] = _protocolControllers['auth']!.text;
        break;
      case VpnProtocol.tuic:
        config['uuid'] = _protocolControllers['uuid']!.text;
        config['password'] = _protocolControllers['password']!.text;
        break;
      case VpnProtocol.wireguard:
        config['privateKey'] = _protocolControllers['privateKey']!.text;
        config['publicKey'] = _protocolControllers['publicKey']!.text;
        break;
    }
    
    return config;
  }

  Future<void> _saveConfiguration() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final config = VpnConfiguration(
        id: widget.configuration?.id ?? const Uuid().v4(),
        name: _nameController.text.trim(),
        serverAddress: _serverAddressController.text.trim(),
        serverPort: int.parse(_serverPortController.text.trim()),
        protocol: _selectedProtocol,
        authMethod: _selectedAuthMethod,
        protocolSpecificConfig: _buildProtocolSpecificConfig(),
        autoConnect: _autoConnect,
        createdAt: widget.configuration?.createdAt ?? DateTime.now(),
        lastUsed: widget.configuration?.lastUsed,
      );

      // Validate configuration
      await _configManager.validateConfiguration(config);
      
      // Save configuration
      if (widget.configuration != null) {
        await _configManager.updateConfiguration(config);
      } else {
        await _configManager.saveConfiguration(config);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.configuration != null
                  ? 'Configuration updated successfully'
                  : 'Configuration saved successfully',
            ),
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save configuration: $e'),
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