import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'l10n.dart';
import 'list_dialogs.dart';
import 'models.dart';
import 'priority.dart';
import 'settings_screen.dart';
import 'store.dart';
import 'task_detail_screen.dart';
import 'update_dialog.dart';
import 'updater.dart';
import 'views.dart';

const _ranges = ['all', 'week', 'month', 'quarter', 'year'];

/// Ab dieser Breite stehen Navigation, Liste und Details nebeneinander (Windows, Tablet quer).
const wideLayoutWidth = 900.0;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.store, this.launch, this.updater});

  final ThaskStore store;

  /// Aufforderung aus dem Android-Widget: Ansicht öffnen und Schnelleingabe fokussieren.
  final ValueNotifier<Uri?>? launch;

  /// Updates aus GitHub (Android, Windows); ohne ihn kein Menüpunkt und keine Prüfung beim Start.
  final Updater? updater;

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

  /// Suchbegriff; null, solange keine Suche offen ist.
  String? _query;
  final _search = TextEditingController();

  /// Per Wischen gelöschte Aufgaben, die noch rückgängig gemacht werden können.
  final _deleting = <String>{};

  @override
  void initState() {
    super.initState();
    widget.launch?.addListener(_handleLaunch);
    WidgetsBinding.instance.addPostFrameCallback((_) => _handleLaunch());
    _checkForUpdate();
  }

  /// Einmal am Tag beim Start; ein gefundenes Update meldet ein Hinweis unten.
  Future<void> _checkForUpdate() async {
    final updater = widget.updater;
    if (updater == null) return;
    final update = await updater.checkDaily();
    if (update == null || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(tr('update_snack', [update.version])),
      duration: const Duration(seconds: 10),
      action: SnackBarAction(
        label: tr('update_install'),
        onPressed: () => showUpdateDialog(context, updater, update: update),
      ),
    ));
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
    _search.dispose();
    super.dispose();
  }

  String get _title => _view.title(store);

  List<Task> get _tasks => [
        for (final task in _query != null ? store.search(_query!) : _view.tasks(store))
          if (!_deleting.contains(task.id)) task,
      ];

  void _openSearch() => setState(() => _query ??= '');

  void _closeSearch() {
    _search.clear();
    setState(() => _query = null);
  }

  /// Gewischt: sofort ausblenden, aber erst löschen, wenn der Hinweis ohne „Rückgängig“ abläuft.
  /// Anhänge löscht der Server mit der Aufgabe, deshalb nicht löschen und wiederherstellen.
  void _swipeDelete(Task task) {
    setState(() {
      _deleting.add(task.id);
      if (_selected == task.id) _selected = null;
    });
    final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
    messenger
        .showSnackBar(SnackBar(
          content: Text(tr('task_deleted', [task.title])),
          persist: false,
          action: SnackBarAction(label: tr('undo'), onPressed: () {}),
        ))
        .closed
        .then((reason) {
      if (reason == SnackBarClosedReason.action) {
        if (mounted) setState(() => _deleting.remove(task.id));
        return;
      }
      _guard(() => store.deleteTask(task)).whenComplete(() {
        if (mounted) setState(() => _deleting.remove(task.id));
      });
    });
  }

  /// Liste, in die neue Aufgaben kommen: die gewählte, sonst die erste.
  String? get _targetList => switch (_view) {
        ListRef(:final listId) => listId,
        _ => (store.visibleLists.firstOrNull ?? store.lists.firstOrNull)?.id,
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
    final added = await _guard(() => store.addQuick(
          listId,
          text,
          dueToday: _view is TodayView || _view is OverdueView,
          dueDay: _view is DayPlanView ? store.planDay : null,
        ));
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
      case 'members':
        final members = await pickMembers(context, store, list);
        if (members != null) await _guard(() => store.updateList(list.id, {'members': members}));
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

  void _selectView(ViewRef view) {
    _search.clear();
    setState(() {
      _view = view;
      _query = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= wideLayoutWidth;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyN, control: true): _entryFocus.requestFocus,
        const SingleActivator(LogicalKeyboardKey.keyF, control: true): _openSearch,
        const SingleActivator(LogicalKeyboardKey.escape): () {
          if (_selected != null) {
            setState(() => _selected = null);
          } else if (_query != null) {
            _closeSearch();
          }
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
    final searching = _query != null;
    final listView = _view is ListRef && !searching;
    final list = listView ? store.list((_view as ListRef).listId) : null;
    Widget tile(Task task) => task.preview
        ? _PreviewTile(
            task: task,
            store: store,
            guard: _guard,
            selected: wide && task.id == _selected,
            onOpen: () => _openTask(task, wide),
          )
        : _TaskTile(
          task: task,
          store: store,
          showList: !listView,
          guard: _guard,
          selected: wide && task.id == _selected,
          onOpen: () => _openTask(task, wide),
          onDelete: () => _swipeDelete(task),
        );
    final selected = wide && _selected != null ? store.task(_selected!) : null;
    final page = Scaffold(
      appBar: searching ? _searchBar(context) : AppBar(
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
          IconButton(tooltip: tr('search'), icon: const Icon(Icons.search), onPressed: _openSearch),
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
              } else if (value == 'update') {
                showUpdateDialog(context, widget.updater!);
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
                  value: 'members',
                  enabled: store.connection == LinkState.connected,
                  child: Text(tr('members_menu')),
                ),
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
              if (widget.updater != null) PopupMenuItem(value: 'update', child: Text(tr('check_updates'))),
              PopupMenuItem(value: 'logout', child: Text(tr('logout'))),
            ],
          ),
        ],
      ),
      drawer: wide ? null : Drawer(child: SafeArea(child: _buildNav(context, inDrawer: true))),
      body: Column(
        children: [
          if (store.connection != LinkState.connected || store.pendingCount > 0) _ConnectionBanner(store: store),
          if (_view is DayPlanView && !searching) _DayBar(store: store),
          Expanded(
            child: tasks.isEmpty && searching
                ? _NoResults(query: _query!)
                : tasks.isEmpty
                ? _EmptyView(visible: store.connection == LinkState.connected || store.fromCache)
                : list != null && list.sort == 'manual'
                    ? _reorderableList(open, done, tile)
                    : ListView(
                    children: [
                      if (searching)
                        for (final task in open) tile(task)
                      else if (_view is PlannedView)
                        ..._plannedSections(context, open, tile)
                      else if (_view is DayPlanView)
                        ..._daySections(context, open, tile)
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
          if (_targetList != null && !searching) _buildEntry(context),
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

  /// Kopfzeile während der Suche: Eingabefeld, Zurück schließt die Suche.
  PreferredSizeWidget _searchBar(BuildContext context) {
    return AppBar(
      leading: IconButton(tooltip: tr('close'), icon: const Icon(Icons.arrow_back), onPressed: _closeSearch),
      title: TextField(
        controller: _search,
        autofocus: true,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(hintText: tr('search_hint'), border: InputBorder.none),
        onChanged: (value) => setState(() => _query = value),
      ),
      actions: [
        if (_search.text.isNotEmpty)
          IconButton(
            tooltip: tr('clear'),
            icon: const Icon(Icons.close),
            onPressed: () {
              _search.clear();
              setState(() => _query = '');
            },
          ),
      ],
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

  /// Tagesplan: Überfälliges (nur heute), der Tag selbst, dann Zeiträume wie „KW 45“, die ihn enthalten.
  List<Widget> _daySections(BuildContext context, List<Task> open, Widget Function(Task) tile) {
    final theme = Theme.of(context);
    final overdue = open.where((t) => !t.preview && _isOverdue(t)).toList();
    final day = open.where((t) => !overdue.contains(t) && t.due!.granularity == Granularity.day).toList();
    final periods = open.where((t) => !overdue.contains(t) && t.due!.granularity != Granularity.day).toList();
    return [
      if (overdue.isNotEmpty)
        ExpansionTile(
          key: const PageStorageKey('day-overdue'),
          initiallyExpanded: !store.overdueCollapsed,
          onExpansionChanged: (expanded) => store.setOverdueCollapsed(!expanded),
          textColor: theme.colorScheme.error,
          collapsedTextColor: theme.colorScheme.error,
          title: Text(tr('overdue_n', [overdue.length])),
          children: [for (final task in overdue) tile(task)],
        ),
      if (day.isNotEmpty && (overdue.isNotEmpty || periods.isNotEmpty)) _SectionHeader(L10n.dayLabel(store.planDay), day.length),
      for (final task in day) tile(task),
      if (periods.isNotEmpty) ...[
        _SectionHeader(tr('in_period'), periods.length),
        for (final task in periods) tile(task),
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

    final lists = store.visibleLists;
    final others = store.otherListCount;
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
        if (!store.hiddenViews.contains('day_view'))
          ListTile(
            leading: const Icon(Icons.event_note_outlined),
            title: Text(tr('view_day_view')),
            selected: _view is DayPlanView,
            trailing: _count(store.dayPlan.where((t) => !t.completed).length),
            onTap: () => select(const DayPlanView()),
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
        if (others > 0)
          ListTile(
            leading: Icon(store.showAllLists ? Icons.person_outline : Icons.people_outline),
            title: Text(store.showAllLists ? tr('only_my_lists') : tr('show_other_lists', [others])),
            textColor: Theme.of(context).colorScheme.onSurfaceVariant,
            iconColor: Theme.of(context).colorScheme.onSurfaceVariant,
            onTap: () => store.setShowAllLists(!store.showAllLists),
          ),
        ListTile(
          leading: const Icon(Icons.add),
          title: Text(tr('new_list')),
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
    required this.onDelete,
    this.selected = false,
    this.showList = false,
  });

  final Task task;
  final ThaskStore store;

  /// In Ansichten wie „Heute“: hinter der Fälligkeit steht, aus welcher Liste die Aufgabe kommt.
  final bool showList;
  final Future<void> Function(Future<void> Function()) guard;
  final VoidCallback onOpen;
  final VoidCallback onDelete;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final due = task.due;
    final dueText = due == null ? null : '${due.label(store.today)}${task.dueTime != null ? ', ${task.dueTime}' : ''}';
    final steps = task.steps.isEmpty ? null : '${task.steps.where((s) => s.completed).length}/${task.steps.length}';
    final listName = showList ? store.list(task.listId)?.name : null;
    return Dismissible(
      key: ValueKey(task.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: theme.colorScheme.error,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: Icon(Icons.delete_outline, color: theme.colorScheme.onError),
      ),
      onDismissed: (_) => onDelete(),
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
        subtitle: (dueText ?? listName ?? steps) == null && task.attachments.isEmpty
            ? null
            : Wrap(
                spacing: 12,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (dueText != null) DueChip(task: task, today: store.today, text: dueText),
                  if (listName != null) _ListOrigin(listName),
                  if (task.recurrence != null) const Icon(Icons.repeat, size: 14),
                  if (steps != null) Text(steps),
                  if (task.attachments.isNotEmpty)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [const Icon(Icons.attach_file, size: 14), Text('${task.attachments.length}')],
                    ),
                ],
              ),
        ),
      ),
    );
  }
}

/// Kommendes Vorkommen einer wiederkehrenden Aufgabe im Tagesplan. Es gibt die Aufgabe so noch nicht, deshalb
/// ohne Haken und ohne Wischen; Antippen öffnet die jetzige Aufgabe.
class _PreviewTile extends StatelessWidget {
  const _PreviewTile({
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
    final muted = theme.colorScheme.onSurfaceVariant;
    final due = task.due!;
    final dueText = '${due.label(store.today)}${task.dueTime != null ? ', ${task.dueTime}' : ''}';
    final listName = store.list(task.listId)?.name;
    return Tooltip(
      message: tr('preview_hint'),
      child: ListTile(
        selected: selected,
        onTap: onOpen,
        // Abhaken erledigt das Vorkommen vorab: eine eigene erledigte Aufgabe, die Wiederholung springt darüber.
        leading: SizedBox(
          width: 40,
          child: IconButton(
            tooltip: tr('occurrence_done'),
            icon: Icon(Icons.radio_button_unchecked, color: muted.withValues(alpha: 0.7)),
            onPressed: () => guard(() => store.setOccurrence(task, due, true)),
          ),
        ),
        title: Text(task.title, style: TextStyle(color: muted)),
        subtitle: Wrap(
          spacing: 12,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            DueChip(task: task, today: store.today, text: dueText),
            if (listName != null) _ListOrigin(listName),
            Text(tr('preview'), style: theme.textTheme.bodySmall?.copyWith(color: muted, fontStyle: FontStyle.italic)),
          ],
        ),
      ),
    );
  }
}

/// Tag des Tagesplans: zurück, Datum (öffnet die Auswahl), weiter und zurück auf heute.
class _DayBar extends StatelessWidget {
  const _DayBar({required this.store});

  final ThaskStore store;

  @override
  Widget build(BuildContext context) {
    final day = store.planDay;
    final isToday = day == store.today;
    Future<void> pick() async {
      final picked = await showDatePicker(
        context: context,
        initialDate: day,
        firstDate: DateTime(store.today.year - 5),
        lastDate: DateTime(store.today.year + 10),
        helpText: tr('pick_day'),
      );
      if (picked != null) store.setPlanDay(picked);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          IconButton(
            tooltip: tr('prev_day'),
            icon: const Icon(Icons.chevron_left),
            onPressed: () => store.setPlanDay(DateTime(day.year, day.month, day.day - 1)),
          ),
          Expanded(
            child: TextButton.icon(
              onPressed: pick,
              icon: const Icon(Icons.event_outlined, size: 18),
              label: Text(
                '${L10n.longDate(day)}${day.year == store.today.year ? '' : ' ${day.year}'}',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          IconButton(
            tooltip: tr('next_day'),
            icon: const Icon(Icons.chevron_right),
            onPressed: () => store.setPlanDay(DateTime(day.year, day.month, day.day + 1)),
          ),
          IconButton(
            tooltip: tr('today'),
            icon: const Icon(Icons.today_outlined),
            onPressed: isToday ? null : () => store.setPlanDay(store.today),
          ),
        ],
      ),
    );
  }
}

/// Name der Liste, aus der eine Aufgabe kommt, in Ansichten wie „Heute“.
class _ListOrigin extends StatelessWidget {
  const _ListOrigin(this.name);

  final String name;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.checklist, size: 14, color: color),
        const SizedBox(width: 4),
        Flexible(
          child: Text(name, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall?.copyWith(color: color)),
        ),
      ],
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

/// Suche ohne Treffer; ohne Suchbegriff bleibt die Fläche leer.
class _NoResults extends StatelessWidget {
  const _NoResults({required this.query});

  final String query;

  @override
  Widget build(BuildContext context) {
    if (query.trim().isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          tr('no_results', [query.trim()]),
          style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          textAlign: TextAlign.center,
        ),
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
