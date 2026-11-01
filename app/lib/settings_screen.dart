import 'package:flutter/material.dart';

import 'l10n.dart';
import 'store.dart';

/// Optionen der Integration, wie die Seite „Einstellungen“ der Weboberfläche. Nur für Administratoren,
/// nur mit Verbindung; jede Änderung wird sofort gespeichert und gilt dann überall.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.store});

  final ThaskStore store;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Map<String, dynamic>? _options;
  List<String> _services = const [];
  String? _error;
  final _days = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _days.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final result = await widget.store.loadOptions();
      if (!mounted) return;
      setState(() {
        _options = Map<String, dynamic>.from(result['options'] as Map);
        _services = [for (final s in result['notify_services'] as List? ?? const []) '$s'];
        _days.text = '${_options!['auto_clear_days'] ?? 0}';
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  Future<void> _save(String key, Object value) async {
    final previous = _options![key];
    setState(() => _options![key] = value);
    try {
      final options = await widget.store.updateOptions({key: value});
      if (mounted) setState(() => _options = options);
    } catch (e) {
      if (!mounted) return;
      setState(() => _options![key] = previous);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  List<String> _list(String key) => [for (final v in _options![key] as List? ?? const []) '$v'];

  void _toggleIn(String key, String value, bool on) {
    final values = _list(key);
    on ? values.add(value) : values.remove(value);
    _save(key, values);
  }

  void _saveDays() {
    final days = (int.tryParse(_days.text.trim()) ?? 0).clamp(0, 3650);
    _days.text = '$days';
    if (days != (_options!['auto_clear_days'] ?? 0)) _save('auto_clear_days', days);
  }

  Widget _section(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
        child: Text(text, style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Theme.of(context).colorScheme.primary)),
      );

  Widget _radios(String key, List<String> values) => RadioGroup<String>(
        groupValue: _options![key] as String?,
        onChanged: (value) {
          if (value != null) _save(key, value);
        },
        child: Column(
          children: [for (final value in values) RadioListTile<String>(value: value, title: Text(tr('${key}_$value')))],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final options = _options;
    return Scaffold(
      appBar: AppBar(title: Text(tr('settings'))),
      body: _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(tr('settings_unavailable'), textAlign: TextAlign.center),
                    const SizedBox(height: 8),
                    Text(_error!, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(height: 16),
                    FilledButton(onPressed: _load, child: Text(tr('retry'))),
                  ],
                ),
              ),
            )
          : options == null
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  children: [
                    _section(tr('opt_overdue_in_today')),
                    _radios('overdue_in_today', const ['section', 'mixed', 'separate']),
                    _section(tr('opt_week_mode')),
                    _radios('week_mode', const ['calendar', 'rolling']),
                    _section(tr('opt_views_apart')),
                    SwitchListTile(
                      value: options['separate_week'] == true,
                      onChanged: (on) => _save('separate_week', on),
                      title: Text(tr('opt_separate_week')),
                      subtitle: Text(tr('opt_separate_week_hint')),
                    ),
                    SwitchListTile(
                      value: options['separate_month'] == true,
                      onChanged: (on) => _save('separate_month', on),
                      title: Text(tr('opt_separate_month')),
                      subtitle: Text(tr('opt_separate_month_hint')),
                    ),
                    _section(tr('opt_hidden_views')),
                    for (final view in const ['important', 'planned', 'this_week', 'this_month'])
                      CheckboxListTile(
                        value: _list('hidden_views').contains(view),
                        onChanged: (on) => _toggleIn('hidden_views', view, on ?? false),
                        title: Text(tr('view_$view')),
                      ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                      child: Text(tr('opt_hidden_views_hint'), style: Theme.of(context).textTheme.bodySmall),
                    ),
                    _section(tr('opt_auto_clear')),
                    ListTile(
                      title: Text(tr('opt_auto_clear_days')),
                      subtitle: Text(tr('opt_auto_clear_hint')),
                      trailing: SizedBox(
                        width: 72,
                        child: Focus(
                          onFocusChange: (focused) {
                            if (!focused) _saveDays();
                          },
                          child: TextField(
                            controller: _days,
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.end,
                            decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()),
                            onSubmitted: (_) => _saveDays(),
                          ),
                        ),
                      ),
                    ),
                    _section(tr('opt_reminder_targets')),
                    if (_services.isEmpty && _list('reminder_targets').isEmpty)
                      ListTile(title: Text(tr('no_notify')))
                    else
                      for (final service in {..._services, ..._list('reminder_targets')}.toList()..sort())
                        CheckboxListTile(
                          value: _list('reminder_targets').contains(service),
                          onChanged: (on) => _toggleIn('reminder_targets', service, on ?? false),
                          title: Text('notify.$service'),
                        ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      child: Text(tr('opt_reminder_targets_hint'), style: Theme.of(context).textTheme.bodySmall),
                    ),
                  ],
                ),
    );
  }
}
