// tHAsk panel: task lists with fuzzy due dates, served by the thask integration.
// Plain web component without build step; talks to the integration over the HA WebSocket API.

const STRINGS = {
  de: {
    my_day: "Mein Tag", important: "Wichtig", planned: "Geplant", this_week: "Diese Woche",
    lists: "Listen", add_task: "Aufgabe hinzufügen", quick_hint: "z. B. „Reifen wechseln nächsten Monat !“",
    new_list: "Neue Liste", completed: "Erledigt", steps: "Schritte", add_step: "Nächster Schritt",
    add_to_my_day: "Zu „Mein Tag“ hinzufügen", remove_from_my_day: "Aus „Mein Tag“ entfernen",
    due: "Fällig", none: "Keine", day: "Tag", week: "Woche", month: "Monat", quarter: "Quartal", year: "Jahr",
    time: "Uhrzeit", reminder: "Erinnerung", recurrence: "Wiederholung", every: "alle", notes: "Notizen",
    notes_hint: "Notiz hinzufügen", list: "Liste", delete: "Löschen", rename: "Umbenennen", group: "Gruppe",
    delete_task_confirm: "Aufgabe „{0}“ löschen?", delete_list_confirm: "Liste „{0}“ mit allen Aufgaben löschen?",
    group_prompt: "Gruppe für diese Liste (leer = keine):", created: "Erstellt", overdue: "Überfällig",
    search: "Suche", search_results: "Suchergebnisse", later: "Später", this_month: "Diesen Monat", empty: "Keine Aufgaben", today: "Heute", tomorrow: "Morgen",
    next_week: "Nächste Woche", next_month: "Nächsten Monat", steps_of: "{0} von {1}",
    rec_day: "Täglich", rec_week: "Wöchentlich", rec_month: "Monatlich", rec_quarter: "Vierteljährlich",
    rec_year: "Jährlich", rec_every: "Alle {0} {1}", units_day: "Tage", units_week: "Wochen",
    units_month: "Monate", units_quarter: "Quartale", units_year: "Jahre", close: "Schließen",
    back: "Zurück", loading: "Lade …", not_loaded: "tHAsk ist nicht geladen. Ist die Integration eingerichtet?",
    kind_due: "Fällig", kind_time: "Uhrzeit", kind_recurrence: "Wiederholung", kind_important: "Wichtig",
    ignore: "Nicht erkennen", mark_important: "Wichtig", complete: "Erledigt", week_short: "KW",
    sort: "Sortieren", sort_manual: "Manuell", sort_important: "Wichtigkeit", sort_due: "Fälligkeit",
    sort_title: "Alphabetisch", sort_created: "Erstellungsdatum", clear_completed: "Erledigte löschen",
    clear_confirm: "{0} erledigte Aufgabe(n) aus „{1}“ endgültig löschen?", cleared: "{0} erledigte Aufgabe(n) gelöscht",
  },
  en: {
    my_day: "My Day", important: "Important", planned: "Planned", this_week: "This week",
    lists: "Lists", add_task: "Add a task", quick_hint: "e.g. “Change tyres next month !”",
    new_list: "New list", completed: "Completed", steps: "Steps", add_step: "Next step",
    add_to_my_day: "Add to My Day", remove_from_my_day: "Remove from My Day",
    due: "Due", none: "None", day: "Day", week: "Week", month: "Month", quarter: "Quarter", year: "Year",
    time: "Time", reminder: "Reminder", recurrence: "Repeat", every: "every", notes: "Notes",
    notes_hint: "Add a note", list: "List", delete: "Delete", rename: "Rename", group: "Group",
    delete_task_confirm: "Delete task “{0}”?", delete_list_confirm: "Delete list “{0}” with all its tasks?",
    group_prompt: "Group for this list (empty = none):", created: "Created", overdue: "Overdue",
    search: "Search", search_results: "Search results", later: "Later", this_month: "This month", empty: "No tasks", today: "Today", tomorrow: "Tomorrow",
    next_week: "Next week", next_month: "Next month", steps_of: "{0} of {1}",
    rec_day: "Daily", rec_week: "Weekly", rec_month: "Monthly", rec_quarter: "Quarterly", rec_year: "Yearly",
    rec_every: "Every {0} {1}", units_day: "days", units_week: "weeks", units_month: "months",
    units_quarter: "quarters", units_year: "years", close: "Close", back: "Back", loading: "Loading …",
    not_loaded: "tHAsk is not loaded. Is the integration set up?",
    kind_due: "Due", kind_time: "Time", kind_recurrence: "Repeat", kind_important: "Important",
    ignore: "Don't detect", mark_important: "Important", complete: "Completed", week_short: "Week",
    sort: "Sort", sort_manual: "Manual", sort_important: "Importance", sort_due: "Due date",
    sort_title: "Alphabetical", sort_created: "Creation date", clear_completed: "Clear completed",
    clear_confirm: "Permanently delete {0} completed task(s) from “{1}”?", cleared: "{0} completed task(s) deleted",
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
const TASK_SORTS = ["manual", "important", "due", "title", "created"];
// The integration appends its version to the module URL (cache busting), so the panel can show it.
const VERSION = new URL(import.meta.url).searchParams.get("v") || "";

const SMART_VIEWS = [
  { key: "my_day", icon: "mdi:white-balance-sunny" },
  { key: "important", icon: "mdi:star-outline" },
  { key: "planned", icon: "mdi:calendar-month-outline" },
  { key: "this_week", icon: "mdi:calendar-week" },
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
    important: (a, b) => b.important - a.important,
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
    this._pane = "list";
    this._loaded = false;
    this._error = null;
    this._parse = null;
    this._disabledKinds = new Set();
    this._parseSeq = 0;
    this._dragTask = null;
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
        return task.my_day === this._todayISO;
      case "important":
        return task.important;
      case "planned":
        return !!task.due;
      case "this_week":
        if (!this._dueBy(task, this._weekEnd())) return false;
        return !task.completed || this._completedSince(task, periodStart("week", this._today));
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
    } else if (view.key === "my_day" && !searching) {
      sorted = sortTasks(tasks, "manual");
    } else {
      sorted = tasks.sort((a, b) => dueKey(a).localeCompare(dueKey(b)) || b.important - a.important || a.position - b.position);
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
      this._selectedTask = null;
      this._pane = "list";
      this._render();
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
    root.querySelector(".app").dataset.pane = this._pane;
    root.querySelector(".app").classList.toggle("has-detail", !!this._selectedTask);
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
    html += `<div class="drop-end" data-drop="list-end"></div></div><div class="new-list"><ha-icon icon="mdi:plus"></ha-icon><input class="new-list-input" placeholder="${esc(this.t("new_list"))}"></div>${VERSION ? `<div class="version">tHAsk v${esc(VERSION)}</div>` : ""}`;
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
    if (this._view.type === "list" && !this._search.trim()) {
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
      root.querySelector(".view-actions").innerHTML = "";
    }
  }

  _renderTasks() {
    const { open, done } = this._viewTasks();
    const searching = !!this._search.trim();
    const reorderable = !searching && this._view.type === "list" && this._listSort(this._view.id) === "manual";
    let html = "";
    if (!searching && this._view.type === "smart" && this._view.key === "planned") {
      const weekEnd = this._weekEnd();
      const monthEnd = periodEnd("month", periodStart("month", this._today));
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
    if (task.my_day === this._todayISO && !(this._view.type === "smart" && this._view.key === "my_day")) {
      meta.push(`<span class="meta"><ha-icon icon="mdi:white-balance-sunny"></ha-icon>${esc(this.t("my_day"))}</span>`);
    }
    if (task.steps.length) {
      const doneSteps = task.steps.filter((s) => s.completed).length;
      meta.push(`<span class="meta">${esc(this.t("steps_of", doneSteps, task.steps.length))}</span>`);
    }
    if (task.due) meta.push(this._dueChip(task));
    if (task.recurrence) meta.push(`<span class="meta"><ha-icon icon="mdi:repeat"></ha-icon></span>`);
    if (task.reminder && !task.completed) meta.push(`<span class="meta"><ha-icon icon="mdi:bell-outline"></ha-icon></span>`);
    if (task.notes) meta.push(`<span class="meta"><ha-icon icon="mdi:note-text-outline"></ha-icon></span>`);
    return `
      <div class="task ${task.completed ? "completed" : ""} ${task.id === this._selectedTask ? "selected" : ""}"
        data-action="select-task" data-task-id="${esc(task.id)}" ${draggable ? `draggable="true" data-drop="task"` : ""}>
        <button class="check" data-action="toggle-complete" data-task-id="${esc(task.id)}" title="${esc(this.t("complete"))}">
          <ha-icon icon="mdi:check"></ha-icon></button>
        <div class="task-body">
          <div class="task-title">${esc(task.title)}</div>
          ${meta.length ? `<div class="task-meta">${meta.join('<span class="dot">·</span>')}</div>` : ""}
        </div>
        <button class="star ${task.important ? "on" : ""}" data-action="toggle-important" data-task-id="${esc(task.id)}" title="${esc(this.t("mark_important"))}">
          <ha-icon icon="${task.important ? "mdi:star" : "mdi:star-outline"}"></ha-icon></button>
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
    if (recurrence.interval > 1) return this.t("rec_every", recurrence.interval, this.t(`units_${recurrence.unit}`));
    return this.t(`rec_${recurrence.unit}`);
  }

  _renderDetail() {
    const detail = this.shadowRoot.querySelector(".detail");
    this._detailFor = this._selectedTask;
    const task = this._tasks.get(this._selectedTask);
    if (!task) {
      detail.innerHTML = "";
      return;
    }
    const lang = this._lang;
    const inMyDay = task.my_day === this._todayISO;
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
          <button class="star ${task.important ? "on" : ""}" data-action="toggle-important" data-task-id="${esc(task.id)}">
            <ha-icon icon="${task.important ? "mdi:star" : "mdi:star-outline"}"></ha-icon></button>
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
      <button class="card action ${inMyDay ? "on" : ""}" data-action="toggle-my-day">
        <ha-icon icon="mdi:white-balance-sunny"></ha-icon>${esc(this.t(inMyDay ? "remove_from_my_day" : "add_to_my_day"))}</button>
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
    const data = { list_id: listId, title: parsed.title, important: !!parsed.important };
    if (parsed.due) data.due = parsed.due;
    if (parsed.due_time) data.due_time = parsed.due_time;
    if (parsed.recurrence) data.recurrence = parsed.recurrence;
    if (this._view.type === "smart") {
      if (this._view.key === "my_day") data.my_day = this._todayISO;
      if (this._view.key === "important") data.important = true;
      if (this._view.key === "this_week" && !data.due) data.due = makePeriod("week", this._today);
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

  // ---- Events -------------------------------------------------------------------------------

  _selectTask(taskId) {
    this._selectedTask = taskId;
    if (this._narrow) this._pane = taskId ? "detail" : "list";
    this._render();
  }

  _onClick(ev) {
    const target = ev.target.closest("[data-action]");
    if (!target) return;
    const action = target.dataset.action;
    const task = this._tasks.get(target.dataset.taskId || this._selectedTask);
    switch (action) {
      case "view":
        this._view = target.dataset.viewType === "list"
          ? { type: "list", id: target.dataset.view }
          : { type: "smart", key: target.dataset.view };
        this._selectedTask = null;
        this._showCompleted = false;
        this._search = "";
        this._pane = "list";
        this._render();
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
      case "toggle-important":
        ev.stopPropagation();
        this._updateTask(task, { important: !task.important });
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
      case "toggle-my-day":
        this._updateTask(task, { my_day: task.my_day === this._todayISO ? null : this._todayISO });
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
      case "list-group": {
        const list = this._lists.find((l) => l.id === this._view.id);
        const group = list && prompt(this.t("group_prompt"), list.group || "");
        if (group !== null && group !== undefined) this._call("thask/list/update", { list_id: list.id, group: group.trim() || null });
        break;
      }
    }
  }

  _onChange(ev) {
    const field = ev.target.dataset?.field;
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
  .main { display: flex; flex-direction: column; min-width: 0; overflow: hidden; }
  .toolbar { display: flex; align-items: center; gap: 8px; padding: 12px 24px 8px; min-height: 64px; }
  .toolbar .menu-slot, .toolbar .back { display: none; }
  .view-title { flex: 1; margin: 0; font-size: 24px; font-weight: 500; color: var(--thask-accent); display: flex; flex-direction: column; min-width: 0; }
  .view-title .subtitle { font-size: 13px; font-weight: 400; color: var(--thask-muted); }
  .list-name { font-size: 24px; font-weight: 500; color: var(--thask-accent); border: none; background: none; outline: none; padding: 0; width: 100%; border-bottom: 1px solid transparent; }
  .list-name:focus { border-bottom-color: var(--thask-accent); }
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
  .star { color: var(--thask-muted); display: inline-flex; flex: none; }
  .star.on { color: var(--thask-accent); }
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

customElements.define("thask-panel", ThaskPanel);
