import 'package:flutter/material.dart';

import 'l10n.dart';
import 'models.dart';
import 'priority.dart';
import 'store.dart';

/// Einheit in Einzahl und Mehrzahl, z. B. („Woche“, „Wochen“).
(String, String) _unitNames(Granularity g) => (tr('unit_${g.name}'), tr('units_${g.name}'));

/// Name der Granularität für die Chips („Tag“, „Woche“ …), groß geschrieben.
String _granularityName(Granularity g) {
  final name = tr('unit_${g.name}');
  return name.isEmpty ? name : name[0].toUpperCase() + name.substring(1);
}

String _two(int n) => n.toString().padLeft(2, '0');

String _everyText(Recurrence r) {
  final (one, many) = _unitNames(r.unit);
  return r.interval == 1 ? tr('every_one', [one]) : tr('every_many', [r.interval, many]);
}

List<String> get _weekdayNames => L10n.weekdaysShort;

String _recurrenceLabel(Recurrence r) {
  final label = switch (r.unit) {
    _ when r.interval == 1 => tr('rec_${r.unit.name}'),
    _ => _everyText(r),
  };
  return r.weekdays.isEmpty ? label : '$label: ${[for (final d in r.weekdays) _weekdayNames[d]].join(', ')}';
}

/// Wochentag eines Datums, 0 = Montag.
int _weekdayOf(DateTime d) => d.weekday - 1;

/// Alle Eigenschaften einer Aufgabe bearbeiten. Jede Änderung wird sofort an Home Assistant geschickt.
class TaskDetailScreen extends StatefulWidget {
  const TaskDetailScreen({super.key, required this.store, required this.taskId, this.onClose});

  final ThaskStore store;
  final String taskId;

  /// Gesetzt, wenn die Details neben der Liste stehen (breites Fenster) statt als eigene Seite.
  final VoidCallback? onClose;

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  late final TextEditingController _title;
  late final TextEditingController _notes;
  final _newStep = TextEditingController();
  final _titleFocus = FocusNode();
  final _notesFocus = FocusNode();
  Task? _last;

  ThaskStore get store => widget.store;

  @override
  void initState() {
    super.initState();
    final task = store.task(widget.taskId);
    _last = task;
    _title = TextEditingController(text: task?.title ?? '');
    _notes = TextEditingController(text: task?.notes ?? '');
    _titleFocus.addListener(() {
      if (!_titleFocus.hasFocus) _saveTitle();
    });
    _notesFocus.addListener(() {
      if (!_notesFocus.hasFocus) _saveNotes();
    });
    store.addListener(_onStoreChanged);
  }

  @override
  void dispose() {
    store.removeListener(_onStoreChanged);
    _saveTitle();
    _saveNotes();
    _title.dispose();
    _notes.dispose();
    _newStep.dispose();
    _titleFocus.dispose();
    _notesFocus.dispose();
    super.dispose();
  }

  /// Wurde die Aufgabe woanders gelöscht, schließen; Änderungen von außen in nicht fokussierte Felder übernehmen.
  void _onStoreChanged() {
    final task = store.task(widget.taskId);
    if (task == null) {
      // Neben der Liste blendet die Startseite die Details selbst aus.
      if (widget.onClose == null && mounted && Navigator.of(context).canPop()) Navigator.of(context).pop();
      return;
    }
    if (!_titleFocus.hasFocus && task.title != _title.text) _title.text = task.title;
    if (!_notesFocus.hasFocus && task.notes != _notes.text) _notes.text = task.notes;
    _last = task;
  }

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

  Future<void> _update(Map<String, dynamic> patch) {
    final task = store.task(widget.taskId) ?? _last;
    if (task == null) return Future.value();
    return _guard(() => store.updateTask(task, patch));
  }

  void _saveTitle() {
    final task = store.task(widget.taskId);
    final text = _title.text.trim();
    if (task == null || text.isEmpty) {
      if (task != null) _title.text = task.title;
      return;
    }
    if (text != task.title) _update({'title': text});
  }

  void _saveNotes() {
    final task = store.task(widget.taskId);
    if (task != null && _notes.text != task.notes) _update({'notes': _notes.text});
  }

  // -- Fälligkeit ------------------------------------------------------------

  void _setGranularity(Task task, Granularity? granularity) {
    if (granularity == null) {
      _update({'due': null, 'due_time': null});
      return;
    }
    final anchor = task.due?.start ?? store.today;
    _update({'due': Period.containing(granularity, anchor).toJson()});
  }

  Future<void> _pickDay(Task task) async {
    final current = task.due!.start;
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(current.year - 2),
      lastDate: DateTime(current.year + 10),
    );
    if (picked != null) _update({'due': Period(Granularity.day, dateOnly(picked)).toJson()});
  }

  Future<void> _pickDueTime(Task task) async {
    final parts = task.dueTime?.split(':');
    final initial = parts == null
        ? const TimeOfDay(hour: 9, minute: 0)
        : TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked != null) _update({'due_time': '${_two(picked.hour)}:${_two(picked.minute)}'});
  }

  // -- Erinnerung ------------------------------------------------------------

  Future<void> _pickReminder(Task task) async {
    final current = task.reminder == null ? null : DateTime.parse(task.reminder!).toLocal();
    final base = current ?? DateTime(store.today.year, store.today.month, store.today.day, 9);
    final date = await showDatePicker(
      context: context,
      initialDate: base,
      firstDate: DateTime(base.year - 1),
      lastDate: DateTime(base.year + 10),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(base));
    if (time == null) return;
    final when = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    _update({'reminder': when.toUtc().toIso8601String()});
  }

  String _reminderText(String iso) {
    final t = DateTime.parse(iso).toLocal();
    return '${Period(Granularity.day, dateOnly(t)).label(store.today)}, ${_two(t.hour)}:${_two(t.minute)}';
  }

  // -- Wiederholung ----------------------------------------------------------

  Future<void> _pickRecurrence(Task task) async {
    final dueDay = task.due?.granularity == Granularity.day ? task.due!.start : null;
    final result = await showDialog<Recurrence>(
      context: context,
      builder: (_) => _RecurrenceDialog(initial: task.recurrence, dueDay: dueDay),
    );
    if (result == null) return;
    final patch = <String, dynamic>{'recurrence': result.toJson()};
    // Die Reihe läuft an Tagen: Fälligkeit auf den nächsten gewählten Wochentag legen, wenn sie keiner ist.
    if (result.weekdays.isNotEmpty && (dueDay == null || !result.weekdays.contains(_weekdayOf(dueDay)))) {
      final today = store.today;
      final from = dueDay != null && dueDay.isAfter(today) ? dueDay : today;
      final next = [
        for (var n = 0; n < 7; n++) DateTime(from.year, from.month, from.day + n),
      ].firstWhere((d) => result.weekdays.contains(_weekdayOf(d)));
      patch['due'] = Period.day(next).toJson();
    }
    _update(patch);
  }

  // -- Schritte --------------------------------------------------------------

  List<Map<String, dynamic>> _stepsJson(List<TaskStep> steps) => [for (final s in steps) s.toJson()];

  void _addStep(Task task) {
    final text = _newStep.text.trim();
    if (text.isEmpty) return;
    _newStep.clear();
    _update({
      'steps': [
        ..._stepsJson(task.steps),
        {'title': text, 'completed': false},
      ],
    });
  }

  void _toggleStep(Task task, TaskStep step, bool done) => _update({
        'steps': [
          for (final s in task.steps) s.id == step.id ? TaskStep(id: s.id, title: s.title, completed: done).toJson() : s.toJson(),
        ],
      });

  void _removeStep(Task task, TaskStep step) =>
      _update({'steps': _stepsJson([for (final s in task.steps) if (s.id != step.id) s])});

  Future<void> _delete(Task task) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('delete_task_q')),
        content: Text(tr('delete_task_text', [task.title])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(tr('cancel'))),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(tr('delete'))),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await _guard(() => store.deleteTask(task));
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final task = store.task(widget.taskId);
        if (task == null) return const Scaffold(body: SizedBox.shrink());
        final theme = Theme.of(context);
        final due = task.due;
        return Scaffold(
          appBar: AppBar(
            automaticallyImplyLeading: widget.onClose == null,
            leading: widget.onClose == null
                ? null
                : IconButton(tooltip: tr('close'), icon: const Icon(Icons.close), onPressed: widget.onClose),
            actions: [
              IconButton(
                tooltip: tr('delete'),
                icon: const Icon(Icons.delete_outline),
                onPressed: () => _delete(task),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              ListTile(
                leading: Checkbox(
                  value: task.completed,
                  shape: const CircleBorder(),
                  onChanged: (v) => _update({'completed': v ?? false}),
                ),
                title: TextField(
                  controller: _title,
                  focusNode: _titleFocus,
                  style: theme.textTheme.titleLarge?.copyWith(
                    decoration: task.completed ? TextDecoration.lineThrough : null,
                  ),
                  decoration: InputDecoration(border: InputBorder.none, hintText: tr('title')),
                  minLines: 1,
                  maxLines: 3,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _saveTitle(),
                ),
              ),
              const Divider(height: 1),
              for (final step in task.steps)
                ListTile(
                  dense: true,
                  leading: Checkbox(
                    value: step.completed,
                    shape: const CircleBorder(),
                    onChanged: (v) => _toggleStep(task, step, v ?? false),
                  ),
                  title: Text(
                    step.title,
                    style: step.completed ? const TextStyle(decoration: TextDecoration.lineThrough) : null,
                  ),
                  trailing: IconButton(
                    tooltip: tr('remove_step'),
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => _removeStep(task, step),
                  ),
                ),
              ListTile(
                dense: true,
                leading: const Icon(Icons.add),
                title: TextField(
                  controller: _newStep,
                  decoration: InputDecoration(border: InputBorder.none, hintText: tr('add_step')),
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _addStep(task),
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Text(tr('priority'), style: theme.textTheme.labelLarge),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Wrap(
                  spacing: 8,
                  children: [
                    for (final level in const [0, 1, 2, 3])
                      ChoiceChip(
                        avatar: priorityColor(level) == null
                            ? null
                            : CircleAvatar(backgroundColor: priorityColor(level), radius: 6),
                        label: Text(priorityName(level)),
                        selected: task.priority == level,
                        onSelected: (_) => _update({'priority': level}),
                      ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Text(tr('due'), style: theme.textTheme.labelLarge),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      label: Text(tr('none')),
                      selected: due == null,
                      onSelected: (_) => _setGranularity(task, null),
                    ),
                    for (final g in Granularity.values)
                      ChoiceChip(
                        label: Text(_granularityName(g)),
                        selected: due?.granularity == g,
                        onSelected: (_) => _setGranularity(task, g),
                      ),
                  ],
                ),
              ),
              if (due != null)
                ListTile(
                  leading: IconButton(
                    tooltip: tr('back'),
                    icon: const Icon(Icons.chevron_left),
                    onPressed: () => _update({'due': due.shift(-1).toJson()}),
                  ),
                  title: TextButton(
                    onPressed: due.granularity == Granularity.day ? () => _pickDay(task) : null,
                    child: Text(
                      due.label(store.today),
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: task.isOverdue(store.today) ? theme.colorScheme.error : null,
                      ),
                    ),
                  ),
                  trailing: IconButton(
                    tooltip: tr('forward'),
                    icon: const Icon(Icons.chevron_right),
                    onPressed: () => _update({'due': due.shift(1).toJson()}),
                  ),
                ),
              if (due?.granularity == Granularity.day)
                ListTile(
                  leading: const Icon(Icons.schedule),
                  title: Text(task.dueTime ?? tr('add_time')),
                  trailing: task.dueTime == null
                      ? null
                      : IconButton(
                          tooltip: tr('remove_time'),
                          icon: const Icon(Icons.close),
                          onPressed: () => _update({'due_time': null}),
                        ),
                  onTap: () => _pickDueTime(task),
                ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.notifications_none),
                title: Text(task.reminder == null ? tr('add_reminder') : _reminderText(task.reminder!)),
                trailing: task.reminder == null
                    ? null
                    : IconButton(
                        tooltip: tr('remove_reminder'),
                        icon: const Icon(Icons.close),
                        onPressed: () => _update({'reminder': null}),
                      ),
                onTap: () => _pickReminder(task),
              ),
              ListTile(
                leading: const Icon(Icons.repeat),
                title: Text(task.recurrence == null ? tr('add_recurrence') : _recurrenceLabel(task.recurrence!)),
                trailing: task.recurrence == null
                    ? null
                    : IconButton(
                        tooltip: tr('remove_recurrence'),
                        icon: const Icon(Icons.close),
                        onPressed: () => _update({'recurrence': null}),
                      ),
                onTap: () => _pickRecurrence(task),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.list),
                title: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: store.list(task.listId) == null ? null : task.listId,
                    items: [
                      for (final list in store.lists) DropdownMenuItem(value: list.id, child: Text(list.name)),
                    ],
                    onChanged: (id) {
                      if (id != null && id != task.listId) _update({'list_id': id});
                    },
                  ),
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: TextField(
                  controller: _notes,
                  focusNode: _notesFocus,
                  minLines: 3,
                  maxLines: 12,
                  keyboardType: TextInputType.multiline,
                  decoration: InputDecoration(
                    labelText: tr('notes'),
                    alignLabelWithHint: true,
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _RecurrenceDialog extends StatefulWidget {
  const _RecurrenceDialog({this.initial, this.dueDay});

  final Recurrence? initial;
  final DateTime? dueDay;

  @override
  State<_RecurrenceDialog> createState() => _RecurrenceDialogState();
}

class _RecurrenceDialogState extends State<_RecurrenceDialog> {
  late int _interval = widget.initial?.interval ?? 1;
  late Granularity _unit = widget.initial?.unit ?? Granularity.week;
  // Ohne Liste gilt der Wochentag des Fälligkeitstags.
  late final Set<int> _weekdays = {
    ...?widget.initial?.weekdays,
    if ((widget.initial?.weekdays.isEmpty ?? true) && widget.dueDay != null) _weekdayOf(widget.dueDay!),
  };

  Recurrence get _result => Recurrence(
        _unit,
        _interval,
        _unit == Granularity.week && _weekdays.isNotEmpty ? (_weekdays.toList()..sort()) : const [],
      );

  @override
  Widget build(BuildContext context) {
    final (one, many) = _unitNames(_unit);
    return AlertDialog(
      title: Text(tr('recurrence')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(tr('every')),
              IconButton(
                icon: const Icon(Icons.remove),
                onPressed: _interval > 1 ? () => setState(() => _interval--) : null,
              ),
              Text('$_interval'),
              IconButton(icon: const Icon(Icons.add), onPressed: () => setState(() => _interval++)),
              Expanded(
                child: DropdownButton<Granularity>(
                  isExpanded: true,
                  value: _unit,
                  items: [
                    for (final g in Granularity.values)
                      DropdownMenuItem(
                        value: g,
                        child: Text(_interval == 1 ? _unitNames(g).$1 : _unitNames(g).$2),
                      ),
                  ],
                  onChanged: (g) => setState(() => _unit = g ?? _unit),
                ),
              ),
            ],
          ),
          if (_unit == Granularity.week) ...[
            const SizedBox(height: 8),
            Text(tr('on_days')),
            const SizedBox(height: 4),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                for (var d = 0; d < 7; d++)
                  FilterChip(
                    label: Text(_weekdayNames[d]),
                    showCheckmark: false,
                    visualDensity: VisualDensity.compact,
                    selected: _weekdays.contains(d),
                    // Mindestens ein Tag bleibt gewählt.
                    onSelected: (on) => setState(() {
                      if (on) {
                        _weekdays.add(d);
                      } else if (_weekdays.length > 1) {
                        _weekdays.remove(d);
                      }
                    }),
                  ),
              ],
            ),
          ],
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(tr('cancel'))),
        FilledButton(
          onPressed: () => Navigator.pop(context, _result),
          child: Text(_unit == Granularity.week && _weekdays.length > 1
              ? _recurrenceLabel(_result)
              : tr('every_many', [_interval, _interval == 1 ? one : many])),
        ),
      ],
    );
  }
}
