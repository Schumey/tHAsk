import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:thask/desktop_bridge.dart';
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
      expect(isoWeekNumber(DateTime(2026, 12, 31)), 53);
      expect(isoWeekNumber(DateTime(2027, 1, 1)), 53);
      expect(isoWeekYear(DateTime(2027, 1, 1)), 2026);
    });
  });

  group('Wiederholung und Tagesplan', () {
    Period day(int month, int d) => Period.day(DateTime(2026, month, d));

    test('nextPeriod wie in core/models.py', () {
      final today = DateTime(2026, 11, 3);
      // Dienstag und Freitag.
      const tueFri = Recurrence(Granularity.week, 1, [1, 4]);
      expect(tueFri.nextPeriod(day(11, 3), today), day(11, 6));
      expect(tueFri.nextPeriod(day(11, 6), today), day(11, 10));
      // Alle zwei Wochen montags und donnerstags: der Donnerstag derselben Woche, dann zwei Wochen weiter.
      const everyOther = Recurrence(Granularity.week, 2, [0, 3]);
      expect(everyOther.nextPeriod(day(11, 2), DateTime(2026, 11, 2)), day(11, 5));
      expect(everyOther.nextPeriod(day(11, 5), DateTime(2026, 11, 2)), day(11, 16));
      // Monatlich am 31.: im Februar der 28., danach bleibt es beim 28.
      const monthly = Recurrence(Granularity.month, 1);
      final feb = monthly.nextPeriod(Period.day(DateTime(2026, 1, 31)), DateTime(2026, 1, 1));
      expect(feb, Period.day(DateTime(2026, 2, 28)));
      expect(monthly.nextPeriod(feb, DateTime(2026, 1, 1)), Period.day(DateTime(2026, 3, 28)));
      // Überfällig: das nächste Vorkommen liegt nicht vor heute.
      expect(const Recurrence(Granularity.day, 3).nextPeriod(day(11, 1), today), day(11, 4));
      // Zeiträume behalten ihre Art.
      expect(monthly.nextPeriod(Period(Granularity.month, DateTime(2026, 11, 1)), today), Period(Granularity.month, DateTime(2026, 12, 1)));
    });

    test('dayTasks zeigt kommende Vorkommen als Vorschau', () {
      final today = DateTime(2026, 11, 3);
      final tasks = [
        Task(id: 'muell', listId: 'l', title: 'Müll', due: day(11, 3), recurrence: const Recurrence(Granularity.week, 1, [1, 4])),
        Task(id: 'monat', listId: 'l', title: 'Rechnungen', due: Period(Granularity.month, DateTime(2026, 11, 1)), recurrence: const Recurrence(Granularity.month, 1)),
        Task(id: 'einmal', listId: 'l', title: 'Zahnarzt', due: day(11, 6)),
        Task(id: 'fertig', listId: 'l', title: 'Erledigt', due: day(11, 3), completed: true, recurrence: const Recurrence(Granularity.day, 1)),
      ];
      String describe(Task t) => '${t.id}${t.preview ? '*' : ''}';
      expect(dayTasks(tasks, DateTime(2026, 11, 3), today).map(describe), ['muell', 'monat', 'fertig']);
      expect(dayTasks(tasks, DateTime(2026, 11, 6), today).map(describe), ['muell*', 'monat', 'einmal']);
      expect(dayTasks(tasks, DateTime(2026, 11, 5), today).map(describe), ['monat']);
      expect(dayTasks(tasks, DateTime(2026, 12, 1), today).map(describe), ['muell*', 'monat*']);
      final preview = dayTasks(tasks, DateTime(2026, 11, 6), today).first;
      expect(preview.due, day(11, 6));
      expect(preview.id, 'muell');
    });

    test('Vorab erledigte Vorkommen: eigene Aufgabe statt Vorschau', () {
      final today = DateTime(2026, 11, 3);
      final bags = Task(
        id: 'muell', listId: 'l', title: 'Müll', due: day(11, 3),
        recurrence: const Recurrence(Granularity.week, 1, [1, 4]), skipped: const ['2026-11-10'],
      );
      final done = Task(id: 'vorab', listId: 'l', title: 'Müll', due: day(11, 10), completed: true, series: 'muell');
      final tasks = [bags, done];
      expect(bags.projectedPeriods(DateTime(2026, 11, 14), today), [day(11, 6), day(11, 13)]);
      String describe(Task t) => '${t.id}${t.preview ? '*' : ''}';
      expect(dayTasks(tasks, DateTime(2026, 11, 10), today).map(describe), ['vorab']);
      expect(dayTasks(tasks, DateTime(2026, 11, 13), today).map(describe), ['muell*']);
      final coming = bags.comingOccurrences(tasks, 3, today);
      expect([for (final o in coming) (o.due, o.done, o.own?.id)], [
        (day(11, 6), false, null),
        (day(11, 10), true, 'vorab'),
        (day(11, 13), false, null),
      ]);
      expect(done.comingOccurrences(tasks, 3, today), isEmpty);
    });
  });

  test('sortTasks hält die manuelle Reihenfolge bei Gleichstand', () {
    Task t(String id, double pos, {int priority = 0, Period? due}) =>
        Task(id: id, listId: 'l', title: id, position: pos, priority: priority, due: due, created: id);
    final tasks = [t('a', 3), t('b', 1, priority: 3), t('c', 2, priority: 1), t('d', 0, priority: 3)];
    expect([for (final x in sortTasks(tasks, 'manual')) x.id], ['d', 'b', 'c', 'a']);
    expect([for (final x in sortTasks(tasks, 'priority')) x.id], ['d', 'b', 'c', 'a']);
    // Ältere Server nennen die Sortierung noch „important“.
    expect([for (final x in sortTasks(tasks, 'important')) x.id], ['d', 'b', 'c', 'a']);
    final dated = [
      t('x', 0, due: Period(Granularity.month, DateTime(2026, 12, 1))),
      t('y', 1, due: Period(Granularity.week, DateTime(2026, 11, 9))),
      t('z', 2),
    ];
    expect([for (final x in sortTasks(dated, 'due')) x.id], ['y', 'x', 'z']);
  });

  test('Priorität: ältere Server senden nur „important“', () {
    Task parse(Map<String, dynamic> extra) =>
        Task.fromJson({'id': 't', 'list_id': 'l', 'title': 'x', ...extra});
    expect(parse({'priority': 2, 'important': false}).priority, 2);
    expect(parse({'priority': 3, 'important': true}).isHighPriority, isTrue);
    expect(parse({'important': true}).priority, 3);
    expect(parse({}).priority, 0);
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

    test('HTTP-Adresse für Anhänge', () {
      expect(httpUri('192.168.1.5:8123', '/api/thask/attachments/t1').toString(),
          'http://192.168.1.5:8123/api/thask/attachments/t1');
      expect(httpUri('https://ha.example.com/sub/', '/api/x').toString(), 'https://ha.example.com/sub/api/x');
    });
  });

  test('Anhänge einer Aufgabe', () {
    final task = Task.fromJson({
      'id': 't', 'list_id': 'l', 'title': 'Steuer',
      'attachments': [
        {'id': 'a1', 'name': 'Bescheid.pdf', 'size': 3500000, 'content_type': 'application/pdf'},
        {'id': 'a2', 'name': 'x.txt', 'size': 830},
      ],
    });
    expect([for (final a in task.attachments) a.sizeLabel], ['3.3 MB', '830 B']);
    expect(Task.fromJson({'id': 't', 'list_id': 'l', 'title': 'Alt'}).attachments, isEmpty);
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

  group('Offline-Änderungen', () {
    late _FakeConnection connection;
    late _MemoryCache cache;
    HaConnection? online;
    late ThaskStore store;

    ThaskStore newStore() => ThaskStore(
          _MemoryCredentials()..saved = (address: 'ha', token: 't'),
          cache: cache,
          connect: (_, _) async => online ?? (throw HaException('offline')),
          clock: () => DateTime(2026, 10, 31),
        );

    setUp(() async {
      connection = _FakeConnection();
      online = null;
      cache = _MemoryCache()
        ..json = jsonEncode({
          'today': '2026-10-31',
          'lists': [
            {'id': 'l1', 'name': 'Aufgaben', 'position': 1},
          ],
          'tasks': [
            {'id': 't1', 'list_id': 'l1', 'title': 'Steuer'},
          ],
        });
      store = newStore();
      await store.start();
    });

    tearDown(() => store.dispose());

    /// Verbindung herstellen: der Server liefert seinen Stand, danach werden die Änderungen gesendet.
    Future<void> reconnect() async {
      online = connection;
      store.resume();
      await Future<void>.delayed(Duration.zero);
      connection.emit(_snapshot);
      for (var i = 0; i < 20 && store.pendingCount > 0; i++) {
        await Future<void>.delayed(Duration.zero);
      }
    }

    test('Aufgabe ohne Verbindung anlegen: sofort sichtbar und vorgemerkt', () async {
      await store.addQuick('l1', 'Milch morgen !');
      expect(store.pendingCount, 1);
      final milk = store.tasksOf('l1').singleWhere((t) => t.title == 'Milch');
      expect(milk.priority, 1);
      expect(milk.due, Period.day(DateTime(2026, 11, 1)));
      expect(cache.outbox, isNotNull);
    });

    test('Reihenfolge ohne Verbindung ändern: sofort sichtbar, beim Verbinden gesendet', () async {
      await store.addQuick('l1', 'Milch');
      await store.addQuick('l1', 'Brot');
      // Neue Aufgaben kommen ans Ende; Brot nach ganz oben ziehen.
      expect([for (final t in store.tasksOf('l1')) t.title], ['Steuer', 'Milch', 'Brot']);
      final bread = store.tasksOf('l1').last;
      await store.moveTask(bread, null);
      expect([for (final t in store.tasksOf('l1')) t.title], ['Brot', 'Steuer', 'Milch']);
      await store.moveTask(store.task('t1')!, bread.id);
      expect([for (final t in store.tasksOf('l1')) t.title], ['Brot', 'Steuer', 'Milch']);

      connection.results['thask/task/create'] = {'id': 'real-1'};
      await reconnect();
      expect(store.pendingCount, 0);
      final moves = [for (final c in connection.calls) if (c.$1 == 'thask/task/move') c.$2];
      final created = connection.calls.where((c) => c.$1 == 'thask/task/create').length;
      expect(created, 2);
      // Die vorläufige Kennung von Brot ist durch die echte ersetzt.
      expect(moves.last, {'task_id': 't1', 'previous_id': 'real-1'});
    });

    test('Listen ohne Verbindung anlegen und ändern: vorläufige Kennung wird ersetzt', () async {
      final listId = await store.createList('Garten');
      expect(store.list(listId!)?.name, 'Garten');
      await store.addQuick(listId, 'Rasen mähen');
      await store.updateList(listId, {'name': 'Garten & Hof'});
      await store.updateList('l1', {'sort': 'priority'});
      expect(store.list(listId)?.name, 'Garten & Hof');
      expect(store.list('l1')?.sort, 'priority');
      expect(store.pendingCount, 4);

      connection.results['thask/list/create'] = {'id': 'liste-echt'};
      connection.results['thask/task/create'] = {'id': 'aufgabe-echt'};
      await reconnect();
      expect(store.pendingCount, 0);
      final calls = [for (final c in connection.calls) if (c.$1 != 'thask/subscribe') c];
      expect([for (final c in calls) c.$1], [
        'thask/list/create',
        'thask/task/create',
        'thask/list/update',
        'thask/list/update',
      ]);
      expect(calls[1].$2['list_id'], 'liste-echt');
      expect(calls[2].$2['list_id'], 'liste-echt');
    });

    test('Offline angelegte Liste wieder löschen: nichts wird gesendet', () async {
      final listId = await store.createList('Weg damit');
      await store.addQuick(listId!, 'Aufgabe');
      await store.deleteList(listId);
      expect(store.list(listId), isNull);
      expect(store.pendingCount, 0);
    });

    test('Vorkommen ohne Verbindung vorab abhaken und wieder öffnen', () async {
      final nov4 = Period.day(DateTime(2026, 11, 4));
      await store.updateTask(store.task('t1')!, {'due': nov4.toJson(), 'recurrence': const Recurrence(Granularity.week, 1).toJson()});
      final week2 = Period.day(DateTime(2026, 11, 11));
      await store.setOccurrence(store.task('t1')!, week2, true);
      final series = store.task('t1')!;
      expect(series.skipped, ['2026-11-11']);
      final own = series.occurrenceTask(store.allTasks, week2.start)!;
      expect(own.completed, isTrue);
      expect(own.recurrence, isNull);
      expect(own.series, 't1');
      expect(dayTasks(store.allTasks, DateTime(2026, 11, 11), store.today).map((t) => (t.id, t.preview)), [(own.id, false)]);

      await store.setOccurrence(store.task('t1')!, week2, false);
      expect(store.task('t1')!.skipped, isEmpty);
      expect(store.task('t1')!.occurrenceTask(store.allTasks, week2.start), isNull);
      expect(store.pendingCount, 3);

      connection.results['thask/task/occurrence'] = {'id': 'vorab-echt'};
      await reconnect();
      final sent = [for (final c in connection.calls) if (c.$1 == 'thask/task/occurrence') c.$2];
      expect([for (final c in sent) c['done']], [true, false]);
      expect(sent.first['due'], week2.toJson());
    });

    test('Erledigte ohne Verbindung löschen', () async {
      await store.setCompleted(store.task('t1')!, true);
      await store.clearCompleted('l1');
      expect(store.tasksOf('l1'), isEmpty);
      expect(store.pendingCount, 2);
    });

    test('Nach dem Verbinden werden die Änderungen der Reihe nach gesendet', () async {
      await store.addQuick('l1', 'Milch');
      final milk = store.tasksOf('l1').singleWhere((t) => t.title == 'Milch');
      await store.setCompleted(milk, true);
      await store.setCompleted(store.task('t1')!, true);
      expect(store.pendingCount, 3);

      connection.results['thask/task/create'] = {'id': 'real-1'};
      await reconnect();

      expect(store.pendingCount, 0);
      expect(connection.calls.map((c) => c.$1), [
        'thask/task/create',
        'thask/task/update',
        'thask/task/update',
      ]);
      // Die Änderung an der neuen Aufgabe geht an die echte Kennung, nicht an die vorläufige.
      expect(connection.calls[1].$2['task_id'], 'real-1');
      expect(connection.calls[2].$2['task_id'], 't1');
      expect(store.tasksOf('l1').where((t) => t.title == 'Milch'), isEmpty);
      expect(jsonDecode(cache.outbox!), isEmpty);
    });

    test('Eine Prioritätsänderung ist sofort sichtbar und geht als priority an den Server', () async {
      await store.updateTask(store.task('t1')!, {'priority': 2});
      expect(store.task('t1')!.priority, 2);
      expect(store.important, isEmpty);
      await store.updateTask(store.task('t1')!, {'priority': 3});
      expect(store.important.map((t) => t.id), ['t1']);

      await reconnect();
      expect(connection.calls.map((c) => c.$2['priority']), [2, 3]);
    });

    test('Eine noch nicht gesendete Aufgabe zu löschen verwirft alle ihre Änderungen', () async {
      await store.addQuick('l1', 'Milch');
      final milk = store.tasksOf('l1').singleWhere((t) => t.title == 'Milch');
      await store.setPriority(milk, 3);
      await store.deleteTask(milk);
      expect(store.pendingCount, 0);
      expect(store.tasksOf('l1').map((t) => t.title), ['Steuer']);
    });

    test('Vorgemerkte Änderungen überstehen einen Neustart', () async {
      await store.setCompleted(store.task('t1')!, true);
      store.dispose();
      store = newStore();
      await store.start();
      expect(store.pendingCount, 1);
      expect(store.task('t1')!.completed, isTrue);
    });

    test('Eine vom Server abgelehnte Änderung wird verworfen', () async {
      await store.deleteTask(store.task('t1')!);
      connection.errors['thask/task/delete'] = HaException('Not found', code: 'not_found');
      await reconnect();
      expect(store.pendingCount, 0);
    });

    test('Bei Verbindungsverlust bleibt die Änderung vorgemerkt', () async {
      await store.setCompleted(store.task('t1')!, true);
      connection.errors['thask/task/update'] = HaException('Die Verbindung wurde beendet.');
      await reconnect();
      expect(store.pendingCount, 1);
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
      expect(store.dueToday, isEmpty);
    });

    test('Änderungen werden angewendet', () async {
      await signIn();
      connection.emit({
        'type': 'change',
        'action': 'created',
        'kind': 'task',
        'id': 't2',
        'list_id': 'l1',
        'item': {'id': 't2', 'list_id': 'l1', 'title': 'Neu', 'due': {'granularity': 'day', 'start': '2026-10-31'}},
      });
      await Future<void>.delayed(Duration.zero);
      expect(store.dueToday.map((t) => t.title), ['Neu']);
      connection.emit({'type': 'change', 'action': 'removed', 'kind': 'task', 'id': 't2', 'list_id': 'l1', 'item': null});
      await Future<void>.delayed(Duration.zero);
      expect(store.dueToday, isEmpty);
    });

    test('Suche über alle Listen: jedes Wort in Titel, Notizen oder Schritten', () async {
      await signIn();
      connection.emit({
        'type': 'change',
        'action': 'created',
        'kind': 'task',
        'id': 't2',
        'list_id': 'l2',
        'item': {
          'id': 't2',
          'list_id': 'l2',
          'title': 'Milch',
          'notes': 'Hafer, nicht Soja',
          'steps': [
            {'id': 's1', 'title': 'Bio-Laden'},
          ],
        },
      });
      await Future<void>.delayed(Duration.zero);
      expect(store.search('milch').map((t) => t.title), ['Milch']);
      expect(store.search(' HAFER  bio ').map((t) => t.title), ['Milch']);
      expect(store.search('milch soja steuer'), isEmpty);
      expect(store.search('st').map((t) => t.title), ['Steuer']);
      expect(store.search('   '), isEmpty);
    });

    test('addQuick erkennt Fälligkeit und Priorität auf dem Gerät', () async {
      await signIn();
      await store.addQuick('l1', 'Steuer KW 47 !');
      final create = connection.calls.singleWhere((c) => c.$1 == 'thask/task/create').$2;
      expect(create['title'], 'Steuer');
      expect(create['due'], {'granularity': 'week', 'start': '2026-11-16'});
      expect(create['priority'], 1);
      expect(create.containsKey('important'), isFalse);
      expect(create.containsKey('due_time'), isFalse);
    });

    test('Listen anlegen, ändern und löschen', () async {
      await signIn();
      connection.results['thask/list/create'] = {'id': 'l9', 'name': 'Garten'};
      expect(await store.createList('Garten', group: 'Zuhause'), 'l9');
      await store.updateList('l1', {'group': null, 'sort': 'due'});
      await store.deleteList('l2');
      final calls = connection.calls.where((c) => c.$1.startsWith('thask/list/'));
      expect(calls.map((c) => c.$1), ['thask/list/create', 'thask/list/update', 'thask/list/delete']);
      expect(calls.map((c) => c.$2), [
        {'name': 'Garten', 'group': 'Zuhause'},
        {'list_id': 'l1', 'group': null, 'sort': 'due'},
        {'list_id': 'l2'},
      ]);
      // Ohne Gruppe wird keine gesendet.
      await store.createList('Ohne');
      expect(connection.calls.last.$2, {'name': 'Ohne'});
    });

    test('Gruppen sind eindeutig und sortiert', () async {
      await signIn();
      for (final (id, group) in [('l1', 'zuhause'), ('l2', 'Auto'), ('l3', 'Auto')]) {
        connection.emit({
          'type': 'change',
          'action': 'updated',
          'kind': 'list',
          'id': id,
          'list_id': id,
          'item': {'id': id, 'name': id, 'group': group},
        });
      }
      await Future<void>.delayed(Duration.zero);
      expect(store.groups, ['Auto', 'zuhause']);
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
      expect((list.single as Map)['priority'], 0);
      expect(list.map((t) => (t as Map)['title']), ['Steuer']);
      expect((list.single as Map)['due'], 'KW 44');
      expect((list.single as Map)['overdue'], isFalse);
      expect((list.single as Map)['fuzzy'], isTrue);
      expect((views['list:l1'] as Map)['count'], 1);
      expect(ViewRef.fromId('list:l1'), isA<ListRef>());
      expect(ViewRef.fromId('gibt-es-nicht'), isA<TodayView>());
    });

    test('Wichtig und Geplant', () async {
      await signIn();
      connection.emit({
        'type': 'change',
        'action': 'created',
        'kind': 'task',
        'id': 't3',
        'list_id': 'l1',
        'item': {'id': 't3', 'list_id': 'l1', 'title': 'Ohne Datum', 'priority': 3},
      });
      await Future<void>.delayed(Duration.zero);
      expect(store.important.map((t) => t.title), ['Ohne Datum']);
      expect(store.planned.map((t) => t.title), ['Steuer']);
    });

    test('Wichtig mit Zeitraum', () async {
      await signIn();
      for (final (id, due) in [('w', '2026-11-01'), ('m', '2026-10-31'), ('q', '2026-12-31'), ('o', null)]) {
        connection.emit({
          'type': 'change',
          'action': 'created',
          'kind': 'task',
          'id': id,
          'list_id': 'l1',
          'item': {
            'id': id,
            'list_id': 'l1',
            'title': id,
            'priority': 3,
            if (due != null) 'due': {'granularity': 'day', 'start': due},
          },
        });
      }
      await Future<void>.delayed(Duration.zero);
      // Heute ist Samstag, 31. Oktober: die Woche endet morgen, der Monat heute.
      expect(store.important.map((t) => t.id), ['m', 'w', 'q', 'o']);
      await store.setImportantRange('week');
      expect(store.important.map((t) => t.id), ['m', 'w']);
      await store.setImportantRange('month');
      expect(store.important.map((t) => t.id), ['m']);
      await store.setImportantRange('quarter');
      expect(store.important.map((t) => t.id), ['m', 'w', 'q']);
    });

    test('Heute zeigt Fälliges, Überfälliges und heute Erledigtes', () async {
      await signIn();
      final items = {
        'heute': {'due': {'granularity': 'day', 'start': '2026-10-31'}},
        'alt': {'due': {'granularity': 'day', 'start': '2026-10-20'}},
        'morgen': {'due': {'granularity': 'day', 'start': '2026-11-01'}},
        'ohne': <String, dynamic>{},
        'erledigt': {
          'due': {'granularity': 'day', 'start': '2026-10-31'},
          'completed': true,
          'completed_at': DateTime(2026, 10, 31, 9).toUtc().toIso8601String(),
        },
      };
      for (final MapEntry(:key, :value) in items.entries) {
        connection.emit({
          'type': 'change',
          'action': 'created',
          'kind': 'task',
          'id': key,
          'list_id': 'l1',
          'item': {'id': key, 'list_id': 'l1', 'title': key, ...value},
        });
      }
      await Future<void>.delayed(Duration.zero);
      expect(store.dueToday.map((t) => t.id).toSet(), {'heute', 'alt', 'erledigt'});
    });

    test('Schnelleingabe in „Heute“ macht die Aufgabe heute fällig', () async {
      await signIn();
      await store.addQuick('l1', 'Milch', dueToday: true);
      await store.addQuick('l1', 'Steuer KW 47', dueToday: true);
      final creates = connection.calls.where((c) => c.$1 == 'thask/task/create').map((c) => c.$2['due']).toList();
      expect(creates, [
        {'granularity': 'day', 'start': '2026-10-31'},
        {'granularity': 'week', 'start': '2026-11-16'},
      ]);
    });

    test('Tagesplan: gewählter Tag, Vorschauen und Schnelleingabe an diesem Tag', () async {
      await signIn();
      connection.emit({
        ..._snapshot,
        'tasks': [
          {
            'id': 'gießen',
            'list_id': 'l1',
            'title': 'Blumen gießen',
            'due': {'granularity': 'day', 'start': '2026-10-30'},
            'recurrence': {'unit': 'day', 'interval': 2},
          },
          {'id': 'post', 'list_id': 'l1', 'title': 'Post', 'due': {'granularity': 'day', 'start': '2026-11-02'}},
        ],
      });
      await Future<void>.delayed(Duration.zero);
      String describe(Task t) => '${t.id}${t.preview ? '*' : ''}';
      // Heute steht das Überfällige; abgehakt käme es am 1. November wieder, dann alle zwei Tage.
      expect(store.planDay, DateTime(2026, 10, 31));
      expect(store.dayPlan.map(describe), ['gießen']);
      store.setPlanDay(DateTime(2026, 11, 1));
      expect(store.dayPlan.map(describe), ['gießen*']);
      store.setPlanDay(DateTime(2026, 11, 2));
      expect(store.dayPlan.map(describe), ['post']);
      store.setPlanDay(DateTime(2026, 11, 3));
      expect(store.dayPlan.map(describe), ['gießen*']);
      await store.addQuick('l1', 'Brief', dueDay: store.planDay);
      final creates = connection.calls.where((c) => c.$1 == 'thask/task/create').map((c) => c.$2['due']).toList();
      expect(creates, [
        {'granularity': 'day', 'start': '2026-11-03'},
      ]);
      // Der Tagesplan steht nicht im Widget.
      expect(ViewRef.all(store).whereType<DayPlanView>(), isEmpty);
      expect(ViewRef.fromId('day_view'), isA<DayPlanView>());
    });

    test('Option der Integration: Überfälliges in „Heute“ oder als eigene Ansicht', () async {
      await signIn();
      connection.emit({
        ..._snapshot,
        'options': {'overdue_in_today': 'section'},
        'tasks': [
          {'id': 'a', 'list_id': 'l1', 'title': 'Alt', 'due': {'granularity': 'day', 'start': '2026-10-29'}},
          {'id': 'b', 'list_id': 'l1', 'title': 'Heute', 'due': {'granularity': 'day', 'start': '2026-10-31'}},
        ],
      });
      await Future<void>.delayed(Duration.zero);
      expect(store.overdueMode, 'section');
      expect([for (final t in store.dueToday) t.id], ['a', 'b']);
      expect(ViewRef.all(store).whereType<OverdueView>(), isEmpty);

      connection.emit({'type': 'options', 'overdue_in_today': 'separate'});
      await Future<void>.delayed(Duration.zero);
      expect([for (final t in store.dueToday) t.id], ['b']);
      expect([for (final t in store.overdue) t.id], ['a']);
      expect(ViewRef.all(store)[1], isA<OverdueView>());
      expect(ViewRef.fromId('overdue'), isA<OverdueView>());
    });

    test('Optionen der Integration: Heute, Woche und Monat getrennt', () async {
      // Heute ist Samstag, der 31. Oktober: Der Oktober endet heute, KW 44 morgen.
      await signIn();
      connection.emit({
        ..._snapshot,
        'tasks': [
          {'id': 'alt', 'list_id': 'l1', 'title': 'Alt', 'due': {'granularity': 'day', 'start': '2026-10-29'}},
          {'id': 'heute', 'list_id': 'l1', 'title': 'Heute', 'due': {'granularity': 'day', 'start': '2026-10-31'}},
          {'id': 'oktober', 'list_id': 'l1', 'title': 'Oktober', 'due': {'granularity': 'month', 'start': '2026-10-01'}},
          {'id': 'sonntag', 'list_id': 'l1', 'title': 'Sonntag', 'due': {'granularity': 'day', 'start': '2026-11-01'}},
          {'id': 'kw44', 'list_id': 'l1', 'title': 'KW 44', 'due': {'granularity': 'week', 'start': '2026-10-26'}},
        ],
      });
      await Future<void>.delayed(Duration.zero);
      Set<String> ids(List<Task> tasks) => {for (final t in tasks) t.id};
      expect(ids(store.dueToday), {'alt', 'heute', 'oktober'});
      expect(ids(store.thisWeek), {'alt', 'heute', 'oktober', 'sonntag', 'kw44'});
      expect(ids(store.thisMonth), {'alt', 'heute', 'oktober'});
      expect(taskbarCount(store), 3);

      connection.emit({'type': 'options', 'overdue_in_today': 'section', 'separate_week': true, 'separate_month': true});
      await Future<void>.delayed(Duration.zero);
      expect(ids(store.dueToday), {'alt', 'heute'});
      expect(ids(store.thisWeek), {'oktober', 'sonntag', 'kw44'});
      // Der Monat endet vor der Woche, getrennt bleibt nichts übrig.
      expect(ids(store.thisMonth), isEmpty);
      expect(taskbarCount(store), 2);

      // Als die nächsten 7 Tage reicht die Woche bis zum 7. November.
      connection.emit({'type': 'options', 'week_mode': 'rolling'});
      await Future<void>.delayed(Duration.zero);
      expect(store.thisWeekEnd, DateTime(2026, 11, 7));
      expect(ids(store.thisWeek), {'alt', 'heute', 'oktober', 'sonntag', 'kw44'});

      // Ausgeblendete Ansichten fehlen in der Navigation und im Widget.
      expect(ViewRef.all(store).whereType<PlannedView>(), hasLength(1));
      connection.emit({'type': 'options', 'hidden_views': ['planned', 'this_month']});
      await Future<void>.delayed(Duration.zero);
      final views = ViewRef.all(store);
      expect(views.whereType<PlannedView>(), isEmpty);
      expect(views.whereType<ThisMonthView>(), isEmpty);
      expect(views.whereType<ThisWeekView>(), hasLength(1));
    });

    test('Option: „Wichtig“ mit Priorität Mittel', () async {
      await signIn();
      connection.emit({
        ..._snapshot,
        'tasks': [
          {'id': 'hoch', 'list_id': 'l1', 'title': 'Hoch', 'priority': 3},
          {'id': 'mittel', 'list_id': 'l1', 'title': 'Mittel', 'priority': 2},
          {'id': 'niedrig', 'list_id': 'l1', 'title': 'Niedrig', 'priority': 1},
        ],
      });
      await Future<void>.delayed(Duration.zero);
      expect([for (final t in store.important) t.id], ['hoch']);
      connection.emit({'type': 'options', 'important_priority': 'medium'});
      await Future<void>.delayed(Duration.zero);
      expect({for (final t in store.important) t.id}, {'hoch', 'mittel'});
    });

    test('Listen für bestimmte Personen: nur in deren Übersicht, auf Wunsch alle', () async {
      await signIn();
      connection.emit({
        ..._snapshot,
        'me': 'max',
        'lists': [
          {'id': 'l1', 'name': 'Alle', 'position': 1},
          {'id': 'l2', 'name': 'Max', 'position': 2, 'members': ['max']},
          {'id': 'l3', 'name': 'Anna', 'position': 3, 'members': ['anna']},
        ],
        'tasks': [
          for (final l in ['l1', 'l2', 'l3'])
            {'id': 't$l', 'list_id': l, 'title': l, 'due': {'granularity': 'day', 'start': '2026-10-30'}},
        ],
      });
      await Future<void>.delayed(Duration.zero);
      expect([for (final l in store.visibleLists) l.id], ['l1', 'l2']);
      expect(store.otherListCount, 1);
      expect({for (final t in store.dueToday) t.listId}, {'l1', 'l2'});
      expect(store.tasksOf('l3'), hasLength(1), reason: 'die Liste selbst bleibt erreichbar');
      store.setShowAllLists(true);
      expect({for (final t in store.dueToday) t.listId}, {'l1', 'l2', 'l3'});
    });

    test('Einstellungen: Optionen laden und ändern', () async {
      await signIn();
      connection.results['thask/options/get'] = {
        'options': {'week_mode': 'calendar', 'hidden_views': <String>[]},
        'notify_services': ['persistent_notification'],
      };
      connection.results['thask/options/update'] = {
        'options': {'week_mode': 'rolling', 'hidden_views': <String>[]},
      };
      final loaded = await store.loadOptions();
      expect(loaded['notify_services'], ['persistent_notification']);
      final options = await store.updateOptions({'week_mode': 'rolling'});
      expect(options['week_mode'], 'rolling');
      expect(connection.calls.last.$1, 'thask/options/update');
      expect(connection.calls.last.$2, {'week_mode': 'rolling'});
    });

    test('Erinnerungen der Integration kommen als Stream, ohne die Daten zu ändern', () async {
      await signIn();
      final reminders = <Task>[];
      final sub = store.reminders.listen(reminders.add);
      connection.emit({
        'type': 'reminder',
        'task': {'id': 't1', 'list_id': 'l1', 'title': 'Steuer', 'list_name': 'Aufgaben'},
      });
      await Future<void>.delayed(Duration.zero);
      expect([for (final t in reminders) t.title], ['Steuer']);
      expect(store.task('t1')?.due, isNotNull);
      await sub.cancel();
    });

    test('Verpasste Erinnerungen: offen, nach dem letzten Lauf und nicht in der Zukunft', () {
      Task task(String id, String? reminder, {bool completed = false}) =>
          Task.fromJson({'id': id, 'list_id': 'l1', 'title': id, 'reminder': reminder, 'completed': completed});
      final since = DateTime.utc(2026, 11, 1, 8);
      final now = DateTime.utc(2026, 11, 1, 12);
      final tasks = [
        task('vorher', '2026-11-01T07:59:00Z'),
        task('verpasst', '2026-11-01T09:00:00Z'),
        task('später', '2026-11-01T11:30:00Z'),
        task('erledigt', '2026-11-01T10:00:00Z', completed: true),
        task('zukunft', '2026-11-01T13:00:00Z'),
        task('ohne', null),
      ];
      expect([for (final t in missedReminders(tasks, since, now)) t.id], ['später', 'verpasst']);
      expect(missedReminders(tasks, since, now, limit: 1).single.id, 'später');
    });

    test('Zähler an der Taskleiste: offene Aufgaben bis heute, auch Überfälliges', () async {
      await signIn();
      connection.emit({
        ..._snapshot,
        'options': {'overdue_in_today': 'separate'},
        'tasks': [
          {'id': 'a', 'list_id': 'l1', 'title': 'Alt', 'due': {'granularity': 'day', 'start': '2026-10-29'}},
          {'id': 'b', 'list_id': 'l1', 'title': 'Heute', 'due': {'granularity': 'day', 'start': '2026-10-31'}},
          {'id': 'c', 'list_id': 'l2', 'title': 'Morgen', 'due': {'granularity': 'day', 'start': '2026-11-01'}},
          {
            'id': 'd',
            'list_id': 'l2',
            'title': 'Erledigt',
            'completed': true,
            'due': {'granularity': 'day', 'start': '2026-10-31'},
          },
        ],
      });
      await Future<void>.delayed(Duration.zero);
      expect(taskbarCount(store), 2);
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
  final errors = <String, Object>{};

  void emit(Map<String, dynamic> event) => _events.add(event);

  @override
  Future<void> get closed => _closed.future;

  @override
  Future<dynamic> call(String type, [Map<String, dynamic> payload = const {}]) async {
    calls.add((type, payload));
    final error = errors[type];
    if (error != null) throw error;
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
  String? outbox;

  @override
  Future<String?> loadOutbox() async => outbox;

  @override
  Future<void> saveOutbox(String value) async => outbox = value;

  @override
  Future<String?> load() async => json;

  @override
  Future<void> save(String value) async => json = value;

  final settings = <String, String>{};

  @override
  Future<String?> loadSetting(String key) async => settings[key];

  @override
  Future<void> saveSetting(String key, String value) async => settings[key] = value;

  @override
  Future<void> clear() async {
    json = null;
    outbox = null;
  }
}
