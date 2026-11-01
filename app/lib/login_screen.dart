import 'package:flutter/material.dart';

import 'l10n.dart';
import 'store.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.store});

  final ThaskStore store;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _address = TextEditingController();
  final _token = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _address.dispose();
    _token.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.store.login(_address.text, _token.text);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('tHAsk', style: theme.textTheme.displaySmall, textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                  Text(
                    tr('connect_title'),
                    style: theme.textTheme.bodyLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  TextField(
                    controller: _address,
                    keyboardType: TextInputType.url,
                    autocorrect: false,
                    enabled: !_busy,
                    decoration: InputDecoration(
                      labelText: tr('address'),
                      hintText: tr('address_hint'),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _token,
                    obscureText: true,
                    autocorrect: false,
                    enableSuggestions: false,
                    enabled: !_busy,
                    onSubmitted: (_) => _submit(),
                    decoration: InputDecoration(
                      labelText: tr('token'),
                      helperText: tr('token_help'),
                      helperMaxLines: 2,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
                  ],
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _busy ? null : _submit,
                    child: _busy
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : Text(tr('connect')),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
