import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'ha_client.dart';
import 'l10n.dart';
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

  /// Der Tag im Tagesplan; er folgt einem neuen Tag, solange er heute zeigt.
  late DateTime planDay = today;

  void setPlanDay(DateTime day) {
    planDay = dateOnly(day);
    notifyListeners();
  }

  void _setToday(DateTime day) {
    if (planDay == today) planDay = day;
    today = day;
  }

  String? _address;
  String? _token;
  HaConnection? _client;
  StreamSubscription<Map<String, dynamic>>? _events;
  bool _stopped = false;
  int _attempt = 0;
  Timer? _retry;

  List<TaskList> get lists => _lists.values.toList()..sort((a, b) => a.position.compareTo(b.position));

  /// Angemeldeter HA-Benutzer (aus dem Stand des Servers): Listen mit Personen stehen nur in deren Übersicht.
  String? me;

  /// Auch die Listen anderer in Navigation und intelligenten Ansichten zeigen (pro Gerät).
  bool showAllLists = false;

  void setShowAllLists(bool value) {
    showAllLists = value;
    _cache?.saveSetting('show_all_lists', value ? '1' : '0');
    notifyListeners();
  }

  /// Listen für alle oder für mich; mit [showAllLists] alle.
  List<TaskList> get visibleLists => showAllLists ? lists : [for (final l in lists) if (l.isFor(me)) l];

  /// Wie viele Listen nur anderen gehören.
  int get otherListCount => _lists.values.where((l) => !l.isFor(me)).length;

  /// Aufgaben der sichtbaren Listen, Grundlage der intelligenten Ansichten.
  Iterable<Task> get _visibleTasks {
    final ids = {for (final l in visibleLists) l.id};
    return _tasks.values.where((t) => ids.contains(t.listId));
  }

  /// Wer für eine Liste infrage kommt: aktive HA-Benutzer, `[(id, name)]`. Braucht eine Verbindung.
  Future<List<({String id, String name})>> loadUsers() async {
    final result = await _call('thask/users', {}) as Map;
    return [
      for (final u in result['users'] as List) (id: (u as Map)['id'] as String, name: u['name'] as String),
    ];
  }

  TaskList? list(String id) => _lists[id];

  List<Task> tasksOf(String listId) {
    final list = _lists[listId];
    return sortTasks(_tasks.values.where((t) => t.listId == listId), list?.sort ?? 'manual');
  }

  /// Option der Integration, wie „Heute“ Überfälliges zeigt: 'section' (oben als eigener Abschnitt),
  /// 'mixed' (zwischen den heutigen) oder 'separate' (nicht in „Heute“, sondern in einer eigenen Ansicht).
  String overdueMode = 'section';

  /// Optionen der Integration, die die Ansichten trennen (wie `core/models.py`): Mit [separateWeek] hat „Heute“
  /// nur Tage (und Überfälliges), ein Zeitraum, der heute endet („KW 44“ am Sonntag), steht in „Diese Woche“,
  /// und „Diese Woche“ lässt weg, was in „Heute“ steht. Mit [separateMonth] zeigt „Diesen Monat“ nur, was
  /// nach dieser Woche fällig ist.
  bool separateWeek = false;
  bool separateMonth = false;

  /// Option der Integration, was „Diese Woche“ umfasst: 'calendar' (Montag bis Sonntag) oder 'rolling'
  /// (heute und die nächsten sieben Tage, damit am Sonntag die nächste Woche schon drin ist).
  String weekMode = 'calendar';

  /// Option der Integration: intelligente Ansichten, die in der Navigation (und im Widget) fehlen.
  List<String> hiddenViews = const [];

  /// Option der Integration, ab welcher Priorität „Wichtig“ zeigt: 'high' (nur Hoch) oder 'medium' (Mittel und Hoch).
  String importantPriority = 'high';

  /// Eigene Zeiträume der Integration („X-Block“) mit den gefundenen Zeiträumen.
  List<CustomPeriod> customPeriods = const [];
  List<dynamic> _rawPeriods = const [];

  /// Letzter Tag von „Diese Woche“.
  DateTime get thisWeekEnd => weekMode == 'rolling'
      ? DateTime(today.year, today.month, today.day + 7)
      : Period.containing(Granularity.week, today).end;

  /// Ob eine Aufgabe zu „Heute“ gehört, Überfälliges eingeschlossen (auch für den Zähler an der Taskleiste).
  bool inTodayView(Task t) {
    if (!t.inToday(today)) return false;
    return !(separateWeek && t.due!.granularity != Granularity.day && !t.due!.end.isBefore(dateOnly(today)));
  }

  /// „Heute“: alles, was bis heute fällig ist, und was heute erledigt wurde.
  /// Überfälliges nur, wenn es keine eigene Ansicht hat.
  List<Task> get dueToday => sortTasks(
        _visibleTasks.where((t) => inTodayView(t) && (overdueMode != 'separate' || !t.isOverdue(today))),
        'due',
      );

  /// Offene Aufgaben, deren Fälligkeit vor heute endete.
  List<Task> get overdue => sortTasks(_visibleTasks.where((t) => t.isOverdue(today)), 'due');

  /// Ob der Abschnitt „Überfällig“ in „Heute“ zugeklappt ist (pro Gerät).
  bool overdueCollapsed = false;

  void setOverdueCollapsed(bool collapsed) {
    overdueCollapsed = collapsed;
    _cache?.saveSetting('overdue_collapsed', collapsed ? '1' : '0');
    notifyListeners();
  }

  /// Alles, was bis zum Ende der laufenden Woche fällig ist (inkl. Überfälligem), ohne Erledigtes.
  List<Task> get thisWeek {
    final weekEnd = thisWeekEnd;
    final day = dateOnly(today);
    bool inToday(Task t) => t.due!.end.isBefore(day) || (t.due!.granularity == Granularity.day && t.due!.end == day);
    return sortTasks(
      _visibleTasks.where(
        (t) => !t.completed && t.due != null && !t.due!.end.isAfter(weekEnd) && !(separateWeek && inToday(t)),
      ),
      'due',
    );
  }

  /// Alles, was bis zum Ende des laufenden Monats fällig ist (inkl. Überfälligem), ohne Erledigtes.
  List<Task> get thisMonth {
    final monthEnd = Period.containing(Granularity.month, today).end;
    final weekEnd = thisWeekEnd;
    return sortTasks(
      _visibleTasks.where(
        (t) =>
            !t.completed &&
            t.due != null &&
            !t.due!.end.isAfter(monthEnd) &&
            !(separateMonth && !t.due!.end.isAfter(weekEnd)),
      ),
      'due',
    );
  }

  /// Zeitraum von „Wichtig“: `all` oder `week`, `month`, `quarter`, `year` (fällig bis zu dessen Ende).
  String importantRange = 'all';

  static const importantRanges = ['all', 'week', 'month', 'quarter', 'year'];

  Future<void> setImportantRange(String range) async {
    importantRange = range;
    notifyListeners();
    await _cache?.saveSetting('important_range', range);
  }

  /// „Wichtig“: Aufgaben mit Priorität hoch (je nach Option auch mittel) im gewählten Zeitraum, nach Fälligkeit.
  List<Task> get important {
    final unit = Granularity.values.where((g) => g.name == importantRange).firstOrNull;
    final end = unit == null ? null : Period.containing(unit, today).end;
    return sortTasks(
      _visibleTasks.where((t) => t.priority >= (importantPriority == 'medium' ? 2 : 3) && (end == null || (t.due != null && !t.due!.end.isAfter(end)))),
      'due',
    );
  }

  /// Tagesplan für [planDay]: was an dem Tag fällig ist, mit Vorschauen wiederkehrender Aufgaben;
  /// heute auch Überfälliges.
  List<Task> get dayPlan {
    final tasks = dayTasks(_visibleTasks, planDay, today, customPeriods);
    if (planDay == today) tasks.addAll(_visibleTasks.where((t) => t.isOverdue(today)));
    return sortByTime(tasks);
  }

  /// Alle Aufgaben mit Fälligkeit, nach Ende des Zeitraums.
  List<Task> get planned => sortTasks(_visibleTasks.where((t) => t.due != null), 'due');

  /// Suche über alle sichtbaren Listen wie in der Weboberfläche: jedes Wort muss in Titel, Notizen,
  /// einem Schritt oder einer Kategorie vorkommen.
  List<Task> search(String query) {
    final words = query.trim().toLowerCase().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return const [];
    bool matches(Task t) {
      final haystack = [t.title, t.notes, for (final s in t.steps) s.title, ...t.categories].map((s) => s.toLowerCase());
      return words.every((w) => haystack.any((text) => text.contains(w)));
    }
    return sortTasks(_visibleTasks.where(matches), 'due');
  }

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
    showAllLists = await _cache?.loadSetting('show_all_lists') == '1';
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
        'me': me,
        'options': {
          'overdue_in_today': overdueMode,
          'separate_week': separateWeek,
          'separate_month': separateMonth,
          'week_mode': weekMode,
          'hidden_views': hiddenViews,
          'important_priority': importantPriority,
        },
        'lists': _rawLists.values.toList(),
        'tasks': _rawTasks.values.toList(),
        'periods': _rawPeriods,
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
    separateWeek = options['separate_week'] == true;
    separateMonth = options['separate_month'] == true;
    weekMode = options['week_mode'] == 'rolling' ? 'rolling' : 'calendar';
    hiddenViews = [for (final view in options['hidden_views'] as List? ?? const []) '$view'];
    importantPriority = options['important_priority'] == 'medium' ? 'medium' : 'high';
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
        _setToday(dateOnly(DateTime.parse(event['today'] as String)));
        me = event['me'] as String? ?? me;
        _applyOptions((event['options'] as Map?)?.cast<String, dynamic>() ?? const {});
        _applyPeriods(event['periods'] as List?);
        // Noch nicht gesendete Änderungen bleiben sichtbar, bis der Server sie bestätigt.
        for (final op in _outbox) {
          _applyOptimistic(op);
        }
      case 'day_changed':
        _setToday(dateOnly(DateTime.parse(event['today'] as String)));
      case 'options':
        _applyOptions(event);
      case 'periods':
        _applyPeriods(event['periods'] as List?);
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

  void _applyPeriods(List<dynamic>? raw) {
    _rawPeriods = raw ?? const [];
    customPeriods = [for (final p in _rawPeriods) CustomPeriod.fromJson((p as Map).cast<String, dynamic>())];
  }

  // -- Aktionen --------------------------------------------------------------

  Future<dynamic> _call(String type, Map<String, dynamic> payload) {
    final client = _client;
    if (client == null || connection != LinkState.connected) {
      throw HaException(tr('err_offline'));
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
    final listId = payload['list_id'];
    final direct = connection == LinkState.connected &&
        _client != null &&
        _outbox.isEmpty &&
        !_isTemp(taskId) &&
        !_isTemp(listId) &&
        !_isTemp(payload['previous_id']);
    if (direct) {
      await _client!.call(type, payload);
      return;
    }
    if (type == 'thask/task/delete' && _isTemp(taskId)) {
      // Die Aufgabe kennt der Server noch gar nicht: Anlegen und alle Änderungen daran verwerfen.
      _outbox.removeWhere((op) => op.tempId == taskId || op.payload['task_id'] == taskId);
      _tasks.remove(taskId);
      _rawTasks.remove(taskId);
    } else if (type == 'thask/list/delete' && _isTemp(listId)) {
      // Ebenso eine offline angelegte Liste samt ihren Aufgaben.
      final doomed = {for (final t in _tasks.values) if (t.listId == listId) t.id};
      _outbox.removeWhere(
        (op) => op.tempId == listId || op.payload['list_id'] == listId || doomed.contains(op.tempId) ||
            doomed.contains(op.payload['task_id']),
      );
      _lists.remove(listId);
      _rawLists.remove(listId);
      doomed.forEach(_tasks.remove);
      doomed.forEach(_rawTasks.remove);
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
      case 'thask/list/create':
        final id = op.tempId!;
        final position = _lists.values.fold<double>(-1, (max, l) => l.position > max ? l.position : max) + 1;
        final raw = <String, dynamic>{
          'id': id,
          'name': payload['name'],
          'group': payload['group'],
          'position': position,
          'sort': 'manual',
        };
        _rawLists[id] = raw;
        _lists[id] = TaskList.fromJson(raw);
      case 'thask/list/update':
        final id = payload['list_id'] as String;
        final current = _rawLists[id];
        if (current == null) return;
        final raw = Map<String, dynamic>.of(current)
          ..addAll({for (final e in payload.entries) if (e.key != 'list_id') e.key: e.value});
        _rawLists[id] = raw;
        _lists[id] = TaskList.fromJson(raw);
      case 'thask/list/delete':
        final id = payload['list_id'] as String;
        _lists.remove(id);
        _rawLists.remove(id);
        final doomed = [for (final t in _tasks.values) if (t.listId == id) t.id];
        doomed.forEach(_tasks.remove);
        doomed.forEach(_rawTasks.remove);
      case 'thask/list/clear_completed':
        final id = payload['list_id'] as String?;
        final doomed = [for (final t in _tasks.values) if (t.completed && (id == null || t.listId == id)) t.id];
        doomed.forEach(_tasks.remove);
        doomed.forEach(_rawTasks.remove);
      case 'thask/task/move':
        final task = _tasks[payload['task_id']];
        if (task == null) return;
        final order = sortTasks(_tasks.values.where((t) => t.listId == task.listId && t.id != task.id), 'manual');
        final previous = payload['previous_id'] as String?;
        final index = previous == null ? 0 : order.indexWhere((t) => t.id == previous) + 1;
        order.insert(index < 0 ? order.length : index, task);
        for (var position = 0; position < order.length; position++) {
          final id = order[position].id;
          final raw = Map<String, dynamic>.of(_rawTasks[id]!)..['position'] = position.toDouble();
          _rawTasks[id] = raw;
          _tasks[id] = Task.fromJson(raw);
        }
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
              for (final key in const ['task_id', 'previous_id', 'list_id']) {
                if (other.payload[key] == op.tempId) other.payload[key] = realId;
              }
            }
            // Die echte Aufgabe bzw. Liste kommt als Änderungsereignis vom Server.
            if (op.type == 'thask/list/create') {
              _lists.remove(op.tempId);
              _rawLists.remove(op.tempId);
              for (final task in [..._tasks.values.where((t) => t.listId == op.tempId)]) {
                final raw = Map<String, dynamic>.of(_rawTasks[task.id]!)..['list_id'] = realId;
                _rawTasks[task.id] = raw;
                _tasks[task.id] = Task.fromJson(raw);
              }
            } else {
              _tasks.remove(op.tempId);
              _rawTasks.remove(op.tempId);
            }
          }
        } on HaException catch (e) {
          if (e.code == null) break;
          // Abgelehnt (z. B. Aufgabe wurde inzwischen gelöscht): die Änderung gilt nicht mehr.
          if (op.tempId != null) {
            _tasks.remove(op.tempId);
            _rawTasks.remove(op.tempId);
            _lists.remove(op.tempId);
            _rawLists.remove(op.tempId);
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
  /// deshalb geht das auch ohne Verbindung. Mit [dueToday] wird sie ohne erkannte Fälligkeit heute fällig,
  /// mit [dueDay] an diesem Tag.
  Future<void> addQuick(String listId, String text, {bool dueToday = false, DateTime? dueDay}) {
    final parsed = parse(text, today, custom: customPeriods);
    final title = parsed.title.isEmpty ? text.trim() : parsed.title;
    if (title.isEmpty) return Future.value();
    return _mutate(
      'thask/task/create',
      {
        'list_id': listId,
        'title': title,
        if (parsed.due != null)
          'due': parsed.due!.toJson()
        else if (dueDay != null || dueToday)
          'due': Period.day(dueDay ?? today).toJson(),
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

  // -- Anhänge (nur mit Verbindung) --------------------------------------------

  /// Größte Datei, die Home Assistant annimmt (wie `MAX_SIZE` in `attachments.py`).
  static const maxAttachmentSize = 15 * 1024 * 1024;

  /// Lädt eine Datei zur Aufgabe hoch; die Aufgabe mit dem Anhang kommt danach über das Abo.
  Future<void> uploadAttachment(Task task, String name, List<int> bytes) async {
    if (connection != LinkState.connected || _address == null) throw HaException(tr('err_offline'));
    if (_isTemp(task.id)) throw HaException(tr('err_not_synced'));
    if (bytes.length > maxAttachmentSize) throw HaException(tr('err_file_too_large', [name]));
    final request = http.MultipartRequest('POST', httpUri(_address!, '/api/thask/attachments/${task.id}'))
      ..headers['Authorization'] = 'Bearer $_token'
      ..files.add(http.MultipartFile.fromBytes('file', bytes, filename: name));
    final response = await http.Response.fromStream(await request.send());
    if (response.statusCode != 200) {
      String message = response.reasonPhrase ?? '${response.statusCode}';
      try {
        message = (jsonDecode(response.body) as Map)['message'] as String? ?? message;
      } catch (_) {}
      throw HaException('$name: $message');
    }
  }

  /// Lädt einen Anhang herunter.
  Future<List<int>> downloadAttachment(Task task, TaskAttachment attachment) async {
    if (connection != LinkState.connected || _address == null) throw HaException(tr('err_offline'));
    final response = await http.get(
      httpUri(_address!, '/api/thask/attachments/${task.id}/${attachment.id}'),
      headers: {'Authorization': 'Bearer $_token'},
    );
    if (response.statusCode != 200) throw HaException('${attachment.name}: ${response.statusCode}');
    return response.bodyBytes;
  }

  Future<void> deleteAttachment(Task task, TaskAttachment attachment) =>
      _call('thask/attachment/delete', {'task_id': task.id, 'attachment_id': attachment.id});

  /// Aufgabe in ihrer Liste direkt hinter [previousId] einordnen, ohne [previousId] ganz nach oben
  /// (wie `move_task` in `core/collection.py`). Geht auch ohne Verbindung.
  Future<void> moveTask(Task task, String? previousId) =>
      _mutate('thask/task/move', {'task_id': task.id, 'previous_id': previousId});

  /// Für den Hintergrundlauf des Widgets: sofort senden, wenn verbunden, ohne die Warteschlange anzufassen.
  Future<void> completeNow(Task task) {
    if (connection == LinkState.connected && _client != null && !_isTemp(task.id)) {
      return _client!.call('thask/task/update', {'task_id': task.id, 'completed': true});
    }
    return setCompleted(task, true);
  }

  /// Erledigte einer Liste löschen; geht auch ohne Verbindung.
  Future<void> clearCompleted(String listId) => _mutate('thask/list/clear_completed', {'list_id': listId});

  // -- Optionen der Integration (nur mit Verbindung und für Administratoren) ---

  /// Alle Optionen und die Benachrichtigungsdienste: `{options: {...}, notify_services: [...]}`.
  Future<Map<String, dynamic>> loadOptions() async =>
      Map<String, dynamic>.from(await _call('thask/options/get', {}) as Map);

  /// Optionen ändern; liefert alle Optionen danach. Die Ansichten folgen über das Abo (Ereignis `options`).
  Future<Map<String, dynamic>> updateOptions(Map<String, dynamic> patch) async {
    final result = await _call('thask/options/update', patch) as Map;
    return Map<String, dynamic>.from(result['options'] as Map);
  }

  // -- Listen (nur mit Verbindung) ---------------------------------------------

  /// Vorhandene Listengruppen, alphabetisch.
  List<String> get groups {
    final names = {
      for (final list in _lists.values)
        if (list.group != null && list.group!.isNotEmpty) list.group!,
    }.toList();
    return names..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  }

  /// Legt eine Liste an und liefert ihre Id. Ohne Verbindung vorgemerkt, mit vorläufiger Id.
  Future<String?> createList(String name, {String? group}) async {
    final payload = {'name': name, 'group': ?group};
    if (connection == LinkState.connected && _client != null && _outbox.isEmpty) {
      final result = await _client!.call('thask/list/create', payload);
      return (result as Map?)?['id'] as String?;
    }
    final tempId = _newTempId();
    await _mutate('thask/list/create', payload, tempId: tempId);
    return tempId;
  }

  /// Felder wie `name`, `group` (null = keine Gruppe) oder `sort`; geht auch ohne Verbindung.
  Future<void> updateList(String listId, Map<String, dynamic> patch) =>
      _mutate('thask/list/update', {'list_id': listId, ...patch});

  /// Liste samt Aufgaben löschen; geht auch ohne Verbindung.
  Future<void> deleteList(String listId) => _mutate('thask/list/delete', {'list_id': listId});

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
