/// Texte der App in den Sprachen der Integration (de, en, nl, fr, es).
///
/// Die Sprache folgt dem Gerät; [L10n.lang] setzt `main()` beim Start. `tr('key', [a, b])` ersetzt `{0}`, `{1}`.
library;

import 'dart:ui';

class L10n {
  static const languages = ['de', 'en', 'nl', 'fr', 'es'];

  /// Aktuelle Sprache. Deutsch, bis `main()` die des Geräts einträgt (auch in Tests).
  static String lang = 'de';

  static Locale get locale => Locale(lang);

  /// Die unterstützte Sprache für einen Sprachcode („de-CH“ → „de“), sonst Englisch.
  static String resolve(String? code) {
    final short = (code ?? 'en').split(RegExp('[-_]')).first.toLowerCase();
    return languages.contains(short) ? short : 'en';
  }

  static List<String> get weekdaysShort => _weekdaysShort[lang]!;
  static List<String> get months => _months[lang]!;
  static List<String> get monthsShort => _monthsShort[lang]!;

  /// Tag als „Mo, 5. Nov.“ in der Form der Sprache.
  static String dayLabel(DateTime d) {
    final w = weekdaysShort[d.weekday - 1];
    final m = monthsShort[d.month - 1];
    return switch (lang) {
      'de' => '$w, ${d.day}. $m',
      'en' => '$w, $m ${d.day}',
      'es' => '$w, ${d.day} $m',
      _ => '$w ${d.day} $m',
    };
  }

  static String weekLabel(int week) => '${tr('week_label')} $week';

  /// Datum für die Kopfzeile, z. B. „Sonntag, 1. November“.
  static String longDate(DateTime d) {
    final w = _weekdaysLong[lang]![d.weekday - 1];
    final m = months[d.month - 1];
    return switch (lang) {
      'de' => '$w, ${d.day}. $m',
      'en' => '$w, $m ${d.day}',
      'es' => '$w, ${d.day} de $m',
      _ => '$w ${d.day} $m',
    };
  }
}

const _weekdaysLong = {
  'de': ['Montag', 'Dienstag', 'Mittwoch', 'Donnerstag', 'Freitag', 'Samstag', 'Sonntag'],
  'en': ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'],
  'nl': ['maandag', 'dinsdag', 'woensdag', 'donderdag', 'vrijdag', 'zaterdag', 'zondag'],
  'fr': ['lundi', 'mardi', 'mercredi', 'jeudi', 'vendredi', 'samedi', 'dimanche'],
  'es': ['lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado', 'domingo'],
};

String tr(String key, [List<Object?> args = const []]) {
  var text = _strings[L10n.lang]?[key] ?? _strings['en']![key] ?? key;
  for (var i = 0; i < args.length; i++) {
    text = text.replaceAll('{$i}', '${args[i]}');
  }
  return text;
}

/// Einzahl oder Mehrzahl: `trPlural(n, 'change')` nimmt `change_one` bzw. `change_many`.
String trPlural(int n, String key) => tr(n == 1 ? '${key}_one' : '${key}_many', [n]);

const _weekdaysShort = {
  'de': ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'],
  'en': ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'],
  'nl': ['ma', 'di', 'wo', 'do', 'vr', 'za', 'zo'],
  'fr': ['lun.', 'mar.', 'mer.', 'jeu.', 'ven.', 'sam.', 'dim.'],
  'es': ['lun', 'mar', 'mié', 'jue', 'vie', 'sáb', 'dom'],
};

const _months = {
  'de': ['Januar', 'Februar', 'März', 'April', 'Mai', 'Juni', 'Juli', 'August', 'September', 'Oktober', 'November', 'Dezember'],
  'en': ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'],
  'nl': ['januari', 'februari', 'maart', 'april', 'mei', 'juni', 'juli', 'augustus', 'september', 'oktober', 'november', 'december'],
  'fr': ['janvier', 'février', 'mars', 'avril', 'mai', 'juin', 'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre'],
  'es': ['enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', 'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'],
};

const _monthsShort = {
  'de': ['Jan.', 'Feb.', 'März', 'Apr.', 'Mai', 'Juni', 'Juli', 'Aug.', 'Sept.', 'Okt.', 'Nov.', 'Dez.'],
  'en': ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'],
  'nl': ['jan.', 'feb.', 'mrt.', 'apr.', 'mei', 'jun.', 'jul.', 'aug.', 'sep.', 'okt.', 'nov.', 'dec.'],
  'fr': ['janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin', 'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.'],
  'es': ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sept', 'oct', 'nov', 'dic'],
};

const _strings = <String, Map<String, String>>{
  'de': {
    'today': 'Heute', 'tomorrow': 'Morgen', 'week_label': 'KW',
    'view_today': 'Heute', 'view_overdue': 'Überfällig', 'view_this_week': 'Diese Woche',
    'view_this_month': 'Diesen Monat', 'view_important': 'Wichtig', 'view_planned': 'Geplant', 'list': 'Liste',
    'later': 'Später', 'overdue_n': 'Überfällig ({0})', 'today_n': 'Heute ({0})', 'completed_n': 'Erledigt ({0})',
    'range_all': 'Alle', 'range_week': 'Bis Ende der Woche', 'range_month': 'Bis Ende des Monats',
    'range_quarter': 'Bis Ende des Quartals', 'range_year': 'Bis Ende des Jahres', 'range': 'Zeitraum',
    'rename_list': 'Liste umbenennen', 'clear_completed': 'Erledigte löschen', 'rename': 'Umbenennen',
    'group_menu': 'Gruppe …', 'sort_menu': 'Sortieren …', 'delete_list': 'Liste löschen', 'logout': 'Abmelden',
    'no_tasks': 'Keine Aufgaben', 'entry_hint': 'Aufgabe hinzufügen, z. B. „Steuer KW 47 !“', 'new_list': 'Neue Liste',
    'change_one': '{0} Änderung', 'change_many': '{0} Änderungen', 'pending': ' · {0} vorgemerkt',
    'sending': 'Sende {0} …', 'connecting_cached': 'Verbinde … (letzter Stand)', 'connecting': 'Verbinde …',
    'offline_cached': 'Offline – letzter Stand', 'not_connected': 'Nicht verbunden', 'retry': 'Erneut versuchen',
    'due_in_period': 'Fällig im Zeitraum', 'due': 'Fällig', 'overdue_suffix': ', überfällig', 'priority_x': 'Priorität {0}',
    'priority': 'Priorität', 'priority_0': 'Keine', 'priority_1': 'Niedrig', 'priority_2': 'Mittel', 'priority_3': 'Hoch',
    'sort_manual': 'Manuell', 'sort_priority': 'Priorität', 'sort_due': 'Fälligkeit', 'sort_title': 'Alphabetisch',
    'sort_created': 'Erstellungsdatum', 'name': 'Name', 'cancel': 'Abbrechen', 'ok': 'OK', 'group': 'Gruppe',
    'no_group': 'Keine Gruppe', 'new_group_menu': 'Neue Gruppe …', 'new_group': 'Neue Gruppe', 'group_name': 'Name der Gruppe',
    'sort_by': 'Sortieren nach', 'delete_list_q': 'Liste löschen?', 'delete_list_text': '„{0}“ wird mit allen Aufgaben gelöscht.',
    'delete': 'Löschen', 'create': 'Anlegen',
    'connect_title': 'Mit Home Assistant verbinden', 'address': 'Adresse',
    'address_hint': 'https://home.example.com oder 192.168.1.5:8123', 'token': 'Langlebiges Zugriffstoken',
    'token_help': 'In Home Assistant: Profil → Sicherheit → Langlebige Zugriffstoken', 'connect': 'Verbinden',
    'err_token': 'Das Zugriffstoken wurde abgelehnt.', 'err_address_missing': 'Bitte die Adresse von Home Assistant eingeben.',
    'err_address_invalid': 'Die Adresse ist ungültig.', 'err_no_answer': 'Home Assistant antwortet nicht.',
    'err_no_connection': 'Keine Verbindung: {0}', 'err_unknown': 'Unbekannter Fehler', 'err_closed': 'Die Verbindung wurde beendet.',
    'err_offline': 'Keine Verbindung zu Home Assistant.',
    'reminder': 'Erinnerung', 'done': 'Erledigt',
    'unit_day': 'Tag', 'unit_week': 'Woche', 'unit_month': 'Monat', 'unit_quarter': 'Quartal', 'unit_year': 'Jahr',
    'units_day': 'Tage', 'units_week': 'Wochen', 'units_month': 'Monate', 'units_quarter': 'Quartale', 'units_year': 'Jahre',
    'every_one': 'Jeden {0}', 'every_many': 'Alle {0} {1}', 'rec_day': 'Täglich', 'rec_week': 'Wöchentlich',
    'rec_month': 'Monatlich', 'rec_quarter': 'Vierteljährlich', 'rec_year': 'Jährlich',
    'delete_task_q': 'Aufgabe löschen?', 'delete_task_text': '„{0}“ wird endgültig gelöscht.', 'close': 'Schließen',
    'title': 'Titel', 'remove_step': 'Schritt entfernen', 'add_step': 'Schritt hinzufügen', 'none': 'Keine',
    'back': 'Zurück', 'forward': 'Weiter', 'add_time': 'Uhrzeit hinzufügen', 'remove_time': 'Uhrzeit entfernen',
    'add_reminder': 'Erinnerung hinzufügen', 'remove_reminder': 'Erinnerung entfernen',
    'add_recurrence': 'Wiederholung hinzufügen', 'remove_recurrence': 'Wiederholung entfernen', 'notes': 'Notizen',
    'recurrence': 'Wiederholung', 'every': 'Alle', 'on_days': 'An',
    'settings': "Einstellungen", 'opt_overdue_in_today': "Überfällige Aufgaben in „Heute“", 'overdue_in_today_section': "Oben in einem eigenen Abschnitt „Überfällig“", 'overdue_in_today_mixed': "Zwischen den heutigen Aufgaben", 'overdue_in_today_separate': "Nicht in „Heute“, sondern in einer eigenen Ansicht „Überfällig“", 'opt_week_mode': "„Diese Woche“", 'week_mode_calendar': "Kalenderwoche (Montag bis Sonntag)", 'week_mode_rolling': "Heute und die nächsten 7 Tage", 'opt_views_apart': "Ansichten trennen", 'opt_separate_week': "„Heute“ und „Diese Woche“ trennen", 'opt_separate_week_hint': "„Heute“ zeigt nur Aufgaben mit einem festen Tag (und Überfälliges); Zeiträume wie „KW 44“ stehen in „Diese Woche“, das nichts zeigt, was schon in „Heute“ steht.", 'opt_separate_month': "„Diesen Monat“ trennen", 'opt_separate_month_hint': "„Diesen Monat“ zeigt nur, was nach dieser Woche bis Monatsende fällig ist.", 'opt_hidden_views': "Ansichten ausblenden", 'opt_hidden_views_hint': "Angehakte Ansichten erscheinen nicht in der Navigation, auch nicht in den Apps und im Widget. „Heute“ bleibt immer.", 'opt_auto_clear': "Erledigte automatisch löschen", 'opt_auto_clear_days': "Tage nach dem Abhaken (0 = nie)", 'opt_auto_clear_hint': "Geprüft beim Start von Home Assistant und jede Nacht. Gelöschte Aufgaben lassen sich nicht wiederherstellen.", 'opt_reminder_targets': "Erinnerungen senden an", 'opt_reminder_targets_hint': "Push über die Companion-App (mit Knopf „Erledigt“) oder persistent_notification für die Glocke in Home Assistant. Die Windows-App zeigt Erinnerungen selbst, solange sie läuft.", 'no_notify': "Keine Benachrichtigungsdienste gefunden.", 'settings_unavailable': "Die Einstellungen sind nur mit Verbindung und für Administratoren von Home Assistant verfügbar.",
    'opt_important_priority': "„Wichtig“ zeigt", 'important_priority_high': "Nur Priorität Hoch", 'important_priority_medium': "Priorität Mittel und Hoch",
    'tray_open': 'Öffnen', 'tray_quit': 'Beenden',
    'empty_title': "Alles erledigt", 'empty_text': "Hier ist gerade nichts zu tun.", 'empty_hint': "Neue Aufgaben unten eingeben, z. B. „Steuer KW 47“.",
    'members_menu': "Für wen …", 'members': "Für wen", 'members_all': "Alle", 'show_other_lists': "Listen anderer zeigen ({0})", 'only_my_lists': "Nur meine Listen", 'members_hint': "Die Liste steht nur bei diesen Personen in der Übersicht. Die anderen können sie trotzdem einblenden.",
  },
  'en': {
    'today': 'Today', 'tomorrow': 'Tomorrow', 'week_label': 'Week',
    'view_today': 'Today', 'view_overdue': 'Overdue', 'view_this_week': 'This week',
    'view_this_month': 'This month', 'view_important': 'Important', 'view_planned': 'Planned', 'list': 'List',
    'later': 'Later', 'overdue_n': 'Overdue ({0})', 'today_n': 'Today ({0})', 'completed_n': 'Completed ({0})',
    'range_all': 'All', 'range_week': 'By end of week', 'range_month': 'By end of month',
    'range_quarter': 'By end of quarter', 'range_year': 'By end of year', 'range': 'Period',
    'rename_list': 'Rename list', 'clear_completed': 'Clear completed', 'rename': 'Rename',
    'group_menu': 'Group …', 'sort_menu': 'Sort …', 'delete_list': 'Delete list', 'logout': 'Sign out',
    'no_tasks': 'No tasks', 'entry_hint': 'Add a task, e.g. “Taxes week 47 !”', 'new_list': 'New list',
    'change_one': '{0} change', 'change_many': '{0} changes', 'pending': ' · {0} queued',
    'sending': 'Sending {0} …', 'connecting_cached': 'Connecting … (last known state)', 'connecting': 'Connecting …',
    'offline_cached': 'Offline – last known state', 'not_connected': 'Not connected', 'retry': 'Try again',
    'due_in_period': 'Due within', 'due': 'Due', 'overdue_suffix': ', overdue', 'priority_x': 'Priority {0}',
    'priority': 'Priority', 'priority_0': 'None', 'priority_1': 'Low', 'priority_2': 'Medium', 'priority_3': 'High',
    'sort_manual': 'Manual', 'sort_priority': 'Priority', 'sort_due': 'Due date', 'sort_title': 'Alphabetical',
    'sort_created': 'Creation date', 'name': 'Name', 'cancel': 'Cancel', 'ok': 'OK', 'group': 'Group',
    'no_group': 'No group', 'new_group_menu': 'New group …', 'new_group': 'New group', 'group_name': 'Group name',
    'sort_by': 'Sort by', 'delete_list_q': 'Delete list?', 'delete_list_text': '“{0}” will be deleted with all its tasks.',
    'delete': 'Delete', 'create': 'Create',
    'connect_title': 'Connect to Home Assistant', 'address': 'Address',
    'address_hint': 'https://home.example.com or 192.168.1.5:8123', 'token': 'Long-lived access token',
    'token_help': 'In Home Assistant: Profile → Security → Long-lived access tokens', 'connect': 'Connect',
    'err_token': 'The access token was rejected.', 'err_address_missing': 'Please enter the address of Home Assistant.',
    'err_address_invalid': 'The address is invalid.', 'err_no_answer': 'Home Assistant does not respond.',
    'err_no_connection': 'No connection: {0}', 'err_unknown': 'Unknown error', 'err_closed': 'The connection was closed.',
    'err_offline': 'No connection to Home Assistant.',
    'reminder': 'Reminder', 'done': 'Done',
    'unit_day': 'day', 'unit_week': 'week', 'unit_month': 'month', 'unit_quarter': 'quarter', 'unit_year': 'year',
    'units_day': 'days', 'units_week': 'weeks', 'units_month': 'months', 'units_quarter': 'quarters', 'units_year': 'years',
    'every_one': 'Every {0}', 'every_many': 'Every {0} {1}', 'rec_day': 'Daily', 'rec_week': 'Weekly',
    'rec_month': 'Monthly', 'rec_quarter': 'Quarterly', 'rec_year': 'Yearly',
    'delete_task_q': 'Delete task?', 'delete_task_text': '“{0}” will be deleted permanently.', 'close': 'Close',
    'title': 'Title', 'remove_step': 'Remove step', 'add_step': 'Add a step', 'none': 'None',
    'back': 'Back', 'forward': 'Next', 'add_time': 'Add time', 'remove_time': 'Remove time',
    'add_reminder': 'Add reminder', 'remove_reminder': 'Remove reminder',
    'add_recurrence': 'Add repeat', 'remove_recurrence': 'Remove repeat', 'notes': 'Notes',
    'recurrence': 'Repeat', 'every': 'Every', 'on_days': 'On',
    'settings': "Settings", 'opt_overdue_in_today': "Overdue tasks in “Today”", 'overdue_in_today_section': "At the top in a section “Overdue”", 'overdue_in_today_mixed': "Among today's tasks", 'overdue_in_today_separate': "Not in “Today” but in a view “Overdue” of their own", 'opt_week_mode': "“This week”", 'week_mode_calendar': "Calendar week (Monday to Sunday)", 'week_mode_rolling': "Today and the next 7 days", 'opt_views_apart': "Keep views apart", 'opt_separate_week': "Keep “Today” and “This week” apart", 'opt_separate_week_hint': "“Today” only shows tasks due on a specific day (and overdue ones); periods such as “week 44” are in “This week”, which leaves out what “Today” shows.", 'opt_separate_month': "Keep “This month” apart", 'opt_separate_month_hint': "“This month” only shows what is due after this week until the end of the month.", 'opt_hidden_views': "Hide views", 'opt_hidden_views_hint': "Ticked views do not appear in the navigation, nor in the apps and the widget. “Today” always stays.", 'opt_auto_clear': "Delete completed tasks automatically", 'opt_auto_clear_days': "days after ticking off (0 = never)", 'opt_auto_clear_hint': "Checked when Home Assistant starts and every night. Deleted tasks cannot be restored.", 'opt_reminder_targets': "Send reminders to", 'opt_reminder_targets_hint': "Push via the companion app (with a “Done” button) or persistent_notification for the bell in Home Assistant. The Windows app shows reminders on its own while it is running.", 'no_notify': "No notify services found.", 'settings_unavailable': "Settings are only available while connected and for Home Assistant administrators.",
    'opt_important_priority': "“Important” shows", 'important_priority_high': "High priority only", 'important_priority_medium': "Medium and high priority",
    'tray_open': 'Open', 'tray_quit': 'Quit',
    'empty_title': "All done", 'empty_text': "Nothing to do here right now.", 'empty_hint': "Add tasks below, e.g. “Taxes week 47”.",
    'members_menu': "Who is it for …", 'members': "Who is it for", 'members_all': "Everyone", 'show_other_lists': "Show others' lists ({0})", 'only_my_lists': "Only my lists", 'members_hint': "Only these people see the list in their overview. Others can still show it.",
  },
  'nl': {
    'today': 'Vandaag', 'tomorrow': 'Morgen', 'week_label': 'Week',
    'view_today': 'Vandaag', 'view_overdue': 'Te laat', 'view_this_week': 'Deze week',
    'view_this_month': 'Deze maand', 'view_important': 'Belangrijk', 'view_planned': 'Gepland', 'list': 'Lijst',
    'later': 'Later', 'overdue_n': 'Te laat ({0})', 'today_n': 'Vandaag ({0})', 'completed_n': 'Voltooid ({0})',
    'range_all': 'Alle', 'range_week': 'Tot eind van de week', 'range_month': 'Tot eind van de maand',
    'range_quarter': 'Tot eind van het kwartaal', 'range_year': 'Tot eind van het jaar', 'range': 'Periode',
    'rename_list': 'Lijst hernoemen', 'clear_completed': 'Voltooide verwijderen', 'rename': 'Hernoemen',
    'group_menu': 'Groep …', 'sort_menu': 'Sorteren …', 'delete_list': 'Lijst verwijderen', 'logout': 'Afmelden',
    'no_tasks': 'Geen taken', 'entry_hint': 'Taak toevoegen, bijv. „Belasting week 47 !”', 'new_list': 'Nieuwe lijst',
    'change_one': '{0} wijziging', 'change_many': '{0} wijzigingen', 'pending': ' · {0} in de wachtrij',
    'sending': '{0} versturen …', 'connecting_cached': 'Verbinden … (laatste stand)', 'connecting': 'Verbinden …',
    'offline_cached': 'Offline – laatste stand', 'not_connected': 'Niet verbonden', 'retry': 'Opnieuw proberen',
    'due_in_period': 'Te doen binnen', 'due': 'Te doen', 'overdue_suffix': ', te laat', 'priority_x': 'Prioriteit {0}',
    'priority': 'Prioriteit', 'priority_0': 'Geen', 'priority_1': 'Laag', 'priority_2': 'Gemiddeld', 'priority_3': 'Hoog',
    'sort_manual': 'Handmatig', 'sort_priority': 'Prioriteit', 'sort_due': 'Vervaldatum', 'sort_title': 'Alfabetisch',
    'sort_created': 'Aanmaakdatum', 'name': 'Naam', 'cancel': 'Annuleren', 'ok': 'OK', 'group': 'Groep',
    'no_group': 'Geen groep', 'new_group_menu': 'Nieuwe groep …', 'new_group': 'Nieuwe groep', 'group_name': 'Groepsnaam',
    'sort_by': 'Sorteren op', 'delete_list_q': 'Lijst verwijderen?', 'delete_list_text': '„{0}” wordt met alle taken verwijderd.',
    'delete': 'Verwijderen', 'create': 'Aanmaken',
    'connect_title': 'Verbinden met Home Assistant', 'address': 'Adres',
    'address_hint': 'https://home.example.com of 192.168.1.5:8123', 'token': 'Langdurig toegangstoken',
    'token_help': 'In Home Assistant: Profiel → Beveiliging → Langdurige toegangstokens', 'connect': 'Verbinden',
    'err_token': 'Het toegangstoken is geweigerd.', 'err_address_missing': 'Voer het adres van Home Assistant in.',
    'err_address_invalid': 'Het adres is ongeldig.', 'err_no_answer': 'Home Assistant reageert niet.',
    'err_no_connection': 'Geen verbinding: {0}', 'err_unknown': 'Onbekende fout', 'err_closed': 'De verbinding is verbroken.',
    'err_offline': 'Geen verbinding met Home Assistant.',
    'reminder': 'Herinnering', 'done': 'Klaar',
    'unit_day': 'dag', 'unit_week': 'week', 'unit_month': 'maand', 'unit_quarter': 'kwartaal', 'unit_year': 'jaar',
    'units_day': 'dagen', 'units_week': 'weken', 'units_month': 'maanden', 'units_quarter': 'kwartalen', 'units_year': 'jaar',
    'every_one': 'Elke {0}', 'every_many': 'Elke {0} {1}', 'rec_day': 'Dagelijks', 'rec_week': 'Wekelijks',
    'rec_month': 'Maandelijks', 'rec_quarter': 'Elk kwartaal', 'rec_year': 'Jaarlijks',
    'delete_task_q': 'Taak verwijderen?', 'delete_task_text': '„{0}” wordt definitief verwijderd.', 'close': 'Sluiten',
    'title': 'Titel', 'remove_step': 'Stap verwijderen', 'add_step': 'Stap toevoegen', 'none': 'Geen',
    'back': 'Terug', 'forward': 'Verder', 'add_time': 'Tijd toevoegen', 'remove_time': 'Tijd verwijderen',
    'add_reminder': 'Herinnering toevoegen', 'remove_reminder': 'Herinnering verwijderen',
    'add_recurrence': 'Herhaling toevoegen', 'remove_recurrence': 'Herhaling verwijderen', 'notes': 'Notities',
    'recurrence': 'Herhaling', 'every': 'Elke', 'on_days': 'Op',
    'settings': "Instellingen", 'opt_overdue_in_today': "Te late taken in „Vandaag”", 'overdue_in_today_section': "Bovenaan in een sectie „Te laat”", 'overdue_in_today_mixed': "Tussen de taken van vandaag", 'overdue_in_today_separate': "Niet in „Vandaag”, maar in een eigen weergave „Te laat”", 'opt_week_mode': "„Deze week”", 'week_mode_calendar': "Kalenderweek (maandag tot zondag)", 'week_mode_rolling': "Vandaag en de komende 7 dagen", 'opt_views_apart': "Weergaven scheiden", 'opt_separate_week': "„Vandaag” en „Deze week” scheiden", 'opt_separate_week_hint': "„Vandaag” toont alleen taken op een vaste dag (en te late); periodes zoals „week 44” staan in „Deze week”, die niets toont wat al in „Vandaag” staat.", 'opt_separate_month': "„Deze maand” scheiden", 'opt_separate_month_hint': "„Deze maand” toont alleen wat na deze week tot het einde van de maand moet.", 'opt_hidden_views': "Weergaven verbergen", 'opt_hidden_views_hint': "Aangevinkte weergaven verschijnen niet in de navigatie, ook niet in de apps en de widget. „Vandaag” blijft altijd.", 'opt_auto_clear': "Voltooide taken automatisch verwijderen", 'opt_auto_clear_days': "dagen na het afvinken (0 = nooit)", 'opt_auto_clear_hint': "Gecontroleerd bij het starten van Home Assistant en elke nacht. Verwijderde taken kunnen niet worden hersteld.", 'opt_reminder_targets': "Herinneringen sturen naar", 'opt_reminder_targets_hint': "Push via de Companion-app (met een knop „Klaar”) of persistent_notification voor de bel in Home Assistant. De Windows-app toont herinneringen zelf zolang hij draait.", 'no_notify': "Geen meldingsdiensten gevonden.", 'settings_unavailable': "Instellingen zijn alleen beschikbaar met verbinding en voor beheerders van Home Assistant.",
    'opt_important_priority': "„Belangrijk” toont", 'important_priority_high': "Alleen prioriteit hoog", 'important_priority_medium': "Prioriteit gemiddeld en hoog",
    'tray_open': 'Openen', 'tray_quit': 'Afsluiten',
    'empty_title': "Alles klaar", 'empty_text': "Hier is nu niets te doen.", 'empty_hint': "Voeg hieronder taken toe, bijv. „Belasting week 47”.",
    'members_menu': "Voor wie …", 'members': "Voor wie", 'members_all': "Iedereen", 'show_other_lists': "Lijsten van anderen tonen ({0})", 'only_my_lists': "Alleen mijn lijsten", 'members_hint': "Alleen deze personen zien de lijst in hun overzicht. Anderen kunnen hem toch tonen.",
  },
  'fr': {
    'today': "Aujourd'hui", 'tomorrow': 'Demain', 'week_label': 'Semaine',
    'view_today': "Aujourd'hui", 'view_overdue': 'En retard', 'view_this_week': 'Cette semaine',
    'view_this_month': 'Ce mois-ci', 'view_important': 'Important', 'view_planned': 'Planifié', 'list': 'Liste',
    'later': 'Plus tard', 'overdue_n': 'En retard ({0})', 'today_n': "Aujourd'hui ({0})", 'completed_n': 'Terminées ({0})',
    'range_all': 'Toutes', 'range_week': "D'ici la fin de la semaine", 'range_month': "D'ici la fin du mois",
    'range_quarter': "D'ici la fin du trimestre", 'range_year': "D'ici la fin de l'année", 'range': 'Période',
    'rename_list': 'Renommer la liste', 'clear_completed': 'Supprimer les terminées', 'rename': 'Renommer',
    'group_menu': 'Groupe …', 'sort_menu': 'Trier …', 'delete_list': 'Supprimer la liste', 'logout': 'Se déconnecter',
    'no_tasks': 'Aucune tâche', 'entry_hint': 'Ajouter une tâche, p. ex. « Impôts semaine 47 ! »', 'new_list': 'Nouvelle liste',
    'change_one': '{0} modification', 'change_many': '{0} modifications', 'pending': ' · {0} en attente',
    'sending': 'Envoi de {0} …', 'connecting_cached': 'Connexion … (dernier état)', 'connecting': 'Connexion …',
    'offline_cached': 'Hors ligne – dernier état', 'not_connected': 'Non connecté', 'retry': 'Réessayer',
    'due_in_period': 'À faire dans', 'due': 'Échéance', 'overdue_suffix': ', en retard', 'priority_x': 'Priorité {0}',
    'priority': 'Priorité', 'priority_0': 'Aucune', 'priority_1': 'Basse', 'priority_2': 'Moyenne', 'priority_3': 'Haute',
    'sort_manual': 'Manuel', 'sort_priority': 'Priorité', 'sort_due': 'Échéance', 'sort_title': 'Alphabétique',
    'sort_created': 'Date de création', 'name': 'Nom', 'cancel': 'Annuler', 'ok': 'OK', 'group': 'Groupe',
    'no_group': 'Aucun groupe', 'new_group_menu': 'Nouveau groupe …', 'new_group': 'Nouveau groupe', 'group_name': 'Nom du groupe',
    'sort_by': 'Trier par', 'delete_list_q': 'Supprimer la liste ?', 'delete_list_text': '« {0} » sera supprimée avec toutes ses tâches.',
    'delete': 'Supprimer', 'create': 'Créer',
    'connect_title': 'Se connecter à Home Assistant', 'address': 'Adresse',
    'address_hint': 'https://home.example.com ou 192.168.1.5:8123', 'token': "Jeton d'accès longue durée",
    'token_help': "Dans Home Assistant : Profil → Sécurité → Jetons d'accès longue durée", 'connect': 'Se connecter',
    'err_token': "Le jeton d'accès a été refusé.", 'err_address_missing': "Veuillez saisir l'adresse de Home Assistant.",
    'err_address_invalid': "L'adresse n'est pas valide.", 'err_no_answer': 'Home Assistant ne répond pas.',
    'err_no_connection': 'Pas de connexion : {0}', 'err_unknown': 'Erreur inconnue', 'err_closed': 'La connexion a été fermée.',
    'err_offline': 'Pas de connexion à Home Assistant.',
    'reminder': 'Rappel', 'done': 'Terminé',
    'unit_day': 'jour', 'unit_week': 'semaine', 'unit_month': 'mois', 'unit_quarter': 'trimestre', 'unit_year': 'an',
    'units_day': 'jours', 'units_week': 'semaines', 'units_month': 'mois', 'units_quarter': 'trimestres', 'units_year': 'ans',
    'every_one': 'Chaque {0}', 'every_many': 'Tous les {0} {1}', 'rec_day': 'Tous les jours', 'rec_week': 'Toutes les semaines',
    'rec_month': 'Tous les mois', 'rec_quarter': 'Tous les trimestres', 'rec_year': 'Tous les ans',
    'delete_task_q': 'Supprimer la tâche ?', 'delete_task_text': '« {0} » sera supprimée définitivement.', 'close': 'Fermer',
    'title': 'Titre', 'remove_step': "Supprimer l'étape", 'add_step': 'Ajouter une étape', 'none': 'Aucune',
    'back': 'Précédent', 'forward': 'Suivant', 'add_time': 'Ajouter une heure', 'remove_time': "Supprimer l'heure",
    'add_reminder': 'Ajouter un rappel', 'remove_reminder': 'Supprimer le rappel',
    'add_recurrence': 'Ajouter une répétition', 'remove_recurrence': 'Supprimer la répétition', 'notes': 'Notes',
    'recurrence': 'Répétition', 'every': 'Tous les', 'on_days': 'Le',
    'settings': "Paramètres", 'opt_overdue_in_today': "Tâches en retard dans « Aujourd'hui »", 'overdue_in_today_section': "En haut, dans une section « En retard »", 'overdue_in_today_mixed': "Parmi les tâches du jour", 'overdue_in_today_separate': "Pas dans « Aujourd'hui », mais dans une vue « En retard » à part", 'opt_week_mode': "« Cette semaine »", 'week_mode_calendar': "Semaine calendaire (lundi à dimanche)", 'week_mode_rolling': "Aujourd'hui et les 7 prochains jours", 'opt_views_apart': "Séparer les vues", 'opt_separate_week': "Séparer « Aujourd'hui » et « Cette semaine »", 'opt_separate_week_hint': "« Aujourd'hui » n'affiche que les tâches d'un jour précis (et celles en retard) ; les périodes comme « semaine 44 » sont dans « Cette semaine », qui n'affiche pas ce qui est déjà dans « Aujourd'hui ».", 'opt_separate_month': "Séparer « Ce mois-ci »", 'opt_separate_month_hint': "« Ce mois-ci » n'affiche que ce qui est à faire après cette semaine jusqu'à la fin du mois.", 'opt_hidden_views': "Masquer des vues", 'opt_hidden_views_hint': "Les vues cochées n'apparaissent pas dans la navigation, ni dans les applications et le widget. « Aujourd'hui » reste toujours.", 'opt_auto_clear': "Supprimer automatiquement les tâches terminées", 'opt_auto_clear_days': "jours après les avoir cochées (0 = jamais)", 'opt_auto_clear_hint': "Vérifié au démarrage de Home Assistant et chaque nuit. Les tâches supprimées ne peuvent pas être restaurées.", 'opt_reminder_targets': "Envoyer les rappels à", 'opt_reminder_targets_hint': "Push via l'application Companion (avec un bouton « Terminé ») ou persistent_notification pour la cloche de Home Assistant. L'application Windows affiche elle-même les rappels tant qu'elle est ouverte.", 'no_notify': "Aucun service de notification trouvé.", 'settings_unavailable': "Les paramètres ne sont disponibles qu'avec une connexion et pour les administrateurs de Home Assistant.",
    'opt_important_priority': "« Important » affiche", 'important_priority_high': "Priorité haute uniquement", 'important_priority_medium': "Priorités moyenne et haute",
    'tray_open': 'Ouvrir', 'tray_quit': 'Quitter',
    'empty_title': "Tout est fait", 'empty_text': "Rien à faire ici pour le moment.", 'empty_hint': "Ajoutez des tâches ci-dessous, p. ex. « Impôts semaine 47 ».",
    'members_menu': "Pour qui …", 'members': "Pour qui", 'members_all': "Tout le monde", 'show_other_lists': "Afficher les listes des autres ({0})", 'only_my_lists': "Seulement mes listes", 'members_hint': "Seules ces personnes voient la liste dans leur aperçu. Les autres peuvent quand même l'afficher.",
  },
  'es': {
    'today': 'Hoy', 'tomorrow': 'Mañana', 'week_label': 'Semana',
    'view_today': 'Hoy', 'view_overdue': 'Vencidas', 'view_this_week': 'Esta semana',
    'view_this_month': 'Este mes', 'view_important': 'Importante', 'view_planned': 'Planificado', 'list': 'Lista',
    'later': 'Más tarde', 'overdue_n': 'Vencidas ({0})', 'today_n': 'Hoy ({0})', 'completed_n': 'Completadas ({0})',
    'range_all': 'Todas', 'range_week': 'Hasta el final de la semana', 'range_month': 'Hasta el final del mes',
    'range_quarter': 'Hasta el final del trimestre', 'range_year': 'Hasta el final del año', 'range': 'Periodo',
    'rename_list': 'Cambiar nombre de la lista', 'clear_completed': 'Eliminar completadas', 'rename': 'Cambiar nombre',
    'group_menu': 'Grupo …', 'sort_menu': 'Ordenar …', 'delete_list': 'Eliminar lista', 'logout': 'Cerrar sesión',
    'no_tasks': 'No hay tareas', 'entry_hint': 'Añadir una tarea, p. ej. «Impuestos semana 47 !»', 'new_list': 'Nueva lista',
    'change_one': '{0} cambio', 'change_many': '{0} cambios', 'pending': ' · {0} en cola',
    'sending': 'Enviando {0} …', 'connecting_cached': 'Conectando … (último estado)', 'connecting': 'Conectando …',
    'offline_cached': 'Sin conexión – último estado', 'not_connected': 'No conectado', 'retry': 'Reintentar',
    'due_in_period': 'Vence dentro de', 'due': 'Vence', 'overdue_suffix': ', vencida', 'priority_x': 'Prioridad {0}',
    'priority': 'Prioridad', 'priority_0': 'Ninguna', 'priority_1': 'Baja', 'priority_2': 'Media', 'priority_3': 'Alta',
    'sort_manual': 'Manual', 'sort_priority': 'Prioridad', 'sort_due': 'Vencimiento', 'sort_title': 'Alfabético',
    'sort_created': 'Fecha de creación', 'name': 'Nombre', 'cancel': 'Cancelar', 'ok': 'Aceptar', 'group': 'Grupo',
    'no_group': 'Sin grupo', 'new_group_menu': 'Nuevo grupo …', 'new_group': 'Nuevo grupo', 'group_name': 'Nombre del grupo',
    'sort_by': 'Ordenar por', 'delete_list_q': '¿Eliminar la lista?', 'delete_list_text': '«{0}» se eliminará con todas sus tareas.',
    'delete': 'Eliminar', 'create': 'Crear',
    'connect_title': 'Conectar con Home Assistant', 'address': 'Dirección',
    'address_hint': 'https://home.example.com o 192.168.1.5:8123', 'token': 'Token de acceso de larga duración',
    'token_help': 'En Home Assistant: Perfil → Seguridad → Tokens de acceso de larga duración', 'connect': 'Conectar',
    'err_token': 'El token de acceso fue rechazado.', 'err_address_missing': 'Introduce la dirección de Home Assistant.',
    'err_address_invalid': 'La dirección no es válida.', 'err_no_answer': 'Home Assistant no responde.',
    'err_no_connection': 'Sin conexión: {0}', 'err_unknown': 'Error desconocido', 'err_closed': 'La conexión se cerró.',
    'err_offline': 'Sin conexión con Home Assistant.',
    'reminder': 'Recordatorio', 'done': 'Hecho',
    'unit_day': 'día', 'unit_week': 'semana', 'unit_month': 'mes', 'unit_quarter': 'trimestre', 'unit_year': 'año',
    'units_day': 'días', 'units_week': 'semanas', 'units_month': 'meses', 'units_quarter': 'trimestres', 'units_year': 'años',
    'every_one': 'Cada {0}', 'every_many': 'Cada {0} {1}', 'rec_day': 'Diariamente', 'rec_week': 'Semanalmente',
    'rec_month': 'Mensualmente', 'rec_quarter': 'Trimestralmente', 'rec_year': 'Anualmente',
    'delete_task_q': '¿Eliminar la tarea?', 'delete_task_text': '«{0}» se eliminará definitivamente.', 'close': 'Cerrar',
    'title': 'Título', 'remove_step': 'Quitar paso', 'add_step': 'Añadir un paso', 'none': 'Ninguno',
    'back': 'Atrás', 'forward': 'Siguiente', 'add_time': 'Añadir hora', 'remove_time': 'Quitar hora',
    'add_reminder': 'Añadir recordatorio', 'remove_reminder': 'Quitar recordatorio',
    'add_recurrence': 'Añadir repetición', 'remove_recurrence': 'Quitar repetición', 'notes': 'Notas',
    'recurrence': 'Repetición', 'every': 'Cada', 'on_days': 'Los',
    'settings': "Ajustes", 'opt_overdue_in_today': "Tareas vencidas en «Hoy»", 'overdue_in_today_section': "Arriba, en una sección «Vencidas»", 'overdue_in_today_mixed': "Entre las tareas de hoy", 'overdue_in_today_separate': "No en «Hoy», sino en una vista propia «Vencidas»", 'opt_week_mode': "«Esta semana»", 'week_mode_calendar': "Semana natural (lunes a domingo)", 'week_mode_rolling': "Hoy y los próximos 7 días", 'opt_views_apart': "Separar vistas", 'opt_separate_week': "Separar «Hoy» y «Esta semana»", 'opt_separate_week_hint': "«Hoy» solo muestra tareas de un día concreto (y las vencidas); los periodos como «semana 44» están en «Esta semana», que no muestra lo que ya está en «Hoy».", 'opt_separate_month': "Separar «Este mes»", 'opt_separate_month_hint': "«Este mes» solo muestra lo que vence después de esta semana hasta final de mes.", 'opt_hidden_views': "Ocultar vistas", 'opt_hidden_views_hint': "Las vistas marcadas no aparecen en la navegación, tampoco en las apps ni en el widget. «Hoy» siempre se mantiene.", 'opt_auto_clear': "Eliminar tareas completadas automáticamente", 'opt_auto_clear_days': "días después de marcarlas (0 = nunca)", 'opt_auto_clear_hint': "Se comprueba al iniciar Home Assistant y cada noche. Las tareas eliminadas no se pueden recuperar.", 'opt_reminder_targets': "Enviar recordatorios a", 'opt_reminder_targets_hint': "Push mediante la app Companion (con un botón «Hecho») o persistent_notification para la campana de Home Assistant. La app de Windows muestra los recordatorios por sí misma mientras está abierta.", 'no_notify': "No se encontraron servicios de notificación.", 'settings_unavailable': "Los ajustes solo están disponibles con conexión y para administradores de Home Assistant.",
    'opt_important_priority': "«Importante» muestra", 'important_priority_high': "Solo prioridad alta", 'important_priority_medium': "Prioridad media y alta",
    'tray_open': 'Abrir', 'tray_quit': 'Salir',
    'empty_title': "Todo hecho", 'empty_text': "No hay nada que hacer aquí ahora.", 'empty_hint': "Añade tareas abajo, p. ej. «Impuestos semana 47».",
    'members_menu': "Para quién …", 'members': "Para quién", 'members_all': "Todos", 'show_other_lists': "Mostrar listas de otros ({0})", 'only_my_lists': "Solo mis listas", 'members_hint': "Solo estas personas ven la lista en su resumen. Los demás pueden mostrarla igualmente.",
  },
};
