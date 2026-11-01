import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'l10n.dart';
import 'list_dialogs.dart';
import 'models.dart';
import 'priority.dart';
import 'settings_screen.dart';
import 'store.dart';
import 'task_detail_screen.dart';
import 'views.dart';

const _ranges = ['all', 'week', 'month', 'quarter', 'year'];

/// Ab dieser Breite stehen Navigation, Liste und Details nebeneinander (Windows, Tablet quer).
const wideLayoutWidth = 900.0;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.store, this.launch});

  final ThaskStore store;

  /// Aufforderung aus dem Android-Widget: Ansicht öffnen und Schnelleingabe fokussieren.
  final ValueNotifier<Uri?>? launch;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  ViewRef _view = const TodayView();

  /// Im breiten Layout die Aufgabe, deren Details rechts stehen.
  String? _selected;
  final _entry = TextEditingController();
  bool _sending = false;

  ThaskStore get store => widget.store;

  final _entryFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    widget.launch?.addListener(_handleLaunch);
    WidgetsBinding.instance.addPostFrameCallback((_) => _handleLaunch());
  }

  void _handleLaunch() {
    final uri = widget.launch?.value;
    if (uri == null || !mounted) return;
    widget.launch!.value = null;
    final view = uri.queryParameters['view'];
    setState(() {
      if (view != null) _view = ViewRef.fromId(view);
    });
    if (uri.host == 'add') _entryFocus.requestFocus();
  }

  @override
  void dispose() {
    widget.launch?.removeListener(_handleLaunch);
    _entryFocus.dispose();
    _entry.dispose();
    super.dispose();
  }

  String get _title => _view.title(store);

  List<Task> get _tasks => _view.tasks(store);

  /// Liste, in die neue Aufgaben kommen: die gewählte, sonst die erste.
  String? get _targetList => switch (_view) {
        ListRef(:final listId) => listId,
        _ => store.lists.isEmpty ? null : store.lists.first.id,
      };

  /// Führt eine Aktion aus und zeigt einen Fehler als Hinweis; true, wenn sie gelang.
  Future<bool> _guard(Future<void> Function() action) async {
    try {
      await action();
      return true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text('$e')));
      }
      return false;
    }
  }

  Future<void> _submit() async {
    final text = _entry.text.trim();
    final listId = _targetList;
    if (text.isEmpty || listId == null || _sending) return;
    setState(() => _sending = true);
    final added = await _guard(() => store.addQuick(listId, text, dueToday: _view is TodayView || _view is OverdueView));
    if (!mounted) return;
    setState(() => _sending = false);
    if (added) _entry.clear();
  }

  Future<void> _newList() async {
    final result = await showListDialog(context, store);
    if (result == null || !mounted) return;
    String? id;
    final ok = await _guard(() async => id = await store.createList(result.name, group: result.group));
    if (ok && id != null && mounted) setState(() => _view = ListRef(id!));
  }

  Future<void> _listMenu(String action, TaskList list) async {
    switch (action) {
      case 'rename':
        final name = await showNameDialog(context, title: tr('rename_list'), initial: list.name);
        if (name != null && name != list.name) await _guard(() => store.updateList(list.id, {'name': name}));
      case 'group':
        final group = await pickGroup(context, store, current: list.group);
        if (group != null && group.value != list.group) {
          await _guard(() => store.updateList(list.id, {'group': group.value}));
        }
      case 'sort':
        final sort = await pickSort(context, current: list.sort);
        if (sort != null && sort != list.sort) await _guard(() => store.updateList(list.id, {'sort': sort}));
      case 'delete':
        if (store.lists.length == 1) return;
        final confirmed = await confirmDelete(context, list.name);
        if (!confirmed || !mounted) return;
        if (await _guard(() => store.deleteList(list.id)) && mounted) {
          setState(() => _view = const TodayView());
        }
    }
  }

  void _openTask(Task task, bool wide) {
    if (wide) {
      setState(() => _selected = task.id);
    } else {
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => TaskDetailScreen(store: store, taskId: task.id)),
      );
    }
  }

  void _selectView(ViewRef view) => setState(() => _view = view);

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= wideLayoutWidth;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyN, control: true): _entryFocus.requestFocus,
        const SingleActivator(LogicalKeyboardKey.escape): () {
          if (_selected != null) setState(() => _selected = null);
        },
      },
      child: ListenableBuilder(listenable: store, builder: (context, _) => _buildScreen(context, wide)),
    );
  }

  Widget _buildScreen(BuildContext context, bool wide) {
    // Die Ansicht „Überfällig“ gibt es nur mit der passenden Option.
    if (_view is OverdueView && store.overdueMode != 'separate') _view = const TodayView();
    // Ausgeblendete Ansichten (Option der Integration) ebenso.
    if (store.hiddenViews.contains(_view.id)) _view = const TodayView();
    final tasks = _tasks;
    final open = tasks.where((t) => !t.completed).toList();
    final done = tasks.where((t) => t.completed).toList();
    final listView = _view is ListRef;
    final list = listView ? store.list((_view as ListRef).listId) : null;
    Widget tile(Task task) => _TaskTile(
          task: task,
          store: store,
          guard: _guard,
          selected: wide && task.id == _selected,
          onOpen: () => _openTask(task, wide),
        );
    final selected = wide && _selected != null ? store.task(_selected!) : null;
    final page = Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: !wide,
        title: _view is TodayView
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_title),
                  Text(
                    L10n.longDate(store.today),
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              )
            : Text(_title),
        actions: [
          if (_view is ImportantView)
            PopupMenuButton<String>(
              tooltip: tr('range'),
              icon: const Icon(Icons.date_range_outlined),
              initialValue: store.importantRange,
              onSelected: store.setImportantRange,
              itemBuilder: (_) => [
                for (final key in _ranges)
                  CheckedPopupMenuItem(value: key, checked: key == store.importantRange, child: Text(tr('range_$key'))),
              ],
            ),
          if (listView)
            IconButton(
              tooltip: tr('clear_completed'),
              icon: const Icon(Icons.cleaning_services_outlined),
              onPressed: done.isEmpty
                  ? null
                  : () => _guard(() => store.clearCompleted((_view as ListRef).listId)),
            ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'logout') {
                store.logout();
              } else if (value == 'settings') {
                Navigator.push(context, MaterialPageRoute<void>(builder: (_) => SettingsScreen(store: store)));
              } else if (list != null) {
                _listMenu(value, list);
              }
            },
            itemBuilder: (_) => [
              if (list != null) ...[
                PopupMenuItem(value: 'rename', child: Text(tr('rename'))),
                PopupMenuItem(value: 'group', child: Text(tr('group_menu'))),
                PopupMenuItem(value: 'sort', child: Text(tr('sort_menu'))),
                PopupMenuItem(
                  value: 'delete',
                  enabled: store.lists.length > 1,
                  child: Text(tr('delete_list')),
                ),
                const PopupMenuDivider(),
              ],
              PopupMenuItem(
                value: 'settings',
                enabled: store.connection == LinkState.connected,
                child: Text(tr('settings')),
              ),
              PopupMenuItem(value: 'logout', child: Text(tr('logout'))),
            ],
          ),
        ],
      ),
      drawer: wide ? null : Drawer(child: SafeArea(child: _buildNav(context, inDrawer: true))),
      body: Column(
        children: [
          if (store.connection != LinkState.connected || store.pendingCount > 0) _ConnectionBanner(store: store),
          Expanded(
            child: tasks.isEmpty
                ? _EmptyView(visible: store.connection == LinkState.connected || store.fromCache)
                : list != null && list.sort == 'manual'
                    ? _reorderableList(open, done, tile)
                    : ListView(
                    children: [
                      if (_view is PlannedView)
                        ..._plannedSections(context, open, tile)
                      else if (_view is TodayView && store.overdueMode == 'section' && open.any(_isOverdue))
                        ..._todaySections(context, open, tile)
                      else
                        for (final task in open) tile(task),
                      if (done.isNotEmpty)
                        ExpansionTile(
                          title: Text(tr('completed_n', [done.length])),
                          children: [for (final task in done) tile(task)],
                        ),
                    ],
                  ),
          ),
          if (_targetList != null) _buildEntry(context),
        ],
      ),
    );
    if (!wide) return page;
    return Scaffold(
      body: Row(
        children: [
          SizedBox(width: 280, child: SafeArea(child: Material(child: _buildNav(context, inDrawer: false)))),
          const VerticalDivider(width: 1),
          Expanded(child: page),
          if (selected != null) ...[
            const VerticalDivider(width: 1),
            SizedBox(
              width: 420,
              child: TaskDetailScreen(
                key: ValueKey(selected.id),
                store: store,
                taskId: selected.id,
                onClose: () => setState(() => _selected = null),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Eigene Liste mit manueller Reihenfolge: offene Aufgaben per Ziehen anordnen (Griff rechts bzw. lange drücken).
  Widget _reorderableList(List<Task> open, List<Task> done, Widget Function(Task) tile) {
    return ReorderableListView(
      buildDefaultDragHandles: true,
      footer: done.isEmpty
          ? null
          : ExpansionTile(
              title: Text(tr('completed_n', [done.length])),
              children: [for (final task in done) tile(task)],
            ),
      // newIndex zählt schon ohne die verschobene Aufgabe.
      onReorderItem: (oldIndex, newIndex) {
        if (newIndex == oldIndex) return;
        final moved = open[oldIndex];
        final rest = [...open]..removeAt(oldIndex);
        // Nach oben: vor die Aufgabe, die jetzt an dieser Stelle steht, also hinter deren Vorgängerin.
        final previous = newIndex == 0 ? null : rest[newIndex - 1].id;
        _guard(() => store.moveTask(moved, previous));
      },
      children: [for (final task in open) KeyedSubtree(key: ValueKey('move-${task.id}'), child: tile(task))],
    );
  }

  /// „Geplant“ nach Überfällig / Diese Woche / Diesen Monat / Später gruppieren.
  List<Widget> _plannedSections(BuildContext context, List<Task> open, Widget Function(Task) tile) {
    final today = store.today;
    final weekEnd = Period.containing(Granularity.week, today).end;
    final monthEnd = Period.containing(Granularity.month, today).end;
    final sections = <String, List<Task>>{'view_overdue': [], 'view_this_week': [], 'view_this_month': [], 'later': []};
    for (final task in open) {
      final end = task.due!.end;
      final key = end.isBefore(today)
          ? 'view_overdue'
          : !end.isAfter(weekEnd)
              ? 'view_this_week'
              : !end.isAfter(monthEnd)
                  ? 'view_this_month'
                  : 'later';
      sections[key]!.add(task);
    }
    return [
      for (final entry in sections.entries)
        if (entry.value.isNotEmpty) ...[
          _SectionHeader(tr(entry.key), entry.value.length, error: entry.key == 'view_overdue'),
          for (final task in entry.value) tile(task),
        ],
    ];
  }

  bool _isOverdue(Task task) => task.isOverdue(store.today);

  /// „Heute“ mit Überfälligem oben in einem eigenen, zuklappbaren Abschnitt.
  List<Widget> _todaySections(BuildContext context, List<Task> open, Widget Function(Task) tile) {
    final theme = Theme.of(context);
    final overdue = open.where(_isOverdue).toList();
    final rest = open.where((t) => !_isOverdue(t)).toList();
    return [
      ExpansionTile(
        key: const PageStorageKey('overdue'),
        initiallyExpanded: !store.overdueCollapsed,
        onExpansionChanged: (expanded) => store.setOverdueCollapsed(!expanded),
        textColor: theme.colorScheme.error,
        collapsedTextColor: theme.colorScheme.error,
        title: Text(tr('overdue_n', [overdue.length])),
        children: [for (final task in overdue) tile(task)],
      ),
      if (rest.isNotEmpty) ...[
        _SectionHeader(tr('view_today'), rest.length),
        for (final task in rest) tile(task),
      ],
    ];
  }

  Widget _buildEntry(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
        child: TextField(
          controller: _entry,
          focusNode: _entryFocus,
          enabled: !_sending,
          textInputAction: TextInputAction.send,
          onSubmitted: (_) => _submit(),
          decoration: InputDecoration(
            hintText: tr('entry_hint'),
            filled: true,
            fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(28), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            prefixIcon: const Icon(Icons.add_task),
            suffixIcon: IconButton(icon: const Icon(Icons.arrow_upward), tooltip: tr('create'), onPressed: _submit),
          ),
        ),
      ),
    );
  }

  /// Ansichten und Listen: im schmalen Layout als Drawer, im breiten fest am linken Rand.
  Widget _buildNav(BuildContext context, {required bool inDrawer}) {
    void select(ViewRef view) {
      _selectView(view);
      if (inDrawer) Navigator.pop(context);
    }

    final lists = store.lists;
    final groups = <String?>[];
    for (final list in lists) {
      if (!groups.contains(list.group)) groups.add(list.group);
    }
    return ListView(
      children: [
        ListTile(
          leading: const Icon(Icons.today_outlined),
          title: Text(tr('view_today')),
          selected: _view is TodayView,
          trailing: _count(store.dueToday.where((t) => !t.completed).length),
          onTap: () => select(const TodayView()),
        ),
        if (store.overdueMode == 'separate')
          ListTile(
            leading: const Icon(Icons.event_busy_outlined),
            title: Text(tr('view_overdue')),
            selected: _view is OverdueView,
            trailing: _count(store.overdue.length),
            onTap: () => select(const OverdueView()),
          ),
        if (!store.hiddenViews.contains('this_week'))
          ListTile(
            leading: const Icon(Icons.date_range_outlined),
            title: Text(tr('view_this_week')),
            selected: _view is ThisWeekView,
            trailing: _count(store.thisWeek.length),
            onTap: () => select(const ThisWeekView()),
          ),
        if (!store.hiddenViews.contains('this_month'))
          ListTile(
            leading: const Icon(Icons.calendar_today_outlined),
            title: Text(tr('view_this_month')),
            selected: _view is ThisMonthView,
            trailing: _count(store.thisMonth.length),
            onTap: () => select(const ThisMonthView()),
          ),
        if (!store.hiddenViews.contains('important'))
          ListTile(
            leading: const Icon(Icons.flag_outlined),
            title: Text(tr('view_important')),
            selected: _view is ImportantView,
            trailing: _count(store.important.where((t) => !t.completed).length),
            onTap: () => select(const ImportantView()),
          ),
        if (!store.hiddenViews.contains('planned'))
          ListTile(
            leading: const Icon(Icons.calendar_month_outlined),
            title: Text(tr('view_planned')),
            selected: _view is PlannedView,
            trailing: _count(store.planned.where((t) => !t.completed).length),
            onTap: () => select(const PlannedView()),
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
        ListTile(
          leading: const Icon(Icons.add),
          title: Text(tr('new_list')),
          enabled: store.connection == LinkState.connected,
          onTap: () {
            if (inDrawer) Navigator.pop(context);
            _newList();
          },
        ),
      ],
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
    final syncing = store.connection == LinkState.connected;
    final pending = store.pendingCount;
    final pendingText = pending == 0 ? '' : tr('pending', [trPlural(pending, 'change')]);
    final message = syncing
        ? tr('sending', [trPlural(pending, 'change')])
        : connecting
            ? '${store.fromCache ? tr('connecting_cached') : tr('connecting')}$pendingText'
            : '${store.fromCache ? tr('offline_cached') : (store.error ?? tr('not_connected'))}$pendingText';
    return Material(
      color: scheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            if (connecting || syncing)
              const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
            else
              Icon(Icons.cloud_off, size: 18, color: scheme.onErrorContainer),
            const SizedBox(width: 12),
            Expanded(
              child: Text(message, style: TextStyle(color: scheme.onErrorContainer)),
            ),
            if (!connecting && !syncing) TextButton(onPressed: store.resume, child: Text(tr('retry'))),
          ],
        ),
      ),
    );
  }
}

class _TaskTile extends StatelessWidget {
  const _TaskTile({
    required this.task,
    required this.store,
    required this.guard,
    required this.onOpen,
    this.selected = false,
  });

  final Task task;
  final ThaskStore store;
  final Future<void> Function(Future<void> Function()) guard;
  final VoidCallback onOpen;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
      child: _PriorityBar(
        priority: task.priority,
        child: ListTile(
        selected: selected,
        onTap: onOpen,
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
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (dueText != null) DueChip(task: task, today: store.today, text: dueText),
                  if (task.recurrence != null) const Icon(Icons.repeat, size: 14),
                  if (steps != null) Text(steps),
                ],
              ),
        ),
      ),
    );
  }
}

/// Fälligkeit als Pille. Zeiträume (Woche, Monat, Quartal, Jahr) laufen rechts aus, ein fester Tag nicht:
/// So ist die Unschärfe der Fälligkeit zu sehen. Überfälliges ist rot, was heute endet, blau.
class DueChip extends StatelessWidget {
  const DueChip({super.key, required this.task, required this.today, required this.text});

  final Task task;
  final DateTime today;
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final due = task.due!;
    final overdue = task.isOverdue(today);
    final endsToday = !task.completed && due.end == dateOnly(today);
    final (background, foreground) = overdue
        ? (scheme.errorContainer, scheme.onErrorContainer)
        : endsToday
            ? (scheme.primaryContainer, scheme.onPrimaryContainer)
            : (scheme.surfaceContainerHighest, scheme.onSurfaceVariant);
    final fuzzy = due.granularity != Granularity.day;
    return Semantics(
      label: '${fuzzy ? tr('due_in_period') : tr('due')} $text${overdue ? tr('overdue_suffix') : ''}',
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: fuzzy ? null : background,
          gradient: fuzzy
              ? LinearGradient(
                  colors: [background, background, background.withValues(alpha: 0)],
                  stops: const [0, 0.62, 1],
                )
              : null,
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(8, 2, fuzzy ? 20 : 8, 2),
          child: Text(
            text,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(color: foreground),
          ),
        ),
      ),
    );
  }
}

/// Farbiger Balken am linken Rand einer Zeile; je höher die Priorität, desto breiter.
class _PriorityBar extends StatelessWidget {
  const _PriorityBar({required this.priority, required this.child});

  final int priority;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final color = priorityColor(priority);
    if (color == null) return child;
    return Semantics(
      label: tr('priority_x', [priorityName(priority)]),
      child: DecoratedBox(
        decoration: BoxDecoration(border: Border(left: BorderSide(color: color, width: priorityBarWidth(priority)))),
        child: child,
      ),
    );
  }
}

/// Abschnittskopf in den Ansichten („Überfällig“, „Diese Woche“ …): Name und Anzahl, überall gleich.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text, this.count, {this.error = false});

  final String text;
  final int count;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = error ? theme.colorScheme.error : theme.colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 6),
      child: Row(
        children: [
          Text(text, style: theme.textTheme.titleSmall?.copyWith(color: color, fontWeight: FontWeight.w600)),
          const SizedBox(width: 8),
          Text('$count', style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

/// Leere Ansicht: freundlicher Hinweis statt nur „Keine Aufgaben“.
class _EmptyView extends StatelessWidget {
  const _EmptyView({required this.visible});

  /// Ohne Verbindung und ohne gespeicherten Stand ist leer nur „noch nicht geladen“.
  final bool visible;

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.task_alt, size: 64, color: theme.colorScheme.primary.withValues(alpha: 0.6)),
            const SizedBox(height: 16),
            Text(tr('empty_title'), style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(tr('empty_text'), style: theme.textTheme.bodyMedium, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            Text(
              tr('empty_hint'),
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
