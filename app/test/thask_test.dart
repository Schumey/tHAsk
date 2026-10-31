import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:thask/ha_client.dart';
import 'package:thask/models.dart';
import 'package:thask/store.dart';
import 'package:thask/views.dart';
import 'package:thask/widget_bridge.dart';

void main() {
  group('Period', () {
    test('Ende je Granularität', () {
      expect(Period(Granularity.week, DateTime(2026, 11, 9)).end, DateTime(2026, 11, 15));
      expect(Period(Granularity.month, DateTime(2026, 2, 1)).end, DateTime(2026, 2, 28));
      expect(Period(Granularity.quarter, DateTime(2026, 10, 1)).end, DateTime(2026, 12, 31));
      expect(Period(Granularity.year, DateTime(2027, 1, 1)).end, DateTime(2027, 12, 31));
    });

    test('containing und shift', () {
      final week = Period.containing(Granularity.week, DateTime(2026, 11, 12));
      expect(week.start, DateTime(2026, 11, 9));
      expect(week.shift(-1).start, DateTime(2026, 11, 2));
      expect(Period.containing(Granularity.quarter, DateTime(2026, 11, 12)).start, DateTime(2026, 10, 1));
      expect(Period(Granularity.month, DateTime(2026, 12, 1)).shift(1).start, DateTime(2027, 1, 1));
    });

    test('Bezeichnung lässt das laufende Jahr weg', () {
      final today = DateTime(2026, 10, 31);
      expect(Period(Granularity.week, DateTime(2026, 11, 9)).label(today), 'KW 46');
      expect(Period(Granularity.month, DateTime(2026, 11, 1)).label(today), 'November');
      expect(Period(Granularity.month, DateTime(2027, 1, 1)).label(today), 'Januar 2027');
      expect(Period(Granularity.quarter, DateTime(2027, 1, 1)).label(today), 'Q1 2027');
      expect(Period(Granularity.year, DateTime(2027, 1, 1)).label(today), '2027');
      expect(Period(Granularity.day, DateTime(2026, 11, 9)).label(today), 'Mo, 9. Nov.');
      expect(Period(Granularity.day, DateTime(2026, 10, 31)).label(today), 'Heute');
      expect(Period(Granularity.day, DateTime(2026, 11, 1)).label(today), 'Morgen');
      expect(Period(Granularity.day, DateTime(2026, 10, 30)).label(today), 'Fr, 30. Okt.');
    });

    test('ISO-Woche am Jahreswechsel', () {
      expect(isoWeek(DateTime(2026, 12, 31)), 53);
      expect(isoWeek(DateTime(2027, 1, 1)), 53);
      expect(isoWeekYear(DateTime(2027, 1, 1)), 2026);
    });
  });

  test('sortTasks hält die manuelle Reihenfolge bei Gleichstand', () {
    Task t(String id, double pos, {bool important = false, Period? due}) =>
        Task(id: id, listId: 'l', title: id, position: pos, important: important, due: due, created: id);
    final tasks = [t('a', 3), t('b', 1, important: true), t('c', 2, important: true), t('d', 0)];
    expect([for (final x in sortTasks(tasks, 'manual')) x.id], ['d', 'b', 'c', 'a']);
    expect([for (final x in sortTasks(tasks, 'important')) x.id], ['b', 'c', 'd', 'a']);
    final dated = [
      t('x', 0, due: Period(Granularity.month, DateTime(2026, 12, 1))),
      t('y', 1, due: Period(Granularity.week, DateTime(2026, 11, 9))),
      t('z', 2),
    ];
    expect([for (final x in sortTasks(dated, 'due')) x.id], ['y', 'x', 'z']);
  });

  group('websocketUri', () {
    test('ergänzt Schema und Pfad', () {
      expect(websocketUri('192.168.1.5:8123').toString(), 'ws://192.168.1.5:8123/api/websocket');
      expect(websocketUri('https://ha.example.com/').toString(), 'wss://ha.example.com/api/websocket');
      expect(websocketUri('http://ha.local:8123/sub').toString(), 'ws://ha.local:8123/sub/api/websocket');
    });

    test('lehnt Leeres ab', () {
      expect(() => websocketUri('  '), throwsA(isA<HaException>()));
    });
  });

  group('Zwischenspeicher', () {
    test('Beim Start wird der letzte Stand angezeigt, auch ohne Verbindung', () async {
      final cache = _MemoryCache()..json = jsonEncode({'today': '2026-10-31', 'lists': [{'id': 'l2', 'name': 'Einkauf', 'position': 2}], 'tasks': []});
      final credentials = _MemoryCredentials()..saved = (address: 'ha', token: 't');
      final store = ThaskStore(credentials,
          cache: cache, connect: (_, _) async => throw HaException('offline'), clock: () => DateTime(2026, 10, 31));
      await store.start();
      expect(store.lists.map((l) => l.name), ['Einkauf']);
      expect(store.fromCache, isTrue);
      expect(store.connection, isNot(LinkState.connected));
      store.dispose();
    });

    test('Der Snapshot vom Server wird gespeichert', () async {
      final cache = _MemoryCache();
      final connection = _FakeConnection();
      final store = ThaskStore(_MemoryCredentials(),
          cache: cache, connect: (_, _) async => connection, clock: () => DateTime(2026, 10, 31));
      final login = store.login('ha', 't');
      await Future<void>.delayed(Duration.zero);
      connection.emit(_snapshot);
      await login;
      await Future<void>.delayed(const Duration(seconds: 3));
      final saved = jsonDecode(cache.json!) as Map<String, dynamic>;
      expect((saved['tasks'] as List).length, 1);
      expect(store.fromCache, isFalse);
      await store.logout();
      expect(cache.json, isNull);
      store.dispose();
    });
  });

  group('ThaskStore', () {
    late _FakeConnection connection;
    late _MemoryCredentials credentials;
    late ThaskStore store;

    setUp(() {
      connection = _FakeConnection();
      credentials = _MemoryCredentials();
      store = ThaskStore(credentials, connect: (_, _) async => connection, clock: () => DateTime(2026, 10, 31));
    });

    tearDown(() => store.dispose());

    Future<void> signIn() async {
      final login = store.login('ha', 't');
      await Future<void>.delayed(Duration.zero);
      connection.emit(_snapshot);
      await login;
    }

    test('Anmeldung lädt den Snapshot und speichert die Zugangsdaten', () async {
      final login = store.login(' http://ha:8123 ', ' token ');
      await Future<void>.delayed(Duration.zero);
      connection.emit(_snapshot);
      await login;
      expect(store.connection, LinkState.connected);
      expect(credentials.saved, (address: 'http://ha:8123', token: 'token'));
      expect(store.lists.map((l) => l.name), ['Aufgaben', 'Einkauf']);
      expect(store.tasksOf('l1').map((t) => t.title), ['Steuer']);
      expect(store.thisWeek.map((t) => t.title), ['Steuer']);
      // KW 44 endet am 1. November und gehört deshalb nicht mehr in den Oktober.
      expect(store.thisMonth, isEmpty);
      expect(store.myDay, isEmpty);
    });

    test('Änderungen werden angewendet', () async {
      await signIn();
      connection.emit({
        'type': 'change',
        'action': 'created',
        'kind': 'task',
        'id': 't2',
        'list_id': 'l1',
        'item': {'id': 't2', 'list_id': 'l1', 'title': 'Neu', 'my_day': '2026-10-31'},
      });
      await Future<void>.delayed(Duration.zero);
      expect(store.myDay.map((t) => t.title), ['Neu']);
      connection.emit({'type': 'change', 'action': 'removed', 'kind': 'task', 'id': 't2', 'list_id': 'l1', 'item': null});
      await Future<void>.delayed(Duration.zero);
      expect(store.myDay, isEmpty);
    });

    test('addQuick nutzt das Parse-Ergebnis des Servers', () async {
      await signIn();
      connection.results['thask/parse'] = {
        'title': 'Steuer',
        'due': {'granularity': 'week', 'start': '2026-11-16'},
        'due_time': null,
        'recurrence': null,
        'important': true,
      };
      await store.addQuick('l1', 'Steuer KW 47 !');
      final create = connection.calls.singleWhere((c) => c.$1 == 'thask/task/create').$2;
      expect(create['title'], 'Steuer');
      expect(create['due'], {'granularity': 'week', 'start': '2026-11-16'});
      expect(create['important'], true);
      expect(create.containsKey('due_time'), isFalse);
    });

    test('updateTask schickt nur die geänderten Felder', () async {
      await signIn();
      await store.updateTask(store.task('t1')!, {'due': null, 'notes': 'x'});
      final update = connection.calls.singleWhere((c) => c.$1 == 'thask/task/update').$2;
      expect(update, {'task_id': 't1', 'due': null, 'notes': 'x'});
    });

    test('Diesen Monat enthält alles bis zum Monatsende, Überfälliges eingeschlossen', () async {
      await signIn();
      for (final (id, due) in [
        ('a', {'granularity': 'month', 'start': '2026-10-01'}),
        ('b', {'granularity': 'day', 'start': '2026-09-15'}),
        ('c', {'granularity': 'month', 'start': '2026-11-01'}),
      ]) {
        connection.emit({
          'type': 'change',
          'action': 'created',
          'kind': 'task',
          'id': id,
          'list_id': 'l1',
          'item': {'id': id, 'list_id': 'l1', 'title': id, 'due': due},
        });
      }
      await Future<void>.delayed(Duration.zero);
      expect(store.thisMonth.map((t) => t.title), ['b', 'a']);
    });

    test('Widget-Daten enthalten alle Ansichten mit offenen Aufgaben', () async {
      await signIn();
      connection.emit({
        'type': 'change',
        'action': 'created',
        'kind': 'task',
        'id': 't4',
        'list_id': 'l1',
        'item': {'id': 't4', 'list_id': 'l1', 'title': 'Erledigt', 'completed': true},
      });
      await Future<void>.delayed(Duration.zero);
      final data = jsonDecode(WidgetBridge.encode(store)) as Map<String, dynamic>;
      final views = {for (final v in data['views'] as List) (v as Map)['id']: v};
      expect(views.keys, containsAll(['my_day', 'this_week', 'this_month', 'important', 'planned', 'list:l1', 'list:l2']));
      final list = (views['list:l1'] as Map)['tasks'] as List;
      expect(list.map((t) => (t as Map)['title']), ['Steuer']);
      expect((list.single as Map)['due'], 'KW 44');
      expect((list.single as Map)['overdue'], isFalse);
      expect(ViewRef.fromId('list:l1'), isA<ListRef>());
      expect(ViewRef.fromId('gibt-es-nicht'), isA<MyDayView>());
    });

    test('Wichtig und Geplant', () async {
      await signIn();
      connection.emit({
        'type': 'change',
        'action': 'created',
        'kind': 'task',
        'id': 't3',
        'list_id': 'l1',
        'item': {'id': 't3', 'list_id': 'l1', 'title': 'Ohne Datum', 'important': true},
      });
      await Future<void>.delayed(Duration.zero);
      expect(store.important.map((t) => t.title), ['Ohne Datum']);
      expect(store.planned.map((t) => t.title), ['Steuer']);
    });

    test('Abmelden löscht Zugangsdaten und Daten', () async {
      await signIn();
      await store.logout();
      expect(credentials.saved, isNull);
      expect(store.lists, isEmpty);
      expect(store.hasCredentials, isFalse);
    });
  });
}

const _snapshot = {
  'type': 'snapshot',
  'today': '2026-10-31',
  'lists': [
    {'id': 'l2', 'name': 'Einkauf', 'position': 2},
    {'id': 'l1', 'name': 'Aufgaben', 'position': 1},
  ],
  'tasks': [
    {
      'id': 't1',
      'list_id': 'l1',
      'title': 'Steuer',
      'due': {'granularity': 'week', 'start': '2026-10-26'},
    },
  ],
};

class _FakeConnection implements HaConnection {
  final _events = StreamController<Map<String, dynamic>>();
  final _closed = Completer<void>();
  final calls = <(String, Map<String, dynamic>)>[];
  final results = <String, dynamic>{};

  void emit(Map<String, dynamic> event) => _events.add(event);

  @override
  Future<void> get closed => _closed.future;

  @override
  Future<dynamic> call(String type, [Map<String, dynamic> payload = const {}]) async {
    calls.add((type, payload));
    return results[type];
  }

  @override
  Stream<Map<String, dynamic>> subscribe(String type, [Map<String, dynamic> payload = const {}]) => _events.stream;

  @override
  Future<void> close() async {
    if (!_closed.isCompleted) _closed.complete();
  }
}

class _MemoryCredentials implements CredentialStore {
  ({String address, String token})? saved;

  @override
  Future<({String address, String token})?> load() async => saved;

  @override
  Future<void> save(String address, String token) async => saved = (address: address, token: token);

  @override
  Future<void> clear() async => saved = null;
}

class _MemoryCache implements SnapshotCache {
  String? json;

  @override
  Future<String?> load() async => json;

  @override
  Future<void> save(String value) async => json = value;

  @override
  Future<void> clear() async => json = null;
}
