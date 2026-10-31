import 'package:flutter/material.dart';

import 'store.dart';

/// Sortierungen einer Liste, wie in der Integration (`TASK_SORTS`).
const listSorts = {
  'manual': 'Manuell',
  'priority': 'Priorität',
  'due': 'Fälligkeit',
  'title': 'Alphabetisch',
  'created': 'Erstellungsdatum',
};

/// Ergebnis der Gruppenauswahl; [value] null heißt „Keine Gruppe“ (Abbrechen liefert gar kein Ergebnis).
class GroupChoice {
  const GroupChoice(this.value);
  final String? value;
}

/// Fragt einen Namen ab; null bei Abbrechen oder leerer Eingabe.
Future<String?> showNameDialog(BuildContext context, {required String title, String initial = '', String? label}) async {
  final controller = TextEditingController(text: initial);
  final name = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(labelText: label ?? 'Name'),
        onSubmitted: (value) => Navigator.pop(context, value),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Abbrechen')),
        FilledButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('OK')),
      ],
    ),
  );
  controller.dispose();
  final trimmed = name?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}

/// Gruppe wählen: vorhandene Gruppen, „Keine Gruppe“ oder „Neue Gruppe …“. Verhindert Tippfehler und doppelte Gruppen.
Future<GroupChoice?> pickGroup(BuildContext context, ThaskStore store, {String? current}) async {
  const newGroup = '\u0000new';
  final picked = await showModalBottomSheet<GroupChoice>(
    context: context,
    builder: (context) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          const ListTile(title: Text('Gruppe')),
          for (final group in store.groups)
            ListTile(
              leading: Icon(group == current ? Icons.check : Icons.folder_outlined),
              title: Text(group),
              selected: group == current,
              onTap: () => Navigator.pop(context, GroupChoice(group)),
            ),
          ListTile(
            leading: Icon(current == null ? Icons.check : Icons.folder_off_outlined),
            title: const Text('Keine Gruppe'),
            selected: current == null,
            onTap: () => Navigator.pop(context, const GroupChoice(null)),
          ),
          ListTile(
            leading: const Icon(Icons.create_new_folder_outlined),
            title: const Text('Neue Gruppe …'),
            onTap: () => Navigator.pop(context, const GroupChoice(newGroup)),
          ),
        ],
      ),
    ),
  );
  if (picked?.value != newGroup) return picked;
  if (!context.mounted) return null;
  final name = await showNameDialog(context, title: 'Neue Gruppe', label: 'Name der Gruppe');
  return name == null ? null : GroupChoice(name);
}

Future<String?> pickSort(BuildContext context, {required String current}) => showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const ListTile(title: Text('Sortieren nach')),
            for (final MapEntry(:key, :value) in listSorts.entries)
              ListTile(
                leading: Icon(key == current ? Icons.radio_button_checked : Icons.radio_button_unchecked),
                title: Text(value),
                selected: key == current,
                onTap: () => Navigator.pop(context, key),
              ),
          ],
        ),
      ),
    );

Future<bool> confirmDelete(BuildContext context, String name) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Liste löschen?'),
        content: Text('„$name“ wird mit allen Aufgaben gelöscht.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Abbrechen')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Löschen')),
        ],
      ),
    ) ??
    false;

/// Neue Liste: Name und optional eine Gruppe.
Future<({String name, String? group})?> showListDialog(BuildContext context, ThaskStore store) =>
    showDialog<({String name, String? group})>(
      context: context,
      builder: (_) => _NewListDialog(store: store),
    );

class _NewListDialog extends StatefulWidget {
  const _NewListDialog({required this.store});

  final ThaskStore store;

  @override
  State<_NewListDialog> createState() => _NewListDialogState();
}

class _NewListDialogState extends State<_NewListDialog> {
  final _name = TextEditingController();
  String? _group;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _name.text.trim();
    if (name.isNotEmpty) Navigator.pop(context, (name: name, group: _group));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Neue Liste'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _name,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Name'),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.folder_outlined),
            title: Text(_group ?? 'Keine Gruppe'),
            trailing: const Icon(Icons.arrow_drop_down),
            onTap: () async {
              final choice = await pickGroup(context, widget.store, current: _group);
              if (choice != null) setState(() => _group = choice.value);
            },
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Abbrechen')),
        FilledButton(onPressed: _submit, child: const Text('Anlegen')),
      ],
    );
  }
}
