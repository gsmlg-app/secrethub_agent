import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:secrethub_agent/secrethub_agent.dart';

void main() {
  runApp(const SecretHubExampleApp());
}

/// Shows plugin registration only; no Core connection or secret data is used.
class SecretHubExampleApp extends StatefulWidget {
  const SecretHubExampleApp({super.key});

  @override
  State<SecretHubExampleApp> createState() => _SecretHubExampleAppState();
}

class _SecretHubExampleAppState extends State<SecretHubExampleApp> {
  String _platformStatus = 'Checking native registration…';

  @override
  void initState() {
    super.initState();
    _checkRegistration();
  }

  Future<void> _checkRegistration() async {
    String status;
    try {
      final version = await SecretHubAgent().getPlatformVersion();
      status = version == null || version.isEmpty
          ? 'Native registration unavailable.'
          : 'Native plugin registered: $version';
    } on PlatformException {
      status = 'Native registration check failed.';
    } on MissingPluginException {
      status = 'Native plugin unavailable on this platform.';
    }
    if (!mounted) return;
    setState(() => _platformStatus = status);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SecretHub Agent',
      home: Scaffold(
        appBar: AppBar(title: const Text('SecretHub Agent')),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                'Plugin bootstrap',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),
              Text(_platformStatus),
              const SizedBox(height: 24),
              const Text(
                'The Agent SDK is not implemented yet. Enrollment, secret reads, '
                'and offline access are unavailable.',
              ),
              const SizedBox(height: 16),
              const Text(
                'The next gate is native non-exportable keys, CSR, Core certificate '
                'issuance, and mTLS WSS on real iOS and Android devices.',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
