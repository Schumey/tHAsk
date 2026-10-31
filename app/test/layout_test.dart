import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thask/home_screen.dart';
import 'package:thask/ha_client.dart';
import 'package:thask/store.dart';
import 'package:thask/task_detail_screen.dart';

void main() {
  late ThaskStore store;

  Future<void> pumpHome(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    store = ThaskStore(
      _Credentials(),
      cache: _Cache(),
      connect: (_, _) async => throw HaException('offline'),
      clock: () => DateTime(2026, 10, 31),
    );
    await tester.runAsync(store.start);
    await tester.pumpWidget(MaterialApp(home: HomeScreen(store: store)));
    await tester.pump();
  }

  tearDown(() => store.dispose());

  testWidgets('Breites Fenster: Navigation fest, Details neben der Liste', (tester) async {
    await pumpHome(tester, const Size(1400, 900));
    expect(find.byType(Drawer), findsNothing);
    expect(find.text('Wichtig'), findsOneWidget);
    await tester.tap(find.text('Steuer'));
    await tester.pump();
    expect(find.byType(TaskDetailScreen), findsOneWidget);
    expect(find.text('Heute'), findsWidgets, reason: 'die Liste bleibt sichtbar');
    await tester.tap(find.byTooltip('Schließen'));
    await tester.pump();
    expect(find.byType(TaskDetailScreen), findsNothing);
  });

  testWidgets('„Heute“ zeigt Überfälliges oben in einem eigenen Abschnitt', (tester) async {
    await pumpHome(tester, const Size(400, 800));
    expect(find.text('Überfällig (1)'), findsOneWidget);
    expect(find.text('Heute (1)'), findsOneWidget);
    await tester.tap(find.text('Überfällig (1)'));
    await tester.pumpAndSettle();
    expect(find.text('Alt'), findsNothing);
    expect(store.overdueCollapsed, isTrue);
  });

  testWidgets('Schmales Fenster: Details als eigene Seite', (tester) async {
    await pumpHome(tester, const Size(400, 800));
    expect(find.text('Wichtig'), findsNothing);
    await tester.tap(find.text('Steuer'));
    await tester.pumpAndSettle();
    expect(find.byType(TaskDetailScreen), findsOneWidget);
    expect(find.byTooltip('Schließen'), findsNothing);
  });
}

class _Credentials implements CredentialStore {
  @override
  Future<({String address, String token})?> load() async => (address: 'ha', token: 't');

  @override
  Future<void> save(String address, String token) async {}

  @override
  Future<void> clear() async {}
}

class _Cache implements SnapshotCache {
  @override
  Future<String?> load() async => jsonEncode({
        'today': '2026-10-31',
        'lists': [
          {'id': 'l1', 'name': 'Aufgaben', 'position': 1},
        ],
        'tasks': [
          {'id': 't1', 'list_id': 'l1', 'title': 'Steuer', 'due': {'granularity': 'day', 'start': '2026-10-31'}},
          {'id': 't2', 'list_id': 'l1', 'title': 'Alt', 'due': {'granularity': 'day', 'start': '2026-10-29'}},
        ],
      });

  @override
  Future<void> save(String value) async {}

  @override
  Future<String?> loadOutbox() async => null;

  @override
  Future<void> saveOutbox(String value) async {}

  @override
  Future<String?> loadSetting(String key) async => null;

  @override
  Future<void> saveSetting(String key, String value) async {}

  @override
  Future<void> clear() async {}
}
