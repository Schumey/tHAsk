import 'package:flutter/material.dart';

import 'models.dart';
import 'store.dart';

/// Welche Ansicht gerade gezeigt wird: eine intelligente Liste oder eine eigene.
sealed class ViewRef {
  const ViewRef();
}

class MyDayView extends ViewRef {
  const MyDayView();
}

class ThisWeekView extends ViewRef {
  const ThisWeekView();
}

class ListRef extends ViewRef {
  const ListRef(this.listId);
  final String listId;
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.store});

  final ThaskStore store;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  ViewRef _view = const MyDayView();
  final _entry = TextEditingController();
  bool _sending = false;

  ThaskStore get store => widget.store;

  @override
  void dispose() {
    _entry.dispose();
    super.dispose();
  }

  String get _title => switch (_view) {
        MyDayView() => 'Mein Tag',
        ThisWeekView() => 'Diese Woche',
        ListRef(:final listId) => store.list(listId)?.name ?? 'Liste',
      };

  List<Task> get _tasks => switch (_view) {
        MyDayView() => store.myDay,
        ThisWeekView() => store.thisWeek,
        ListRef(:final listId) => store.tasksOf(listId),
      };

  /// Liste, in die neue Aufgaben kommen: die gewählte, sonst die erste.
  String? get _targetList => switch (_view) {
        ListRef(:final listId) => listId,
        _ => store.lists.isEmpty ? null : store.lists.first.id,
      };

  Future<void> _guard(Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _submit() async {
    final text = _entry.text.trim();
    final listId = _targetList;
    if (text.isEmpty || listId == null || _sending) return;
    setState(() => _sending = true);
    await _guard(() => store.addQuick(listId, text, myDay: _view is MyDayView));
    if (!mounted) return;
    setState(() => _sending = false);
    if (store.connection == LinkState.connected) _entry.clear();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final tasks = _tasks;
        final open = tasks.where((t) => !t.completed).toList();
        final done = tasks.where((t) => t.completed).toList();
        final listView = _view is ListRef;
        return Scaffold(
          appBar: AppBar(
            title: Text(_title),
            actions: [
              if (listView)
                IconButton(
                  tooltip: 'Erledigte löschen',
                  icon: const Icon(Icons.cleaning_services_outlined),
                  onPressed: done.isEmpty
                      ? null
                      : () => _guard(() => store.clearCompleted((_view as ListRef).listId)),
                ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'logout') store.logout();
                },
                itemBuilder: (_) => const [PopupMenuItem(value: 'logout', child: Text('Abmelden'))],
              ),
            ],
          ),
          drawer: _buildDrawer(context),
          body: Column(
            children: [
              if (store.connection != LinkState.connected) _ConnectionBanner(store: store),
              Expanded(
                child: tasks.isEmpty
                    ? Center(
                        child: Text(
                          store.connection == LinkState.connected ? 'Keine Aufgaben' : '',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      )
                    : ListView(
                        children: [
                          for (final task in open) _TaskTile(task: task, store: store, guard: _guard),
                          if (done.isNotEmpty)
                            ExpansionTile(
                              title: Text('Erledigt (${done.length})'),
                              children: [for (final task in done) _TaskTile(task: task, store: store, guard: _guard)],
                            ),
                        ],
                      ),
              ),
              if (_targetList != null) _buildEntry(context),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEntry(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
        child: TextField(
          controller: _entry,
          enabled: !_sending,
          textInputAction: TextInputAction.send,
          onSubmitted: (_) => _submit(),
          decoration: InputDecoration(
            hintText: 'Aufgabe hinzufügen, z. B. „Steuer KW 47 !“',
            border: const OutlineInputBorder(),
            isDense: true,
            suffixIcon: IconButton(icon: const Icon(Icons.add), onPressed: _submit),
          ),
        ),
      ),
    );
  }

  Widget _buildDrawer(BuildContext context) {
    void select(ViewRef view) {
      setState(() => _view = view);
      Navigator.pop(context);
    }

    final lists = store.lists;
    final groups = <String?>[];
    for (final list in lists) {
      if (!groups.contains(list.group)) groups.add(list.group);
    }
    return Drawer(
      child: SafeArea(
        child: ListView(
          children: [
            ListTile(
              leading: const Icon(Icons.wb_sunny_outlined),
              title: const Text('Mein Tag'),
              selected: _view is MyDayView,
              trailing: _count(store.myDay.where((t) => !t.completed).length),
              onTap: () => select(const MyDayView()),
            ),
            ListTile(
              leading: const Icon(Icons.date_range_outlined),
              title: const Text('Diese Woche'),
              selected: _view is ThisWeekView,
              trailing: _count(store.thisWeek.length),
              onTap: () => select(const ThisWeekView()),
            ),
            const Divider(),
            for (final group in groups) ...[
              if (group != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Text(group, style: Theme.of(context).textTheme.labelLarge),
                ),
              for (final list in lists.where((l) => l.group == group))
                ListTile(
                  leading: const Icon(Icons.list),
                  title: Text(list.name),
                  selected: _view is ListRef && (_view as ListRef).listId == list.id,
                  trailing: _count(store.openCount(list.id)),
                  onTap: () => select(ListRef(list.id)),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget? _count(int n) => n == 0 ? null : Text('$n');
}

class _ConnectionBanner extends StatelessWidget {
  const _ConnectionBanner({required this.store});

  final ThaskStore store;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final connecting = store.connection == LinkState.connecting;
    return Material(
      color: scheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            if (connecting)
              const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
            else
              Icon(Icons.cloud_off, size: 18, color: scheme.onErrorContainer),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                connecting ? 'Verbinde …' : (store.error ?? 'Nicht verbunden'),
                style: TextStyle(color: scheme.onErrorContainer),
              ),
            ),
            if (!connecting) TextButton(onPressed: store.resume, child: const Text('Erneut versuchen')),
          ],
        ),
      ),
    );
  }
}

class _TaskTile extends StatelessWidget {
  const _TaskTile({required this.task, required this.store, required this.guard});

  final Task task;
  final ThaskStore store;
  final Future<void> Function(Future<void> Function()) guard;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final overdue = task.isOverdue(store.today);
    final due = task.due;
    final dueText = due == null ? null : '${due.label(store.today)}${task.dueTime != null ? ', ${task.dueTime}' : ''}';
    final steps = task.steps.isEmpty ? null : '${task.steps.where((s) => s.completed).length}/${task.steps.length}';
    return Dismissible(
      key: ValueKey(task.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: theme.colorScheme.error,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: Icon(Icons.delete_outline, color: theme.colorScheme.onError),
      ),
      onDismissed: (_) => guard(() => store.deleteTask(task)),
      child: ListTile(
        leading: Checkbox(
          value: task.completed,
          shape: const CircleBorder(),
          onChanged: (value) => guard(() => store.setCompleted(task, value ?? false)),
        ),
        title: Text(
          task.title,
          style: task.completed ? const TextStyle(decoration: TextDecoration.lineThrough) : null,
        ),
        subtitle: (dueText ?? steps) == null
            ? null
            : Wrap(
                spacing: 12,
                children: [
                  if (dueText != null)
                    Text(dueText, style: TextStyle(color: overdue ? theme.colorScheme.error : null)),
                  if (task.recurrence != null) const Icon(Icons.repeat, size: 14),
                  if (steps != null) Text(steps),
                ],
              ),
        trailing: IconButton(
          tooltip: 'Wichtig',
          icon: Icon(task.important ? Icons.star : Icons.star_border,
              color: task.important ? Colors.amber.shade700 : null),
          onPressed: () => guard(() => store.setImportant(task, !task.important)),
        ),
      ),
    );
  }
}
