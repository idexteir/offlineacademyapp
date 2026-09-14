import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';
import '../../core/config/providers.dart';
import '../../core/network/api_client.dart';

class ConnectionScreen extends ConsumerStatefulWidget {
  const ConnectionScreen({super.key});

  @override
  ConsumerState<ConnectionScreen> createState() => _ConnectionScreenState();
}

class _ConnectionScreenState extends ConsumerState<ConnectionScreen> {
  final _controller = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _testing = false;
  String? _statusMessage;
  bool _isError = false;

  @override
  void initState() {
    super.initState();
    // Pre-fill with saved URL if present.
    final saved = ref.read(serverUrlProvider);
    if (saved != null && saved.isNotEmpty) {
      _controller.text = saved;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _testConnection() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _testing = true;
      _statusMessage = null;
      _isError = false;
    });

    final rawUrl = _controller.text.trim().replaceAll(RegExp(r'/+$'), '');
    final client = OfflineAcademyClient(baseUrl: rawUrl);

    try {
      final result = await client.getSettings();
      switch (result) {
        case ApiSuccess(:final data):
          // Validate that this actually looks like an OfflineAcademy server
          // by checking for expected keys in the response.
          if (!data.containsKey('coursesRoot') && !data.containsKey('autoFetchQuizzes')) {
            setState(() {
              _statusMessage = 'Invalid OfflineAcademy server';
              _isError = true;
            });
            return;
          }
          // Save URL and navigate.
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('server_url', rawUrl);
          ref.read(serverUrlProvider.notifier).state = rawUrl;
          if (mounted) context.go('/courses');

        case ApiError(:final message):
          setState(() {
            _statusMessage = message;
            _isError = true;
          });
      }
    } finally {
      client.dispose();
      if (mounted) setState(() => _testing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header
                    const Icon(Icons.school, size: 64, color: Color(0xFF6C63FF)),
                    const SizedBox(height: 16),
                    Text(
                      'OfflineAcademy',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Enter your server URL to connect',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.white54,
                          ),
                    ),
                    const SizedBox(height: 40),

                    // URL field
                    TextFormField(
                      controller: _controller,
                      keyboardType: TextInputType.url,
                      autocorrect: false,
                      enableSuggestions: false,
                      decoration: const InputDecoration(
                        labelText: 'Server URL',
                        hintText: 'http://192.168.1.100:6969',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.link),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter a server URL';
                        }
                        final trimmed = value.trim();
                        if (!trimmed.startsWith('http://') && !trimmed.startsWith('https://')) {
                          return 'URL must start with http:// or https://';
                        }
                        return null;
                      },
                      onFieldSubmitted: (_) => _testConnection(),
                    ),
                    const SizedBox(height: 8),

                    // Hint
                    Text(
                      'Examples:\n'
                      '  http://192.168.1.100:6969  (LAN)\n'
                      '  http://10.0.2.2:6969  (emulator)\n'
                      '  https://academy.example.com',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white38),
                    ),
                    const SizedBox(height: 24),

                    // Status message
                    if (_statusMessage != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _isError
                              ? Colors.red.withAlpha(30)
                              : Colors.green.withAlpha(30),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _isError ? Colors.red.shade700 : Colors.green.shade700,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _isError ? Icons.error_outline : Icons.check_circle_outline,
                              color: _isError ? Colors.red.shade400 : Colors.green.shade400,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _statusMessage!,
                                style: TextStyle(
                                  color: _isError ? Colors.red.shade300 : Colors.green.shade300,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (_statusMessage != null) const SizedBox(height: 16),

                    // Connect button
                    FilledButton(
                      onPressed: _testing ? null : _testConnection,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: _testing
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Test Connection & Connect'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
