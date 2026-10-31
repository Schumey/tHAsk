import 'dart:async';

import 'package:flutter/foundation.dart';

import 'ha_client.dart';
import 'models.dart';

enum LinkState { disconnected, connecting, connected }

/// Zugangsdaten, getrennt vom Speicherort (Plugin) damit der Rest ohne Plugin testbar bleibt.
abstract class CredentialStore {
  Future<({String address, String token})?> load();
  Future<void> save(String address, String token);
  Future<void> clear();
}

typedef ClientFactory = Future<HaConnection> Function(String address, String token);

/// Hält Listen und Aufgaben, hält die Verbindung zu Home Assistant und wendet Änderungen an.
class ThaskStore extends ChangeNotifier {
  ThaskStore(this._credentials, {ClientFactory? connect, DateTime Function()? clock})
      : _connect = connect ?? HaClient.connect,
        _clock = clock ?? DateTime.now;

  final CredentialStore _credentials;
  final ClientFactory _connect;
  final DateTime Function() _clock;

  LinkState connection = LinkState.disconnected;
  String? error;
  bool loaded = false;
  bool get hasCredentials => _address != null;

  final Map<String, TaskList> _lists = {};
  final Map<String, Task> _tasks = {};
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

  /// Aufgaben für „Mein Tag“ über alle Listen.
  List<Task> get myDay => sortTasks(_tasks.values.where((t) => t.inMyDay(today)), 'manual');

  /// Alles, was bis zum Ende der laufenden Woche fällig ist (inkl. Überfälligem), ohne Erledigtes.
  List<Task> get thisWeek {
    final weekEnd = Period.containing(Granularity.week, today).end;
    return sortTasks(_tasks.values.where((t) => !t.completed && t.due != null && !t.due!.end.isAfter(weekEnd)), 'due');
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
    unawaited(_run());
    notifyListeners();
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
    _lists.clear();
    _tasks.clear();
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

  /// Nach Rückkehr in die App sofort neu verbinden statt auf den Timer zu warten.
  void resume() {
    if (_stopped || _address == null || connection == LinkState.connected) return;
    _retry?.cancel();
    unawaited(_run());
  }

  void _apply(Map<String, dynamic> event) {
    switch (event['type']) {
      case 'snapshot':
        _lists
          ..clear()
          ..addEntries([
            for (final l in event['lists'] as List) MapEntry((l as Map)['id'] as String, TaskList.fromJson(l.cast())),
          ]);
        _tasks
          ..clear()
          ..addEntries([
            for (final t in event['tasks'] as List) MapEntry((t as Map)['id'] as String, Task.fromJson(t.cast())),
          ]);
        today = dateOnly(DateTime.parse(event['today'] as String));
      case 'day_changed':
        today = dateOnly(DateTime.parse(event['today'] as String));
      case 'change':
        final id = event['id'] as String;
        final item = (event['item'] as Map?)?.cast<String, dynamic>();
        if (event['kind'] == 'list') {
          if (item == null) {
            _lists.remove(id);
          } else {
            _lists[id] = TaskList.fromJson(item);
          }
        } else {
          if (item == null) {
            _tasks.remove(id);
          } else {
            _tasks[id] = Task.fromJson(item);
          }
        }
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

  Future<void> addTask(String listId, String title, {Period? due, bool important = false, bool myDay = false}) async {
    await _call('thask/task/create', {
      'list_id': listId,
      'title': title,
      if (due != null) 'due': due.toJson(),
      if (important) 'important': true,
      if (myDay) 'my_day': isoDate(today),
    });
  }

  /// Aufgabe aus einem Schnelleingabe-Text anlegen („Steuer KW 47 !“): der Server erkennt Fälligkeit und Wichtig.
  Future<void> addQuick(String listId, String text, {bool myDay = false}) async {
    final parsed = await parse(text);
    final title = (parsed['title'] as String).trim();
    await _call('thask/task/create', {
      'list_id': listId,
      'title': title.isEmpty ? text.trim() : title,
      if (parsed['due'] != null) 'due': parsed['due'],
      if (parsed['due_time'] != null) 'due_time': parsed['due_time'],
      if (parsed['recurrence'] != null) 'recurrence': parsed['recurrence'],
      if (parsed['important'] == true) 'important': true,
      if (myDay) 'my_day': isoDate(today),
    });
  }

  Future<void> setCompleted(Task task, bool completed) =>
      _call('thask/task/update', {'task_id': task.id, 'completed': completed});

  Future<void> setImportant(Task task, bool important) =>
      _call('thask/task/update', {'task_id': task.id, 'important': important});

  Future<void> deleteTask(Task task) => _call('thask/task/delete', {'task_id': task.id});

  Future<void> clearCompleted(String listId) => _call('thask/list/clear_completed', {'list_id': listId});

  /// Schnelleingabe zerlegen lassen (Titel, Fälligkeit, Wichtig, …).
  Future<Map<String, dynamic>> parse(String text) async =>
      (await _call('thask/parse', {'text': text}) as Map).cast<String, dynamic>();

  @override
  void dispose() {
    _stopped = true;
    _retry?.cancel();
    _events?.cancel();
    _client?.close();
    super.dispose();
  }
}
