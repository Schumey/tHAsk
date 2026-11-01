import 'package:flutter/material.dart';

import 'l10n.dart';
import 'models.dart';
import 'store.dart';

/// Sortierungen einer Liste, wie in der Integration (`TASK_SORTS`).
const listSorts = ['manual', 'priority', 'due', 'title', 'created'];

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
        decoration: InputDecoration(labelText: label ?? tr('name')),
        onSubmitted: (value) => Navigator.pop(context, value),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(tr('cancel'))),
        FilledButton(onPressed: () => Navigator.pop(context, controller.text), child: Text(tr('ok'))),
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
          ListTile(title: Text(tr('group'))),
          for (final group in store.groups)
            ListTile(
              leading: Icon(group == current ? Icons.check : Icons.folder_outlined),
              title: Text(group),
              selected: group == current,
              onTap: () => Navigator.pop(context, GroupChoice(group)),
            ),
          ListTile(
            leading: Icon(current == null ? Icons.check : Icons.folder_off_outlined),
            title: Text(tr('no_group')),
            selected: current == null,
            onTap: () => Navigator.pop(context, const GroupChoice(null)),
          ),
          ListTile(
            leading: const Icon(Icons.create_new_folder_outlined),
            title: Text(tr('new_group_menu')),
            onTap: () => Navigator.pop(context, const GroupChoice(newGroup)),
          ),
        ],
      ),
    ),
  );
  if (picked?.value != newGroup) return picked;
  if (!context.mounted) return null;
  final name = await showNameDialog(context, title: tr('new_group'), label: tr('group_name'));
  return name == null ? null : GroupChoice(name);
}

Future<String?> pickSort(BuildContext context, {required String current}) => showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(title: Text(tr('sort_by'))),
            for (final key in listSorts)
              ListTile(
                leading: Icon(key == current ? Icons.radio_button_checked : Icons.radio_button_unchecked),
                title: Text(tr('sort_$key')),
                selected: key == current,
                onTap: () => Navigator.pop(context, key),
              ),
          ],
        ),
      ),
    );

/// Für wen eine Liste ist: Personen ankreuzen, keine = alle. Liefert die Auswahl oder null bei Abbruch.
Future<List<String>?> pickMembers(BuildContext context, ThaskStore store, TaskList list) async {
  final List<({String id, String name})> users;
  try {
    users = await store.loadUsers();
  } on Exception catch (e) {
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    return null;
  }
  if (!context.mounted) return null;
  final chosen = <String>{...list.members};
  return showDialog<List<String>>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text(tr('members')),
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CheckboxListTile(
                value: chosen.isEmpty,
                title: Text(tr('members_all')),
                onChanged: (_) => setState(chosen.clear),
              ),
              const Divider(),
              for (final user in users)
                CheckboxListTile(
                  value: chosen.contains(user.id),
                  title: Text(user.name),
                  onChanged: (on) => setState(() => on! ? chosen.add(user.id) : chosen.remove(user.id)),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                child: Text(tr('members_hint'), style: Theme.of(context).textTheme.bodySmall),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(tr('cancel'))),
          FilledButton(
            onPressed: () => Navigator.pop(context, [for (final u in users) if (chosen.contains(u.id)) u.id]),
            child: Text(tr('ok')),
          ),
        ],
      ),
    ),
  );
}

Future<bool> confirmDelete(BuildContext context, String name) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('delete_list_q')),
        content: Text(tr('delete_list_text', [name])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(tr('cancel'))),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(tr('delete'))),
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
      title: Text(tr('new_list')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _name,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(labelText: tr('name')),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.folder_outlined),
            title: Text(_group ?? tr('no_group')),
            trailing: const Icon(Icons.arrow_drop_down),
            onTap: () async {
              final choice = await pickGroup(context, widget.store, current: _group);
              if (choice != null) setState(() => _group = choice.value);
            },
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(tr('cancel'))),
        FilledButton(onPressed: _submit, child: Text(tr('create'))),
      ],
    );
  }
}
