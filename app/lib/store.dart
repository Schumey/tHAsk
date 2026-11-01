import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'ha_client.dart';
import 'models.dart';
import 'parser.dart';

enum LinkState { disconnected, connecting, connected }

/// Zugangsdaten, getrennt vom Speicherort (Plugin) damit der Rest ohne Plugin testbar bleibt.
abstract class CredentialStore {
  Future<({String address, String token})?> load();
  Future<void> save(String address, String token);
  Future<void> clear();
}

/// Letzter bekannter Stand, damit die App auch ohne Verbindung etwas zeigt.
abstract class SnapshotCache {
  Future<String?> load();
  Future<void> save(String json);

  /// Noch nicht an Home Assistant gesendete Änderungen.
  Future<String?> loadOutbox();
  Future<void> saveOutbox(String json);

  /// Einstellungen dieses Geräts, z. B. der Zeitraum von „Wichtig“.
  Future<String?> loadSetting(String key);
  Future<void> saveSetting(String key, String value);

  /// Löscht Stand und Änderungen.
  Future<void> clear();
}

/// Eine vorgemerkte Änderung, die noch an Home Assistant gesendet werden muss.
class _Op {
  _Op(this.type, this.payload, this.created, {this.tempId});

  final String type;
  final Map<String, dynamic> payload;
  final String created;

  /// Vorläufige Kennung einer offline angelegten Aufgabe, bis der Server die echte vergibt.
  final String? tempId;

  Map<String, dynamic> toJson() => {'type': type, 'payload': payload, 'created': created, 'temp_id': tempId};

  factory _Op.fromJson(Map<String, dynamic> json) => _Op(
        json['type'] as String,
        (json['payload'] as Map).cast<String, dynamic>(),
        json['created'] as String,
        tempId: json['temp_id'] as String?,
      );
}

const _tempPrefix = 'local-';

typedef ClientFactory = Future<HaConnection> Function(String address, String token);

/// Hält Listen und Aufgaben, hält die Verbindung zu Home Assistant und wendet Änderungen an.
class ThaskStore extends ChangeNotifier {
  /// [autoFlush] aus: vorgemerkte Änderungen werden nicht gesendet (für den kurzen Hintergrundlauf des Widgets,
  /// damit nicht zwei Prozesse dieselbe Warteschlange abarbeiten).
  ThaskStore(this._credentials,
      {this._cache, ClientFactory? connect, DateTime Function()? clock, this.autoFlush = true})
      : _connect = connect ?? HaClient.connect,
        _clock = clock ?? DateTime.now;

  final CredentialStore _credentials;
  final SnapshotCache? _cache;
  Timer? _saveTimer;
  final ClientFactory _connect;
  final DateTime Function() _clock;
  final bool autoFlush;

  final List<_Op> _outbox = [];
  bool _flushing = false;
  int _localCounter = 0;

  /// Anzahl der Änderungen, die noch auf die Verbindung zu Home Assistant warten.
  int get pendingCount => _outbox.length;

  LinkState connection = LinkState.disconnected;
  String? error;
  bool loaded = false;
  bool get hasCredentials => _address != null;

  final Map<String, TaskList> _lists = {};
  final Map<String, Task> _tasks = {};
  // Unveränderte Server-Daten, aus denen der Zwischenspeicher geschrieben wird.
  final Map<String, Map<String, dynamic>> _rawLists = {};
  final Map<String, Map<String, dynamic>> _rawTasks = {};
  /// Zeigt, dass die Anzeige aus dem Zwischenspeicher stammt und noch nicht aktuell ist.
  bool fromCache = false;
  late DateTime today = dateOnly(_clock());

  String? _address;
  String? _token;
  HaConnection? _client;
  StreamSubscription<Map<String, dynamic>>? _events;
  bool _stopped = false;
  int _attempt = 0;
  Timer? _retry;

  List<TaskList> get lists => _lists.values.toList()..sort((a, b) => a.position.compareTo(b.position));

  TaskList? list(String id) => _lists[id];

  List<Task> tasksOf(String listId) {
    final list = _lists[listId];
    return sortTasks(_tasks.values.where((t) => t.listId == listId), list?.sort ?? 'manual');
  }

  /// Option der Integration, wie „Heute“ Überfälliges zeigt: 'section' (oben als eigener Abschnitt),
  /// 'mixed' (zwischen den heutigen) oder 'separate' (nicht in „Heute“, sondern in einer eigenen Ansicht).
  String overdueMode = 'section';

  /// „Heute“: alles, was bis heute fällig ist, und was heute erledigt wurde.
  /// Überfälliges nur, wenn es keine eigene Ansicht hat.
  List<Task> get dueToday => sortTasks(
        _tasks.values.where((t) => t.inToday(today) && (overdueMode != 'separate' || !t.isOverdue(today))),
        'due',
      );

  /// Offene Aufgaben, deren Fälligkeit vor heute endete.
  List<Task> get overdue => sortTasks(_tasks.values.where((t) => t.isOverdue(today)), 'due');

  /// Ob der Abschnitt „Überfällig“ in „Heute“ zugeklappt ist (pro Gerät).
  bool overdueCollapsed = false;

  void setOverdueCollapsed(bool collapsed) {
    overdueCollapsed = collapsed;
    _cache?.saveSetting('overdue_collapsed', collapsed ? '1' : '0');
    notifyListeners();
  }

  /// Alles, was bis zum Ende der laufenden Woche fällig ist (inkl. Überfälligem), ohne Erledigtes.
  List<Task> get thisWeek {
    final weekEnd = Period.containing(Granularity.week, today).end;
    return sortTasks(_tasks.values.where((t) => !t.completed && t.due != null && !t.due!.end.isAfter(weekEnd)), 'due');
  }

  /// Alles, was bis zum Ende des laufenden Monats fällig ist (inkl. Überfälligem), ohne Erledigtes.
  List<Task> get thisMonth {
    final monthEnd = Period.containing(Granularity.month, today).end;
    return sortTasks(_tasks.values.where((t) => !t.completed && t.due != null && !t.due!.end.isAfter(monthEnd)), 'due');
  }

  /// Zeitraum von „Wichtig“: `all` oder `week`, `month`, `quarter`, `year` (fällig bis zu dessen Ende).
  String importantRange = 'all';

  static const importantRanges = ['all', 'week', 'month', 'quarter', 'year'];

  Future<void> setImportantRange(String range) async {
    importantRange = range;
    notifyListeners();
    await _cache?.saveSetting('important_range', range);
  }

  /// „Wichtig“: Aufgaben mit Priorität hoch im gewählten Zeitraum, nach Fälligkeit.
  List<Task> get important {
    final unit = Granularity.values.where((g) => g.name == importantRange).firstOrNull;
    final end = unit == null ? null : Period.containing(unit, today).end;
    return sortTasks(
      _tasks.values.where((t) => t.isHighPriority && (end == null || (t.due != null && !t.due!.end.isAfter(end)))),
      'due',
    );
  }

  /// Alle Aufgaben mit Fälligkeit, nach Ende des Zeitraums.
  List<Task> get planned => sortTasks(_tasks.values.where((t) => t.due != null), 'due');

  int openCount(String listId) => _tasks.values.where((t) => t.listId == listId && !t.completed).length;

  // -- Verbindung ----------------------------------------------------------

  /// Gespeicherte Zugangsdaten laden und verbinden.
  Future<void> start() async {
    final saved = await _credentials.load();
    loaded = true;
    if (saved == null) {
      notifyListeners();
      return;
    }
    _address = saved.address;
    _token = saved.token;
    _stopped = false;
    await _loadCache();
    unawaited(_run());
    notifyListeners();
  }

  Future<void> _loadCache() async {
    final range = await _cache?.loadSetting('important_range');
    if (range != null && importantRanges.contains(range)) importantRange = range;
    overdueCollapsed = await _cache?.loadSetting('overdue_collapsed') == '1';
    final pending = await _cache?.loadOutbox();
    if (pending != null) {
      try {
        _outbox
          ..clear()
          ..addAll([for (final op in jsonDecode(pending) as List) _Op.fromJson((op as Map).cast<String, dynamic>())]);
      } catch (_) {
        _outbox.clear();
      }
    }
    final cached = await _cache?.load();
    if (cached == null) return;
    try {
      _apply({'type': 'snapshot', ...(jsonDecode(cached) as Map<String, dynamic>)}, fromServer: false);
      fromCache = true;
    } catch (_) {
      // Ein unlesbarer Zwischenspeicher wird beim nächsten Snapshot überschrieben.
    }
  }

  void _scheduleSave() {
    if (_cache == null) return;
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(seconds: 2), () {
      _cache.save(jsonEncode({
        'today': isoDate(today),
        'options': {'overdue_in_today': overdueMode},
        'lists': _rawLists.values.toList(),
        'tasks': _rawTasks.values.toList(),
      }));
    });
  }

  /// Anmelden mit neuen Zugangsdaten; wirft bei falscher Adresse oder falschem Token.
  Future<void> login(String address, String token) async {
    final client = await _connect(address.trim(), token.trim());
    await _credentials.save(address.trim(), token.trim());
    _address = address.trim();
    _token = token.trim();
    _stopped = false;
    _attach(client);
    await _subscribe(client);
  }

  Future<void> logout() async {
    _stopped = true;
    _retry?.cancel();
    await _events?.cancel();
    await _client?.close();
    _client = null;
    await _credentials.clear();
    _address = _token = null;
    _saveTimer?.cancel();
    await _cache?.clear();
    _lists.clear();
    _tasks.clear();
    _rawLists.clear();
    _rawTasks.clear();
    _outbox.clear();
    fromCache = false;
    connection = LinkState.disconnected;
    error = null;
    notifyListeners();
  }

  Future<void> _run() async {
    if (_stopped || _address == null) return;
    connection = LinkState.connecting;
    notifyListeners();
    try {
      final client = await _connect(_address!, _token!);
      _attach(client);
      await _subscribe(client);
    } on HaAuthException catch (e) {
      // Ein abgelehntes Token wird nicht erneut versucht.
      error = e.message;
      connection = LinkState.disconnected;
      _stopped = true;
      notifyListeners();
    } catch (e) {
      error = '$e';
      _scheduleRetry();
    }
  }

  void _attach(HaConnection client) {
    _client = client;
    unawaited(client.closed.then((_) {
      if (identical(_client, client) && !_stopped) {
        connection = LinkState.disconnected;
        notifyListeners();
        _scheduleRetry();
      }
    }));
  }

  Future<void> _subscribe(HaConnection client) async {
    await _events?.cancel();
    final completer = Completer<void>();
    _events = client.subscribe('thask/subscribe').listen(
      (event) {
        _apply(event);
        if (!completer.isCompleted) completer.complete();
      },
      onError: (Object e) {
        if (!completer.isCompleted) completer.completeError(e);
      },
    );
    await completer.future;
    connection = LinkState.connected;
    error = null;
    _attempt = 0;
    notifyListeners();
    if (autoFlush && _outbox.isNotEmpty) unawaited(_flush());
  }

  void _scheduleRetry() {
    if (_stopped) return;
    connection = LinkState.disconnected;
    notifyListeners();
    _retry?.cancel();
    final seconds = (1 << _attempt.clamp(0, 5)).clamp(2, 30);
    _attempt++;
    _retry = Timer(Duration(seconds: seconds), _run);
  }

  /// Wartet, bis die Verbindung steht und der erste Stand vom Server da ist; false nach Ablauf der Zeit.
  Future<bool> waitUntilConnected(Duration timeout) async {
    if (connection == LinkState.connected) return true;
    final result = Completer<bool>();
    void check() {
      if (connection == LinkState.connected && !result.isCompleted) result.complete(true);
    }

    addListener(check);
    final timer = Timer(timeout, () {
      if (!result.isCompleted) result.complete(false);
    });
    final connected = await result.future;
    removeListener(check);
    timer.cancel();
    return connected;
  }

  /// Nach Rückkehr in die App sofort neu verbinden statt auf den Timer zu warten.
  void resume() {
    if (_stopped || _address == null || connection == LinkState.connected) return;
    _retry?.cancel();
    unawaited(_run());
  }

  void _applyOptions(Map<String, dynamic> options) {
    final mode = options['overdue_in_today'];
    overdueMode = const ['section', 'mixed', 'separate'].contains(mode) ? mode as String : 'section';
  }

  final _reminders = StreamController<Task>.broadcast();

  /// Fällige Erinnerungen, so wie die Integration sie meldet (für Benachrichtigungen am PC).
  Stream<Task> get reminders => _reminders.stream;

  void _apply(Map<String, dynamic> event, {bool fromServer = true}) {
    switch (event['type']) {
      case 'reminder':
        _reminders.add(Task.fromJson((event['task'] as Map).cast<String, dynamic>()));
        return;
      case 'snapshot':
        _rawLists
          ..clear()
          ..addEntries([
            for (final l in event['lists'] as List) MapEntry((l as Map)['id'] as String, l.cast<String, dynamic>()),
          ]);
        _rawTasks
          ..clear()
          ..addEntries([
            for (final t in event['tasks'] as List) MapEntry((t as Map)['id'] as String, t.cast<String, dynamic>()),
          ]);
        _lists
          ..clear()
          ..addEntries([for (final e in _rawLists.entries) MapEntry(e.key, TaskList.fromJson(e.value))]);
        _tasks
          ..clear()
          ..addEntries([for (final e in _rawTasks.entries) MapEntry(e.key, Task.fromJson(e.value))]);
        today = dateOnly(DateTime.parse(event['today'] as String));
        _applyOptions((event['options'] as Map?)?.cast<String, dynamic>() ?? const {});
        // Noch nicht gesendete Änderungen bleiben sichtbar, bis der Server sie bestätigt.
        for (final op in _outbox) {
          _applyOptimistic(op);
        }
      case 'day_changed':
        today = dateOnly(DateTime.parse(event['today'] as String));
      case 'options':
        _applyOptions(event);
      case 'change':
        final id = event['id'] as String;
        final item = (event['item'] as Map?)?.cast<String, dynamic>();
        if (event['kind'] == 'list') {
          if (item == null) {
            _lists.remove(id);
            _rawLists.remove(id);
          } else {
            _lists[id] = TaskList.fromJson(item);
            _rawLists[id] = item;
          }
        } else {
          if (item == null) {
            _tasks.remove(id);
            _rawTasks.remove(id);
          } else {
            _tasks[id] = Task.fromJson(item);
            _rawTasks[id] = item;
          }
        }
    }
    if (fromServer) {
      fromCache = false;
      _scheduleSave();
    }
    notifyListeners();
  }

  // -- Aktionen --------------------------------------------------------------

  Future<dynamic> _call(String type, Map<String, dynamic> payload) {
    final client = _client;
    if (client == null || connection != LinkState.connected) {
      throw HaException('Keine Verbindung zu Home Assistant.');
    }
    return client.call(type, payload);
  }

  Task? task(String id) => _tasks[id];

  bool _isTemp(Object? id) => id is String && id.startsWith(_tempPrefix);

  String _newTempId() => '$_tempPrefix${_clock().microsecondsSinceEpoch}-${_localCounter++}';

  /// Änderung an Aufgaben: direkt senden, wenn verbunden, sonst vormerken und sofort sichtbar machen.
  /// Solange Änderungen warten, wird alles hinten angestellt, damit die Reihenfolge stimmt.
  Future<void> _mutate(String type, Map<String, dynamic> payload, {String? tempId}) async {
    final taskId = payload['task_id'];
    final direct =
        connection == LinkState.connected && _client != null && _outbox.isEmpty && !_isTemp(taskId);
    if (direct) {
      await _client!.call(type, payload);
      return;
    }
    if (type == 'thask/task/delete' && _isTemp(taskId)) {
      // Die Aufgabe kennt der Server noch gar nicht: Anlegen und alle Änderungen daran verwerfen.
      _outbox.removeWhere((op) => op.tempId == taskId || op.payload['task_id'] == taskId);
      _tasks.remove(taskId);
      _rawTasks.remove(taskId);
    } else {
      final op = _Op(type, payload, _clock().toUtc().toIso8601String(), tempId: tempId);
      _outbox.add(op);
      _applyOptimistic(op);
    }
    await _saveOutbox();
    notifyListeners();
    if (connection == LinkState.connected && autoFlush) unawaited(_flush());
  }

  Future<void> _saveOutbox() async {
    await _cache?.saveOutbox(jsonEncode([for (final op in _outbox) op.toJson()]));
  }

  /// Priorität aus einer Änderung; vorgemerkte Änderungen älterer App-Versionen enthalten noch `important`.
  int _priorityOf(Map<String, dynamic> payload) =>
      (payload['priority'] as num?)?.toInt() ?? (payload['important'] == true ? 3 : 0);

  /// Wirkt eine vorgemerkte Änderung auf den lokalen Stand, damit die Anzeige sofort stimmt.
  void _applyOptimistic(_Op op) {
    final payload = op.payload;
    switch (op.type) {
      case 'thask/task/create':
        final id = op.tempId!;
        final listId = payload['list_id'] as String;
        final positions = [for (final t in _tasks.values) if (t.listId == listId) t.position];
        final raw = <String, dynamic>{
          'id': id,
          'list_id': listId,
          'title': payload['title'],
          'notes': '',
          'completed': false,
          'priority': _priorityOf(payload),
          'important': _priorityOf(payload) >= 3,
          'due': payload['due'],
          'due_time': payload['due_time'],
          'reminder': null,
          'recurrence': payload['recurrence'],
          'my_day': payload['my_day'],
          'steps': <Map<String, dynamic>>[],
          'categories': <String>[],
          'position': positions.isEmpty ? 0.0 : positions.reduce((a, b) => a > b ? a : b) + 1,
          'created': op.created,
          'completed_at': null,
        };
        _rawTasks[id] = raw;
        _tasks[id] = Task.fromJson(raw);
      case 'thask/task/update':
        final id = payload['task_id'] as String;
        final current = _rawTasks[id];
        if (current == null) return;
        final raw = Map<String, dynamic>.of(current);
        payload.forEach((key, value) {
          if (key == 'task_id' || key == 'important') return;
          raw[key] = key == 'steps'
              ? [
                  for (final step in value as List)
                    {
                      'completed': false,
                      ...(step as Map).cast<String, dynamic>(),
                      'id': step['id'] ?? _newTempId(),
                    },
                ]
              : value;
        });
        if (payload.containsKey('priority') || payload.containsKey('important')) {
          raw['priority'] = _priorityOf(payload);
          raw['important'] = _priorityOf(payload) >= 3;
        }
        if (payload.containsKey('completed')) {
          raw['completed_at'] = payload['completed'] == true ? op.created : null;
        }
        _rawTasks[id] = raw;
        _tasks[id] = Task.fromJson(raw);
      case 'thask/task/delete':
        final id = payload['task_id'] as String;
        _tasks.remove(id);
        _rawTasks.remove(id);
    }
  }

  /// Vorgemerkte Änderungen der Reihe nach an Home Assistant senden. Bricht bei Verbindungsverlust ab
  /// und macht beim nächsten Verbinden weiter; vom Server abgelehnte Änderungen werden verworfen.
  Future<void> _flush() async {
    if (_flushing) return;
    _flushing = true;
    try {
      while (_outbox.isNotEmpty && connection == LinkState.connected && _client != null) {
        final op = _outbox.first;
        try {
          final result = await _client!.call(op.type, op.payload);
          if (op.tempId != null && result is Map) {
            final realId = result['id'] as String;
            for (final other in _outbox) {
              if (other.payload['task_id'] == op.tempId) other.payload['task_id'] = realId;
            }
            // Die echte Aufgabe kommt als Änderungsereignis vom Server.
            _tasks.remove(op.tempId);
            _rawTasks.remove(op.tempId);
          }
        } on HaException catch (e) {
          if (e.code == null) break;
          // Abgelehnt (z. B. Aufgabe wurde inzwischen gelöscht): die Änderung gilt nicht mehr.
          if (op.tempId != null) {
            _tasks.remove(op.tempId);
            _rawTasks.remove(op.tempId);
          }
        }
        _outbox.remove(op);
        await _saveOutbox();
        notifyListeners();
      }
    } finally {
      _flushing = false;
    }
  }

  Future<void> addTask(String listId, String title, {Period? due, int priority = 0}) =>
      _mutate(
        'thask/task/create',
        {
          'list_id': listId,
          'title': title,
          if (due != null) 'due': due.toJson(),
          if (priority > 0) 'priority': priority,
        },
        tempId: _newTempId(),
      );

  /// Aufgabe aus einem Schnelleingabe-Text anlegen („Steuer KW 47 !“). Erkannt wird auf dem Gerät,
  /// deshalb geht das auch ohne Verbindung. Mit [dueToday] wird sie ohne erkannte Fälligkeit heute fällig.
  Future<void> addQuick(String listId, String text, {bool dueToday = false}) {
    final parsed = parse(text, today);
    final title = parsed.title.isEmpty ? text.trim() : parsed.title;
    if (title.isEmpty) return Future.value();
    return _mutate(
      'thask/task/create',
      {
        'list_id': listId,
        'title': title,
        if (parsed.due != null)
          'due': parsed.due!.toJson()
        else if (dueToday)
          'due': Period.day(today).toJson(),
        if (parsed.dueTime != null) 'due_time': parsed.dueTime,
        if (parsed.recurrence != null) 'recurrence': parsed.recurrence!.toJson(),
        if (parsed.priority > 0) 'priority': parsed.priority,
      },
      tempId: _newTempId(),
    );
  }

  /// Felder einer Aufgabe ändern (in der Form der API, z. B. `{'notes': '…', 'due': null}`).
  Future<void> updateTask(Task task, Map<String, dynamic> patch) =>
      _mutate('thask/task/update', {'task_id': task.id, ...patch});

  Future<void> setCompleted(Task task, bool completed) => updateTask(task, {'completed': completed});

  Future<void> setPriority(Task task, int priority) => updateTask(task, {'priority': priority});

  Future<void> deleteTask(Task task) => _mutate('thask/task/delete', {'task_id': task.id});

  /// Für den Hintergrundlauf des Widgets: sofort senden, wenn verbunden, ohne die Warteschlange anzufassen.
  Future<void> completeNow(Task task) {
    if (connection == LinkState.connected && _client != null && !_isTemp(task.id)) {
      return _client!.call('thask/task/update', {'task_id': task.id, 'completed': true});
    }
    return setCompleted(task, true);
  }

  Future<void> clearCompleted(String listId) => _call('thask/list/clear_completed', {'list_id': listId});

  // -- Listen (nur mit Verbindung) ---------------------------------------------

  /// Vorhandene Listengruppen, alphabetisch.
  List<String> get groups {
    final names = {
      for (final list in _lists.values)
        if (list.group != null && list.group!.isNotEmpty) list.group!,
    }.toList();
    return names..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  }

  /// Legt eine Liste an und liefert ihre Id.
  Future<String?> createList(String name, {String? group}) async {
    final result = await _call('thask/list/create', {'name': name, 'group': ?group});
    return (result as Map?)?['id'] as String?;
  }

  /// Felder wie `name`, `group` (null = keine Gruppe) oder `sort`.
  Future<void> updateList(String listId, Map<String, dynamic> patch) async {
    await _call('thask/list/update', {'list_id': listId, ...patch});
  }

  Future<void> deleteList(String listId) async {
    await _call('thask/list/delete', {'list_id': listId});
  }

  @override
  void dispose() {
    _stopped = true;
    _retry?.cancel();
    _saveTimer?.cancel();
    _events?.cancel();
    _client?.close();
    _reminders.close();
    super.dispose();
  }
}
