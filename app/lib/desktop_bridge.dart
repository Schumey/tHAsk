import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications_platform_interface/flutter_local_notifications_platform_interface.dart';
import 'package:flutter_local_notifications_windows/flutter_local_notifications_windows.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'l10n.dart';
import 'models.dart';
import 'store.dart';

/// Kanal zum Windows-Runner (`runner/flutter_window.cpp`): Zähler an der Taskleiste, Fenster nach vorn holen,
/// Texte des Symbols im Infobereich (`setTray`).
const _taskbar = MethodChannel('thask/taskbar');

/// Zähler an der Taskleiste: offene Aufgaben in „Heute“, Überfälliges eingeschlossen.
int taskbarCount(ThaskStore store) =>
    [for (final list in store.lists) ...store.tasksOf(list.id)].where((t) => !t.completed && store.inTodayView(t)).length;

/// Offene Aufgaben, deren Erinnerung nach [since] und spätestens [now] fällig wurde: verpasst, weil die App nicht lief.
/// Höchstens [limit], die neuesten zuerst.
List<Task> missedReminders(Iterable<Task> tasks, DateTime since, DateTime now, {int limit = 5}) {
  final missed = <(DateTime, Task)>[
    for (final task in tasks)
      if (!task.completed && task.reminder != null)
        if (DateTime.tryParse(task.reminder!) case final at? when at.isAfter(since) && !at.isAfter(now)) (at, task),
  ]..sort((a, b) => b.$1.compareTo(a.$1));
  return [for (final (_, task) in missed.take(limit)) task];
}

/// Windows: zeigt Erinnerungen als Benachrichtigung und die Zahl der heute fälligen Aufgaben an der Taskleiste.
class DesktopBridge {
  DesktopBridge(this.store);

  final ThaskStore store;

  /// Erst bei Bedarf anlegen: Der Konstruktor lädt eine Windows-DLL und würde auf Android abstürzen.
  late final _notifications = FlutterLocalNotificationsWindows();
  StreamSubscription<Task>? _reminders;
  int? _count;

  static bool get supported => !kIsWeb && Platform.isWindows;

  Future<void> attach() async {
    if (!supported) return;
    await _notifications.initialize(
      settings: const WindowsInitializationSettings(
        appName: 'tHAsk',
        appUserModelId: 'Schumey.tHAsk',
        guid: '9d3c3f1e-5b0a-4f7e-9a51-2c8e7b4d6a10',
      ),
      onDidReceiveNotificationResponse: _onResponse,
    );
    _reminders = store.reminders.listen((task) {
      _show(task);
      unawaited(_markSeen());
    });
    store.addListener(_updateCount);
    store.addListener(_catchUp);
    _updateCount();
    _catchUp();
    // Merkt sich, bis wann Erinnerungen angekommen sein können, damit der nächste Start nur Verpasstes nachholt.
    _seenTimer = Timer.periodic(const Duration(minutes: 1), (_) => unawaited(_markSeen()));
  }

  static const _seenKey = 'thask_reminders_seen';
  Timer? _seenTimer;
  bool _caughtUp = false;

  Future<void> _markSeen() async =>
      (await SharedPreferences.getInstance()).setString(_seenKey, DateTime.now().toUtc().toIso8601String());

  /// Einmal nach dem ersten Stand vom Server: Erinnerungen zeigen, die fällig wurden, während die App nicht lief.
  Future<void> _catchUp() async {
    if (_caughtUp || !store.loaded || store.fromCache || store.connection != LinkState.connected) return;
    _caughtUp = true;
    final prefs = await SharedPreferences.getInstance();
    final since = DateTime.tryParse(prefs.getString(_seenKey) ?? '');
    final now = DateTime.now();
    if (since != null) {
      for (final task in missedReminders([for (final l in store.lists) ...store.tasksOf(l.id)], since, now)) {
        await _show(task);
      }
    }
    await _markSeen();
  }

  void dispose() {
    if (!supported) return;
    _reminders?.cancel();
    _seenTimer?.cancel();
    store.removeListener(_updateCount);
    store.removeListener(_catchUp);
    _notifications.dispose();
  }

  void _updateCount() {
    // Ohne Verbindung und ohne Zwischenspeicher wäre die Zahl 0 und damit falsch.
    if (!store.loaded || !store.hasCredentials) return;
    final count = taskbarCount(store);
    if (count == _count) return;
    _count = count;
    unawaited(_taskbar.invokeMethod('setBadge', count).catchError((_) => null));
    unawaited(_taskbar.invokeMethod('setTray', {
      'tooltip': count > 0 ? 'tHAsk – ${tr('today_n', [count])}' : 'tHAsk',
      'open': tr('tray_open'),
      'quit': tr('tray_quit'),
    }).catchError((_) => null));
  }

  Future<void> _show(Task task) async {
    final list = store.list(task.listId)?.name;
    await _notifications.show(
      // Die Kennung pro Aufgabe ersetzt eine ältere Benachrichtigung derselben Aufgabe.
      id: task.id.hashCode & 0x7fffffff,
      title: task.title,
      body: list ?? tr('reminder'),
      payload: 'open:${task.id}',
      notificationDetails: WindowsNotificationDetails(
        actions: [WindowsAction(content: tr('done'), arguments: 'done:${task.id}')],
      ),
    );
  }

  void _onResponse(NotificationResponse response) {
    final payload = response.payload ?? '';
    final split = payload.indexOf(':');
    if (split < 0) return;
    final task = store.task(payload.substring(split + 1));
    switch (payload.substring(0, split)) {
      case 'done':
        if (task != null && !task.completed) unawaited(store.setCompleted(task, true));
      case 'open':
        unawaited(_taskbar.invokeMethod('activate').catchError((_) => null));
    }
  }
}
