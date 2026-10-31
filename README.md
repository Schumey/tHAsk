# tHAsk

Lokale Aufgabenverwaltung für Home Assistant – mit **unscharfen Fälligkeiten**: Eine Aufgabe ist nicht nur an einem Tag fällig, sondern auch „in KW 46“, „im November“, „in Q1“ oder „2027“.

## Status

Version 0.3 – Integration mit Weboberfläche in der HA-Seitenleiste. Android-App und Widget folgen.

## Installation

1. Ordner `custom_components/thask` nach `/config/custom_components/thask` kopieren (oder per HACS als benutzerdefiniertes Repository).
2. Home Assistant neu starten.
3. **Einstellungen → Geräte & Dienste → Integration hinzufügen → tHAsk**.

Beim ersten Start wird die Liste „Aufgaben“ angelegt.

## Weboberfläche

Nach dem Einrichten erscheint **tHAsk** in der HA-Seitenleiste (auch in der Companion-App auf dem Handy):

- Intelligente Listen **Mein Tag**, **Wichtig** (Priorität Hoch), **Geplant** (gruppiert nach Überfällig / Diese Woche / Diesen Monat / Später), **Diese Woche** und **Diesen Monat** (alles, was bis Monatsende fällig ist, inkl. Überfälligem), darunter die eigenen Listen (mit Gruppen).
- **Schnelleingabe** mit Erkennung, z. B. „Reifen wechseln nächsten Monat !“, „Steuer KW 47“, „Rechnungen ablegen jeden Monat“, „Zahnarzt morgen um 9:30“. Erkanntes wird als Chip angezeigt; ein Klick auf den Chip nimmt die Erkennung zurück.
- **Detailbereich**: Schritte, „Mein Tag“, Fälligkeit als Tag/Woche/Monat/Quartal/Jahr mit Vor-/Zurück-Pfeilen, Erinnerung, Wiederholung, Liste, Notizen.
- Aufgaben per Drag & Drop sortieren oder auf eine andere Liste in der Seitenleiste ziehen.
- **Suche** (oben in der Seitenleiste) durchsucht alle Listen nach Titel, Notizen, Schritten und Kategorien; mehrere Wörter müssen alle vorkommen.
- Listen anlegen (unten in der Seitenleiste), umbenennen (auf den Titel klicken), Gruppe per Auswahl setzen (vorhandene Gruppen, „Keine Gruppe“ oder „Neue Gruppe …“), löschen und per Drag & Drop in der Seitenleiste anordnen.
- Aufgaben pro Liste sortieren: manuell, nach Priorität, Fälligkeit, alphabetisch oder Erstellungsdatum (gilt auch für die HA-Entity). Bei automatischer Sortierung ist Drag & Drop innerhalb der Liste aus.
- **Erledigte löschen** (Besen-Symbol im Listenkopf).

### Priorität

Jede Aufgabe hat eine Priorität von 0 bis 3, im Panel als farbiger Balken an der Zeile (Niedrig grün, Mittel gelb, Hoch rot; je höher, desto breiter der Balken). In der Schnelleingabe setzen `!`, `!!` und `!!!` Niedrig, Mittel und Hoch. Die alte Markierung „Wichtig“ wurde zu Priorität Hoch; ältere Clients können weiter `important` senden bzw. lesen (Hoch = wichtig) und `sort: important` verwenden.

## Was in Home Assistant entsteht

| Entity | Inhalt |
|---|---|
| `todo.thask_<liste>` | eine pro Liste |
| `todo.thask_mein_tag` | Aufgaben, die heute zu „Mein Tag“ hinzugefügt wurden |
| `todo.thask_diese_woche` | alles, was bis Sonntag erledigt sein muss (inkl. Überfälligem) |

Home Assistant kennt nur exakte Daten. Deshalb zeigt es bei einer Zeitraum-Fälligkeit das **letzte Datum** des Zeitraums an (KW 46 → 15.11.). Solange das Datum dort nicht geändert wird, bleibt der Zeitraum erhalten.

Jede Liste hat die Attribute `overdue` und `due_today` (Anzahl).

### Services

- `thask.add_task` – Aufgabe mit Zeitraum anlegen, z. B. `due_granularity: week` (ohne Datum = aktuelle Woche).
- `thask.get_tasks` – Aufgaben abfragen (`due: today | this_week | this_month | overdue | all`), liefert eine Antwort für Automationen/Skripte.
- `thask.clear_completed` – erledigte Aufgaben einer Liste (oder aller Listen) löschen, optional nur ältere als `older_than_days`. Gut für eine nächtliche Aufräum-Automation.
- `thask.import_ms_todo` – Import aus Microsoft To Do (siehe unten).

### Events

| Event | Wann |
|---|---|
| `thask_task_due` | um Mitternacht, wenn der Zeitraum einer Aufgabe beginnt |
| `thask_task_overdue` | um Mitternacht nach dem letzten Tag des Zeitraums |
| `thask_reminder` | zum Erinnerungszeitpunkt einer Aufgabe |

Beispiel: Erinnerung als Push aufs Handy – Automation mit Trigger *Event* `thask_reminder` und Aktion `notify.mobile_app_<handy>` mit `{{ trigger.event.data.title }}`.

## Import aus MS To-Do

Übernommen werden Listen, Aufgaben, Notizen, Schritte, Fälligkeit, Erinnerung, Wiederholung, Priorität (hoch/niedrig, normal = keine), Kategorien und erledigte Aufgaben. Nicht übernommen werden „Mein Tag“ (gibt die Microsoft-API nicht her), Listengruppen und Anhänge.

### 1. App bei Microsoft registrieren (einmalig, ca. 5 Minuten)

1. Auf [entra.microsoft.com](https://entra.microsoft.com) mit deinem Microsoft-Konto anmelden → **App-Registrierungen** → **Neue Registrierung**.
   Falls dort keine App-Registrierung möglich ist (kein Verzeichnis vorhanden), braucht es ein kostenloses Azure-Konto.
2. Name: `tHAsk Export`, Kontotyp: **Nur persönliche Microsoft-Konten**, Umleitungs-URI leer lassen → **Registrieren**.
3. Die **Anwendungs-ID (Client)** kopieren.
4. **Authentifizierung** → **Öffentliche Clientflows zulassen** auf **Ja** → **Speichern**.
   In der neuen Vorschau-Ansicht „Authentication (Preview)“ erst über den Link im blauen Hinweis zur alten Ansicht wechseln; der Schalter steht dort unten unter „Erweiterte Einstellungen“. Alternativ im **Manifest** `"isFallbackPublicClient": true` setzen.

Die Berechtigung „Tasks.Read“ (nur lesen) wird beim Anmelden abgefragt.

### 2. Exportieren (auf dem PC)

```bash
python tools/ms_todo_export.py --client-id <Anwendungs-ID>
```

Das Skript zeigt einen Code; im Browser auf der angezeigten Seite eingeben und anmelden. Ergebnis: `thask_ms_todo.json`. Mit einem Arbeits-/Schulkonto `--tenant organizations` angeben (und bei der Registrierung den passenden Kontotyp wählen).

### 3. Importieren (in Home Assistant)

1. `thask_ms_todo.json` in den HA-Konfigurationsordner kopieren (z. B. mit dem File-Editor oder per Samba), also neben `configuration.yaml`.
2. **Werkzeuge → Aktionen** → `thask.import_ms_todo` mit `dry_run: true` ausführen und **Antwort anzeigen**. Das ändert nichts, sondern zeigt, was passieren würde – inklusive wie viele Aufgaben am Monatsende (`month_end_candidates`) oder an einem Sonntag (`sunday_candidates`) fällig sind.
3. Mit `dry_run: false` wirklich importieren. Optional:
   - `convert_month_ends: true` – fällig am Monatsletzten → „fällig im Monat“
   - `convert_sundays: true` – fällig am Sonntag → „fällig in der Woche“

Listen mit gleichem Namen werden zusammengeführt (z. B. „Aufgaben“). Ein erneuter Import überspringt bereits importierte Aufgaben. Danach kann die JSON-Datei gelöscht werden.

## WebSocket-API (für die Apps)

Alle Befehle laufen über die normale HA-WebSocket-Verbindung (Authentifizierung über HA):

| Befehl | Parameter |
|---|---|
| `thask/info` | – |
| `thask/data` | – (alle Listen und Aufgaben) |
| `thask/subscribe` | – (Snapshot, danach jede Änderung als Event) |
| `thask/list/create`, `thask/list/update`, `thask/list/delete` | `name`, `group`, `color`, `icon`, `position`, `sort` (`manual`, `priority`, `due`, `title`, `created`) / `list_id` |
| `thask/list/move` | `list_id`, `previous_id` |
| `thask/list/clear_completed` | `list_id` (leer = alle), `older_than_days` |
| `thask/task/create`, `thask/task/update`, `thask/task/delete` | siehe unten / `task_id` |
| `thask/task/move` | `task_id`, `previous_id` |
| `thask/parse` | `text`, `disabled` (Liste aus `due`, `time`, `recurrence`, `priority`) – Schnelleingabe |

Aufgabenfelder: `list_id`, `title`, `notes`, `completed`, `priority` (0 keine, 1 niedrig, 2 mittel, 3 hoch), `due` (`{"granularity": "day|week|month|quarter|year", "start": "2026-11-09"}`), `due_time` (`"HH:MM"`, nur bei Tagen), `reminder` (ISO-Datum mit Uhrzeit), `recurrence` (`{"unit": "month", "interval": 1}`), `my_day` (ISO-Datum), `steps`, `categories`.

Wird eine wiederkehrende Aufgabe erledigt, entsteht eine neue Aufgabe für den nächsten Zeitraum, der noch nicht vorbei ist.

## Entwicklung

Die Datums- und Datenlogik in `custom_components/thask/core` hängt nicht von Home Assistant ab:

```bash
python -m pytest
```

Die Weboberfläche lässt sich ohne Home Assistant im Browser testen, mit der echten Datenlogik und Beispieldaten im Speicher:

```bash
python tools/panel_dev_server.py
```

Dann http://localhost:8765 öffnen.
