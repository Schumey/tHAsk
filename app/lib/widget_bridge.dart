import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

import 'credentials.dart';
import 'models.dart';
import 'snapshot_cache.dart';
import 'store.dart';
import 'views.dart';

/// Klasse des Android-Widgets (`ThaskWidgetReceiver.kt`).
const widgetProvider = 'de.schumey.thask.ThaskWidgetReceiver';

/// Pro Ansicht werden höchstens so viele offene Aufgaben ans Widget gegeben.
const maxWidgetTasks = 40;

/// Gibt dem Android-Widget die Daten aller Ansichten und nimmt dessen Aktionen entgegen.
class WidgetBridge {
  WidgetBridge(this.store);

  final ThaskStore store;

  /// Vom Widget angefordert („+“ oder Antippen eines Titels), solange die App noch nicht darauf reagiert hat.
  final launch = ValueNotifier<Uri?>(null);

  Timer? _timer;
  String? _last;
  StreamSubscription<Uri?>? _clicks;

  static bool get supported => !kIsWeb && Platform.isAndroid;

  Future<void> attach() async {
    if (!supported) return;
    await HomeWidget.registerInteractivityCallback(widgetBackgroundCallback);
    store.addListener(_schedule);
    final initial = await HomeWidget.initiallyLaunchedFromHomeWidget();
    if (initial != null) launch.value = initial;
    _clicks = HomeWidget.widgetClicked.listen((uri) {
      if (uri != null) launch.value = uri;
    });
    _schedule();
  }

  void dispose() {
    _timer?.cancel();
    _clicks?.cancel();
    store.removeListener(_schedule);
    launch.dispose();
  }

  void _schedule() {
    _timer?.cancel();
    _timer = Timer(const Duration(seconds: 1), () async {
      final json = encode(store);
      if (json == _last) return;
      _last = json;
      await push(store, json: json);
    });
  }

  /// Alle Ansichten mit ihren offenen Aufgaben als JSON für das Widget.
  static String encode(ThaskStore store) {
    final today = store.today;
    return jsonEncode({
      'today': isoDate(today),
      'views': [
        for (final view in ViewRef.all(store))
          {
            'id': view.id,
            'title': view.title(store),
            'count': view.tasks(store).where((t) => !t.completed).length,
            'tasks': [
              for (final task in view.tasks(store).where((t) => !t.completed).take(maxWidgetTasks))
                {
                  'id': task.id,
                  'title': task.title,
                  'due': task.due == null
                      ? null
                      : '${task.due!.label(today)}${task.dueTime != null ? ', ${task.dueTime}' : ''}',
                  'overdue': task.isOverdue(today),
                  // Fällig bis heute (blau) und Zeitraum statt festem Tag (Chip läuft aus).
                  'today': task.due != null && task.due!.end == dateOnly(today),
                  'fuzzy': task.due != null && task.due!.granularity != Granularity.day,
                  'priority': task.priority,
                },
            ],
          },
      ],
    });
  }

  /// Daten ans Widget schreiben und es neu zeichnen lassen. Vorläufig ausgeblendete Aufgaben werden wieder freigegeben.
  static Future<void> push(ThaskStore store, {String? json}) async {
    if (!supported || store.lists.isEmpty) return;
    await HomeWidget.saveWidgetData<String>('views', json ?? encode(store));
    await HomeWidget.saveWidgetData<String>('pending_done', '');
    await HomeWidget.updateWidget(qualifiedAndroidName: widgetProvider);
  }
}

/// Läuft im Hintergrund, wenn im Widget eine Aufgabe abgehakt oder aktualisiert wird
/// (`thask://complete?id=…` oder `thask://refresh`).
@pragma('vm:entry-point')
Future<void> widgetBackgroundCallback(Uri? uri) async {
  if (uri == null) return;
  // Die Warteschlange arbeitet nur die App selbst ab, nicht dieser kurze Hintergrundlauf.
  final store = ThaskStore(SecureCredentialStore(), cache: PrefsSnapshotCache(), autoFlush: false);
  try {
    await store.start();
    await store.waitUntilConnected(const Duration(seconds: 15));
    if (uri.host == 'complete') {
      final task = store.task(uri.queryParameters['id'] ?? '');
      if (task != null) {
        // Ohne Verbindung wird das Abhaken vorgemerkt und später von der App gesendet.
        await store.completeNow(task);
        // Das Änderungsereignis ist vor der Antwort eingetroffen; kurz Zeit zum Verarbeiten.
        await Future<void>.delayed(const Duration(milliseconds: 300));
      }
    }
  } catch (_) {
    // Bei einem Fehler bleibt der letzte Stand; push() gibt die ausgeblendete Aufgabe wieder frei.
  } finally {
    await WidgetBridge.push(store);
    store.dispose();
  }
}
