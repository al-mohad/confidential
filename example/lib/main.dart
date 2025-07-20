import 'package:flutter/material.dart';

// Import the generated obfuscated literals
import 'generated/confidential.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Confidential Example',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Dart Confidential Example'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  String? _deobfuscatedApiKey;
  List<String>? _deobfuscatedLibraries;
  List<String>? _deobfuscatedPaths;
  List<String>? _deobfuscatedDigests;
  String? _deobfuscatedVaultKey;
  String? _error;

  void _deobfuscateSecrets() {
    setState(() {
      _error = null;
      try {
        // Use the actual generated obfuscated values
        // Note: The deobfuscation methods are not implemented in this demo,
        // so we'll catch the UnimplementedError and show the obfuscated data structure

        try {
          _deobfuscatedApiKey = Secrets.apiKey.value;
        } catch (e) {
          _deobfuscatedApiKey =
              'Obfuscated (${Secrets.apiKey.secret.data.length} bytes, nonce: ${Secrets.apiKey.secret.nonce})';
        }

        try {
          _deobfuscatedLibraries = List<String>.from(
            Secrets.suspiciousDynamicLibraries.value,
          );
        } catch (e) {
          _deobfuscatedLibraries = [
            'Obfuscated (${Secrets.suspiciousDynamicLibraries.secret.data.length} bytes, nonce: ${Secrets.suspiciousDynamicLibraries.secret.nonce})',
          ];
        }

        try {
          _deobfuscatedPaths = List<String>.from(
            Secrets.suspiciousFilePaths.value,
          );
        } catch (e) {
          _deobfuscatedPaths = [
            'Obfuscated (${Secrets.suspiciousFilePaths.secret.data.length} bytes, nonce: ${Secrets.suspiciousFilePaths.secret.nonce})',
          ];
        }

        // For demo purposes, show some example values for the missing namespaces
        _deobfuscatedDigests = [
          'Example: 7a6820614ee600bbaed493522c221c0d9095f3b4d7839415ffab16cbf61767ad',
          'Example: cf84a70a41072a42d0f25580b5cb54d6a9de45db824bbb7ba85d541b099fd49f',
          'Example: c1a5d45809269301993d028313a5c4a5d8b2f56de9725d4d1af9da1ccf186f30',
        ];

        _deobfuscatedVaultKey =
            'Example: com.example.app.keys.secret_vault_private_key';
      } catch (e) {
        _error = 'Failed to deobfuscate: $e';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              'This example demonstrates how to use dart-confidential to obfuscate sensitive literals in your Flutter app.',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 20),

            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Build Process:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text('1. Run: dart run build_runner build'),
                  const Text(
                    '2. Generated code: lib/generated/confidential.dart',
                  ),
                  const Text('3. Tap button below to simulate deobfuscation'),
                ],
              ),
            ),
            const SizedBox(height: 20),

            if (_error != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade300),
                ),
                child: Text(
                  'Error: $_error',
                  style: TextStyle(color: Colors.red.shade800),
                ),
              ),
              const SizedBox(height: 20),
            ],

            if (_deobfuscatedApiKey != null) ...[
              _buildSecretCard('API Key', _deobfuscatedApiKey!, Icons.key),
              const SizedBox(height: 16),
            ],

            if (_deobfuscatedLibraries != null) ...[
              _buildListCard(
                'Suspicious Dynamic Libraries',
                _deobfuscatedLibraries!,
                Icons.warning,
              ),
              const SizedBox(height: 16),
            ],

            if (_deobfuscatedPaths != null) ...[
              _buildListCard(
                'Suspicious File Paths',
                _deobfuscatedPaths!,
                Icons.folder,
              ),
              const SizedBox(height: 16),
            ],

            if (_deobfuscatedDigests != null) ...[
              _buildListCard(
                'Trusted SPKI Digests',
                _deobfuscatedDigests!,
                Icons.security,
              ),
              const SizedBox(height: 16),
            ],

            if (_deobfuscatedVaultKey != null) ...[
              _buildSecretCard(
                'Secret Vault Key Tag',
                _deobfuscatedVaultKey!,
                Icons.vpn_key,
              ),
              const SizedBox(height: 16),
            ],
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _deobfuscateSecrets,
        tooltip: 'Deobfuscate Secrets',
        icon: const Icon(Icons.lock_open),
        label: const Text('Deobfuscate'),
      ),
    );
  }

  Widget _buildSecretCard(String title, String value, IconData icon) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Theme.of(context).primaryColor),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Text(
                value,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListCard(String title, List<String> items, IconData icon) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Theme.of(context).primaryColor),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: items
                    .map(
                      (item) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text(
                          '• $item',
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
