# tHAsk

Lokale Aufgabenverwaltung für Home Assistant – mit **unscharfen Fälligkeiten**: Eine Aufgabe ist nicht nur an einem Tag fällig, sondern auch „in KW 46“, „im November“, „in Q1“ oder „2027“.

Gedacht als Ersatz für Microsoft To Do: Die Daten liegen in Home Assistant (und damit in dessen Backups), der Zugriff läuft über die HA-Anmeldung, auch von unterwegs (z. B. Nabu Casa).

## Überblick

| Teil | Was es ist |
|---|---|
| **Integration** (`custom_components/thask`) | Datenhaltung, todo-Entities, Services, Events, Erinnerungen, Trigger, WebSocket-API |
| **Weboberfläche** | Seite „tHAsk“ in der HA-Seitenleiste, auch in der Companion-App |
| **Dashboard-Karte** | `custom:thask-card` für beliebige Dashboards |
| **Android-App mit Widget** (`app/`) | Flutter-App mit Offline-Modus, Widget auf dem Startbildschirm |
| **Windows-App** (`app/`) | dieselbe App für Windows, mit Installer, Benachrichtigungen und Zähler an der Taskleiste |

Aktueller Stand: **0.9.1** (siehe [Releases](https://github.com/Schumey/tHAsk/releases)). Die Apps werden bisher nicht als fertige Pakete ausgeliefert, sondern aus dem Quellcode gebaut.

### Funktionen

- Fälligkeit als Tag, Woche, Monat, Quartal oder Jahr, optional mit Uhrzeit; Wiederholungen (auch an mehreren Wochentagen); Erinnerungen; Schritte; Notizen; Priorität (Niedrig, Mittel, Hoch); Kategorien.
- Intelligente Listen: **Heute**, **Überfällig** (optional), **Wichtig**, **Geplant**, **Diese Woche**, **Diesen Monat**, dazu eigene Listen mit Gruppen.
- **Schnelleingabe mit Erkennung**: „Steuer KW 47 !!!“, „Blumen gießen jeden Mi und Sa“, „Zahnarzt morgen um 9:30“ – auch auf Englisch, Niederländisch, Französisch und Spanisch („Dentist next Friday“, „Tandarts morgen om 9 uur“, „Impôts semaine 47“, „Leche mañana a las 9“).
- **Sprachen**: Deutsch, Englisch, Niederländisch, Französisch und Spanisch. Weboberfläche und Karte folgen der Sprache in Home Assistant, die Apps der des Geräts.
- **Erinnerungen** als Push (Companion-App, mit Knopf „Erledigt“), in der HA-Glocke und als Windows-Benachrichtigung.
- **Trigger**: legen Aufgaben automatisch an, wenn in HA etwas zutrifft (z. B. ein Kalendertermin morgen).
- **Import** aus Microsoft To Do, Todoist, Google Tasks, TickTick, iCalendar und CSV.

## Sprachen

| | Deutsch | Englisch | Niederländisch | Französisch | Spanisch |
|---|---|---|---|---|---|
| Integration (Einrichtung, Optionen, Services), Weboberfläche, Karte | ✓ | ✓ | ✓ | ✓ | ✓ |
| Android-App, Widget, Windows-App | ✓ | ✓ | ✓ | ✓ | ✓ |
| Schnelleingabe | ✓ | ✓ | häufige Wendungen | häufige Wendungen | häufige Wendungen |

Die Schnelleingabe versteht alle Sprachen gleichzeitig, unabhängig von der eingestellten. Auf Niederländisch, Französisch und Spanisch erkennt sie u. a.: heute/morgen/übermorgen, diese/nächste Woche, Monat und Jahr, Wochentage, Monatsnamen, Kalenderwoche, „in 3 Tagen“, Monatsende, Uhrzeiten („om 9 uur“, „à 9h“, „14h30“, „a las 9“) und Wiederholungen („elke maandag“, „tous les jours“, „cada miércoles y sábado“).

Eine neue Sprache braucht: `translations/<sprache>.json`, die Texte in `www/thask-panel.js` und `www/thask-card.js`, Monats- und Wochentagsnamen in `core/period.py` und `www/thask-common.js`, in der App `lib/l10n.dart` und `android/app/src/main/res/values-<sprache>/strings.xml`.

## Installation

Voraussetzung: Home Assistant 2025.2 oder neuer. Das eigene Symbol der Integration (unter Geräte & Dienste) zeigt HA ab 2026.3.

1. Ordner `custom_components/thask` nach `/config/custom_components/thask` kopieren (z. B. per Samba oder File-Editor; oder per HACS als benutzerdefiniertes Repository).
2. Home Assistant neu starten.
3. **Einstellungen → Geräte & Dienste → Integration hinzufügen → tHAsk**.

Beim ersten Start wird die Liste „Aufgaben“ angelegt. Für ein Update den Ordner ersetzen und HA neu starten.

### Optionen

In der Weboberfläche unter **Einstellungen** (unten in der Seitenleiste), in der App im Menü oben rechts unter **Einstellungen** (beides nur für Administratoren und mit Verbindung) oder in Home Assistant unter Einstellungen → Geräte & Dienste → tHAsk → **Konfigurieren**. Änderungen wirken ohne Neustart, auch in den Apps.

- **Überfällige Aufgaben in „Heute“**: oben als eigener, zuklappbarer Abschnitt (Standard), zwischen den heutigen oder nicht in „Heute“, sondern in einer eigenen Ansicht „Überfällig“. Gilt für Weboberfläche, Karte, Apps, Widget und `todo.thask_mein_tag`.
- **„Diese Woche“**: die Kalenderwoche (Montag bis Sonntag, Standard) oder heute und die nächsten 7 Tage. Mit den 7 Tagen steht am Sonntag schon die kommende Woche darin, auch ein Zeitraum wie „KW 45“. Gilt auch für `todo.thask_diese_woche`.
- **„Heute“ und „Diese Woche“ trennen** (aus): „Heute“ zeigt nur Aufgaben, die an einem bestimmten Tag fällig sind, dazu Überfälliges. Ein Zeitraum, der heute endet (am Sonntag „KW 44“), steht dann in „Diese Woche“; „Diese Woche“ zeigt umgekehrt nichts, was schon in „Heute“ steht. Gilt auch für `todo.thask_mein_tag`, `todo.thask_diese_woche` und den Zähler an der Taskleiste.
- **„Diesen Monat“ trennen** (aus): „Diesen Monat“ zeigt nur, was nach dieser Woche bis Monatsende fällig ist.
- **„Wichtig“ zeigt**: nur Priorität Hoch (Standard) oder Mittel und Hoch.
- **Ansichten ausblenden**: „Wichtig“, „Geplant“, „Diese Woche“ und „Diesen Monat“ lassen sich aus der Navigation der Weboberfläche, der Apps und des Widgets nehmen. „Heute“ bleibt immer; Dashboard-Karten mit einer ausdrücklich gewählten Ansicht zeigen sie weiter.
- **Erledigte automatisch löschen**: erledigte Aufgaben so viele Tage nach dem Abhaken löschen (0 = nie, Standard). Geprüft beim Start von Home Assistant, jede Nacht und direkt nach dem Ändern der Option. Für einzelne Listen oder eigene Regeln gibt es weiterhin `thask.clear_completed`.
- **Erinnerungen senden an**: Benachrichtigungsdienste für Erinnerungen, siehe [Erinnerungen](#erinnerungen).

## Weboberfläche

Nach dem Einrichten erscheint **tHAsk** in der HA-Seitenleiste:

- Intelligente Listen:
  - **Heute**: alles, was bis heute fällig ist, inklusive Zeiträumen, die heute enden, und heute Erledigtem. Überfälliges je nach Option.
  - **Wichtig**: Priorität Hoch. Der Zeitraum oben rechts ist wählbar: alle oder fällig bis Ende der Woche, des Monats, des Quartals oder des Jahres; jedes Gerät merkt sich die Wahl.
  - **Geplant**: gruppiert nach Überfällig, Diese Woche, Diesen Monat und Später.
  - **Diese Woche** und **Diesen Monat**: alles, was bis Sonntag bzw. Monatsende fällig ist, inklusive Überfälligem.
  - Darunter die eigenen Listen, mit Gruppen.
- **Schnelleingabe** mit Erkennung, z. B. „Reifen wechseln nächsten Monat !“, „Steuer KW 47“, „Rechnungen ablegen jeden Monat“, „Training alle 2 Wochen Mo und Do“, „Zeitung werktags“. Erkanntes erscheint als Chip; ein Klick auf den Chip nimmt die Erkennung zurück.
- **Detailbereich**: Schritte, Priorität, Fälligkeit als Tag/Woche/Monat/Quartal/Jahr mit Vor-/Zurück-Pfeilen, Erinnerung, Wiederholung (wöchentlich auch an mehreren Wochentagen), Liste, Notizen.
- Aufgaben per Drag & Drop sortieren oder auf eine andere Liste in der Seitenleiste ziehen.
- **Suche** (oben in der Seitenleiste) über alle Listen, in Titel, Notizen, Schritten und Kategorien; mehrere Wörter müssen alle vorkommen.
- Listen anlegen (unten in der Seitenleiste), umbenennen (Klick auf den Titel), Gruppe wählen (vorhandene, „Keine Gruppe“ oder „Neue Gruppe …“), löschen und per Drag & Drop anordnen.
- **Sortierung pro Liste**: manuell, nach Priorität, Fälligkeit, alphabetisch oder Erstellungsdatum (gilt auch für die HA-Entity). Bei automatischer Sortierung ist Drag & Drop innerhalb der Liste aus.
- **Erledigte löschen** (Besen-Symbol im Listenkopf).
- **Trigger** (unten in der Seitenleiste, nur für Administratoren), siehe [Trigger](#trigger).
- **Einstellungen** (darunter, nur für Administratoren): die [Optionen](#optionen) der Integration.

### Priorität

Jede Aufgabe hat eine Priorität von 0 bis 3, angezeigt als farbiger Balken an der Zeile: Niedrig grün, Mittel orange, Hoch rot; je höher, desto breiter der Balken. Weboberfläche und Karte nehmen die Farben aus dem HA-Theme (`--success-color`, `--warning-color`, `--error-color`). In der Schnelleingabe setzen `!`, `!!` und `!!!` Niedrig, Mittel und Hoch.

Die alte Markierung „Wichtig“ wurde zu Priorität Hoch. Ältere Clients können weiter `important` senden bzw. lesen (Hoch = wichtig) und `sort: important` verwenden.

## Dashboard-Karte

Die Integration bringt die Karte `custom:thask-card` mit; eine Ressource muss nicht angelegt werden. Im Dashboard unter „Karte hinzufügen“ → „tHAsk“ auswählen und im Editor einstellen, oder in YAML:

```yaml
type: custom:thask-card
view: my_day            # my_day, overdue, important, planned, this_week, this_month oder list:<Listen-ID>
# views: [my_day, this_week]   # statt view: mehrere Ansichten auf einer Karte
tabs: false             # mehrere Ansichten als Reiter statt untereinander
hide_duplicates: true   # untereinander: jede Aufgabe nur in der ersten passenden Ansicht
title: Heute            # optional, sonst der Name der Ansicht
show_entry: true        # Schnelleingabe mit Erkennung („Steuer KW 47 !“)
show_completed: false   # Erledigte zuklappbar darunter
show_list: true         # bei intelligenten Ansichten die Liste jeder Aufgabe zeigen
min_priority: 0         # 1–3: nur Aufgaben ab dieser Priorität
max_items: 0            # höchstens so viele offene Aufgaben, 0 = alle
compact: false          # nur Titel, ohne Fälligkeit und Liste
```

Mehrere Ansichten stehen untereinander, jede mit eigener Überschrift (z. B. „Heute“ und darunter „Diese Woche“ ohne die heutigen Aufgaben), oder als Reiter. Die Schnelleingabe legt in der ersten bzw. der gezeigten Ansicht an.

Zeiträume erscheinen als Chips (KW 46, November, Q4), Überfälliges rot; „Heute“ folgt der Option für Überfälliges, „Geplant“ ist gruppiert. Ein Klick auf eine Aufgabe klappt Schritte und Notizen auf (Schritte abhaken und hinzufügen), der Kreis hakt sie ab, die Überschrift öffnet die tHAsk-Seite.

## Erinnerungen

Eine Aufgabe kann eine Erinnerung mit Datum und Uhrzeit haben (im Detailbereich). Zum Zeitpunkt passiert Folgendes:

- **Push und HA-Glocke**: An die Dienste aus der Option *Erinnerungen senden an* geht eine Benachrichtigung, oben die Aufgabe, darunter Liste und Fälligkeit. Geeignet sind z. B. `mobile_app_<handy>` (Push über die Companion-App, mit Knopf **„Erledigt“**, der die Aufgabe abhakt) und `persistent_notification` (Glocke in HA).
- **Windows-App**: Läuft sie, zeigt sie eine Windows-Benachrichtigung, ebenfalls mit „Erledigt“. Ein Klick holt die App nach vorn.
- **Event** `thask_reminder` für eigene Automationen, z. B. für andere Dienste oder mit Bedingungen (Felder siehe [Events](#events)).

Ohne Auswahl bei *Erinnerungen senden an* gibt es nur das Event und die Benachrichtigung der Windows-App.

## Trigger

Ein Trigger legt **einmal pro Tag** automatisch eine Aufgabe an, wenn in Home Assistant etwas zutrifft. Beispiel: Steht morgen ein Termin „Frühschicht“ im Kalender, entsteht heute die Aufgabe „Frühschicht vorbereiten“. Die Integration prüft jede Minute.

**Wenn** – eine oder mehrere Bedingungen, verknüpft mit *alle (UND)* oder *mindestens eine (ODER)*, jede einzeln umkehrbar (NICHT):

| Bedingung | trifft zu, wenn … |
|---|---|
| Zustand einer Entität | die Entität den Zustand hat (leer = `on`/`home`/`true`/`open`; `>20`, `<=5` vergleichen Zahlen), optional schon seit N Minuten |
| Kalendereintrag | der Kalender an dem Tag einen Termin hat, dessen Titel den Text enthält (leer = jeder Termin); zählt jeder Tag des Termins, nur der erste oder nur der letzte |
| Uhrzeit | die Uhrzeit erreicht ist |

- **Nur zwischen**: Zeitfenster, auch über Mitternacht (22:00 bis 06:00).
- **Anlegen bis zu N Tage vorher** (bei Kalenderbedingungen): Termine bis zu N Tage voraus zählen; die Aufgabe entsteht, sobald der Termin im Fenster liegt (1 = am Vortag, für einen Termin, der erst heute eingetragen wird, noch am selben Tag). Zustand und Uhrzeit beziehen sich immer auf jetzt.
- Pro Termin entsteht nur eine Aufgabe, auch wenn er mehrere Tage dauert.

**Dann** – eine Aufgabe: Titel mit Platzhaltern `{termin}`, `{datum}`, `{wochentag}`, `{zustand}` (englisch `{event}`, `{date}`, `{weekday}`, `{state}`), Liste, Fälligkeit (*Heute*, *Vortag*, *Tag*, *Woche* oder *Monat* des Termins bzw. des Auslösetags; der Vortag eines Termins von heute ist heute), Priorität.

Auf der Trigger-Seite: Haken = aktiv, Kolben = **Testen** (zeigt, ob die Bedingungen jetzt zutreffen, legt nichts an), Play = **Jetzt ausführen** (legt die Aufgabe sofort für heute an), Pfeil oben = **Jetzt prüfen** (alle Trigger). Im Editor lässt sich ein Trigger bis zu einem Datum **pausieren**. Der **Verlauf** zeigt die angelegten Aufgaben; **Rückgängig** löscht die Aufgabe wieder, und der Trigger legt für diesen Tag nichts mehr an.

Bei jeder angelegten Aufgabe feuert das Event `thask_trigger_fired`. Gespeichert werden die Trigger in `.storage/thask.triggers`.

## Was in Home Assistant entsteht

| Entity | Inhalt |
|---|---|
| `todo.thask_<liste>` | eine pro Liste |
| `todo.thask_mein_tag` | „Heute“: alles, was bis heute fällig ist (der Name stammt noch von „Mein Tag“); neue Aufgaben dort werden heute fällig |
| `todo.thask_uberfallig` | offene Aufgaben, deren Fälligkeit vor heute endete |
| `todo.thask_diese_woche` | alles, was bis Sonntag erledigt sein muss (inkl. Überfälligem) |

Ist das Gerät „tHAsk“ einem Bereich zugeordnet, stellt HA dessen Namen voran (z. B. `todo.sonstiges_thask_uberfallig`).

Home Assistant kennt nur exakte Daten. Deshalb zeigt es bei einer Zeitraum-Fälligkeit das **letzte Datum** des Zeitraums an (KW 46 → 15.11.). Solange das Datum dort nicht geändert wird, bleibt der Zeitraum erhalten. Jede Liste hat die Attribute `overdue` und `due_today` (Anzahl).

Aufgaben aus Automationen legt man am einfachsten mit `todo.add_item` an, mit Zeitraum über `thask.add_task`.

### Services

- `thask.add_task` – Aufgabe mit Zeitraum anlegen, z. B. `due_granularity: week` (ohne Datum = aktuelle Woche).
- `thask.get_tasks` – Aufgaben abfragen (`due: today | this_week | this_month | overdue | all`), liefert eine Antwort für Automationen und Skripte.
- `thask.clear_completed` – erledigte Aufgaben einer Liste (oder aller Listen) löschen, optional nur ältere als `older_than_days`. Gut für eine nächtliche Aufräum-Automation.
- `thask.import_ms_todo` – Import aus Microsoft To Do (siehe unten).
- `thask.import_tasks` – Import aus Todoist, Google Tasks, TickTick, iCalendar und CSV (siehe unten).

### Events

| Event | Wann |
|---|---|
| `thask_task_due` | um Mitternacht, wenn der Zeitraum einer Aufgabe beginnt |
| `thask_task_overdue` | um Mitternacht nach dem letzten Tag des Zeitraums |
| `thask_reminder` | zum Erinnerungszeitpunkt einer Aufgabe |
| `thask_trigger_fired` | wenn ein Trigger eine Aufgabe angelegt hat (`trigger_id`, `trigger_name`, `day`, `task`) |

Die drei Aufgaben-Events enthalten die Felder der Aufgabe (siehe [WebSocket-API](#websocket-api)) und zusätzlich `list_name`, `due_label` (z. B. „KW 46“), `due_end` (letzter Tag) und `due_status`. In einer Automation z. B. `{{ trigger.event.data.title }}`.

## Import aus Microsoft To Do

Übernommen werden Listen, Aufgaben, Notizen, Schritte, Fälligkeit, Erinnerung, Wiederholung (auch an mehreren Wochentagen), Priorität (hoch/niedrig, normal = keine), Kategorien und erledigte Aufgaben. Nicht übernommen werden „Mein Tag“ (gibt die Microsoft-API nicht her), Listengruppen und Anhänge.

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

1. `thask_ms_todo.json` in den HA-Konfigurationsordner kopieren, also neben `configuration.yaml`.
2. **Entwicklerwerkzeuge → Aktionen** → `thask.import_ms_todo` mit `dry_run: true` ausführen und **Antwort anzeigen**. Das ändert nichts, sondern zeigt, was passieren würde – inklusive wie viele Aufgaben am Monatsende (`month_end_candidates`) oder an einem Sonntag (`sunday_candidates`) fällig sind.
3. Mit `dry_run: false` wirklich importieren. Optional:
   - `convert_month_ends: true` – fällig am Monatsletzten → „fällig im Monat“
   - `convert_sundays: true` – fällig am Sonntag → „fällig in der Woche“

Listen mit gleichem Namen werden zusammengeführt (z. B. „Aufgaben“). Ein erneuter Import überspringt bereits importierte Aufgaben. Die JSON-Datei enthält persönliche Daten; nach dem Import kann sie gelöscht werden.

## Import aus anderen Apps

Der Service `thask.import_tasks` übernimmt Aufgaben aus weiteren Apps. Die Exportdatei in den HA-Konfigurationsordner kopieren (neben `configuration.yaml`), dann unter **Entwicklerwerkzeuge → Aktionen** `thask.import_tasks` mit `file: <Dateiname>` und zuerst `dry_run: true` ausführen (**Antwort anzeigen**), danach mit `dry_run: false`. Das Format wird in der Regel erkannt; mit `list` landet alles in einer Liste, sonst entstehen die Listen wie in der Datei. Ein erneuter Import überspringt bereits importierte Aufgaben.

| App | Exportieren | Übernommen |
|---|---|---|
| **Todoist** | pro Projekt: Projektmenü → *Als CSV exportieren*; alle Projekte: Einstellungen → *Backups* → ZIP herunterladen | Projekte als Listen, Aufgaben, Beschreibung und Kommentare als Notizen, Unteraufgaben als Schritte, Priorität (p1 = Hoch, p2 = Mittel, p3 = Niedrig), Fälligkeit (auch „every day“, „next month“ usw.), Labels und Abschnitte als Kategorien. Erledigte Aufgaben exportiert Todoist nicht. |
| **Google Tasks** | [Google Takeout](https://takeout.google.com) → nur *Tasks* → `Tasks.json` aus dem ZIP | Listen, Aufgaben, Notizen, Fälligkeit (Tag), Unteraufgaben als Schritte, erledigte Aufgaben |
| **TickTick** | Einstellungen → Konto → *Sicherung erstellen* (CSV) | Listen (Ordner als Gruppe), Aufgaben, Inhalt als Notizen, Checklisten und Unteraufgaben als Schritte, Fälligkeit mit Uhrzeit, Wiederholung, Priorität, Tags, erledigte Aufgaben. Erinnerungen nicht. |
| **iCalendar** (`.ics` mit Aufgaben) | z. B. Apple Erinnerungen über einen CalDAV-Client, Thunderbird, Nextcloud Tasks | Aufgaben (VTODO), Beschreibung, Fälligkeit, Wiederholung, Priorität, Kategorien, Unteraufgaben als Schritte. Listenname aus der Datei, sonst der Dateiname. |
| **CSV** (allgemein) | aus jeder App oder Tabelle mit Kopfzeile, Trennzeichen Komma oder Semikolon | Spalten werden am Namen erkannt (deutsch oder englisch): Titel, Notizen, Liste, Fällig, Priorität, Erledigt, Kategorien. Fälligkeit als `2026-11-30`, `30.11.2026`, `11/30/2026` oder wie in der Schnelleingabe („KW 47“, „November“). |

Für Apps ohne passenden Export (etwa Any.do oder Things) die Aufgaben in eine Tabelle übertragen und als CSV speichern; eine Spalte „Titel“ genügt.

## Android-App

Die App spiegelt die Weboberfläche: intelligente Listen und eigene Listen (anlegen, umbenennen, Gruppe, Sortierung, löschen), Detailbereich, Schnelleingabe mit Erkennung, Priorität als farbiger Balken, Fälligkeit als Pille (rot überfällig, blau wenn sie heute endet). Sie hält Verbindung zu Home Assistant über die WebSocket-API, zeigt offline den letzten Stand und merkt Änderungen ohne Verbindung vor, bis sie gesendet werden können – auch Listen anlegen, umbenennen, sortieren, löschen und „Erledigte löschen“. Gesendet werden nur die geänderten Felder; ändern zwei Geräte dasselbe Feld, gilt die zuletzt gesendete Änderung. In eigenen Listen mit manueller Sortierung lassen sich Aufgaben per Ziehen anordnen (lange drücken bzw. am Griff ziehen).

**Widget**: zeigt eine Ansicht mit der Zahl der offenen Aufgaben; ein Tipp auf den Titel öffnet die Auswahl der Ansicht, das tHAsk-Symbol öffnet die App in dieser Ansicht. Aufgaben lassen sich abhaken (auch offline vorgemerkt), „+“ öffnet die Schnelleingabe. Es aktualisiert sich alle 30 Minuten (das Minimum von Android) und von Hand mit ↻.

Erinnerungen kommen auf dem Handy über die Companion-App, siehe [Erinnerungen](#erinnerungen).

**Anmeldung** mit der Adresse von Home Assistant und einem **langlebigen Zugriffstoken** (HA → Profil → Sicherheit), pro Gerät.

**Bauen und installieren** (im Ordner `app`, Handy per USB mit USB-Debugging):

```bash
flutter build apk --debug
```

```bash
adb install -r build/app/outputs/flutter-apk/app-debug.apk
```

`adb install -r` aktualisiert die App und behält Anmeldung, Zwischenspeicher und vorgemerkte Änderungen. `flutter install` dagegen deinstalliert vorher und löscht diese Daten.

## Windows-App

Dieselbe App läuft auch unter Windows. Ab 900 px Fensterbreite stehen Navigation, Liste und Details nebeneinander. Strg+N springt in die Eingabe, Esc schließt die Details. Ein zweiter Start holt das laufende Fenster nach vorn.

Solange die App läuft, zeigt sie Erinnerungen als Windows-Benachrichtigung (mit „Erledigt“) und an der Taskleiste die Zahl der offenen Aufgaben in „Heute“ (inklusive Überfälligem). Erinnerungen, die fällig wurden, während die App nicht lief, holt sie beim nächsten Start nach (höchstens fünf).

Das Schließen-Kreuz blendet das Fenster nur aus; die App bleibt mit ihrem Symbol im Infobereich der Taskleiste und meldet weiter Erinnerungen. Ein Klick auf das Symbol holt das Fenster zurück, „Beenden“ im Kontextmenü schließt die App wirklich.

Den Installer baut ein Skript. Es braucht Flutter mit den Visual Studio Build Tools (Desktopentwicklung mit C++, plus ATL) und [Inno Setup 6](https://jrsoftware.org/isinfo.php) (`winget install --id JRSoftware.InnoSetup --exact --scope user`):

```powershell
app\windows\installer\build_installer.ps1   # -> app\build\installer\thask-setup-<Version>.exe
```

Das Setup installiert ohne Adminrechte für den aktuellen Benutzer nach `%LOCALAPPDATA%\Programs\tHAsk`, mit Startmenü-Eintrag. Optional legt es eine Desktop-Verknüpfung an und startet die App beim Anmelden im Infobereich der Taskleiste. Ein Update installiert man über das alte Setup drüber; eine laufende App wird dabei geschlossen. Anmeldung und zwischengespeicherte Daten liegen unter `%APPDATA%\de.schumey\tHAsk`, das Setup lässt sie auch beim Deinstallieren unangetastet. Deinstallieren geht über Windows-Einstellungen → Apps.

## WebSocket-API

Die Apps, die Weboberfläche und die Karte nutzen diese Befehle über die normale HA-WebSocket-Verbindung (Authentifizierung über HA):

| Befehl | Parameter |
|---|---|
| `thask/info` | – |
| `thask/data` | – (alle Listen und Aufgaben) |
| `thask/subscribe` | – (Snapshot mit `options`, danach jede Änderung als Event; `options` nach einer Änderung der Optionen; `reminder` mit der Aufgabe zum Erinnerungszeitpunkt) |
| `thask/list/create`, `thask/list/update`, `thask/list/delete` | `name`, `group`, `color`, `icon`, `position`, `sort` (`manual`, `priority`, `due`, `title`, `created`) / `list_id` |
| `thask/list/move` | `list_id`, `previous_id` |
| `thask/list/clear_completed` | `list_id` (leer = alle), `older_than_days` |
| `thask/task/create`, `thask/task/update`, `thask/task/delete` | siehe unten / `task_id` |
| `thask/task/move` | `task_id`, `previous_id` |
| `thask/parse` | `text`, `disabled` (Liste aus `due`, `time`, `recurrence`, `priority`) – Schnelleingabe |
| `thask/triggers/subscribe` | – (Trigger, letzte Läufe und Prüfstatus, nach jeder Änderung erneut); nur Administratoren, wie alle `thask/trigger/*` |
| `thask/trigger/create`, `thask/trigger/update`, `thask/trigger/delete` | `name`, `conditions`, `task`, `enabled`, `combine`, `window_from`, `window_to`, `days_ahead`, `paused_until` / `trigger_id` |
| `thask/trigger/test`, `thask/trigger/run` | `trigger_id` |
| `thask/trigger/check` | – (alle Trigger jetzt prüfen) |
| `thask/trigger/undo` | `run_id` |
| `thask/options/get` | – (alle Optionen und die Benachrichtigungsdienste); nur Administratoren |
| `thask/options/update` | `overdue_in_today`, `week_mode`, `separate_week`, `separate_month`, `hidden_views`, `auto_clear_days`, `important_priority`, `reminder_targets`; nur Administratoren |

Aufgabenfelder: `list_id`, `title`, `notes`, `completed`, `priority` (0 keine, 1 niedrig, 2 mittel, 3 hoch), `due` (`{"granularity": "day|week|month|quarter|year", "start": "2026-11-09"}`), `due_time` (`"HH:MM"`, nur bei Tagen), `reminder` (ISO-Datum mit Uhrzeit), `recurrence` (`{"unit": "month", "interval": 1}`, wöchentlich an mehreren Tagen: `{"unit": "week", "interval": 1, "weekdays": [2, 5]}` mit 0 = Montag), `steps`, `categories`. `my_day` wird noch angenommen, hat aber keine Wirkung mehr („Heute“ richtet sich nach der Fälligkeit).

Wird eine wiederkehrende Aufgabe erledigt, entsteht eine neue Aufgabe für den nächsten Zeitraum, der noch nicht vorbei ist.

## Entwicklung

| Ordner | Inhalt |
|---|---|
| `custom_components/thask/core` | Datums- und Datenlogik, Parser der Schnelleingabe, Trigger, Importe; ohne Abhängigkeit von Home Assistant |
| `custom_components/thask/www` | Weboberfläche (`thask-panel.js`), Karte (`thask-card.js`) und gemeinsamer Code (`thask-common.js`), ohne Build-Schritt |
| `custom_components/thask/brand` | Symbol der Integration |
| `app/` | Flutter-App für Android und Windows, Widget in `android/app/src/main/kotlin`, Installer in `windows/installer` |
| `tests/` | Tests für `core` |
| `tools/` | Dev-Server, MS-To-Do-Export, Erzeugung der Symbole |

Tests:

```bash
python -m pytest
```

```bash
cd app && flutter analyze && flutter test
```

Weboberfläche und Karte lassen sich ohne Home Assistant im Browser testen, mit der echten Datenlogik und Beispieldaten im Speicher:

```bash
python tools/panel_dev_server.py
```

Dann http://localhost:8765 (Weboberfläche) bzw. http://localhost:8765/card (Beispielkarten) öffnen. Den visuellen Karteneditor zeigt der Dev-Server nicht, der braucht `ha-form` aus HA.

Die Symbole für Android, Windows, die Integration und die Seitenleiste (`thask:logo`) erzeugt `python tools/make_app_icon.py` (braucht Pillow); Farben und Maße stehen oben im Skript.
