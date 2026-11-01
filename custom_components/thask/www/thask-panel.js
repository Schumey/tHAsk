// tHAsk panel: task lists with fuzzy due dates, served by the thask integration.
// Plain web component without build step; talks to the integration over the HA WebSocket API.

const STRINGS = {
  de: {
    my_day: "Heute", important: "Wichtig", planned: "Geplant", this_week: "Diese Woche",
    lists: "Listen", add_task: "Aufgabe hinzufügen", quick_hint: "z. B. „Reifen wechseln nächsten Monat !“",
    new_list: "Neue Liste", completed: "Erledigt", steps: "Schritte", add_step: "Nächster Schritt",
    range: "Zeitraum", range_all: "Alle", range_week: "Bis Ende der Woche", range_month: "Bis Ende des Monats",
    range_quarter: "Bis Ende des Quartals", range_year: "Bis Ende des Jahres",
    due: "Fällig", none: "Keine", day: "Tag", week: "Woche", month: "Monat", quarter: "Quartal", year: "Jahr",
    time: "Uhrzeit", reminder: "Erinnerung", recurrence: "Wiederholung", every: "alle", notes: "Notizen",
    notes_hint: "Notiz hinzufügen", list: "Liste", delete: "Löschen", rename: "Umbenennen", group: "Gruppe",
    delete_task_confirm: "Aufgabe „{0}“ löschen?", delete_list_confirm: "Liste „{0}“ mit allen Aufgaben löschen?",
    no_group: "Keine Gruppe", new_group: "Neue Gruppe …", group_name: "Name der Gruppe", created: "Erstellt", overdue: "Überfällig",
    search: "Suche", search_results: "Suchergebnisse", later: "Später", this_month: "Diesen Monat", empty: "Keine Aufgaben", today: "Heute", tomorrow: "Morgen",
    next_week: "Nächste Woche", next_month: "Nächsten Monat", steps_of: "{0} von {1}",
    rec_day: "Täglich", rec_week: "Wöchentlich", rec_month: "Monatlich", rec_quarter: "Vierteljährlich",
    rec_year: "Jährlich", rec_every: "Alle {0} {1}", units_day: "Tage", units_week: "Wochen",
    units_month: "Monate", units_quarter: "Quartale", units_year: "Jahre", close: "Schließen", on_weekdays: "An",
    back: "Zurück", loading: "Lade …", not_loaded: "tHAsk ist nicht geladen. Ist die Integration eingerichtet?",
    kind_due: "Fällig", kind_time: "Uhrzeit", kind_recurrence: "Wiederholung", kind_priority: "Priorität",
    ignore: "Nicht erkennen", priority: "Priorität", priority_0: "Keine", priority_1: "Niedrig", priority_2: "Mittel", priority_3: "Hoch", complete: "Erledigt", week_short: "KW",
    sort: "Sortieren", sort_manual: "Manuell", sort_priority: "Priorität", sort_due: "Fälligkeit",
    sort_title: "Alphabetisch", sort_created: "Erstellungsdatum", clear_completed: "Erledigte löschen",
    clear_confirm: "{0} erledigte Aufgabe(n) aus „{1}“ endgültig löschen?", cleared: "{0} erledigte Aufgabe(n) gelöscht",
    triggers: "Trigger", new_trigger: "Neuer Trigger", check_now: "Jetzt prüfen", name: "Name", when: "Wenn", then: "Dann",
    cond_state: "Zustand einer Entität", cond_calendar: "Kalendereintrag", cond_time: "Uhrzeit", entity: "Entität",
    state_is: "Zustand", state_hint: "leer = an / zuhause; >20 oder <5 für Zahlen", title_contains: "Titel enthält (leer = jeder Termin)",
    from_time: "ab", negate: "umkehren (NICHT)", hold_minutes: "seit Minuten", part_any: "jeder Tag des Termins",
    part_start: "nur Starttag", part_end: "nur Endtag", add_condition: "Weitere Bedingung", combine_and: "alle (UND)",
    combine_or: "mindestens eine (ODER)", window: "Nur zwischen", days_ahead: "Anlegen bis zu Tage vorher", days_ahead_hint: "0 = am Tag des Termins, 1 = schon am Vortag, 7 = eine Woche vorher", task_title: "Titel der Aufgabe",
    placeholders: "Platzhalter: {termin}, {datum}, {wochentag}, {zustand}", due_today: "Heute", due_day: "Tag (des Termins)",
    due_day_before: "Vortag (des Termins)", due_week: "Woche (des Termins)", due_month: "Monat (des Termins)", save: "Speichern", test: "Testen", run_now: "Jetzt ausführen",
    paused_until: "Pausiert bis", paused_until_x: "pausiert bis {0}", history: "Verlauf", undo: "Rückgängig", undone: "rückgängig gemacht",
    no_triggers: "Noch keine Trigger. Ein Trigger legt einmal pro Tag eine Aufgabe an, wenn in Home Assistant etwas zutrifft, z. B. ein Kalendertermin morgen.",
    last_check: "Zuletzt geprüft {0}", test_met: "Trifft jetzt zu", test_not_met: "Trifft jetzt nicht zu", enabled: "Aktiv",
    delete_trigger_confirm: "Trigger „{0}“ löschen?", for_day: "für {0}", task_created: "Aufgabe „{0}“ angelegt",
    fired_none: "Kein Trigger hat ausgelöst", fired_n: "{0} Aufgabe(n) angelegt", missing_fields: "Name, Titel und für jede Bedingung die Entität bzw. Uhrzeit angeben",
    is_on: "an", by_hand: "von Hand",
    settings: "Einstellungen", saved: "Gespeichert", opt_overdue_in_today: "Überfällige Aufgaben in „Heute“", overdue_in_today_section: "Oben in einem eigenen Abschnitt „Überfällig“", overdue_in_today_mixed: "Zwischen den heutigen Aufgaben", overdue_in_today_separate: "Nicht in „Heute“, sondern in einer eigenen Ansicht „Überfällig“", opt_week_mode: "„Diese Woche“", week_mode_calendar: "Kalenderwoche (Montag bis Sonntag)", week_mode_rolling: "Heute und die nächsten 7 Tage", opt_views_apart: "Ansichten trennen", opt_separate_week: "„Heute“ und „Diese Woche“ trennen", opt_separate_week_hint: "„Heute“ zeigt nur Aufgaben mit einem festen Tag (und Überfälliges); Zeiträume wie „KW 44“ stehen in „Diese Woche“, das nichts zeigt, was schon in „Heute“ steht.", opt_separate_month: "„Diesen Monat“ trennen", opt_separate_month_hint: "„Diesen Monat“ zeigt nur, was nach dieser Woche bis Monatsende fällig ist.", opt_reminder_targets: "Erinnerungen senden an", opt_reminder_targets_hint: "Push über die Companion-App (mit Knopf „Erledigt“) oder persistent_notification für die Glocke in Home Assistant. Die Windows-App zeigt Erinnerungen selbst, solange sie läuft.", no_notify: "Keine Benachrichtigungsdienste gefunden.",
  },
  en: {
    my_day: "Today", important: "Important", planned: "Planned", this_week: "This week",
    lists: "Lists", add_task: "Add a task", quick_hint: "e.g. “Change tyres next month !”",
    new_list: "New list", completed: "Completed", steps: "Steps", add_step: "Next step",
    range: "Period", range_all: "All", range_week: "By end of week", range_month: "By end of month",
    range_quarter: "By end of quarter", range_year: "By end of year",
    due: "Due", none: "None", day: "Day", week: "Week", month: "Month", quarter: "Quarter", year: "Year",
    time: "Time", reminder: "Reminder", recurrence: "Repeat", every: "every", notes: "Notes",
    notes_hint: "Add a note", list: "List", delete: "Delete", rename: "Rename", group: "Group",
    delete_task_confirm: "Delete task “{0}”?", delete_list_confirm: "Delete list “{0}” with all its tasks?",
    no_group: "No group", new_group: "New group …", group_name: "Group name", created: "Created", overdue: "Overdue",
    search: "Search", search_results: "Search results", later: "Later", this_month: "This month", empty: "No tasks", today: "Today", tomorrow: "Tomorrow",
    next_week: "Next week", next_month: "Next month", steps_of: "{0} of {1}",
    rec_day: "Daily", rec_week: "Weekly", rec_month: "Monthly", rec_quarter: "Quarterly", rec_year: "Yearly",
    rec_every: "Every {0} {1}", units_day: "days", units_week: "weeks", units_month: "months",
    units_quarter: "quarters", units_year: "years", close: "Close", on_weekdays: "On", back: "Back", loading: "Loading …",
    not_loaded: "tHAsk is not loaded. Is the integration set up?",
    kind_due: "Due", kind_time: "Time", kind_recurrence: "Repeat", kind_priority: "Priority",
    ignore: "Don't detect", priority: "Priority", priority_0: "None", priority_1: "Low", priority_2: "Medium", priority_3: "High", complete: "Completed", week_short: "Week",
    sort: "Sort", sort_manual: "Manual", sort_priority: "Priority", sort_due: "Due date",
    sort_title: "Alphabetical", sort_created: "Creation date", clear_completed: "Clear completed",
    clear_confirm: "Permanently delete {0} completed task(s) from “{1}”?", cleared: "{0} completed task(s) deleted",
    triggers: "Triggers", new_trigger: "New trigger", check_now: "Check now", name: "Name", when: "When", then: "Then",
    cond_state: "Entity state", cond_calendar: "Calendar event", cond_time: "Time of day", entity: "Entity",
    state_is: "State", state_hint: "empty = on / home; >20 or <5 for numbers", title_contains: "Title contains (empty = any event)",
    from_time: "from", negate: "invert (NOT)", hold_minutes: "for minutes", part_any: "every day of the event",
    part_start: "first day only", part_end: "last day only", add_condition: "Another condition", combine_and: "all (AND)",
    combine_or: "at least one (OR)", window: "Only between", days_ahead: "Add up to days before", days_ahead_hint: "0 = on the day of the event, 1 = the day before, 7 = a week before", task_title: "Task title",
    placeholders: "Placeholders: {event}, {date}, {weekday}, {state}", due_today: "Today", due_day: "Day (of the event)",
    due_day_before: "Day before (the event)", due_week: "Week (of the event)", due_month: "Month (of the event)", save: "Save", test: "Test", run_now: "Run now",
    paused_until: "Paused until", paused_until_x: "paused until {0}", history: "History", undo: "Undo", undone: "undone",
    no_triggers: "No triggers yet. A trigger adds a task once a day when something applies in Home Assistant, e.g. a calendar event tomorrow.",
    last_check: "Last checked {0}", test_met: "Applies now", test_not_met: "Does not apply now", enabled: "Enabled",
    delete_trigger_confirm: "Delete trigger “{0}”?", for_day: "for {0}", task_created: "Task “{0}” added",
    fired_none: "No trigger fired", fired_n: "{0} task(s) added", missing_fields: "Enter a name, a title and the entity or time of each condition",
    is_on: "on", by_hand: "by hand",
    settings: "Settings", saved: "Saved", opt_overdue_in_today: "Overdue tasks in “Today”", overdue_in_today_section: "At the top in a section “Overdue”", overdue_in_today_mixed: "Among today's tasks", overdue_in_today_separate: "Not in “Today” but in a view “Overdue” of their own", opt_week_mode: "“This week”", week_mode_calendar: "Calendar week (Monday to Sunday)", week_mode_rolling: "Today and the next 7 days", opt_views_apart: "Keep views apart", opt_separate_week: "Keep “Today” and “This week” apart", opt_separate_week_hint: "“Today” only shows tasks due on a specific day (and overdue ones); periods such as “week 44” are in “This week”, which leaves out what “Today” shows.", opt_separate_month: "Keep “This month” apart", opt_separate_month_hint: "“This month” only shows what is due after this week until the end of the month.", opt_reminder_targets: "Send reminders to", opt_reminder_targets_hint: "Push via the companion app (with a “Done” button) or persistent_notification for the bell in Home Assistant. The Windows app shows reminders on its own while it is running.", no_notify: "No notify services found.",
  },
  nl: {
    my_day: "Vandaag", important: "Belangrijk", planned: "Gepland", this_week: "Deze week",
    lists: "Lijsten", add_task: "Taak toevoegen", quick_hint: "bijv. „Banden wisselen volgende maand !”",
    new_list: "Nieuwe lijst", completed: "Voltooid", steps: "Stappen", add_step: "Volgende stap",
    range: "Periode", range_all: "Alle", range_week: "Tot eind van de week", range_month: "Tot eind van de maand",
    range_quarter: "Tot eind van het kwartaal", range_year: "Tot eind van het jaar",
    due: "Te doen", none: "Geen", day: "Dag", week: "Week", month: "Maand", quarter: "Kwartaal", year: "Jaar",
    time: "Tijd", reminder: "Herinnering", recurrence: "Herhalen", every: "elke", notes: "Notities",
    notes_hint: "Notitie toevoegen", list: "Lijst", delete: "Verwijderen", rename: "Hernoemen", group: "Groep",
    delete_task_confirm: "Taak „{0}” verwijderen?", delete_list_confirm: "Lijst „{0}” met alle taken verwijderen?",
    no_group: "Geen groep", new_group: "Nieuwe groep …", group_name: "Groepsnaam", created: "Gemaakt", overdue: "Te laat",
    search: "Zoeken", search_results: "Zoekresultaten", later: "Later", this_month: "Deze maand", empty: "Geen taken", today: "Vandaag", tomorrow: "Morgen",
    next_week: "Volgende week", next_month: "Volgende maand", steps_of: "{0} van {1}",
    rec_day: "Dagelijks", rec_week: "Wekelijks", rec_month: "Maandelijks", rec_quarter: "Elk kwartaal", rec_year: "Jaarlijks",
    rec_every: "Elke {0} {1}", units_day: "dagen", units_week: "weken", units_month: "maanden",
    units_quarter: "kwartalen", units_year: "jaren", close: "Sluiten", on_weekdays: "Op", back: "Terug", loading: "Laden …",
    not_loaded: "tHAsk is niet geladen. Is de integratie ingesteld?",
    kind_due: "Te doen", kind_time: "Tijd", kind_recurrence: "Herhalen", kind_priority: "Prioriteit",
    ignore: "Niet herkennen", priority: "Prioriteit", priority_0: "Geen", priority_1: "Laag", priority_2: "Gemiddeld", priority_3: "Hoog", complete: "Voltooid", week_short: "Week",
    sort: "Sorteren", sort_manual: "Handmatig", sort_priority: "Prioriteit", sort_due: "Vervaldatum",
    sort_title: "Alfabetisch", sort_created: "Aanmaakdatum", clear_completed: "Voltooide verwijderen",
    clear_confirm: "{0} voltooide taak/taken definitief uit „{1}” verwijderen?", cleared: "{0} voltooide taak/taken verwijderd",
    triggers: "Triggers", new_trigger: "Nieuwe trigger", check_now: "Nu controleren", name: "Naam", when: "Als", then: "Dan",
    cond_state: "Status van een entiteit", cond_calendar: "Agenda-afspraak", cond_time: "Tijdstip", entity: "Entiteit",
    state_is: "Status", state_hint: "leeg = on / home; >20 of <5 voor getallen", title_contains: "Titel bevat (leeg = elke afspraak)",
    from_time: "vanaf", negate: "omkeren (NIET)", hold_minutes: "gedurende minuten", part_any: "elke dag van de afspraak",
    part_start: "alleen de eerste dag", part_end: "alleen de laatste dag", add_condition: "Nog een voorwaarde", combine_and: "alle (EN)",
    combine_or: "minstens één (OF)", window: "Alleen tussen", days_ahead: "Aanmaken tot dagen vooraf", days_ahead_hint: "0 = op de dag van de afspraak, 1 = de dag ervoor, 7 = een week ervoor", task_title: "Titel van de taak",
    placeholders: "Plaatshouders: {afspraak}, {datum}, {weekdag}, {toestand}", due_today: "Vandaag", due_day: "Dag (van de afspraak)",
    due_day_before: "Dag ervoor (van de afspraak)", due_week: "Week (van de afspraak)", due_month: "Maand (van de afspraak)", save: "Opslaan", test: "Testen", run_now: "Nu uitvoeren",
    paused_until: "Gepauzeerd tot", paused_until_x: "gepauzeerd tot {0}", history: "Geschiedenis", undo: "Ongedaan maken", undone: "ongedaan gemaakt",
    no_triggers: "Nog geen triggers. Een trigger voegt één keer per dag een taak toe als er iets in Home Assistant geldt, bijv. een afspraak morgen in de agenda.",
    last_check: "Laatst gecontroleerd {0}", test_met: "Geldt nu", test_not_met: "Geldt nu niet", enabled: "Actief",
    delete_trigger_confirm: "Trigger „{0}” verwijderen?", for_day: "voor {0}", task_created: "Taak „{0}” toegevoegd",
    fired_none: "Geen trigger uitgevoerd", fired_n: "{0} taak/taken toegevoegd", missing_fields: "Vul een naam, een titel en de entiteit of tijd van elke voorwaarde in",
    is_on: "aan", by_hand: "handmatig",
    settings: "Instellingen", saved: "Opgeslagen", opt_overdue_in_today: "Te late taken in „Vandaag”", overdue_in_today_section: "Bovenaan in een sectie „Te laat”", overdue_in_today_mixed: "Tussen de taken van vandaag", overdue_in_today_separate: "Niet in „Vandaag”, maar in een eigen weergave „Te laat”", opt_week_mode: "„Deze week”", week_mode_calendar: "Kalenderweek (maandag tot zondag)", week_mode_rolling: "Vandaag en de komende 7 dagen", opt_views_apart: "Weergaven scheiden", opt_separate_week: "„Vandaag” en „Deze week” scheiden", opt_separate_week_hint: "„Vandaag” toont alleen taken op een vaste dag (en te late); periodes zoals „week 44” staan in „Deze week”, die niets toont wat al in „Vandaag” staat.", opt_separate_month: "„Deze maand” scheiden", opt_separate_month_hint: "„Deze maand” toont alleen wat na deze week tot het einde van de maand moet.", opt_reminder_targets: "Herinneringen sturen naar", opt_reminder_targets_hint: "Push via de Companion-app (met een knop „Klaar”) of persistent_notification voor de bel in Home Assistant. De Windows-app toont herinneringen zelf zolang hij draait.", no_notify: "Geen meldingsdiensten gevonden.",
  },
  fr: {
    my_day: "Aujourd'hui", important: "Important", planned: "Planifié", this_week: "Cette semaine",
    lists: "Listes", add_task: "Ajouter une tâche", quick_hint: "p. ex. « Changer les pneus le mois prochain ! »",
    new_list: "Nouvelle liste", completed: "Terminées", steps: "Étapes", add_step: "Étape suivante",
    range: "Période", range_all: "Toutes", range_week: "D'ici la fin de la semaine", range_month: "D'ici la fin du mois",
    range_quarter: "D'ici la fin du trimestre", range_year: "D'ici la fin de l'année",
    due: "Échéance", none: "Aucune", day: "Jour", week: "Semaine", month: "Mois", quarter: "Trimestre", year: "Année",
    time: "Heure", reminder: "Rappel", recurrence: "Répéter", every: "tous les", notes: "Notes",
    notes_hint: "Ajouter une note", list: "Liste", delete: "Supprimer", rename: "Renommer", group: "Groupe",
    delete_task_confirm: "Supprimer la tâche « {0} » ?", delete_list_confirm: "Supprimer la liste « {0} » et toutes ses tâches ?",
    no_group: "Aucun groupe", new_group: "Nouveau groupe …", group_name: "Nom du groupe", created: "Créée le", overdue: "En retard",
    search: "Rechercher", search_results: "Résultats de recherche", later: "Plus tard", this_month: "Ce mois-ci", empty: "Aucune tâche", today: "Aujourd'hui", tomorrow: "Demain",
    next_week: "La semaine prochaine", next_month: "Le mois prochain", steps_of: "{0} sur {1}",
    rec_day: "Tous les jours", rec_week: "Toutes les semaines", rec_month: "Tous les mois", rec_quarter: "Tous les trimestres", rec_year: "Tous les ans",
    rec_every: "Tous les {0} {1}", units_day: "jours", units_week: "semaines", units_month: "mois",
    units_quarter: "trimestres", units_year: "ans", close: "Fermer", on_weekdays: "Le", back: "Retour", loading: "Chargement …",
    not_loaded: "tHAsk n'est pas chargé. L'intégration est-elle configurée ?",
    kind_due: "Échéance", kind_time: "Heure", kind_recurrence: "Répéter", kind_priority: "Priorité",
    ignore: "Ne pas reconnaître", priority: "Priorité", priority_0: "Aucune", priority_1: "Basse", priority_2: "Moyenne", priority_3: "Haute", complete: "Terminée", week_short: "Sem.",
    sort: "Trier", sort_manual: "Manuel", sort_priority: "Priorité", sort_due: "Échéance",
    sort_title: "Alphabétique", sort_created: "Date de création", clear_completed: "Supprimer les terminées",
    clear_confirm: "Supprimer définitivement {0} tâche(s) terminée(s) de « {1} » ?", cleared: "{0} tâche(s) terminée(s) supprimée(s)",
    triggers: "Déclencheurs", new_trigger: "Nouveau déclencheur", check_now: "Vérifier maintenant", name: "Nom", when: "Quand", then: "Alors",
    cond_state: "État d'une entité", cond_calendar: "Événement d'agenda", cond_time: "Heure", entity: "Entité",
    state_is: "État", state_hint: "vide = on / home ; >20 ou <5 pour les nombres", title_contains: "Le titre contient (vide = tout événement)",
    from_time: "à partir de", negate: "inverser (NON)", hold_minutes: "depuis minutes", part_any: "chaque jour de l'événement",
    part_start: "premier jour seulement", part_end: "dernier jour seulement", add_condition: "Autre condition", combine_and: "toutes (ET)",
    combine_or: "au moins une (OU)", window: "Seulement entre", days_ahead: "Créer jusqu'à jours avant", days_ahead_hint: "0 = le jour de l'événement, 1 = la veille, 7 = une semaine avant", task_title: "Titre de la tâche",
    placeholders: "Variables : {evenement}, {date}, {jour}, {etat}", due_today: "Aujourd'hui", due_day: "Jour (de l'événement)",
    due_day_before: "Veille (de l'événement)", due_week: "Semaine (de l'événement)", due_month: "Mois (de l'événement)", save: "Enregistrer", test: "Tester", run_now: "Exécuter maintenant",
    paused_until: "En pause jusqu'au", paused_until_x: "en pause jusqu'au {0}", history: "Historique", undo: "Annuler", undone: "annulé",
    no_triggers: "Aucun déclencheur. Un déclencheur ajoute une tâche une fois par jour quand une condition est remplie dans Home Assistant, p. ex. un événement demain dans l'agenda.",
    last_check: "Dernière vérification {0}", test_met: "Remplie maintenant", test_not_met: "Non remplie maintenant", enabled: "Actif",
    delete_trigger_confirm: "Supprimer le déclencheur « {0} » ?", for_day: "pour {0}", task_created: "Tâche « {0} » ajoutée",
    fired_none: "Aucun déclencheur exécuté", fired_n: "{0} tâche(s) ajoutée(s)", missing_fields: "Indiquez un nom, un titre et l'entité ou l'heure de chaque condition",
    is_on: "activé", by_hand: "manuellement",
    settings: "Paramètres", saved: "Enregistré", opt_overdue_in_today: "Tâches en retard dans « Aujourd'hui »", overdue_in_today_section: "En haut, dans une section « En retard »", overdue_in_today_mixed: "Parmi les tâches du jour", overdue_in_today_separate: "Pas dans « Aujourd'hui », mais dans une vue « En retard » à part", opt_week_mode: "« Cette semaine »", week_mode_calendar: "Semaine calendaire (lundi à dimanche)", week_mode_rolling: "Aujourd'hui et les 7 prochains jours", opt_views_apart: "Séparer les vues", opt_separate_week: "Séparer « Aujourd'hui » et « Cette semaine »", opt_separate_week_hint: "« Aujourd'hui » n'affiche que les tâches d'un jour précis (et celles en retard) ; les périodes comme « semaine 44 » sont dans « Cette semaine », qui n'affiche pas ce qui est déjà dans « Aujourd'hui ».", opt_separate_month: "Séparer « Ce mois-ci »", opt_separate_month_hint: "« Ce mois-ci » n'affiche que ce qui est à faire après cette semaine jusqu'à la fin du mois.", opt_reminder_targets: "Envoyer les rappels à", opt_reminder_targets_hint: "Push via l'application Companion (avec un bouton « Terminé ») ou persistent_notification pour la cloche de Home Assistant. L'application Windows affiche elle-même les rappels tant qu'elle est ouverte.", no_notify: "Aucun service de notification trouvé.",
  },
  es: {
    my_day: "Hoy", important: "Importante", planned: "Planificado", this_week: "Esta semana",
    lists: "Listas", add_task: "Añadir una tarea", quick_hint: "p. ej. «Cambiar neumáticos el próximo mes !»",
    new_list: "Nueva lista", completed: "Completadas", steps: "Pasos", add_step: "Siguiente paso",
    range: "Periodo", range_all: "Todas", range_week: "Hasta el final de la semana", range_month: "Hasta el final del mes",
    range_quarter: "Hasta el final del trimestre", range_year: "Hasta el final del año",
    due: "Vencimiento", none: "Ninguno", day: "Día", week: "Semana", month: "Mes", quarter: "Trimestre", year: "Año",
    time: "Hora", reminder: "Recordatorio", recurrence: "Repetir", every: "cada", notes: "Notas",
    notes_hint: "Añadir una nota", list: "Lista", delete: "Eliminar", rename: "Cambiar nombre", group: "Grupo",
    delete_task_confirm: "¿Eliminar la tarea «{0}»?", delete_list_confirm: "¿Eliminar la lista «{0}» con todas sus tareas?",
    no_group: "Sin grupo", new_group: "Nuevo grupo …", group_name: "Nombre del grupo", created: "Creada", overdue: "Vencidas",
    search: "Buscar", search_results: "Resultados de búsqueda", later: "Más tarde", this_month: "Este mes", empty: "No hay tareas", today: "Hoy", tomorrow: "Mañana",
    next_week: "La próxima semana", next_month: "El próximo mes", steps_of: "{0} de {1}",
    rec_day: "Diariamente", rec_week: "Semanalmente", rec_month: "Mensualmente", rec_quarter: "Trimestralmente", rec_year: "Anualmente",
    rec_every: "Cada {0} {1}", units_day: "días", units_week: "semanas", units_month: "meses",
    units_quarter: "trimestres", units_year: "años", close: "Cerrar", on_weekdays: "Los", back: "Atrás", loading: "Cargando …",
    not_loaded: "tHAsk no está cargado. ¿Está configurada la integración?",
    kind_due: "Vencimiento", kind_time: "Hora", kind_recurrence: "Repetir", kind_priority: "Prioridad",
    ignore: "No reconocer", priority: "Prioridad", priority_0: "Ninguna", priority_1: "Baja", priority_2: "Media", priority_3: "Alta", complete: "Completada", week_short: "Sem.",
    sort: "Ordenar", sort_manual: "Manual", sort_priority: "Prioridad", sort_due: "Vencimiento",
    sort_title: "Alfabético", sort_created: "Fecha de creación", clear_completed: "Eliminar completadas",
    clear_confirm: "¿Eliminar definitivamente {0} tarea(s) completada(s) de «{1}»?", cleared: "{0} tarea(s) completada(s) eliminada(s)",
    triggers: "Disparadores", new_trigger: "Nuevo disparador", check_now: "Comprobar ahora", name: "Nombre", when: "Cuando", then: "Entonces",
    cond_state: "Estado de una entidad", cond_calendar: "Evento del calendario", cond_time: "Hora del día", entity: "Entidad",
    state_is: "Estado", state_hint: "vacío = on / home; >20 o <5 para números", title_contains: "El título contiene (vacío = cualquier evento)",
    from_time: "desde", negate: "invertir (NO)", hold_minutes: "durante minutos", part_any: "cada día del evento",
    part_start: "solo el primer día", part_end: "solo el último día", add_condition: "Otra condición", combine_and: "todas (Y)",
    combine_or: "al menos una (O)", window: "Solo entre", days_ahead: "Crear hasta días antes", days_ahead_hint: "0 = el día del evento, 1 = el día anterior, 7 = una semana antes", task_title: "Título de la tarea",
    placeholders: "Variables: {evento}, {fecha}, {dia}, {estado}", due_today: "Hoy", due_day: "Día (del evento)",
    due_day_before: "Día anterior (al evento)", due_week: "Semana (del evento)", due_month: "Mes (del evento)", save: "Guardar", test: "Probar", run_now: "Ejecutar ahora",
    paused_until: "En pausa hasta", paused_until_x: "en pausa hasta {0}", history: "Historial", undo: "Deshacer", undone: "deshecho",
    no_triggers: "Aún no hay disparadores. Un disparador añade una tarea una vez al día cuando algo se cumple en Home Assistant, p. ej. un evento mañana en el calendario.",
    last_check: "Última comprobación {0}", test_met: "Se cumple ahora", test_not_met: "No se cumple ahora", enabled: "Activo",
    delete_trigger_confirm: "¿Eliminar el disparador «{0}»?", for_day: "para {0}", task_created: "Tarea «{0}» añadida",
    fired_none: "Ningún disparador ejecutado", fired_n: "{0} tarea(s) añadida(s)", missing_fields: "Introduce un nombre, un título y la entidad o la hora de cada condición",
    is_on: "encendido", by_hand: "a mano",
    settings: "Ajustes", saved: "Guardado", opt_overdue_in_today: "Tareas vencidas en «Hoy»", overdue_in_today_section: "Arriba, en una sección «Vencidas»", overdue_in_today_mixed: "Entre las tareas de hoy", overdue_in_today_separate: "No en «Hoy», sino en una vista propia «Vencidas»", opt_week_mode: "«Esta semana»", week_mode_calendar: "Semana natural (lunes a domingo)", week_mode_rolling: "Hoy y los próximos 7 días", opt_views_apart: "Separar vistas", opt_separate_week: "Separar «Hoy» y «Esta semana»", opt_separate_week_hint: "«Hoy» solo muestra tareas de un día concreto (y las vencidas); los periodos como «semana 44» están en «Esta semana», que no muestra lo que ya está en «Hoy».", opt_separate_month: "Separar «Este mes»", opt_separate_month_hint: "«Este mes» solo muestra lo que vence después de esta semana hasta final de mes.", opt_reminder_targets: "Enviar recordatorios a", opt_reminder_targets_hint: "Push mediante la app Companion (con un botón «Hecho») o persistent_notification para la campana de Home Assistant. La app de Windows muestra los recordatorios por sí misma mientras está abierta.", no_notify: "No se encontraron servicios de notificación.",
  },
};

const TASK_SORTS = ["manual", "priority", "due", "title", "created"];
// Period of the "Important" view: everything, or what is due by the end of this week, month …
const IMPORTANT_RANGES = ["all", "week", "month", "quarter", "year"];
const RANGE_STORAGE_KEY = "thask.importantRange";
const OVERDUE_COLLAPSED_KEY = "thask.overdueCollapsed";
// The integration appends its version to the module URL (cache busting), so the panel can show it.
const VERSION = new URL(import.meta.url).searchParams.get("v") || "";
// The version in the URL keeps the browser from mixing an old helper module with a new panel.
const {
  MONTHS, MONTHS_SHORT, WEEKDAYS_SHORT, GRANULARITIES, pad, toISO, parseISO, addDays,
  addMonths, weekdayIndex, periodStart, periodEnd, isoWeek, makePeriod, shiftPeriod, periodEndOf,
  periodStatus, periodLabel, periodRange, sortTasks, esc, dueBy, completedSince, isOverdue,
  matchesSmart, sortByDue, splitDone, language, dateLocale,
} = await import(`./thask-common.js?v=${VERSION}`);

const CONDITION_KINDS = ["state", "calendar", "time"];
const TRIGGER_DUE = ["none", "today", "day_before", "day", "week", "month"];
// Domains offered for state conditions.
const STATE_DOMAINS = ["person", "device_tracker", "binary_sensor", "sensor", "input_boolean", "input_select", "switch", "light", "zone", "sun", "alarm_control_panel", "climate", "cover", "lock", "media_player", "vacuum"];

const SMART_VIEWS = [
  { key: "my_day", icon: "mdi:calendar-today" },
  // Only with the option "overdue tasks in a view of their own".
  { key: "overdue", icon: "mdi:calendar-alert" },
  { key: "important", icon: "mdi:flag-outline" },
  { key: "planned", icon: "mdi:calendar-month-outline" },
  { key: "this_week", icon: "mdi:calendar-week" },
  { key: "this_month", icon: "mdi:calendar-month" },
];

// ---- Panel --------------------------------------------------------------------------------

class ThaskPanel extends HTMLElement {
  constructor() {
    super();
    this.attachShadow({ mode: "open" });
    this._lists = [];
    this._tasks = new Map();
    this._today = periodStart("day", new Date());
    this._view = { type: "smart", key: "my_day" };
    this._selectedTask = null;
    this._showCompleted = false;
    this._search = "";
    this._groupMenu = null; // null | "pick" | "new"
    this._overdueMode = "section"; // option of the integration: section | mixed | separate
    this._separateWeek = false; // options of the integration: keep the smart views apart
    this._separateMonth = false;
    this._weekMode = "calendar"; // "This week": calendar | rolling (today and the next seven days)
    this._settings = null; // settings page: { options, notify_services } once loaded
    this._overdueCollapsed = false;
    try {
      this._overdueCollapsed = localStorage.getItem(OVERDUE_COLLAPSED_KEY) === "1";
    } catch {
      // storage blocked: expanded
    }
    this._pane = "list";
    this._loaded = false;
    this._error = null;
    this._parse = null;
    this._disabledKinds = new Set();
    this._parseSeq = 0;
    this._dragTask = null;
    this._importantRange = "all";
    try {
      const stored = localStorage.getItem(RANGE_STORAGE_KEY);
      if (IMPORTANT_RANGES.includes(stored)) this._importantRange = stored;
    } catch {
      // storage blocked: keep the default
    }
    this._triggers = null; // null until the trigger subscription answered
    this._triggerRuns = [];
    this._triggerStatus = {};
    this._triggerDraft = null;
    this._triggerTests = {};
    // The module waits for its helpers before defining the element, so Home Assistant may already have set
    // these on the plain element; such values would hide the setters below. Hand them over.
    for (const prop of ["narrow", "hass"]) {
      if (Object.prototype.hasOwnProperty.call(this, prop)) {
        const value = this[prop];
        delete this[prop];
        this[prop] = value;
      }
    }
  }

  set hass(hass) {
    const first = !this._hass;
    this._hass = hass;
    if (this._menuButton) this._menuButton.hass = hass;
    if (first) {
      this._lang = language(hass.language);
      this._locale = dateLocale(hass.language);
      this._buildSkeleton();
      this._subscribe();
    }
  }

  set narrow(narrow) {
    this._narrow = narrow;
    if (this._menuButton) this._menuButton.narrow = narrow;
    this.toggleAttribute("narrow", !!narrow);
  }

  t(key, ...args) {
    let text = STRINGS[this._lang][key] ?? STRINGS.en[key] ?? key;
    args.forEach((arg, index) => (text = text.replace(`{${index}}`, arg)));
    return text;
  }

  disconnectedCallback() {
    this._unsubscribe?.then((unsub) => unsub()).catch(() => {});
    this._unsubscribe = null;
    this._triggersUnsub?.then((unsub) => unsub()).catch(() => {});
    this._triggersUnsub = null;
  }

  connectedCallback() {
    if (this._hass && !this._unsubscribe) this._subscribe();
  }

  // ---- Data -----------------------------------------------------------------------------

  _subscribe() {
    this._unsubscribe = this._hass.connection.subscribeMessage((event) => this._onEvent(event), { type: "thask/subscribe" });
    this._unsubscribe.catch((err) => {
      this._error = err?.message || this.t("not_loaded");
      this._render();
    });
  }

  _onEvent(event) {
    if (event.type === "snapshot") {
      this._today = parseISO(event.today);
      this._lists = event.lists;
      this._tasks = new Map(event.tasks.map((task) => [task.id, task]));
      this._setOptions(event.options || {});
      this._loaded = true;
      this._error = null;
      if (this._view.type === "list" && !this._lists.some((l) => l.id === this._view.id)) {
        this._view = { type: "smart", key: "my_day" };
      }
    } else if (event.type === "day_changed") {
      this._today = parseISO(event.today);
    } else if (event.type === "options") {
      this._setOptions(event);
    } else if (event.type === "change") {
      this._applyChange(event);
    }
    this._render();
  }

  _setOptions(options) {
    this._overdueMode = options.overdue_in_today || "section";
    this._separateWeek = !!options.separate_week;
    this._separateMonth = !!options.separate_month;
    this._weekMode = options.week_mode || "calendar";
    if (this._view.type === "smart" && this._view.key === "overdue" && this._overdueMode !== "separate") {
      this._view = { type: "smart", key: "my_day" };
    }
  }

  _isOverdue(task) {
    return isOverdue(task, this._today);
  }

  _applyChange(change) {
    if (change.kind === "task") {
      if (change.action === "removed") {
        this._tasks.delete(change.id);
        // A move to another list arrives as removed + created with the same id, so wait before closing.
        if (change.id === this._selectedTask) {
          setTimeout(() => {
            if (this._selectedTask === change.id && !this._tasks.has(change.id)) this._selectTask(null);
          }, 500);
        }
      } else {
        this._tasks.set(change.id, change.item);
      }
      return;
    }
    if (change.action === "removed") {
      this._lists = this._lists.filter((l) => l.id !== change.id);
      if (this._view.type === "list" && this._view.id === change.id) this._view = { type: "smart", key: "my_day" };
    } else {
      this._lists = [...this._lists.filter((l) => l.id !== change.id), change.item];
    }
    this._lists.sort((a, b) => a.position - b.position || a.created.localeCompare(b.created));
  }

  async _call(type, data = {}) {
    try {
      return await this._hass.callWS({ type, ...data });
    } catch (err) {
      this._toast(err?.message || String(err));
      throw err;
    }
  }

  _updateTask(task, patch) {
    // Apply locally right away so quick successive edits build on each other; the server's change event follows.
    const current = this._tasks.get(task.id) || task;
    this._tasks.set(task.id, { ...current, ...patch });
    this._render();
    return this._call("thask/task/update", { task_id: task.id, ...patch });
  }

  // ---- Derived data -----------------------------------------------------------------------

  get _todayISO() {
    return toISO(this._today);
  }

  _monthEnd() {
    return periodEnd("month", periodStart("month", this._today));
  }

  _weekEnd() {
    return periodEnd("week", periodStart("week", this._today));
  }

  _dueBy(task, day) {
    return dueBy(task, day);
  }

  _completedSince(task, day) {
    return completedSince(task, day);
  }

  _matchesSmart(task, key) {
    return matchesSmart(task, key, {
      today: this._today, overdueMode: this._overdueMode, importantRange: this._importantRange,
      separateWeek: this._separateWeek, separateMonth: this._separateMonth, rollingWeek: this._weekMode === "rolling",
    });
  }

  _matchesSearch(task) {
    const query = this._search.trim().toLowerCase();
    if (!query) return true;
    const haystack = [task.title, task.notes, ...(task.steps || []).map((s) => s.title), ...(task.categories || [])];
    return query.split(/\s+/).every((word) => haystack.some((text) => (text || "").toLowerCase().includes(word)));
  }

  _viewTasks(view = this._view) {
    // An active search looks through all lists; the sidebar counts (explicit view) stay unaffected.
    const searching = view === this._view && this._search.trim();
    const tasks = [...this._tasks.values()].filter((task) =>
      searching ? this._matchesSearch(task)
        : view.type === "list" ? task.list_id === view.id : this._matchesSmart(task, view.key)
    );
    return splitDone(view.type === "list" && !searching ? sortTasks(tasks, this._listSort(view.id)) : sortByDue(tasks));
  }

  _listSort(listId) {
    return this._lists.find((l) => l.id === listId)?.sort || "manual";
  }

  _viewTitle() {
    if (this._view.type === "triggers") return this.t("triggers");
    if (this._view.type === "settings") return this.t("settings");
    if (this._search.trim()) return this.t("search_results");
    if (this._view.type === "smart") return this.t(this._view.key);
    return this._lists.find((l) => l.id === this._view.id)?.name ?? "";
  }

  _defaultListId() {
    if (this._view.type === "list") return this._view.id;
    return this._lists[0]?.id;
  }

  // ---- Rendering ----------------------------------------------------------------------------

  _buildSkeleton() {
    this.shadowRoot.innerHTML = `
      <style>${STYLE}</style>
      <div class="app">
        <nav class="sidebar"></nav>
        <main class="main">
          <header class="toolbar">
            <span class="menu-slot"></span>
            <button class="icon-button back" data-action="back-to-sidebar" title="${esc(this.t("back"))}"><ha-icon icon="mdi:arrow-left"></ha-icon></button>
            <h1 class="view-title"></h1>
            <span class="view-actions"></span>
          </header>
          <div class="group-menu" hidden></div>
          <div class="quick-add">
            <div class="quick-row">
              <ha-icon icon="mdi:plus"></ha-icon>
              <input class="quick-input" placeholder="${esc(this.t("add_task"))}" title="${esc(this.t("quick_hint"))}" autocomplete="off">
            </div>
            <div class="chips"></div>
          </div>
          <div class="tasks"></div>
        </main>
        <aside class="detail"></aside>
        <div class="toast" hidden></div>
      </div>`;
    const root = this.shadowRoot;
    this._menuButton = document.createElement("ha-menu-button");
    this._menuButton.hass = this._hass;
    this._menuButton.narrow = this._narrow;
    root.querySelector(".menu-slot").append(this._menuButton);

    const quick = root.querySelector(".quick-input");
    quick.addEventListener("input", () => {
      this._disabledKinds.clear();
      this._requestParse();
    });
    quick.addEventListener("keydown", (ev) => {
      if (ev.key === "Enter") this._quickAdd();
      if (ev.key === "Escape") this._resetQuickAdd();
    });
    root.addEventListener("input", (ev) => {
      if (!ev.target.classList?.contains("search-input")) return;
      this._search = ev.target.value;
      if (this._view.type === "triggers" || this._view.type === "settings") this._view = { type: "smart", key: "my_day" };
      this._selectedTask = null;
      this._pane = "list";
      this._render();
    });
    root.addEventListener("input", (ev) => {
      if (ev.target.dataset?.tfield) this._onTriggerField(ev.target, false);
    });
    root.addEventListener("click", (ev) => this._onClick(ev));
    root.addEventListener("change", (ev) => this._onChange(ev));
    root.addEventListener("keydown", (ev) => this._onKeyDown(ev));
    root.addEventListener("focusout", (ev) => this._onFocusOut(ev));
    root.addEventListener("dragstart", (ev) => this._onDragStart(ev));
    root.addEventListener("dragover", (ev) => this._onDragOver(ev));
    root.addEventListener("dragleave", (ev) => ev.target.closest?.("[data-drop]")?.classList.remove("drop-target"));
    root.addEventListener("drop", (ev) => this._onDrop(ev));
    root.addEventListener("dragend", () => {
      this._dragTask = null;
      this._dragList = null;
      root.querySelectorAll(".drop-target, .dragging").forEach((el) => el.classList.remove("drop-target", "dragging"));
    });
    this._render();
  }

  _render() {
    const root = this.shadowRoot;
    if (!root.querySelector(".app")) return;
    const triggersView = this._view.type === "triggers";
    root.querySelector(".app").dataset.pane = this._pane;
    root.querySelector(".app").classList.toggle("has-detail", triggersView ? !!this._triggerDraft : !!this._selectedTask);
    root.querySelector(".app").classList.toggle("triggers-view", triggersView);
    root.querySelector(".app").classList.toggle("settings-view", this._view.type === "settings");
    if (this._error) {
      root.querySelector(".tasks").innerHTML = `<div class="empty">${esc(this._error)}</div>`;
      return;
    }
    if (!this._loaded) {
      root.querySelector(".tasks").innerHTML = `<div class="empty">${esc(this.t("loading"))}</div>`;
      return;
    }
    this._renderSidebar();
    this._renderHeader();
    this._renderGroupMenu();
    if (this._view.type === "settings") {
      root.querySelector(".app").classList.remove("has-detail");
      this._renderSettings();
      return;
    }
    if (triggersView) {
      this._renderTriggers();
      if (this._editorDraft !== this._triggerDraft) this._renderTriggerEditor();
      return;
    }
    this._editorDraft = undefined;
    this._renderTasks();
    this._renderChips();
    if (!this._isEditingDetail() || this._detailFor !== this._selectedTask) this._renderDetail();
  }

  // The detail pane is not replaced while the user is typing in it (an empty "next step" field does not count).
  _isEditingDetail() {
    const active = this.shadowRoot.activeElement;
    if (!active || !this.shadowRoot.querySelector(".detail").contains(active)) return false;
    if (!active.matches("input, textarea, select")) return false;
    return !(active.dataset.field === "new-step" && !active.value);
  }

  _renderSidebar() {
    const count = (view) => this._viewTasks(view).open.length;
    const isActive = (view) =>
      view.type === this._view.type && (view.type === "list" ? view.id === this._view.id : view.key === this._view.key);
    const item = (view, icon, label) => `
      <button class="nav-item ${isActive(view) ? "active" : ""}" data-action="view" data-view-type="${view.type}"
        data-view="${esc(view.type === "list" ? view.id : view.key)}" ${view.type === "list" ? `data-drop="list" data-list-id="${esc(view.id)}" draggable="true"` : ""}>
        <ha-icon icon="${icon}"></ha-icon><span class="nav-label">${esc(label)}</span>
        <span class="count">${count(view) || ""}</span>
      </button>`;

    let html = `<div class="search"><ha-icon icon="mdi:magnify"></ha-icon><input class="search-input" type="search" placeholder="${esc(this.t("search"))}" autocomplete="off"></div><div class="nav-section">${SMART_VIEWS.filter((v) => v.key !== "overdue" || this._overdueMode === "separate").map((v) => item({ type: "smart", key: v.key }, v.icon, this.t(v.key))).join("")}</div><div class="divider"></div><div class="nav-section lists">`;
    let group = null;
    for (const list of this._lists) {
      if ((list.group || null) !== group) {
        // Ungrouped lists after a group get a divider so they don't look like part of it.
        html += list.group ? `<div class="group">${esc(list.group)}</div>` : `<div class="divider"></div>`;
        group = list.group || null;
      }
      html += item({ type: "list", id: list.id }, list.icon || "mdi:format-list-bulleted", list.name);
    }
    html += `<div class="drop-end" data-drop="list-end"></div></div>`;
    if (this._hass.user?.is_admin) {
      html += `<div class="divider"></div><button class="nav-item ${this._view.type === "triggers" ? "active" : ""}" data-action="view" data-view-type="triggers" data-view="triggers">
        <ha-icon icon="mdi:lightning-bolt-outline"></ha-icon><span class="nav-label">${esc(this.t("triggers"))}</span>
        <span class="count">${this._triggers?.length || ""}</span></button>
        <button class="nav-item ${this._view.type === "settings" ? "active" : ""}" data-action="view" data-view-type="settings" data-view="settings">
        <ha-icon icon="mdi:cog-outline"></ha-icon><span class="nav-label">${esc(this.t("settings"))}</span></button>`;
    }
    html += `<div class="new-list"><ha-icon icon="mdi:plus"></ha-icon><input class="new-list-input" placeholder="${esc(this.t("new_list"))}"></div>${VERSION ? `<div class="version">tHAsk v${esc(VERSION)}</div>` : ""}`;
    const sidebar = this.shadowRoot.querySelector(".sidebar");
    const focused = this.shadowRoot.activeElement?.classList.contains("new-list-input");
    const pending = sidebar.querySelector(".new-list-input")?.value || "";
    const searchFocused = this.shadowRoot.activeElement?.classList.contains("search-input");
    sidebar.innerHTML = html;
    const input = sidebar.querySelector(".new-list-input");
    input.value = pending;
    if (focused) input.focus();
    const searchInput = sidebar.querySelector(".search-input");
    searchInput.value = this._search;
    if (searchFocused) searchInput.focus();
  }

  _renderHeader() {
    const root = this.shadowRoot;
    const title = root.querySelector(".view-title");
    if (this._view.type === "settings") {
      title.textContent = this.t("settings");
      root.querySelector(".view-actions").innerHTML = "";
    } else if (this._view.type === "triggers") {
      title.textContent = this.t("triggers");
      root.querySelector(".view-actions").innerHTML = `
        <button class="icon-button" data-action="trigger-check" title="${esc(this.t("check_now"))}"><ha-icon icon="mdi:refresh"></ha-icon></button>
        <button class="icon-button" data-action="trigger-new" title="${esc(this.t("new_trigger"))}"><ha-icon icon="mdi:plus"></ha-icon></button>`;
    } else if (this._view.type === "list" && !this._search.trim()) {
      if (!title.querySelector("input") || root.activeElement !== title.querySelector("input")) {
        title.innerHTML = `<input class="list-name" value="${esc(this._viewTitle())}" title="${esc(this.t("rename"))}">`;
      }
      const sort = this._listSort(this._view.id);
      const doneCount = this._viewTasks().done.length;
      root.querySelector(".view-actions").innerHTML = `
        <label class="sort" title="${esc(this.t("sort"))}"><ha-icon icon="mdi:sort"></ha-icon>
          <select data-field="list-sort">${TASK_SORTS.map((mode) => `<option value="${mode}" ${mode === sort ? "selected" : ""}>${esc(this.t(`sort_${mode}`))}</option>`).join("")}</select></label>
        <button class="icon-button" data-action="list-clear-completed" title="${esc(this.t("clear_completed"))}" ${doneCount ? "" : "disabled"}><ha-icon icon="mdi:broom"></ha-icon></button>
        <button class="icon-button" data-action="list-group" title="${esc(this.t("group"))}"><ha-icon icon="mdi:folder-outline"></ha-icon></button>
        <button class="icon-button" data-action="list-delete" title="${esc(this.t("delete"))}"><ha-icon icon="mdi:delete-outline"></ha-icon></button>`;
    } else {
      const sub = this._view.key === "my_day" && !this._search.trim()
        ? `<span class="subtitle">${esc(this._today.toLocaleDateString(this._locale, { weekday: "long", day: "numeric", month: "long" }))}</span>`
        : "";
      title.innerHTML = `${esc(this._viewTitle())}${sub}`;
      root.querySelector(".view-actions").innerHTML = this._view.key === "important" && !this._search.trim()
        ? `<label class="sort" title="${esc(this.t("range"))}"><ha-icon icon="mdi:calendar-range"></ha-icon>
            <select data-field="important-range">${IMPORTANT_RANGES.map((r) => `<option value="${r}" ${r === this._importantRange ? "selected" : ""}>${esc(this.t(`range_${r}`))}</option>`).join("")}</select></label>`
        : "";
    }
  }

  _renderGroupMenu() {
    const menu = this.shadowRoot.querySelector(".group-menu");
    const list = this._view.type === "list" && !this._search.trim() ? this._lists.find((l) => l.id === this._view.id) : null;
    if (!list || !this._groupMenu) {
      this._groupMenu = null;
      menu.hidden = true;
      menu.dataset.state = "";
      return;
    }
    if (menu.dataset.state === this._groupMenu && !menu.hidden) return; // keep the typed name while other data changes
    menu.dataset.state = this._groupMenu;
    menu.hidden = false;
    if (this._groupMenu === "new") {
      menu.innerHTML = `<input class="group-input" placeholder="${esc(this.t("group_name"))}" autocomplete="off">`;
      menu.querySelector(".group-input").focus();
      return;
    }
    const groups = [...new Set(this._lists.map((l) => l.group).filter(Boolean))].sort((a, b) => a.localeCompare(b));
    const item = (label, icon, attrs, on) => `<button class="menu-item ${on ? "on" : ""}" ${attrs}>
      <ha-icon icon="${icon}"></ha-icon><span>${esc(label)}</span></button>`;
    menu.innerHTML = [
      ...groups.map((g) => item(g, g === list.group ? "mdi:check" : "mdi:folder-outline", `data-action="group-set" data-group="${esc(g)}"`, g === list.group)),
      item(this.t("no_group"), !list.group ? "mdi:check" : "mdi:folder-off-outline", 'data-action="group-set" data-group=""', !list.group),
      item(this.t("new_group"), "mdi:folder-plus-outline", 'data-action="group-new"', false),
    ].join("");
  }

  _setGroup(name) {
    const list = this._lists.find((l) => l.id === this._view.id);
    this._groupMenu = null;
    this._render();
    if (list && (name || null) !== (list.group || null)) this._call("thask/list/update", { list_id: list.id, group: name || null });
  }

  _renderTasks() {
    const { open, done } = this._viewTasks();
    const searching = !!this._search.trim();
    const reorderable = !searching && this._view.type === "list" && this._listSort(this._view.id) === "manual";
    let html = "";
    if (!searching && this._view.type === "smart" && this._view.key === "planned") {
      const weekEnd = this._weekEnd();
      const monthEnd = this._monthEnd();
      const groups = { overdue: [], this_week: [], this_month: [], later: [] };
      for (const task of open) {
        const end = periodEndOf(task.due);
        const key = end < this._today ? "overdue" : end <= weekEnd ? "this_week" : end <= monthEnd ? "this_month" : "later";
        groups[key].push(task);
      }
      for (const [key, tasks] of Object.entries(groups)) {
        if (tasks.length) html += `<div class="section-title ${key}">${esc(this.t(key))} <span>${tasks.length}</span></div>${tasks.map((t) => this._taskRow(t, false)).join("")}`;
      }
    } else if (!searching && this._view.type === "smart" && this._view.key === "my_day" && this._overdueMode === "section"
      && open.some((t) => this._isOverdue(t))) {
      // Overdue at the top under a heading that folds away; then today's tasks.
      const overdue = open.filter((t) => this._isOverdue(t));
      const rest = open.filter((t) => !this._isOverdue(t));
      html += `<button class="section-title overdue" data-action="toggle-overdue">
        <ha-icon icon="${this._overdueCollapsed ? "mdi:chevron-right" : "mdi:chevron-down"}"></ha-icon>${esc(this.t("overdue"))} <span>${overdue.length}</span></button>`;
      if (!this._overdueCollapsed) html += overdue.map((t) => this._taskRow(t, false)).join("");
      if (rest.length) html += `<div class="section-title">${esc(this.t("today"))} <span>${rest.length}</span></div>${rest.map((t) => this._taskRow(t, false)).join("")}`;
    } else {
      html += open.map((task) => this._taskRow(task, reorderable)).join("");
    }
    if (!open.length && !done.length) html += `<div class="empty">${esc(this.t("empty"))}</div>`;
    if (done.length) {
      html += `<button class="section-title completed-toggle" data-action="toggle-completed">
        <ha-icon icon="${this._showCompleted ? "mdi:chevron-down" : "mdi:chevron-right"}"></ha-icon>${esc(this.t("completed"))} <span>${done.length}</span></button>`;
      if (this._showCompleted) html += done.map((task) => this._taskRow(task, false)).join("");
    }
    if (reorderable) html += `<div class="drop-end" data-drop="end"></div>`;
    this.shadowRoot.querySelector(".tasks").innerHTML = html;
  }

  _dueChip(task) {
    if (!task.due) return "";
    const status = task.completed ? "" : periodStatus(task.due, this._today);
    let label = periodLabel(task.due, this._lang, this._today);
    if (task.due.granularity === "day") {
      const days = Math.round((parseISO(task.due.start) - this._today) / 864e5);
      if (days === 0) label = this.t("today");
      else if (days === 1) label = this.t("tomorrow");
      if (task.due_time) label += `, ${task.due_time}`;
    }
    const icon = task.due.granularity === "day" ? "mdi:calendar" : "mdi:calendar-range";
    return `<span class="meta due ${status}"><ha-icon icon="${icon}"></ha-icon>${esc(label)}</span>`;
  }

  _taskRow(task, draggable) {
    const meta = [];
    if (this._view.type === "smart") {
      const list = this._lists.find((l) => l.id === task.list_id);
      if (list) meta.push(`<span class="meta">${esc(list.name)}</span>`);
    }
    if (task.steps.length) {
      const doneSteps = task.steps.filter((s) => s.completed).length;
      meta.push(`<span class="meta">${esc(this.t("steps_of", doneSteps, task.steps.length))}</span>`);
    }
    if (task.due) meta.push(this._dueChip(task));
    if (task.recurrence) meta.push(`<span class="meta" title="${esc(this._recurrenceLabel(task.recurrence))}"><ha-icon icon="mdi:repeat"></ha-icon></span>`);
    if (task.reminder && !task.completed) meta.push(`<span class="meta"><ha-icon icon="mdi:bell-outline"></ha-icon></span>`);
    if (task.notes) meta.push(`<span class="meta"><ha-icon icon="mdi:note-text-outline"></ha-icon></span>`);
    return `
      <div class="task prio-${task.priority || 0} ${task.completed ? "completed" : ""} ${task.id === this._selectedTask ? "selected" : ""}"
        ${task.priority ? `title="${esc(this.t("priority"))}: ${esc(this.t(`priority_${task.priority}`))}"` : ""}
        data-action="select-task" data-task-id="${esc(task.id)}" ${draggable ? `draggable="true" data-drop="task"` : ""}>
        <button class="check" data-action="toggle-complete" data-task-id="${esc(task.id)}" title="${esc(this.t("complete"))}">
          <ha-icon icon="mdi:check"></ha-icon></button>
        <div class="task-body">
          <div class="task-title">${esc(task.title)}</div>
          ${meta.length ? `<div class="task-meta">${meta.join('<span class="dot">·</span>')}</div>` : ""}
        </div>
      </div>`;
  }

  _renderChips() {
    const chips = this.shadowRoot.querySelector(".chips");
    const parsed = this._parse;
    if (!parsed || !parsed.tokens.length) {
      chips.innerHTML = this._disabledKinds.size
        ? [...this._disabledKinds].map((k) => `<span class="chip off">${esc(this.t(`kind_${k}`))}</span>`).join("")
        : "";
      return;
    }
    const describe = (token) => {
      switch (token.kind) {
        case "due": return parsed.due_label + (parsed.due && parsed.due.granularity !== "day" ? ` (${periodRange(parsed.due, this._locale)})` : "");
        case "time": return parsed.due_time;
        case "recurrence": return this._recurrenceLabel(parsed.recurrence);
        default: return "";
      }
    };
    chips.innerHTML = parsed.tokens.map((token) => `
      <button class="chip" data-action="disable-kind" data-kind="${token.kind}" title="${esc(this.t("ignore"))}">
        <b>${esc(this.t(`kind_${token.kind}`))}</b> ${esc(describe(token))} <ha-icon icon="mdi:close"></ha-icon></button>`).join("");
  }

  _recurrenceLabel(recurrence) {
    if (!recurrence) return "";
    const label = recurrence.interval > 1
      ? this.t("rec_every", recurrence.interval, this.t(`units_${recurrence.unit}`))
      : this.t(`rec_${recurrence.unit}`);
    const days = recurrence.unit === "week" ? recurrence.weekdays || [] : [];
    return days.length ? `${label}: ${days.map((d) => WEEKDAYS_SHORT[this._lang][d]).join(", ")}` : label;
  }

  // Weekdays of a weekly recurrence; without a list it is the weekday of the due day.
  _recurrenceDays(task) {
    if (task.recurrence?.weekdays?.length) return task.recurrence.weekdays;
    return task.due?.granularity === "day" ? [weekdayIndex(parseISO(task.due.start))] : [];
  }

  _renderDetail() {
    if (this._view.type === "triggers") return; // the detail pane holds the trigger editor
    const detail = this.shadowRoot.querySelector(".detail");
    this._detailFor = this._selectedTask;
    const task = this._tasks.get(this._selectedTask);
    if (!task) {
      detail.innerHTML = "";
      return;
    }
    const lang = this._lang;
    const granularity = task.due?.granularity || "";
    const reminderLocal = task.reminder ? (() => {
      const d = new Date(task.reminder);
      return `${toISO(d)}T${pad(d.getHours())}:${pad(d.getMinutes())}`;
    })() : "";

    let dueEditor = "";
    if (task.due && granularity === "day") {
      dueEditor = `
        <div class="row"><input type="date" class="field" data-field="due-day" value="${esc(task.due.start)}">
        <input type="time" class="field time" data-field="due-time" value="${esc(task.due_time || "")}" title="${esc(this.t("time"))}"></div>`;
    } else if (task.due) {
      dueEditor = `
        <div class="stepper">
          <button class="icon-button" data-action="due-shift" data-shift="-1"><ha-icon icon="mdi:chevron-left"></ha-icon></button>
          <div class="stepper-label"><b>${esc(periodLabel(task.due, lang, this._today))}</b><span>${esc(periodRange(task.due, this._locale))}</span></div>
          <button class="icon-button" data-action="due-shift" data-shift="1"><ha-icon icon="mdi:chevron-right"></ha-icon></button>
        </div>`;
    }
    const quick = [
      ["today", makePeriod("day", this._today)],
      ["tomorrow", makePeriod("day", addDays(this._today, 1))],
      ["this_week", makePeriod("week", this._today)],
      ["next_week", makePeriod("week", addDays(this._today, 7))],
      ["this_month", makePeriod("month", this._today)],
      ["next_month", makePeriod("month", addMonths(this._today, 1))],
    ];

    const refocusNewStep = this.shadowRoot.activeElement?.dataset?.field === "new-step";
    detail.innerHTML = `
      <div class="detail-header">
        <button class="icon-button" data-action="close-detail" title="${esc(this.t("close"))}"><ha-icon icon="mdi:close"></ha-icon></button>
      </div>
      <div class="card title-card">
        <div class="row">
          <button class="check ${task.completed ? "on" : ""}" data-action="toggle-complete" data-task-id="${esc(task.id)}"><ha-icon icon="mdi:check"></ha-icon></button>
          <textarea class="title-input" data-field="title" rows="1">${esc(task.title)}</textarea>
        </div>
        <div class="steps">
          ${task.steps.map((step, index) => `
            <div class="step ${step.completed ? "completed" : ""}">
              <button class="check small ${step.completed ? "on" : ""}" data-action="toggle-step" data-index="${index}"><ha-icon icon="mdi:check"></ha-icon></button>
              <input class="step-input" data-field="step" data-index="${index}" value="${esc(step.title)}">
              <button class="icon-button small" data-action="delete-step" data-index="${index}"><ha-icon icon="mdi:close"></ha-icon></button>
            </div>`).join("")}
          <div class="step add"><ha-icon icon="mdi:plus"></ha-icon><input class="step-input" data-field="new-step" placeholder="${esc(this.t("add_step"))}"></div>
        </div>
      </div>
      <div class="card">
        <div class="label"><ha-icon icon="mdi:flag-outline"></ha-icon>${esc(this.t("priority"))}</div>
        <div class="segmented">
          ${[0, 1, 2, 3].map((n) => `<button class="prio-btn prio-${n} ${n === (task.priority || 0) ? "on" : ""}" data-action="priority-set" data-priority="${n}">${esc(this.t(`priority_${n}`))}</button>`).join("")}
        </div>
      </div>
      <div class="card">
        <div class="label"><ha-icon icon="mdi:calendar-range"></ha-icon>${esc(this.t("due"))}</div>
        <div class="segmented">
          ${["", ...GRANULARITIES].map((g) => `<button class="${g === granularity ? "on" : ""}" data-action="due-granularity" data-granularity="${g}">${esc(this.t(g || "none"))}</button>`).join("")}
        </div>
        ${dueEditor}
        <div class="quick-due">${quick.map(([key, period]) => `<button class="chip" data-action="due-set" data-period='${esc(JSON.stringify(period))}'>${esc(this.t(key))}</button>`).join("")}</div>
      </div>
      <div class="card">
        <div class="label"><ha-icon icon="mdi:bell-outline"></ha-icon>${esc(this.t("reminder"))}</div>
        <div class="row"><input type="datetime-local" class="field" data-field="reminder" value="${esc(reminderLocal)}">
        ${task.reminder ? `<button class="icon-button" data-action="clear-reminder"><ha-icon icon="mdi:close"></ha-icon></button>` : ""}</div>
      </div>
      <div class="card">
        <div class="label"><ha-icon icon="mdi:repeat"></ha-icon>${esc(this.t("recurrence"))}</div>
        <div class="row">
          <select class="field" data-field="recurrence-unit">
            <option value="">${esc(this.t("none"))}</option>
            ${GRANULARITIES.map((g) => `<option value="${g}" ${task.recurrence?.unit === g ? "selected" : ""}>${esc(this.t(`rec_${g}`))}</option>`).join("")}
          </select>
          ${task.recurrence ? `<span class="muted">${esc(this.t("every"))}</span><input type="number" min="1" class="field number" data-field="recurrence-interval" value="${task.recurrence.interval}">` : ""}
        </div>
        ${task.recurrence?.unit === "week" ? `
          <div class="row weekdays"><span class="muted">${esc(this.t("on_weekdays"))}</span>
            <div class="segmented">${WEEKDAYS_SHORT[lang].map((name, d) => `<button class="${this._recurrenceDays(task).includes(d) ? "on" : ""}" data-action="recurrence-weekday" data-weekday="${d}">${esc(name)}</button>`).join("")}</div>
          </div>` : ""}
      </div>
      <div class="card">
        <div class="label"><ha-icon icon="mdi:format-list-bulleted"></ha-icon>${esc(this.t("list"))}</div>
        <select class="field" data-field="list">
          ${this._lists.map((l) => `<option value="${esc(l.id)}" ${l.id === task.list_id ? "selected" : ""}>${esc(l.name)}</option>`).join("")}
        </select>
      </div>
      <div class="card">
        <textarea class="notes" data-field="notes" rows="5" placeholder="${esc(this.t("notes_hint"))}">${esc(task.notes)}</textarea>
      </div>
      <div class="detail-footer">
        <span class="muted">${esc(this.t("created"))} ${esc(new Date(task.created).toLocaleDateString(this._locale))}</span>
        <button class="icon-button danger" data-action="delete-task" title="${esc(this.t("delete"))}"><ha-icon icon="mdi:delete-outline"></ha-icon></button>
      </div>`;
    this._autosize(detail.querySelector(".title-input"));
    if (refocusNewStep) detail.querySelector('[data-field="new-step"]').focus();
  }

  _autosize(textarea) {
    if (!textarea) return;
    textarea.style.height = "auto";
    textarea.style.height = `${textarea.scrollHeight}px`;
  }

  _toast(message) {
    const toast = this.shadowRoot.querySelector(".toast");
    if (!toast) return;
    toast.textContent = message;
    toast.hidden = false;
    clearTimeout(this._toastTimer);
    this._toastTimer = setTimeout(() => (toast.hidden = true), 4000);
  }

  // ---- Quick add ----------------------------------------------------------------------------

  _requestParse() {
    clearTimeout(this._parseTimer);
    this._parseTimer = setTimeout(() => this._runParse(), 120);
  }

  async _runParse() {
    const text = this.shadowRoot.querySelector(".quick-input").value;
    const seq = ++this._parseSeq;
    if (!text.trim()) {
      this._parse = null;
      this._renderChips();
      return null;
    }
    try {
      const result = await this._hass.callWS({ type: "thask/parse", text, disabled: [...this._disabledKinds] });
      if (seq === this._parseSeq) {
        this._parse = result;
        this._renderChips();
      }
      return result;
    } catch {
      return null;
    }
  }

  async _quickAdd() {
    const input = this.shadowRoot.querySelector(".quick-input");
    const text = input.value.trim();
    if (!text) return;
    clearTimeout(this._parseTimer);
    const parsed = (await this._runParse()) || { title: text, tokens: [] };
    const listId = this._defaultListId();
    if (!parsed.title || !listId) return;
    const data = { list_id: listId, title: parsed.title, priority: parsed.priority || 0 };
    if (parsed.due) data.due = parsed.due;
    if (parsed.due_time) data.due_time = parsed.due_time;
    if (parsed.recurrence) data.recurrence = parsed.recurrence;
    if (this._view.type === "smart") {
      if (this._view.key === "my_day" && !data.due) data.due = makePeriod("day", this._today);
      if (this._view.key === "important") data.priority = Math.max(data.priority, 3);
      if (this._view.key === "this_week" && !data.due) data.due = makePeriod("week", this._today);
      if (this._view.key === "this_month" && !data.due) data.due = makePeriod("month", this._today);
    }
    await this._call("thask/task/create", data);
    this._resetQuickAdd();
  }

  _resetQuickAdd() {
    this.shadowRoot.querySelector(".quick-input").value = "";
    this._parse = null;
    this._disabledKinds.clear();
    this._renderChips();
  }

  // ---- Triggers -----------------------------------------------------------------------------

  _subscribeTriggers() {
    if (this._triggersUnsub) return;
    this._triggersUnsub = this._hass.connection.subscribeMessage((event) => {
      this._triggers = event.triggers;
      this._triggerRuns = event.runs;
      this._triggerStatus = event.status || {};
      this._render();
    }, { type: "thask/triggers/subscribe" });
    this._triggersUnsub.catch((err) => {
      this._triggersUnsub = null;
      this._toast(err?.message || String(err));
    });
  }

  _emptyCondition(kind = "calendar") {
    return { kind, entity: "", match: "", negate: false, hold_minutes: 0, part: "any" };
  }

  _newTriggerDraft() {
    return {
      name: "", enabled: true, combine: "and", window_from: "", window_to: "", days_ahead: 0, paused_until: null,
      conditions: [this._emptyCondition()],
      task: { title: "", list_id: this._lists[0]?.id || null, due: "day", priority: 0, notes: "" },
    };
  }

  _openTrigger(draft) {
    this._triggerDraft = draft;
    this._editorDraft = undefined;
    if (this._narrow) this._pane = draft ? "detail" : "list";
    this._render();
  }

  _conditionText(c) {
    const not = c.negate ? `${this.t("negate").split(" ")[0]} ` : "";
    switch (c.kind) {
      case "time": return `${not}${this.t("from_time")} ${c.match}`;
      case "calendar": return `${not}${c.entity}${c.match ? `: „${c.match}“` : ""}`;
      default: return `${c.entity} ${c.negate ? "≠" : "="} ${c.match || this.t("is_on")}${c.hold_minutes ? ` (${c.hold_minutes} min)` : ""}`;
    }
  }

  _dayLabel(iso) {
    return periodLabel(makePeriod("day", parseISO(iso)), this._lang, this._today);
  }

  // ---- Settings: the options of the integration (administrators only) --------------------

  async _loadSettings() {
    try {
      this._settings = await this._hass.callWS({ type: "thask/options/get" });
    } catch (err) {
      this._settings = { error: err.message || String(err) };
    }
    if (this._view.type === "settings") this._render();
  }

  async _saveOption(input) {
    const key = input.dataset.option;
    const value = key === "reminder_targets"
      ? [...this.shadowRoot.querySelectorAll("[data-option=reminder_targets]")].filter((box) => box.checked).map((box) => box.value)
      : input.type === "checkbox" ? input.checked : input.value;
    try {
      const result = await this._hass.callWS({ type: "thask/options/update", [key]: value });
      this._settings = { ...this._settings, options: result.options };
      this._toast(this.t("saved"));
    } catch (err) {
      this._toast(err.message || String(err));
      this._loadSettings();
    }
  }

  _renderSettings() {
    const box = this.shadowRoot.querySelector(".tasks");
    const settings = this._settings;
    if (!settings || settings.error) {
      box.innerHTML = `<div class="empty">${esc(settings ? settings.error : this.t("loading"))}</div>`;
      return;
    }
    const o = settings.options;
    const radios = (key, values) => values.map((value) => `
      <label class="option-choice"><input type="radio" name="${key}" value="${value}" data-option="${key}" ${o[key] === value ? "checked" : ""}>
        <span>${esc(this.t(`${key}_${value}`))}</span></label>`).join("");
    const toggle = (key) => `
      <label class="option-choice"><input type="checkbox" data-option="${key}" ${o[key] ? "checked" : ""}>
        <span>${esc(this.t(`opt_${key}`))}</span></label>
      <div class="muted option-hint">${esc(this.t(`opt_${key}_hint`))}</div>`;
    const chosen = o.reminder_targets || [];
    const targets = [...new Set([...settings.notify_services, ...chosen])].sort();
    box.innerHTML = `<div class="settings">
      <div class="section-title">${esc(this.t("opt_overdue_in_today"))}</div>
      ${radios("overdue_in_today", ["section", "mixed", "separate"])}
      <div class="section-title">${esc(this.t("opt_week_mode"))}</div>
      ${radios("week_mode", ["calendar", "rolling"])}
      <div class="section-title">${esc(this.t("opt_views_apart"))}</div>
      ${toggle("separate_week")}
      ${toggle("separate_month")}
      <div class="section-title">${esc(this.t("opt_reminder_targets"))}</div>
      ${targets.length ? targets.map((service) => `
        <label class="option-choice"><input type="checkbox" value="${esc(service)}" data-option="reminder_targets" ${chosen.includes(service) ? "checked" : ""}>
          <span>notify.${esc(service)}</span></label>`).join("") : `<div class="muted option-hint">${esc(this.t("no_notify"))}</div>`}
      <div class="muted option-hint">${esc(this.t("opt_reminder_targets_hint"))}</div>
    </div>`;
  }

  _renderTriggers() {
    const box = this.shadowRoot.querySelector(".tasks");
    if (this._triggers === null) {
      box.innerHTML = `<div class="empty">${esc(this.t("loading"))}</div>`;
      return;
    }
    const icons = { state: "mdi:toggle-switch-outline", calendar: "mdi:calendar-outline", time: "mdi:clock-outline" };
    let html = this._triggers.map((t) => {
      const test = this._triggerTests[t.id];
      const meta = t.conditions.map((c) => `<span class="meta"><ha-icon icon="${icons[c.kind]}"></ha-icon>${esc(this._conditionText(c))}</span>`);
      if (t.paused_until && t.paused_until >= this._todayISO) meta.push(`<span class="meta"><ha-icon icon="mdi:pause"></ha-icon>${esc(this.t("paused_until_x", this._dayLabel(t.paused_until)))}</span>`);
      return `
        <div class="task trigger ${t.enabled ? "" : "disabled"} ${t.id === this._triggerDraft?.id ? "selected" : ""}" data-action="trigger-edit" data-trigger-id="${esc(t.id)}">
          <button class="check ${t.enabled ? "on" : ""}" data-action="trigger-toggle" data-trigger-id="${esc(t.id)}" title="${esc(this.t("enabled"))}"><ha-icon icon="mdi:check"></ha-icon></button>
          <div class="task-body">
            <div class="task-title">${esc(t.name)} <span class="muted">→ ${esc(t.task.title)}</span></div>
            <div class="task-meta">${meta.join(`<span class="dot">${t.combine === "or" ? "|" : "·"}</span>`)}</div>
            ${test ? `<div class="test-result ${test.met ? "ok" : ""}">${esc(this.t(test.met ? "test_met" : "test_not_met"))}${test.results.length > 1 ? ` (${test.results.map((r) => (r ? "✓" : "✗")).join(" ")})` : ""}${test.event ? `: ${esc(test.event)}` : ""}</div>` : ""}
          </div>
          <button class="icon-button" data-action="trigger-test" data-trigger-id="${esc(t.id)}" title="${esc(this.t("test"))}"><ha-icon icon="mdi:flask-outline"></ha-icon></button>
          <button class="icon-button" data-action="trigger-run" data-trigger-id="${esc(t.id)}" title="${esc(this.t("run_now"))}"><ha-icon icon="mdi:play"></ha-icon></button>
        </div>`;
    }).join("");
    if (!this._triggers.length) html += `<div class="empty">${esc(this.t("no_triggers"))}</div>`;
    const status = this._triggerStatus;
    if (status.last_check) {
      const time = new Date(status.last_check).toLocaleTimeString(this._locale, { hour: "2-digit", minute: "2-digit" });
      html += `<div class="muted status-line">${esc(this.t("last_check", time))}</div>`;
    }
    for (const error of status.errors || []) html += `<div class="error-line"><ha-icon icon="mdi:alert-outline"></ha-icon>${esc(error)}</div>`;
    if (this._triggerRuns.length) {
      const names = new Map(this._triggers.map((t) => [t.id, t.name]));
      html += `<div class="section-title">${esc(this.t("history"))}</div>`;
      html += this._triggerRuns.map((run) => `
        <div class="run ${run.undone ? "undone" : ""}">
          <div class="task-body">
            <div class="task-title">${esc(run.title)}</div>
            <div class="task-meta"><span class="meta">${esc(names.get(run.trigger_id) || "")}</span><span class="dot">·</span>
              <span class="meta">${esc(this.t("for_day", this._dayLabel(run.day)))}</span>${run.manual ? `<span class="dot">·</span><span class="meta">${esc(this.t("by_hand"))}</span>` : ""}</div>
          </div>
          ${run.undone ? `<span class="muted">${esc(this.t("undone"))}</span>` : `<button class="chip" data-action="trigger-undo" data-run-id="${esc(run.id)}">${esc(this.t("undo"))}</button>`}
        </div>`).join("");
    }
    box.innerHTML = html;
  }

  _renderTriggerEditor() {
    const detail = this.shadowRoot.querySelector(".detail");
    const draft = this._triggerDraft;
    this._editorDraft = draft;
    if (!draft) {
      detail.innerHTML = "";
      return;
    }
    const states = Object.values(this._hass.states || {});
    const options = (pred) => states.filter((s) => pred(s.entity_id.split(".")[0]))
      .map((s) => `<option value="${esc(s.entity_id)}">${esc(s.attributes?.friendly_name || "")}</option>`).join("");
    const option = (value, label, current) => `<option value="${esc(value)}" ${value === current ? "selected" : ""}>${esc(label)}</option>`;
    const hasCalendar = draft.conditions.some((c) => c.kind === "calendar");
    const conditions = draft.conditions.map((c, i) => {
      let fields;
      if (c.kind === "time") {
        fields = `<div class="row"><span class="muted">${esc(this.t("from_time"))}</span><input type="time" class="field" data-tfield="cond.match" data-index="${i}" value="${esc(c.match)}"></div>`;
      } else if (c.kind === "calendar") {
        fields = `
          <input class="field" list="thask-calendars" data-tfield="cond.entity" data-index="${i}" value="${esc(c.entity)}" placeholder="calendar.…">
          <input class="field" data-tfield="cond.match" data-index="${i}" value="${esc(c.match)}" placeholder="${esc(this.t("title_contains"))}">
          <select class="field" data-tfield="cond.part" data-index="${i}">${["any", "start", "end"].map((p) => option(p, this.t(`part_${p}`), c.part)).join("")}</select>`;
      } else {
        fields = `
          <input class="field" list="thask-entities" data-tfield="cond.entity" data-index="${i}" value="${esc(c.entity)}" placeholder="person.…">
          <input class="field" data-tfield="cond.match" data-index="${i}" value="${esc(c.match)}" placeholder="${esc(this.t("state_is"))}" title="${esc(this.t("state_hint"))}">
          <div class="row"><span class="muted">${esc(this.t("hold_minutes"))}</span><input type="number" min="0" class="field number" data-tfield="cond.hold_minutes" data-index="${i}" value="${c.hold_minutes || 0}"></div>`;
      }
      return `
        <div class="condition">
          <div class="row">
            <select class="field" data-tfield="cond.kind" data-index="${i}">${CONDITION_KINDS.map((k) => option(k, this.t(`cond_${k}`), c.kind)).join("")}</select>
            ${draft.conditions.length > 1 ? `<button class="icon-button small" data-action="trigger-remove-condition" data-index="${i}" title="${esc(this.t("delete"))}"><ha-icon icon="mdi:close"></ha-icon></button>` : ""}
          </div>
          ${fields}
          <label class="row muted"><input type="checkbox" data-tfield="cond.negate" data-index="${i}" ${c.negate ? "checked" : ""}>${esc(this.t("negate"))}</label>
        </div>`;
    }).join("");
    detail.innerHTML = `
      <datalist id="thask-calendars">${options((d) => d === "calendar")}</datalist>
      <datalist id="thask-entities">${options((d) => STATE_DOMAINS.includes(d))}</datalist>
      <div class="detail-header">
        <button class="icon-button" data-action="trigger-close" title="${esc(this.t("close"))}"><ha-icon icon="mdi:close"></ha-icon></button>
      </div>
      <div class="card">
        <input class="title-input" data-tfield="name" value="${esc(draft.name)}" placeholder="${esc(this.t("name"))}">
        <label class="row muted"><input type="checkbox" data-tfield="enabled" ${draft.enabled ? "checked" : ""}>${esc(this.t("enabled"))}</label>
      </div>
      <div class="card">
        <div class="label"><ha-icon icon="mdi:lightning-bolt-outline"></ha-icon>${esc(this.t("when"))}</div>
        ${draft.conditions.length > 1 ? `<select class="field" data-tfield="combine">${["and", "or"].map((v) => option(v, this.t(`combine_${v}`), draft.combine)).join("")}</select>` : ""}
        ${conditions}
        <button class="chip" data-action="trigger-add-condition"><ha-icon icon="mdi:plus"></ha-icon>${esc(this.t("add_condition"))}</button>
        <div class="row"><span class="muted">${esc(this.t("window"))}</span>
          <input type="time" class="field" data-tfield="window_from" value="${esc(draft.window_from)}">
          <input type="time" class="field" data-tfield="window_to" value="${esc(draft.window_to)}"></div>
        ${hasCalendar ? `<div class="row" title="${esc(this.t("days_ahead_hint"))}"><span class="muted">${esc(this.t("days_ahead"))}</span><input type="number" min="0" max="60" class="field number" data-tfield="days_ahead" value="${draft.days_ahead || 0}"></div>
          <span class="muted">${esc(this.t("days_ahead_hint"))}</span>` : ""}
      </div>
      <div class="card">
        <div class="label"><ha-icon icon="mdi:checkbox-marked-circle-outline"></ha-icon>${esc(this.t("then"))}</div>
        <input class="field" data-tfield="task.title" value="${esc(draft.task.title)}" placeholder="${esc(this.t("task_title"))}">
        <span class="muted">${esc(this.t("placeholders"))}</span>
        <select class="field" data-tfield="task.list_id">${this._lists.map((l) => option(l.id, l.name, draft.task.list_id)).join("")}</select>
        <div class="row"><span class="muted">${esc(this.t("due"))}</span>
          <select class="field" data-tfield="task.due">${TRIGGER_DUE.map((d) => option(d, this.t(d === "none" ? "none" : `due_${d}`), draft.task.due)).join("")}</select></div>
        <div class="segmented">
          ${[0, 1, 2, 3].map((n) => `<button class="prio-btn prio-${n} ${n === draft.task.priority ? "on" : ""}" data-action="trigger-priority" data-priority="${n}">${esc(this.t(`priority_${n}`))}</button>`).join("")}
        </div>
      </div>
      <div class="card">
        <div class="row"><span class="muted">${esc(this.t("paused_until"))}</span>
          <input type="date" class="field" data-tfield="paused_until" value="${esc(draft.paused_until || "")}"></div>
      </div>
      <div class="detail-footer">
        <button class="button primary" data-action="trigger-save">${esc(this.t("save"))}</button>
        ${draft.id ? `<button class="icon-button danger" data-action="trigger-delete" title="${esc(this.t("delete"))}"><ha-icon icon="mdi:delete-outline"></ha-icon></button>` : ""}
      </div>`;
  }

  _onTriggerField(target, committed) {
    const draft = this._triggerDraft;
    if (!draft) return;
    const field = target.dataset.tfield;
    const value = target.type === "checkbox" ? target.checked : target.value;
    let rerender = false;
    if (field.startsWith("cond.")) {
      const condition = draft.conditions[Number(target.dataset.index)];
      const key = field.slice(5);
      if (key === "kind") {
        if (value !== condition.kind) draft.conditions[Number(target.dataset.index)] = this._emptyCondition(value);
        rerender = true;
      } else {
        condition[key] = key === "hold_minutes" ? Number(value) || 0 : value;
      }
    } else if (field.startsWith("task.")) {
      draft.task[field.slice(5)] = value;
    } else if (field === "days_ahead") {
      draft.days_ahead = Number(value) || 0;
    } else if (field === "paused_until") {
      draft.paused_until = value || null;
    } else {
      draft[field] = value;
      rerender = field === "combine";
    }
    if (rerender && committed) this._renderTriggerEditor();
  }

  _triggerPayload(draft) {
    const { id, created, modified, ...fields } = draft;
    fields.conditions = fields.conditions.map((c) => {
      const condition = { kind: c.kind, entity: c.kind === "time" ? "" : c.entity.trim(), match: c.match.trim(), negate: !!c.negate, part: c.part || "any", hold_minutes: c.kind === "state" ? c.hold_minutes || 0 : 0 };
      return condition;
    });
    fields.task = { ...fields.task, title: fields.task.title.trim() };
    fields.name = fields.name.trim();
    return fields;
  }

  async _onTriggerAction(action, target) {
    const triggerId = target.dataset.triggerId;
    const trigger = this._triggers?.find((t) => t.id === triggerId);
    switch (action) {
      case "trigger-new":
        this._openTrigger(this._newTriggerDraft());
        break;
      case "trigger-edit":
        if (trigger) this._openTrigger(structuredClone(trigger));
        break;
      case "trigger-close":
        this._openTrigger(null);
        break;
      case "trigger-add-condition":
        this._triggerDraft.conditions.push(this._emptyCondition("state"));
        this._renderTriggerEditor();
        break;
      case "trigger-remove-condition":
        this._triggerDraft.conditions.splice(Number(target.dataset.index), 1);
        this._renderTriggerEditor();
        break;
      case "trigger-priority":
        this._triggerDraft.task.priority = Number(target.dataset.priority);
        this._renderTriggerEditor();
        break;
      case "trigger-save": {
        const draft = this._triggerDraft;
        const payload = this._triggerPayload(draft);
        const incomplete = !payload.name || !payload.task.title
          || payload.conditions.some((c) => (c.kind === "time" ? !c.match : !c.entity));
        if (incomplete) {
          this._toast(this.t("missing_fields"));
          break;
        }
        try {
          if (draft.id) await this._call("thask/trigger/update", { trigger_id: draft.id, ...payload });
          else await this._call("thask/trigger/create", payload);
          this._openTrigger(null);
        } catch {
          // _call showed the error
        }
        break;
      }
      case "trigger-delete": {
        const draft = this._triggerDraft;
        if (draft?.id && confirm(this.t("delete_trigger_confirm", draft.name))) {
          await this._call("thask/trigger/delete", { trigger_id: draft.id });
          this._openTrigger(null);
        }
        break;
      }
      case "trigger-toggle":
        if (trigger) this._call("thask/trigger/update", { trigger_id: trigger.id, enabled: !trigger.enabled });
        break;
      case "trigger-test":
        this._triggerTests[triggerId] = await this._call("thask/trigger/test", { trigger_id: triggerId });
        this._render();
        break;
      case "trigger-run": {
        const run = await this._call("thask/trigger/run", { trigger_id: triggerId });
        this._toast(this.t("task_created", run.title));
        break;
      }
      case "trigger-check": {
        const result = await this._call("thask/trigger/check");
        this._toast(result.fired.length ? this.t("fired_n", result.fired.length) : this.t("fired_none"));
        break;
      }
      case "trigger-undo":
        this._call("thask/trigger/undo", { run_id: target.dataset.runId });
        break;
    }
  }

  // ---- Events -------------------------------------------------------------------------------

  _selectTask(taskId) {
    this._selectedTask = taskId;
    if (this._narrow) this._pane = taskId ? "detail" : "list";
    this._render();
  }

  _onClick(ev) {
    if (this._groupMenu && !ev.target.closest(".group-menu, [data-action='list-group']")) {
      this._groupMenu = null;
      this._render();
    }
    const target = ev.target.closest("[data-action]");
    if (!target) return;
    const action = target.dataset.action;
    const task = this._tasks.get(target.dataset.taskId || this._selectedTask);
    switch (action) {
      case "view":
        this._view = target.dataset.viewType === "list" ? { type: "list", id: target.dataset.view }
          : target.dataset.viewType === "triggers" ? { type: "triggers" }
          : target.dataset.viewType === "settings" ? { type: "settings" }
          : { type: "smart", key: target.dataset.view };
        if (this._view.type === "triggers") this._subscribeTriggers();
        if (this._view.type === "settings") this._loadSettings();
        this._selectedTask = null;
        this._showCompleted = false;
        this._search = "";
        this._groupMenu = null;
        this._pane = "list";
        this._render();
        break;
      case "trigger-new":
      case "trigger-edit":
      case "trigger-close":
      case "trigger-save":
      case "trigger-delete":
      case "trigger-toggle":
      case "trigger-test":
      case "trigger-run":
      case "trigger-check":
      case "trigger-undo":
      case "trigger-add-condition":
      case "trigger-remove-condition":
      case "trigger-priority":
        ev.stopPropagation();
        this._onTriggerAction(action, target);
        break;
      case "back-to-sidebar":
        this._pane = "sidebar";
        this._render();
        break;
      case "select-task":
        this._selectTask(target.dataset.taskId);
        break;
      case "close-detail":
        this._selectTask(null);
        break;
      case "toggle-complete":
        ev.stopPropagation();
        this._updateTask(task, { completed: !task.completed });
        break;
      case "priority-set":
        this._updateTask(task, { priority: Number(target.dataset.priority) });
        break;
      case "toggle-completed":
        this._showCompleted = !this._showCompleted;
        this._render();
        break;
      case "toggle-overdue":
        this._overdueCollapsed = !this._overdueCollapsed;
        try {
          localStorage.setItem(OVERDUE_COLLAPSED_KEY, this._overdueCollapsed ? "1" : "0");
        } catch {
          // not remembered
        }
        this._render();
        break;
      case "disable-kind":
        this._disabledKinds.add(target.dataset.kind);
        this._runParse();
        this.shadowRoot.querySelector(".quick-input").focus();
        break;
      case "toggle-step": {
        const steps = task.steps.map((s, i) => (i === Number(target.dataset.index) ? { ...s, completed: !s.completed } : s));
        this._updateTask(task, { steps });
        break;
      }
      case "delete-step":
        this._updateTask(task, { steps: task.steps.filter((_, i) => i !== Number(target.dataset.index)) });
        break;
      case "due-granularity": {
        const granularity = target.dataset.granularity;
        if (!granularity) this._updateTask(task, { due: null });
        else {
          const base = task.due ? parseISO(task.due.start) : this._today;
          this._updateTask(task, { due: makePeriod(granularity, base < this._today ? this._today : base) });
        }
        break;
      }
      case "due-shift":
        this._updateTask(task, { due: shiftPeriod(task.due, Number(target.dataset.shift)) });
        break;
      case "due-set":
        this._updateTask(task, { due: JSON.parse(target.dataset.period) });
        break;
      case "clear-reminder":
        this._updateTask(task, { reminder: null });
        break;
      case "recurrence-weekday": {
        const day = Number(target.dataset.weekday);
        const current = this._recurrenceDays(task);
        const weekdays = current.includes(day) ? current.filter((d) => d !== day) : [...current, day].sort();
        if (!weekdays.length) break;
        const patch = { recurrence: { ...task.recurrence, weekdays } };
        // The series runs on days: move the due date to the next chosen weekday unless it already is one.
        const due = task.due?.granularity === "day" ? parseISO(task.due.start) : null;
        if (!due || !weekdays.includes(weekdayIndex(due))) {
          const from = due && due > this._today ? due : this._today;
          const offset = [0, 1, 2, 3, 4, 5, 6].find((n) => weekdays.includes(weekdayIndex(addDays(from, n))));
          patch.due = { granularity: "day", start: toISO(addDays(from, offset)) };
        }
        this._updateTask(task, patch);
        break;
      }
      case "delete-task":
        if (confirm(this.t("delete_task_confirm", task.title))) this._call("thask/task/delete", { task_id: task.id });
        break;
      case "list-delete": {
        const list = this._lists.find((l) => l.id === this._view.id);
        if (list && confirm(this.t("delete_list_confirm", list.name))) this._call("thask/list/delete", { list_id: list.id });
        break;
      }
      case "list-clear-completed": {
        const list = this._lists.find((l) => l.id === this._view.id);
        const count = this._viewTasks().done.length;
        if (list && count && confirm(this.t("clear_confirm", count, list.name))) {
          this._call("thask/list/clear_completed", { list_id: list.id }).then((result) => this._toast(this.t("cleared", result.removed)));
        }
        break;
      }
      case "list-group":
        this._groupMenu = this._groupMenu ? null : "pick";
        this._render();
        break;
      case "group-set":
        this._setGroup(target.dataset.group);
        break;
      case "group-new":
        this._groupMenu = "new";
        this._render();
        break;
    }
  }

  _onChange(ev) {
    if (ev.target.dataset?.tfield) {
      this._onTriggerField(ev.target, true);
      return;
    }
    if (ev.target.dataset?.option) {
      this._saveOption(ev.target);
      return;
    }
    const field = ev.target.dataset?.field;
    if (field === "important-range") {
      this._importantRange = ev.target.value;
      try {
        localStorage.setItem(RANGE_STORAGE_KEY, this._importantRange);
      } catch {
        // not remembered, still applied
      }
      this._render();
      return;
    }
    if (field === "list-sort" && this._view.type === "list") {
      const listId = this._view.id;
      this._lists = this._lists.map((l) => (l.id === listId ? { ...l, sort: ev.target.value } : l));
      this._render();
      this._call("thask/list/update", { list_id: listId, sort: ev.target.value });
      return;
    }
    const task = this._tasks.get(this._selectedTask);
    if (!field || !task) return;
    const value = ev.target.value;
    switch (field) {
      case "due-day":
        if (value) this._updateTask(task, { due: { granularity: "day", start: value } });
        break;
      case "due-time":
        this._updateTask(task, { due_time: value || null });
        break;
      case "reminder":
        this._updateTask(task, { reminder: value || null });
        break;
      case "recurrence-unit":
        this._updateTask(task, { recurrence: value ? { unit: value, interval: task.recurrence?.interval || 1 } : null });
        break;
      case "recurrence-interval":
        if (Number(value) >= 1) this._updateTask(task, { recurrence: { ...task.recurrence, interval: Number(value) } });
        break;
      case "list":
        this._updateTask(task, { list_id: value });
        break;
    }
  }

  _onKeyDown(ev) {
    const target = ev.target;
    if (target.matches?.(".group-input")) {
      if (ev.key === "Enter" && target.value.trim()) this._setGroup(target.value.trim());
      if (ev.key === "Escape") {
        this._groupMenu = null;
        this._render();
      }
      return;
    }
    if (ev.key === "Enter" && !ev.shiftKey && target.matches?.(".title-input, .step-input, .list-name, .new-list-input")) {
      ev.preventDefault();
      if (target.dataset.field === "new-step") this._commitField(target);
      else target.blur();
    }
    if (target.matches?.(".title-input")) requestAnimationFrame(() => this._autosize(target));
  }

  _onFocusOut(ev) {
    this._commitField(ev.target);
    // Pending changes that arrived while typing.
    setTimeout(() => {
      if (!this._isEditingDetail()) this._renderDetail();
    });
  }

  _commitField(target) {
    const task = this._tasks.get(this._selectedTask);
    if (target.classList?.contains("new-list-input")) {
      const name = target.value.trim();
      if (name) {
        target.value = "";
        this._call("thask/list/create", { name }).then((list) => {
          this._view = { type: "list", id: list.id };
          this._render();
        });
      }
      return;
    }
    if (target.classList?.contains("list-name")) {
      const list = this._lists.find((l) => l.id === this._view.id);
      const name = target.value.trim();
      if (list && name && name !== list.name) this._call("thask/list/update", { list_id: list.id, name });
      return;
    }
    if (!task) return;
    const value = target.value;
    switch (target.dataset?.field) {
      case "title":
        if (value.trim() && value.trim() !== task.title) this._updateTask(task, { title: value.trim() });
        break;
      case "notes":
        if (value !== task.notes) this._updateTask(task, { notes: value });
        break;
      case "step": {
        const index = Number(target.dataset.index);
        if (task.steps[index] && value.trim() && value.trim() !== task.steps[index].title) {
          this._updateTask(task, { steps: task.steps.map((s, i) => (i === index ? { ...s, title: value.trim() } : s)) });
        }
        break;
      }
      case "new-step":
        if (value.trim()) {
          target.value = "";
          this._updateTask(task, { steps: [...task.steps, { title: value.trim(), completed: false }] });
        }
        break;
    }
  }

  // ---- Drag and drop: reorder within a list, or drop onto another list -------------------

  _onDragStart(ev) {
    const listItem = ev.target.closest?.(".nav-item[draggable]");
    if (listItem) {
      this._dragList = listItem.dataset.listId;
      listItem.classList.add("dragging");
      ev.dataTransfer.effectAllowed = "move";
      ev.dataTransfer.setData("text/plain", this._dragList);
      return;
    }
    const row = ev.target.closest?.(".task[draggable]");
    if (!row) return;
    this._dragTask = row.dataset.taskId;
    row.classList.add("dragging");
    ev.dataTransfer.effectAllowed = "move";
    ev.dataTransfer.setData("text/plain", this._dragTask);
  }

  _onDragOver(ev) {
    const target = ev.target.closest?.("[data-drop]");
    if (!target) return;
    const listDrop = ["list", "list-end"].includes(target.dataset.drop);
    // Lists can only be dropped among lists; tasks onto lists or tasks, not the list end.
    if (this._dragList ? !listDrop : !this._dragTask || target.dataset.drop === "list-end") return;
    ev.preventDefault();
    this.shadowRoot.querySelectorAll(".drop-target").forEach((el) => el !== target && el.classList.remove("drop-target"));
    target.classList.add("drop-target");
  }

  _onDrop(ev) {
    const target = ev.target.closest?.("[data-drop]");
    if (this._dragList && target) {
      ev.preventDefault();
      // Dropping onto a list places the dragged one before it.
      const listId = this._dragList;
      const order = this._lists.map((l) => l.id).filter((id) => id !== listId);
      const index = target.dataset.drop === "list-end" ? order.length : order.indexOf(target.dataset.listId);
      if (index >= 0) this._call("thask/list/move", { list_id: listId, previous_id: index === 0 ? null : order[index - 1] });
      return;
    }
    const taskId = this._dragTask;
    if (!taskId || !target) return;
    ev.preventDefault();
    const task = this._tasks.get(taskId);
    if (target.dataset.drop === "list") {
      if (target.dataset.listId !== task.list_id) this._updateTask(task, { list_id: target.dataset.listId });
      return;
    }
    // Dropping onto a task places the dragged one before it.
    const order = this._viewTasks().open.map((t) => t.id).filter((id) => id !== taskId);
    const index = target.dataset.drop === "end" ? order.length : order.indexOf(target.dataset.taskId);
    if (index < 0) return;
    this._call("thask/task/move", { task_id: taskId, previous_id: index === 0 ? null : order[index - 1] });
  }
}

const STYLE = `
  :host {
    --thask-accent: var(--primary-color, #03a9f4);
    --thask-prio-1: var(--success-color, #43a047);
    --thask-prio-2: var(--warning-color, #ffa600);
    --thask-prio-3: var(--error-color, #db4437);
    --thask-bg: var(--primary-background-color, #fafafa);
    --thask-surface: var(--card-background-color, #fff);
    --thask-sidebar: var(--secondary-background-color, #f2f2f2);
    --thask-text: var(--primary-text-color, #212121);
    --thask-muted: var(--secondary-text-color, #727272);
    --thask-divider: var(--divider-color, rgba(0, 0, 0, 0.12));
    --thask-danger: var(--error-color, #db4437);
    --thask-warning: var(--warning-color, #ffa600);
    display: block;
    height: 100%;
    background: var(--thask-bg);
    color: var(--thask-text);
    font-family: var(--paper-font-body1_-_font-family, Roboto, "Segoe UI", sans-serif);
    font-size: 14px;
  }
  * { box-sizing: border-box; }
  button { font: inherit; color: inherit; background: none; border: none; cursor: pointer; padding: 0; }
  input, textarea, select { font: inherit; color: inherit; }
  ha-icon { --mdc-icon-size: 20px; flex: none; }
  /* --xp-taskbar-height: fixed bottom bar of the HomeAssistantXP theme, 0 without it */
  .app { display: grid; grid-template-columns: 260px 1fr; height: calc(100vh - var(--xp-taskbar-height, 0px)); overflow: hidden; }
  .app.has-detail { grid-template-columns: 260px 1fr 360px; }
  .sidebar { background: var(--thask-sidebar); border-right: 1px solid var(--thask-divider); overflow-y: auto; padding: 8px 0; display: flex; flex-direction: column; }
  .search { display: flex; align-items: center; gap: 8px; margin: 8px 12px; padding: 0 10px; border-radius: 8px; background: color-mix(in srgb, var(--thask-text) 12%, transparent); color: var(--thask-muted); }
  .search-input { flex: 1; min-width: 0; border: none; background: none; outline: none; padding: 8px 0; font-size: 14px; color: var(--thask-text); }
  .nav-section { display: flex; flex-direction: column; }
  .nav-section.lists { flex: 1; }
  .nav-item { display: flex; align-items: center; gap: 12px; padding: 10px 16px; text-align: left; border-left: 3px solid transparent; }
  .nav-item:hover { background: color-mix(in srgb, var(--thask-text) 10%, transparent); }
  .nav-item.active { background: color-mix(in srgb, var(--thask-text) 16%, transparent); border-left-color: var(--thask-accent); font-weight: 500; }
  .nav-item ha-icon { color: var(--thask-accent); }
  .nav-label { flex: 1; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
  .count { color: var(--thask-muted); font-size: 12px; }
  .group { padding: 12px 16px 4px; font-size: 12px; font-weight: 500; color: var(--thask-muted); text-transform: uppercase; letter-spacing: 0.04em; }
  .divider { height: 1px; background: var(--thask-divider); margin: 8px 16px; }
  .version { padding: 8px 16px 12px; font-size: 12px; color: var(--thask-muted); }
  .new-list { display: flex; align-items: center; gap: 12px; padding: 10px 16px; color: var(--thask-accent); }
  .new-list input { flex: 1; min-width: 0; border: none; background: none; outline: none; }
  .main { position: relative; display: flex; flex-direction: column; min-width: 0; overflow: hidden; }
  .toolbar { display: flex; align-items: center; gap: 8px; padding: 12px 24px 8px; min-height: 64px; }
  .toolbar .menu-slot, .toolbar .back { display: none; }
  .view-title { flex: 1; margin: 0; font-size: 24px; font-weight: 500; color: var(--thask-accent); display: flex; flex-direction: column; min-width: 0; }
  .view-title .subtitle { font-size: 13px; font-weight: 400; color: var(--thask-muted); }
  .list-name { font-size: 24px; font-weight: 500; color: var(--thask-accent); border: none; background: none; outline: none; padding: 0; width: 100%; border-bottom: 1px solid transparent; }
  .list-name:focus { border-bottom-color: var(--thask-accent); }
  .group-menu { position: absolute; right: 24px; top: 56px; z-index: 5; min-width: 200px; padding: 6px 0; border-radius: 8px; background: var(--thask-surface); box-shadow: var(--ha-card-box-shadow, 0 4px 16px rgba(0,0,0,0.3)); }
  .group-menu[hidden] { display: none; }
  .menu-item { display: flex; align-items: center; gap: 12px; width: 100%; padding: 8px 16px; text-align: left; color: var(--thask-text); }
  .menu-item:hover { background: color-mix(in srgb, var(--thask-text) 14%, transparent); }
  .menu-item.on { color: var(--thask-accent); }
  .group-input { box-sizing: border-box; width: calc(100% - 24px); margin: 4px 12px; padding: 8px; border: 1px solid var(--thask-accent); border-radius: 6px; background: none; outline: none; color: var(--thask-text); }
  .view-actions { display: flex; gap: 4px; align-items: center; }
  .sort { display: inline-flex; align-items: center; gap: 4px; color: var(--thask-muted); padding: 0 4px; }
  .sort select { border: none; background: none; color: var(--thask-text); font-size: 13px; cursor: pointer; max-width: 130px; }
  .sort select option { background: var(--thask-surface); }
  .icon-button:disabled { opacity: 0.35; cursor: default; background: none; }
  .nav-item.dragging { opacity: 0.4; }
  .lists .drop-end { min-height: 12px; }
  .icon-button { width: 36px; height: 36px; display: inline-flex; align-items: center; justify-content: center; border-radius: 50%; color: var(--thask-muted); flex: none; }
  .icon-button:hover { background: color-mix(in srgb, var(--thask-text) 14%, transparent); }
  .icon-button.small { width: 28px; height: 28px; }
  .icon-button.danger:hover { color: var(--thask-danger); }
  .quick-add { margin: 0 24px 8px; background: var(--thask-surface); border-radius: 8px; box-shadow: var(--ha-card-box-shadow, 0 1px 2px rgba(0,0,0,0.15)); }
  .quick-row { display: flex; align-items: center; gap: 12px; padding: 0 16px; color: var(--thask-accent); }
  .quick-input { flex: 1; min-width: 0; border: none; background: none; outline: none; padding: 14px 0; font-size: 15px; color: var(--thask-text); }
  .chips { display: flex; flex-wrap: wrap; gap: 6px; padding: 0 16px; }
  .chips:not(:empty) { padding-bottom: 10px; }
  .chip { display: inline-flex; align-items: center; gap: 4px; border-radius: 14px; padding: 4px 10px; font-size: 12px; background: color-mix(in srgb, var(--thask-text) 12%, transparent); }
  .chip ha-icon { --mdc-icon-size: 14px; opacity: 0.6; }
  .chip.off { text-decoration: line-through; opacity: 0.6; }
  .chips .chip { background: color-mix(in srgb, var(--thask-accent) 15%, transparent); }
  .tasks { flex: 1; overflow-y: auto; padding: 0 24px 24px; display: flex; flex-direction: column; gap: 2px; }
  .task { display: flex; align-items: center; gap: 12px; padding: 10px 12px; background: var(--thask-surface); border-radius: 6px; cursor: pointer; border: 1px solid transparent; }
  .task:hover { filter: brightness(0.97); }
  .task.selected { border-color: var(--thask-accent); }
  .task.dragging { opacity: 0.4; }
  .task.drop-target { box-shadow: inset 0 2px 0 var(--thask-accent); }
  .drop-end { min-height: 24px; border-radius: 6px; }
  .drop-end.drop-target { box-shadow: inset 0 2px 0 var(--thask-accent); }
  .nav-item.drop-target { background: color-mix(in srgb, var(--thask-accent) 20%, transparent); }
  .task-body { flex: 1; min-width: 0; }
  .task-title { overflow-wrap: anywhere; }
  .task.completed .task-title { text-decoration: line-through; color: var(--thask-muted); }
  .task-meta { display: flex; flex-wrap: wrap; align-items: center; gap: 4px; margin-top: 2px; font-size: 12px; color: var(--thask-muted); }
  .meta { display: inline-flex; align-items: center; gap: 3px; }
  .meta ha-icon { --mdc-icon-size: 14px; }
  .meta.due.current { color: var(--thask-accent); }
  .meta.due.overdue { color: var(--thask-danger); }
  .dot { opacity: 0.6; }
  .check { width: 22px; height: 22px; border-radius: 50%; border: 2px solid var(--thask-muted); display: inline-flex; align-items: center; justify-content: center; flex: none; color: transparent; }
  .check ha-icon { --mdc-icon-size: 14px; }
  .check:hover { color: var(--thask-muted); }
  .task.completed .check, .check.on { background: var(--thask-accent); border-color: var(--thask-accent); color: var(--text-primary-color, #fff); }
  .check.small { width: 18px; height: 18px; }
  /* Priority: the bar gets wider with the level, so the level does not depend on the colour alone. */
  .task.prio-1 { box-shadow: inset 3px 0 0 var(--thask-prio-1); }
  .task.prio-2 { box-shadow: inset 5px 0 0 var(--thask-prio-2); }
  .task.prio-3 { box-shadow: inset 7px 0 0 var(--thask-prio-3); }
  .prio-btn.prio-1.on { box-shadow: inset 0 -3px 0 var(--thask-prio-1); }
  .prio-btn.prio-2.on { box-shadow: inset 0 -3px 0 var(--thask-prio-2); }
  .prio-btn.prio-3.on { box-shadow: inset 0 -3px 0 var(--thask-prio-3); }
  .section-title { display: flex; align-items: center; gap: 6px; padding: 14px 4px 6px; font-weight: 500; font-size: 13px; text-align: left; }
  .section-title span { color: var(--thask-muted); font-weight: 400; }
  .section-title.overdue { color: var(--thask-danger); }
  .empty { padding: 48px 16px; text-align: center; color: var(--thask-muted); }
  .detail { background: var(--thask-sidebar); border-left: 1px solid var(--thask-divider); overflow-y: auto; padding: 8px 16px 16px; display: none; flex-direction: column; gap: 8px; }
  .has-detail .detail { display: flex; }
  .detail-header { display: flex; justify-content: flex-end; }
  .card { background: var(--thask-surface); border-radius: 8px; padding: 12px; display: flex; flex-direction: column; gap: 8px; }
  .card.action { flex-direction: row; align-items: center; gap: 12px; text-align: left; color: var(--thask-muted); }
  .card.action.on { color: var(--thask-accent); }
  .row { display: flex; align-items: center; gap: 8px; }
  .title-input { flex: 1; font-size: 17px; font-weight: 500; border: none; background: none; outline: none; resize: none; overflow: hidden; padding: 0; }
  .steps { display: flex; flex-direction: column; }
  .step { display: flex; align-items: center; gap: 10px; padding: 4px 2px; }
  .step.completed .step-input { text-decoration: line-through; color: var(--thask-muted); }
  .step.add { color: var(--thask-accent); }
  .step-input { flex: 1; min-width: 0; border: none; background: none; outline: none; padding: 4px 0; }
  .label { display: flex; align-items: center; gap: 8px; color: var(--thask-muted); font-size: 13px; }
  .label ha-icon { --mdc-icon-size: 18px; }
  .segmented { display: flex; flex-wrap: wrap; border: 1px solid var(--thask-divider); border-radius: 6px; overflow: hidden; }
  .segmented button { flex: 1 1 auto; padding: 6px 6px; font-size: 12px; border-right: 1px solid var(--thask-divider); }
  .segmented button:last-child { border-right: none; }
  .segmented button.on { background: var(--thask-accent); color: var(--text-primary-color, #fff); }
  .row.weekdays { margin-top: 8px; }
  .row.weekdays .segmented { flex: 1; }
  .stepper { display: flex; align-items: center; gap: 4px; }
  .stepper-label { flex: 1; display: flex; flex-direction: column; align-items: center; }
  .stepper-label span { font-size: 12px; color: var(--thask-muted); }
  .quick-due { display: flex; flex-wrap: wrap; gap: 6px; }
  .field { flex: 1; min-width: 0; padding: 6px 8px; border: 1px solid var(--thask-divider); border-radius: 6px; background: var(--thask-bg); }
  .field.time { flex: 0 0 110px; }
  .field.number { flex: 0 0 64px; }
  .muted { color: var(--thask-muted); font-size: 12px; }
  .notes { width: 100%; border: none; background: none; outline: none; resize: vertical; }
  .detail-footer { display: flex; align-items: center; justify-content: space-between; margin-top: auto; padding-top: 8px; }
  .triggers-view .quick-add, .settings-view .quick-add { display: none; }
  .settings { max-width: 640px; padding: 0 4px 24px; }
  .option-choice { display: flex; align-items: center; gap: 10px; padding: 6px 4px; cursor: pointer; }
  .option-choice input { margin: 0; accent-color: var(--primary-color, #03a9f4); }
  .option-hint { padding: 0 4px 8px 30px; }
  .task.trigger.disabled .task-title { color: var(--thask-muted); }
  .test-result { font-size: 12px; margin-top: 4px; color: var(--thask-danger); }
  .test-result.ok { color: var(--thask-accent); }
  .status-line { padding: 12px 4px 0; }
  .error-line { display: flex; align-items: center; gap: 6px; padding: 4px; font-size: 12px; color: var(--thask-danger); }
  .error-line ha-icon { --mdc-icon-size: 16px; }
  .run { display: flex; align-items: center; gap: 12px; padding: 8px 12px; background: var(--thask-surface); border-radius: 6px; }
  .run.undone .task-title { text-decoration: line-through; color: var(--thask-muted); }
  .condition { display: flex; flex-direction: column; gap: 6px; padding: 8px; border: 1px solid var(--thask-divider); border-radius: 6px; }
  .detail .title-input { width: 100%; }
  .button { padding: 8px 16px; border-radius: 6px; }
  .button.primary { background: var(--thask-accent); color: var(--text-primary-color, #fff); }
  .toast { position: fixed; left: 50%; bottom: 24px; transform: translateX(-50%); background: var(--primary-text-color, #323232); color: var(--primary-background-color, #fff); padding: 10px 16px; border-radius: 6px; max-width: 90vw; z-index: 10; }

  :host([narrow]) .app, :host([narrow]) .app.has-detail { grid-template-columns: 1fr; }
  :host([narrow]) .toolbar .menu-slot, :host([narrow]) .toolbar .back { display: inline-flex; }
  :host([narrow]) .toolbar { padding: 4px 8px; }
  :host([narrow]) .quick-add { margin: 0 12px 8px; }
  :host([narrow]) .tasks { padding: 0 12px 24px; }
  :host([narrow]) .sidebar, :host([narrow]) .main, :host([narrow]) .detail { display: none; }
  :host([narrow]) [data-pane="sidebar"] .sidebar { display: flex; }
  :host([narrow]) [data-pane="list"] .main { display: flex; }
  :host([narrow]) [data-pane="detail"] .detail { display: flex; }
`;

// After an update HA loads the module again under a new ?v= URL while the old one is still registered.
if (!customElements.get("thask-panel")) customElements.define("thask-panel", ThaskPanel);
