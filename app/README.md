# tHAsk-App

Flutter-App für Android (mit Widget) und Windows. Was sie kann und wie man sie baut und installiert, steht in der [README im Hauptordner](../README.md#android-app).

## Aufbau

| Datei | Inhalt |
|---|---|
| `lib/main.dart` | Start, Theme (HA-Blau) |
| `lib/store.dart` | Zustand, Live-Abo `thask/subscribe`, Offline-Warteschlange |
| `lib/ha_client.dart` | WebSocket-Verbindung zu Home Assistant |
| `lib/models.dart`, `lib/views.dart` | Datenmodell und intelligente Listen |
| `lib/parser.dart` | Schnelleingabe (Gegenstück zu `custom_components/thask/core/parser.py`) |
| `lib/home_screen.dart`, `lib/task_detail_screen.dart`, `lib/list_dialogs.dart`, `lib/login_screen.dart` | Oberfläche |
| `lib/widget_bridge.dart` | Daten für das Android-Widget |
| `lib/desktop_bridge.dart` | Windows: Benachrichtigungen und Zähler an der Taskleiste |
| `android/app/src/main/kotlin/de/schumey/thask/` | Widget (Jetpack Glance) und Auswahl der Ansicht |
| `windows/runner/` | Windows: Einzelinstanz, Start minimiert, Zähler an der Taskleiste (`taskbar_badge.cpp`) |
| `windows/installer/` | Inno-Setup-Skript und Build-Skript für den Installer |

## Entwickeln

```bash
flutter analyze
```

```bash
flutter test
```

```bash
flutter run -d windows
```

Bei Änderungen am Parser die Tests in `test/` und `tests/test_parser.py` im Hauptordner gleich halten. Viele Dateien haben CRLF-Zeilenenden; kein `dart format` über ganze Dateien laufen lassen.
