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
  },
};

const MONTHS = {
  de: ["Januar", "Februar", "März", "April", "Mai", "Juni", "Juli", "August", "September", "Oktober", "November", "Dezember"],
  en: ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"],
};
const MONTHS_SHORT = {
  de: ["Jan.", "Feb.", "März", "Apr.", "Mai", "Juni", "Juli", "Aug.", "Sep.", "Okt.", "Nov.", "Dez."],
  en: ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"],
};
const WEEKDAYS_SHORT = { de: ["Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"], en: ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"] };
const GRANULARITIES = ["day", "week", "month", "quarter", "year"];
const TASK_SORTS = ["manual", "priority", "due", "title", "created"];
// Period of the "Important" view: everything, or what is due by the end of this week, month …
const IMPORTANT_RANGES = ["all", "week", "month", "quarter", "year"];
const RANGE_STORAGE_KEY = "thask.importantRange";
// The integration appends its version to the module URL (cache busting), so the panel can show it.
const VERSION = new URL(import.meta.url).searchParams.get("v") || "";

const CONDITION_KINDS = ["state", "calendar", "time"];
const TRIGGER_DUE = ["none", "today", "day_before", "day", "week", "month"];
// Domains offered for state conditions.
const STATE_DOMAINS = ["person", "device_tracker", "binary_sensor", "sensor", "input_boolean", "input_select", "switch", "light", "zone", "sun", "alarm_control_panel", "climate", "cover", "lock", "media_player", "vacuum"];

const SMART_VIEWS = [
  { key: "my_day", icon: "mdi:calendar-today" },
  { key: "important", icon: "mdi:flag-outline" },
  { key: "planned", icon: "mdi:calendar-month-outline" },
  { key: "this_week", icon: "mdi:calendar-week" },
  { key: "this_month", icon: "mdi:calendar-month" },
];

// ---- Dates and periods (same rules as core/period.py) ------------------------------------

const pad = (n) => String(n).padStart(2, "0");
const toISO = (d) => `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`;
const parseISO = (s) => {
  const [y, m, d] = s.split("-").map(Number);
  return new Date(y, m - 1, d);
};
const addDays = (d, n) => new Date(d.getFullYear(), d.getMonth(), d.getDate() + n);
const addMonths = (d, n) => {
  const first = new Date(d.getFullYear(), d.getMonth() + n, 1);
  const last = new Date(first.getFullYear(), first.getMonth() + 1, 0).getDate();
  return new Date(first.getFullYear(), first.getMonth(), Math.min(d.getDate(), last));
};
const weekdayIndex = (d) => (d.getDay() + 6) % 7;

function periodStart(granularity, d) {
  switch (granularity) {
    case "week": return addDays(d, -weekdayIndex(d));
    case "month": return new Date(d.getFullYear(), d.getMonth(), 1);
    case "quarter": return new Date(d.getFullYear(), Math.floor(d.getMonth() / 3) * 3, 1);
    case "year": return new Date(d.getFullYear(), 0, 1);
    default: return new Date(d.getFullYear(), d.getMonth(), d.getDate());
  }
}

function periodEnd(granularity, start) {
  switch (granularity) {
    case "week": return addDays(start, 6);
    case "month": return addDays(addMonths(start, 1), -1);
    case "quarter": return addDays(addMonths(start, 3), -1);
    case "year": return new Date(start.getFullYear(), 11, 31);
    default: return start;
  }
}

function isoWeek(d) {
  const thursday = addDays(d, 3 - weekdayIndex(d));
  const year = thursday.getFullYear();
  const dayOfYear = Math.round((thursday - new Date(year, 0, 1)) / 864e5);
  return [year, Math.floor(dayOfYear / 7) + 1];
}

function makePeriod(granularity, d) {
  return { granularity, start: toISO(periodStart(granularity, d)) };
}

function shiftPeriod(period, count) {
  const start = parseISO(period.start);
  const shifted = {
    day: () => addDays(start, count),
    week: () => addDays(start, 7 * count),
    month: () => addMonths(start, count),
    quarter: () => addMonths(start, 3 * count),
    year: () => addMonths(start, 12 * count),
  }[period.granularity]();
  return makePeriod(period.granularity, shifted);
}

const periodEndOf = (period) => periodEnd(period.granularity, parseISO(period.start));

function periodStatus(period, today) {
  if (periodEndOf(period) < today) return "overdue";
  if (parseISO(period.start) <= today) return "current";
  return "upcoming";
}

function periodLabel(period, lang, today) {
  const start = parseISO(period.start);
  let text;
  let year = start.getFullYear();
  switch (period.granularity) {
    case "day": {
      const weekday = WEEKDAYS_SHORT[lang][weekdayIndex(start)];
      const month = MONTHS_SHORT[lang][start.getMonth()];
      text = lang === "de" ? `${weekday}, ${start.getDate()}. ${month}` : `${weekday}, ${month} ${start.getDate()}`;
      break;
    }
    case "week": {
      const [weekYear, week] = isoWeek(start);
      year = weekYear;
      text = lang === "de" ? `KW ${week}` : `Week ${week}`;
      break;
    }
    case "month":
      text = MONTHS[lang][start.getMonth()];
      break;
    case "quarter":
      text = `Q${Math.floor(start.getMonth() / 3) + 1}`;
      break;
    default:
      return String(year);
  }
  return year === today.getFullYear() ? text : `${text} ${year}`;
}

function periodRange(period, lang) {
  if (period.granularity === "day") return "";
  const start = parseISO(period.start);
  const end = periodEndOf(period);
  const fmt = (d) => d.toLocaleDateString(lang === "de" ? "de-DE" : "en-GB", { day: "numeric", month: "short" });
  return `${fmt(start)} – ${fmt(end)}`;
}

// Same rules as sort_tasks in core/models.py; ties keep the manual order.
function sortTasks(tasks, mode) {
  const manual = [...tasks].sort((a, b) => a.position - b.position || a.created.localeCompare(b.created));
  const dueKey = (task) => (task.due ? toISO(periodEndOf(task.due)) : "9999-12-31");
  const keyed = {
    priority: (a, b) => b.priority - a.priority,
    due: (a, b) => dueKey(a).localeCompare(dueKey(b)),
    title: (a, b) => a.title.localeCompare(b.title, undefined, { sensitivity: "base" }),
    created: (a, b) => b.created.localeCompare(a.created),
  }[mode];
  return keyed ? manual.sort(keyed) : manual;
}

const esc = (value) =>
  String(value ?? "").replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[c]);

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
  }

  set hass(hass) {
    const first = !this._hass;
    this._hass = hass;
    if (this._menuButton) this._menuButton.hass = hass;
    if (first) {
      this._lang = (hass.language || "en").startsWith("de") ? "de" : "en";
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
    let text = STRINGS[this._lang][key] ?? key;
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
      this._loaded = true;
      this._error = null;
      if (this._view.type === "list" && !this._lists.some((l) => l.id === this._view.id)) {
        this._view = { type: "smart", key: "my_day" };
      }
    } else if (event.type === "day_changed") {
      this._today = parseISO(event.today);
    } else if (event.type === "change") {
      this._applyChange(event);
    }
    this._render();
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
    return task.due && periodEndOf(task.due) <= day;
  }

  _completedSince(task, day) {
    return task.completed_at && new Date(task.completed_at) >= day;
  }

  _matchesSmart(task, key) {
    switch (key) {
      case "my_day":
        // Today: everything due by today (overdue included), and what was completed today.
        if (!this._dueBy(task, this._today)) return false;
        return !task.completed || this._completedSince(task, this._today);
      case "important":
        if (task.priority < 3) return false;
        if (this._importantRange === "all") return true;
        return this._dueBy(task, periodEnd(this._importantRange, periodStart(this._importantRange, this._today)));
      case "planned":
        return !!task.due;
      case "this_week":
        if (!this._dueBy(task, this._weekEnd())) return false;
        return !task.completed || this._completedSince(task, periodStart("week", this._today));
      case "this_month":
        if (!this._dueBy(task, this._monthEnd())) return false;
        return !task.completed || this._completedSince(task, periodStart("month", this._today));
    }
    return false;
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
    const dueKey = (task) => (task.due ? toISO(periodEndOf(task.due)) : "9999");
    let sorted;
    if (view.type === "list" && !searching) {
      sorted = sortTasks(tasks, this._listSort(view.id));
    } else {
      sorted = tasks.sort((a, b) => dueKey(a).localeCompare(dueKey(b)) || b.priority - a.priority || a.position - b.position);
    }
    return {
      open: sorted.filter((task) => !task.completed),
      done: sorted.filter((task) => task.completed).sort((a, b) => (b.completed_at || "").localeCompare(a.completed_at || "")),
    };
  }

  _listSort(listId) {
    return this._lists.find((l) => l.id === listId)?.sort || "manual";
  }

  _viewTitle() {
    if (this._view.type === "triggers") return this.t("triggers");
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
      if (this._view.type === "triggers") this._view = { type: "smart", key: "my_day" };
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

    let html = `<div class="search"><ha-icon icon="mdi:magnify"></ha-icon><input class="search-input" type="search" placeholder="${esc(this.t("search"))}" autocomplete="off"></div><div class="nav-section">${SMART_VIEWS.map((v) => item({ type: "smart", key: v.key }, v.icon, this.t(v.key))).join("")}</div><div class="divider"></div><div class="nav-section lists">`;
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
        <span class="count">${this._triggers?.length || ""}</span></button>`;
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
    if (this._view.type === "triggers") {
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
        ? `<span class="subtitle">${esc(this._today.toLocaleDateString(this._lang === "de" ? "de-DE" : "en-GB", { weekday: "long", day: "numeric", month: "long" }))}</span>`
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
        case "due": return parsed.due_label + (parsed.due && parsed.due.granularity !== "day" ? ` (${periodRange(parsed.due, this._lang)})` : "");
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
          <div class="stepper-label"><b>${esc(periodLabel(task.due, lang, this._today))}</b><span>${esc(periodRange(task.due, lang))}</span></div>
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
        <span class="muted">${esc(this.t("created"))} ${esc(new Date(task.created).toLocaleDateString(lang === "de" ? "de-DE" : "en-GB"))}</span>
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
      const time = new Date(status.last_check).toLocaleTimeString(this._lang === "de" ? "de-DE" : "en-GB", { hour: "2-digit", minute: "2-digit" });
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
          : { type: "smart", key: target.dataset.view };
        if (this._view.type === "triggers") this._subscribeTriggers();
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
    --thask-prio-1: #43a047;
    --thask-prio-2: #fdd835;
    --thask-prio-3: #e53935;
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
  .search { display: flex; align-items: center; gap: 8px; margin: 8px 12px; padding: 0 10px; border-radius: 8px; background: rgba(127, 127, 127, 0.12); color: var(--thask-muted); }
  .search-input { flex: 1; min-width: 0; border: none; background: none; outline: none; padding: 8px 0; font-size: 14px; color: var(--thask-text); }
  .nav-section { display: flex; flex-direction: column; }
  .nav-section.lists { flex: 1; }
  .nav-item { display: flex; align-items: center; gap: 12px; padding: 10px 16px; text-align: left; border-left: 3px solid transparent; }
  .nav-item:hover { background: rgba(127, 127, 127, 0.1); }
  .nav-item.active { background: rgba(127, 127, 127, 0.16); border-left-color: var(--thask-accent); font-weight: 500; }
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
  .menu-item:hover { background: rgba(127, 127, 127, 0.14); }
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
  .icon-button:hover { background: rgba(127, 127, 127, 0.14); }
  .icon-button.small { width: 28px; height: 28px; }
  .icon-button.danger:hover { color: var(--thask-danger); }
  .quick-add { margin: 0 24px 8px; background: var(--thask-surface); border-radius: 8px; box-shadow: var(--ha-card-box-shadow, 0 1px 2px rgba(0,0,0,0.15)); }
  .quick-row { display: flex; align-items: center; gap: 12px; padding: 0 16px; color: var(--thask-accent); }
  .quick-input { flex: 1; min-width: 0; border: none; background: none; outline: none; padding: 14px 0; font-size: 15px; color: var(--thask-text); }
  .chips { display: flex; flex-wrap: wrap; gap: 6px; padding: 0 16px; }
  .chips:not(:empty) { padding-bottom: 10px; }
  .chip { display: inline-flex; align-items: center; gap: 4px; border-radius: 14px; padding: 4px 10px; font-size: 12px; background: rgba(127, 127, 127, 0.12); }
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
  .triggers-view .quick-add { display: none; }
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
  .toast { position: fixed; left: 50%; bottom: 24px; transform: translateX(-50%); background: #323232; color: #fff; padding: 10px 16px; border-radius: 6px; max-width: 90vw; z-index: 10; }

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
