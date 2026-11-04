import 'dart:io';

import 'package:flutter/material.dart';

import 'l10n.dart';
import 'updater.dart';

/// „Nach Updates suchen“: prüft (oder nimmt das schon gefundene [update]), lädt und installiert.
Future<void> showUpdateDialog(BuildContext context, Updater updater, {AppUpdate? update}) => showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _UpdateDialog(updater: updater, found: update),
    );

enum _Step { checking, upToDate, available, downloading, installing, failed }

class _UpdateDialog extends StatefulWidget {
  const _UpdateDialog({required this.updater, this.found});

  final Updater updater;
  final AppUpdate? found;

  @override
  State<_UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<_UpdateDialog> {
  _Step _step = _Step.checking;
  AppUpdate? _update;
  String _current = '';
  double? _progress;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    setState(() => _step = _Step.checking);
    try {
      _current = await widget.updater.currentVersion();
      final update = widget.found ?? await widget.updater.check();
      if (!mounted) return;
      setState(() {
        _update = update;
        _step = update == null ? _Step.upToDate : _Step.available;
      });
    } catch (e) {
      _fail(e);
    }
  }

  Future<void> _install() async {
    setState(() {
      _step = _Step.downloading;
      _progress = null;
    });
    try {
      final file = await widget.updater.download(_update!, (p) {
        if (mounted) setState(() => _progress = p);
      });
      if (!mounted) return;
      setState(() => _step = _Step.installing);
      await widget.updater.install(file);
      if (mounted && Platform.isAndroid) Navigator.pop(context);
    } catch (e) {
      _fail(e);
    }
  }

  void _fail(Object e) {
    if (!mounted) return;
    setState(() {
      _error = '$e';
      _step = _Step.failed;
    });
  }

  String get _size => '${(_update!.size / 1048576).toStringAsFixed(1)} MB';

  @override
  Widget build(BuildContext context) {
    final close = TextButton(onPressed: () => Navigator.pop(context), child: Text(tr('close')));
    final (Widget content, List<Widget> actions) = switch (_step) {
      _Step.checking => (_busy(tr('update_checking'), null), const <Widget>[]),
      _Step.upToDate => (Text(tr('update_none', [_current])), [close]),
      _Step.available => (
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(tr('update_available', [_update!.version, _current])),
              const SizedBox(height: 8),
              Text(
                '$_size · ${tr(Platform.isAndroid ? 'update_hint_android' : 'update_hint_windows')}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          [
            TextButton(onPressed: () => Navigator.pop(context), child: Text(tr('update_later'))),
            FilledButton(onPressed: _install, child: Text(tr('update_install'))),
          ]
        ),
      _Step.downloading => (_busy(tr('update_downloading'), _progress), const <Widget>[]),
      _Step.installing => (_busy(tr('update_installing'), null), const <Widget>[]),
      _Step.failed => (
          Text('${tr('update_failed')}\n\n$_error'),
          [close, FilledButton(onPressed: _update == null ? _check : _install, child: Text(tr('retry')))]
        ),
    };
    return AlertDialog(title: Text(tr('check_updates')), content: content, actions: actions);
  }

  Widget _busy(String text, double? progress) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(text),
          const SizedBox(height: 16),
          LinearProgressIndicator(value: progress),
        ],
      );
}
