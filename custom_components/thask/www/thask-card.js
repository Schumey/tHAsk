// tHAsk dashboard card: one view (Today, This week, a list …) with fuzzy due dates, quick add and steps.
// Loaded on every dashboard by the integration; use it as `type: custom:thask-card`.

const VERSION = new URL(import.meta.url).searchParams.get("v") || "";
// The sidebar entry uses the icon `thask:logo`; this module is loaded on every page, so it registers it.
await import(`./thask-icons.js?v=${VERSION}`);
const {
  parseISO, periodStart, periodEnd, periodEndOf, periodStatus, periodLabel, makePeriod, sortTasks, esc,
  isOverdue, matchesSmart, sortByDue, splitDone, language,
} = await import(`./thask-common.js?v=${VERSION}`);

const STRINGS = {
  de: {
    my_day: "Heute", overdue: "Überfällig", important: "Wichtig", planned: "Geplant", this_week: "Diese Woche",
    this_month: "Diesen Monat", later: "Später", today: "Heute", tomorrow: "Morgen", empty: "Keine Aufgaben",
    completed: "Erledigt", add_task: "Aufgabe hinzufügen", more: "{0} weitere", loading: "Lade …",
    not_loaded: "tHAsk ist nicht geladen", unknown_list: "Unbekannte Liste", open_panel: "In tHAsk öffnen",
    complete: "Erledigt", add_step: "Schritt hinzufügen",
    // editor
    views: "Ansichten (mehrere möglich)", tabs: "Als Reiter statt untereinander",
    hide_duplicates: "Jede Aufgabe nur einmal zeigen", title: "Titel (leer = Name der Ansicht)", show_entry: "Schnelleingabe",
    show_completed: "Erledigte zeigen", show_list: "Liste bei jeder Aufgabe zeigen",
    min_priority: "Mindestens Priorität", max_items: "Höchstens so viele Aufgaben (0 = alle)", compact: "Kompakt",
    priority_0: "Alle", priority_1: "Niedrig", priority_2: "Mittel", priority_3: "Hoch",
    card_description: "Eine tHAsk-Ansicht oder -Liste mit Zeiträumen, Schnelleingabe und Schritten.",
  },
  en: {
    my_day: "Today", overdue: "Overdue", important: "Important", planned: "Planned", this_week: "This week",
    this_month: "This month", later: "Later", today: "Today", tomorrow: "Tomorrow", empty: "No tasks",
    completed: "Completed", add_task: "Add a task", more: "{0} more", loading: "Loading …",
    not_loaded: "tHAsk is not loaded", unknown_list: "Unknown list", open_panel: "Open in tHAsk",
    complete: "Completed", add_step: "Add a step",
    views: "Views (one or more)", tabs: "As tabs instead of one below the other",
    hide_duplicates: "Show each task only once", title: "Title (empty = name of the view)", show_entry: "Quick add",
    show_completed: "Show completed", show_list: "Show the list of each task",
    min_priority: "At least priority", max_items: "At most this many tasks (0 = all)", compact: "Compact",
    priority_0: "All", priority_1: "Low", priority_2: "Medium", priority_3: "High",
    card_description: "A tHAsk view or list with fuzzy due dates, quick add and steps.",
  },
  nl: {
    my_day: "Vandaag", overdue: "Te laat", important: "Belangrijk", planned: "Gepland", this_week: "Deze week",
    this_month: "Deze maand", later: "Later", today: "Vandaag", tomorrow: "Morgen", empty: "Geen taken",
    completed: "Voltooid", add_task: "Taak toevoegen", more: "nog {0}", loading: "Laden …",
    not_loaded: "tHAsk is niet geladen", unknown_list: "Onbekende lijst", open_panel: "Openen in tHAsk",
    complete: "Voltooid", add_step: "Stap toevoegen",
    views: "Weergaven (een of meer)", tabs: "Als tabbladen in plaats van onder elkaar",
    hide_duplicates: "Elke taak maar één keer tonen", title: "Titel (leeg = naam van de weergave)", show_entry: "Snel toevoegen",
    show_completed: "Voltooide tonen", show_list: "Lijst bij elke taak tonen",
    min_priority: "Minstens prioriteit", max_items: "Hoogstens zoveel taken (0 = alle)", compact: "Compact",
    priority_0: "Alle", priority_1: "Laag", priority_2: "Gemiddeld", priority_3: "Hoog",
    card_description: "Een tHAsk-weergave of -lijst met vage vervaldatums, snel toevoegen en stappen.",
  },
  fr: {
    my_day: "Aujourd'hui", overdue: "En retard", important: "Important", planned: "Planifié", this_week: "Cette semaine",
    this_month: "Ce mois-ci", later: "Plus tard", today: "Aujourd'hui", tomorrow: "Demain", empty: "Aucune tâche",
    completed: "Terminées", add_task: "Ajouter une tâche", more: "{0} de plus", loading: "Chargement …",
    not_loaded: "tHAsk n'est pas chargé", unknown_list: "Liste inconnue", open_panel: "Ouvrir dans tHAsk",
    complete: "Terminée", add_step: "Ajouter une étape",
    views: "Vues (une ou plusieurs)", tabs: "En onglets plutôt que l'une sous l'autre",
    hide_duplicates: "Afficher chaque tâche une seule fois", title: "Titre (vide = nom de la vue)", show_entry: "Saisie rapide",
    show_completed: "Afficher les terminées", show_list: "Afficher la liste de chaque tâche",
    min_priority: "Priorité minimale", max_items: "Au plus ce nombre de tâches (0 = toutes)", compact: "Compact",
    priority_0: "Toutes", priority_1: "Basse", priority_2: "Moyenne", priority_3: "Haute",
    card_description: "Une vue ou une liste tHAsk avec échéances souples, saisie rapide et étapes.",
  },
  es: {
    my_day: "Hoy", overdue: "Vencidas", important: "Importante", planned: "Planificado", this_week: "Esta semana",
    this_month: "Este mes", later: "Más tarde", today: "Hoy", tomorrow: "Mañana", empty: "No hay tareas",
    completed: "Completadas", add_task: "Añadir una tarea", more: "{0} más", loading: "Cargando …",
    not_loaded: "tHAsk no está cargado", unknown_list: "Lista desconocida", open_panel: "Abrir en tHAsk",
    complete: "Completada", add_step: "Añadir un paso",
    views: "Vistas (una o varias)", tabs: "En pestañas en lugar de una debajo de otra",
    hide_duplicates: "Mostrar cada tarea solo una vez", title: "Título (vacío = nombre de la vista)", show_entry: "Entrada rápida",
    show_completed: "Mostrar completadas", show_list: "Mostrar la lista de cada tarea",
    min_priority: "Prioridad mínima", max_items: "Como máximo tantas tareas (0 = todas)", compact: "Compacto",
    priority_0: "Todas", priority_1: "Baja", priority_2: "Media", priority_3: "Alta",
    card_description: "Una vista o lista de tHAsk con vencimientos flexibles, entrada rápida y pasos.",
  },
};

const SMART_VIEWS = ["my_day", "overdue", "important", "planned", "this_week", "this_month"];
const VIEW_ICONS = {
  my_day: "mdi:calendar-today", overdue: "mdi:calendar-alert", important: "mdi:flag-outline",
  planned: "mdi:calendar-month-outline", this_week: "mdi:calendar-week", this_month: "mdi:calendar-month",
};
const DEFAULTS = {
  view: "my_day", tabs: false, hide_duplicates: true, show_entry: true, show_completed: false, show_list: true,
  min_priority: 0, max_items: 0, compact: false,
};

const parseView = (id) => (id.startsWith("list:") ? { id, type: "list", listId: id.slice(5) } : { id, type: "smart", key: id });
// Shared with the panel: whether the "Overdue" section in Today is folded (per device).
const OVERDUE_COLLAPSED_KEY = "thask.overdueCollapsed";
const RANGE_STORAGE_KEY = "thask.importantRange";

const lang = (hass) => language(hass?.language);
const translate = (hass, key, ...args) => {
  const text = STRINGS[lang(hass)][key] ?? STRINGS.en[key] ?? key;
  return args.reduce((s, a, i) => s.replace(`{${i}}`, a), text);
};
const readStorage = (key) => {
  try {
    return localStorage.getItem(key);
  } catch {
    return null;
  }
};

class ThaskCard extends HTMLElement {
  constructor() {
    super();
    this.attachShadow({ mode: "open" });
    this._loaded = false;
    this._error = null;
    this._lists = [];
    this._tasks = new Map();
    this._today = periodStart("day", new Date());
    this._overdueMode = "section";
    this._options = {};
    this._expanded = null; // id of the task whose steps and notes are shown
    this._showDone = new Set(); // views whose completed tasks are unfolded
    this._tab = 0;
    this._overdueCollapsed = readStorage(OVERDUE_COLLAPSED_KEY) === "1";
    this._parseTimer = null;
    this._parsed = null;
    // Like the panel: a hass set before the element was defined would hide the setter.
    if (Object.prototype.hasOwnProperty.call(this, "hass")) {
      const hass = this.hass;
      delete this.hass;
      this.hass = hass;
    }
  }

  static getConfigElement() {
    return document.createElement("thask-card-editor");
  }

  static getStubConfig() {
    return { view: "my_day" };
  }

  setConfig(config) {
    if (!config || typeof config !== "object") throw new Error("Invalid configuration");
    this._config = { ...DEFAULTS, ...config };
    this._render();
  }

  set hass(hass) {
    const first = !this._hass;
    this._hass = hass;
    if (first) {
      this._render();
      this._subscribe();
    }
  }

  connectedCallback() {
    this._subscribe();
  }

  disconnectedCallback() {
    // Unsubscribe while the dashboard isn't shown; the next connect gets a fresh snapshot.
    this._unsub?.then((unsub) => unsub()).catch(() => {});
    this._unsub = null;
  }

  getCardSize() {
    return 2 + Math.min(this._views().reduce((n, view) => n + this._visible(view).open.length, 0), 8);
  }

  getGridOptions() {
    return { columns: 6, min_columns: 4, rows: "auto" };
  }

  t(key, ...args) {
    return translate(this._hass, key, ...args);
  }

  // ---- Data -------------------------------------------------------------------------------

  _subscribe() {
    if (this._unsub || !this._hass || !this.isConnected) return;
    this._unsub = this._hass.connection.subscribeMessage((event) => this._onEvent(event), { type: "thask/subscribe" });
    this._unsub.catch((err) => {
      this._unsub = null;
      this._error = err?.message || this.t("not_loaded");
      this._render();
    });
  }

  _onEvent(event) {
    switch (event.type) {
      case "snapshot":
        this._today = parseISO(event.today);
        this._lists = event.lists;
        this._tasks = new Map(event.tasks.map((task) => [task.id, task]));
        this._overdueMode = event.options?.overdue_in_today || "section";
        this._options = event.options || {};
        this._loaded = true;
        this._error = null;
        break;
      case "day_changed":
        this._today = parseISO(event.today);
        break;
      case "options":
        this._overdueMode = event.overdue_in_today || "section";
        this._options = event;
        break;
      case "change":
        if (event.kind === "task") {
          if (event.action === "removed") this._tasks.delete(event.id);
          else this._tasks.set(event.id, event.item);
        } else {
          this._lists = event.action === "removed"
            ? this._lists.filter((l) => l.id !== event.id)
            : [...this._lists.filter((l) => l.id !== event.id), event.item].sort((a, b) => a.position - b.position);
        }
        break;
    }
    this._render();
  }

  async _call(type, data = {}) {
    try {
      return await this._hass.callWS({ type, ...data });
    } catch (err) {
      this._error = err?.message || String(err);
      this._render();
      setTimeout(() => {
        this._error = null;
        this._render();
      }, 4000);
      throw err;
    }
  }

  _update(task, patch) {
    // Show the change at once; the server's change event follows.
    this._tasks.set(task.id, { ...task, ...patch });
    this._render();
    return this._call("thask/task/update", { task_id: task.id, ...patch }).catch(() => {});
  }

  // ---- Derived ----------------------------------------------------------------------------

  // The views of the card: `views` (several, below each other or as tabs) or the single `view`.
  _views() {
    const ids = Array.isArray(this._config.views) && this._config.views.length ? this._config.views : [this._config.view || "my_day"];
    return ids.map(parseView);
  }

  _tabs() {
    return !!this._config.tabs && this._views().length > 1;
  }

  // The view new tasks go to: the shown tab, or the first view.
  _active() {
    const views = this._views();
    return this._tabs() ? views[Math.min(this._tab, views.length - 1)] : views[0];
  }

  _viewName(view) {
    if (view.type === "list") return this._lists.find((l) => l.id === view.listId)?.name ?? this.t("unknown_list");
    return this.t(view.key);
  }

  _viewIcon(view) {
    return view.type === "list" ? "mdi:format-list-checks" : VIEW_ICONS[view.key] || "mdi:checkbox-marked-circle-outline";
  }

  _visible(view, skip = null) {
    if (!this._loaded) return { open: [], done: [] };
    const ctx = {
      today: this._today, overdueMode: this._overdueMode, importantRange: readStorage(RANGE_STORAGE_KEY) || "all",
      separateWeek: !!this._options.separate_week, separateMonth: !!this._options.separate_month,
      rollingWeek: this._options.week_mode === "rolling",
    };
    const minPriority = Number(this._config.min_priority) || 0;
    const tasks = [...this._tasks.values()].filter((task) =>
      (view.type === "list" ? task.list_id === view.listId : matchesSmart(task, view.key, ctx))
      && task.priority >= minPriority && !skip?.has(task.id)
    );
    if (view.type === "list") {
      const sort = this._lists.find((l) => l.id === view.listId)?.sort || "manual";
      return splitDone(sortTasks(tasks, sort));
    }
    return splitDone(sortByDue(tasks));
  }

  _listId() {
    const view = this._active();
    return view.type === "list" ? view.listId : this._lists[0]?.id;
  }

  // ---- Rendering --------------------------------------------------------------------------

  _render() {
    // Without hass the language is unknown; Home Assistant sets it right after the config.
    if (!this._config || !this._hass) return;
    if (!this.shadowRoot.querySelector("ha-card")) this._buildSkeleton();
    const root = this.shadowRoot;
    const card = root.querySelector("ha-card");
    card.classList.toggle("compact", !!this._config.compact);
    const views = this._views();
    const header = root.querySelector(".header");
    let body;
    if (!this._loaded) {
      body = `<div class="empty">${esc(this.t("loading"))}</div>`;
    } else if (views.length === 1) {
      body = this._renderTasks(views[0], this._visible(views[0]));
    } else if (this._tabs()) {
      const active = this._active();
      body = this._renderTasks(active, this._visible(active));
    } else {
      // One below the other; with hide_duplicates a task only shows in the first view it belongs to.
      const seen = this._config.hide_duplicates ? new Set() : null;
      body = views.map((view) => {
        const visible = this._visible(view, seen);
        visible.open.forEach((task) => seen?.add(task.id));
        return `<div class="view-head"><ha-icon icon="${this._viewIcon(view)}"></ha-icon><span class="name">${esc(this._viewName(view))}</span>
          <span class="count">${visible.open.length || ""}</span></div>${this._renderTasks(view, visible)}`;
      }).join("");
    }
    if (this._tabs()) {
      header.innerHTML = `<div class="tabs">${views.map((view, i) => `
        <button class="tab ${i === Math.min(this._tab, views.length - 1) ? "on" : ""}" data-action="tab" data-tab="${i}" title="${esc(this._viewName(view))}">
          <ha-icon icon="${this._viewIcon(view)}"></ha-icon><span class="name">${esc(this._viewName(view))}</span>
          <span class="count">${this._visible(view).open.length || ""}</span></button>`).join("")}</div>`;
      header.hidden = false;
    } else if (views.length === 1 || this._config.title) {
      const view = views[0];
      const count = views.length === 1 && this._loaded ? this._visible(view).open.length : 0;
      header.innerHTML = `<button class="title-row" data-action="open-panel" title="${esc(this.t("open_panel"))}">
        <ha-icon icon="${views.length === 1 ? this._viewIcon(view) : "mdi:checkbox-marked-circle-outline"}"></ha-icon>
        <span class="name">${esc(this._config.title || this._viewName(view))}</span><span class="count">${count || ""}</span></button>`;
      header.hidden = false;
    } else {
      header.hidden = true; // the views bring their own headings
    }
    root.querySelector(".entry").hidden = !this._config.show_entry || !this._loaded;
    root.querySelector(".quick").placeholder = views.length > 1 && !this._tabs()
      ? `${this.t("add_task")} (${this._viewName(views[0])})` : this.t("add_task");
    root.querySelector(".error").textContent = this._error || "";
    root.querySelector(".error").hidden = !this._error;
    root.querySelector(".tasks").innerHTML = body;
  }

  _buildSkeleton() {
    this.shadowRoot.innerHTML = `<style>${STYLE}</style>
      <ha-card>
        <div class="header"></div>
        <div class="entry">
          <ha-icon icon="mdi:plus"></ha-icon>
          <input class="quick" placeholder="${esc(this.t("add_task"))}" autocomplete="off">
          <span class="hint"></span>
        </div>
        <div class="error" hidden></div>
        <div class="tasks"></div>
      </ha-card>`;
    const input = this.shadowRoot.querySelector(".quick");
    input.addEventListener("keydown", (ev) => {
      if (ev.key === "Enter") this._quickAdd();
      ev.stopPropagation(); // keep dashboard shortcuts out of the input
    });
    input.addEventListener("input", () => {
      clearTimeout(this._parseTimer);
      this._parseTimer = setTimeout(() => this._runParse(), 150);
    });
    this.shadowRoot.addEventListener("click", (ev) => this._onClick(ev));
    this.shadowRoot.addEventListener("keydown", (ev) => {
      if (ev.key === "Enter" && ev.target.classList?.contains("step-input")) this._addStep(ev.target);
    });
  }

  _renderTasks(view, { open, done }) {
    let html = "";
    const max = Number(this._config.max_items) || 0;
    const shown = max ? open.slice(0, max) : open;
    const rest = open.length - shown.length;
    if (view.type === "smart" && view.key === "planned") {
      const weekEnd = periodEnd("week", periodStart("week", this._today));
      const monthEnd = periodEnd("month", periodStart("month", this._today));
      const groups = { overdue: [], this_week: [], this_month: [], later: [] };
      for (const task of shown) {
        const end = periodEndOf(task.due);
        groups[end < this._today ? "overdue" : end <= weekEnd ? "this_week" : end <= monthEnd ? "this_month" : "later"].push(task);
      }
      for (const [key, tasks] of Object.entries(groups)) {
        if (tasks.length) html += `<div class="section ${key}">${esc(this.t(key))}</div>${tasks.map((t) => this._row(t, view)).join("")}`;
      }
    } else if (view.type === "smart" && view.key === "my_day" && this._overdueMode === "section" && shown.some((t) => isOverdue(t, this._today))) {
      const overdue = shown.filter((t) => isOverdue(t, this._today));
      const today = shown.filter((t) => !isOverdue(t, this._today));
      html += `<button class="section overdue toggle" data-action="toggle-overdue">
        <ha-icon icon="${this._overdueCollapsed ? "mdi:chevron-right" : "mdi:chevron-down"}"></ha-icon>${esc(this.t("overdue"))} <span>${overdue.length}</span></button>`;
      if (!this._overdueCollapsed) html += overdue.map((t) => this._row(t, view)).join("");
      if (today.length) html += `<div class="section">${esc(this.t("today"))}</div>${today.map((t) => this._row(t, view)).join("")}`;
    } else {
      html += shown.map((t) => this._row(t, view)).join("");
    }
    if (rest > 0) html += `<button class="more" data-action="open-panel">${esc(this.t("more", rest))}</button>`;
    if (!open.length && !(this._config.show_completed && done.length)) html += `<div class="empty">${esc(this.t("empty"))}</div>`;
    if (this._config.show_completed && done.length) {
      const unfolded = this._showDone.has(view.id);
      html += `<button class="section toggle" data-action="toggle-done" data-view="${esc(view.id)}">
        <ha-icon icon="${unfolded ? "mdi:chevron-down" : "mdi:chevron-right"}"></ha-icon>${esc(this.t("completed"))} <span>${done.length}</span></button>`;
      if (unfolded) html += done.map((t) => this._row(t, view)).join("");
    }
    return html;
  }

  _dueChip(task) {
    const status = task.completed ? "" : periodStatus(task.due, this._today);
    let label = periodLabel(task.due, lang(this._hass), this._today);
    if (task.due.granularity === "day") {
      const days = Math.round((parseISO(task.due.start) - this._today) / 864e5);
      if (days === 0) label = this.t("today");
      else if (days === 1) label = this.t("tomorrow");
      if (task.due_time) label += `, ${task.due_time}`;
    }
    const icon = task.due.granularity === "day" ? "mdi:calendar" : "mdi:calendar-range";
    return `<span class="meta due ${status}"><ha-icon icon="${icon}"></ha-icon>${esc(label)}</span>`;
  }

  _row(task, view) {
    const meta = [];
    if (view.type === "smart" && this._config.show_list) {
      const list = this._lists.find((l) => l.id === task.list_id);
      if (list) meta.push(`<span class="meta">${esc(list.name)}</span>`);
    }
    if (task.due) meta.push(this._dueChip(task));
    if (task.steps?.length) meta.push(`<span class="meta"><ha-icon icon="mdi:format-list-bulleted"></ha-icon>${task.steps.filter((s) => s.completed).length}/${task.steps.length}</span>`);
    if (task.recurrence) meta.push(`<span class="meta"><ha-icon icon="mdi:repeat"></ha-icon></span>`);
    if (task.notes) meta.push(`<span class="meta"><ha-icon icon="mdi:note-text-outline"></ha-icon></span>`);
    const expanded = this._expanded === task.id;
    return `
      <div class="task prio-${task.priority || 0} ${task.completed ? "completed" : ""} ${expanded ? "expanded" : ""}" data-action="expand" data-id="${esc(task.id)}">
        <button class="check" data-action="complete" data-id="${esc(task.id)}" title="${esc(this.t("complete"))}"><ha-icon icon="mdi:check"></ha-icon></button>
        <div class="body">
          <div class="title">${esc(task.title)}</div>
          ${meta.length && !this._config.compact ? `<div class="metas">${meta.join("")}</div>` : ""}
          ${expanded ? this._details(task) : ""}
        </div>
      </div>`;
  }

  _details(task) {
    const steps = (task.steps || []).map((step) => `
      <div class="step ${step.completed ? "completed" : ""}">
        <button class="check small" data-action="step" data-id="${esc(task.id)}" data-step="${esc(step.id)}"><ha-icon icon="mdi:check"></ha-icon></button>
        <span>${esc(step.title)}</span>
      </div>`).join("");
    return `<div class="details">
      ${steps}
      <input class="step-input" data-id="${esc(task.id)}" placeholder="${esc(this.t("add_step"))}" autocomplete="off">
      ${task.notes ? `<div class="notes">${esc(task.notes)}</div>` : ""}
    </div>`;
  }

  // ---- Actions ----------------------------------------------------------------------------

  _onClick(ev) {
    const target = ev.target.closest("[data-action]");
    if (!target || target.classList.contains("step-input")) return;
    const task = this._tasks.get(target.dataset.id);
    switch (target.dataset.action) {
      case "complete":
        ev.stopPropagation();
        if (task) this._update(task, { completed: !task.completed });
        break;
      case "step": {
        ev.stopPropagation();
        if (!task) break;
        const steps = task.steps.map((s) => (s.id === target.dataset.step ? { ...s, completed: !s.completed } : s));
        this._update(task, { steps });
        break;
      }
      case "expand":
        if (ev.target.closest(".details")) break;
        this._expanded = this._expanded === target.dataset.id ? null : target.dataset.id;
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
      case "toggle-done":
        if (!this._showDone.delete(target.dataset.view)) this._showDone.add(target.dataset.view);
        this._render();
        break;
      case "tab":
        this._tab = Number(target.dataset.tab);
        this._expanded = null;
        this._render();
        break;
      case "open-panel":
        history.pushState(null, "", "/thask");
        window.dispatchEvent(new CustomEvent("location-changed", { detail: { replace: false } }));
        break;
    }
  }

  _addStep(input) {
    const task = this._tasks.get(input.dataset.id);
    const title = input.value.trim();
    if (!task || !title) return;
    this._call("thask/task/update", { task_id: task.id, steps: [...task.steps, { title, completed: false }] }).catch(() => {});
    input.value = "";
  }

  async _runParse() {
    const input = this.shadowRoot.querySelector(".quick");
    const hint = this.shadowRoot.querySelector(".hint");
    const text = input.value.trim();
    this._parsed = null;
    hint.textContent = "";
    if (!text) return null;
    try {
      this._parsed = await this._hass.callWS({ type: "thask/parse", text });
      hint.textContent = this._parsed.due_label || "";
    } catch {
      this._parsed = null;
    }
    return this._parsed;
  }

  async _quickAdd() {
    const input = this.shadowRoot.querySelector(".quick");
    if (!input.value.trim()) return;
    clearTimeout(this._parseTimer);
    const parsed = (await this._runParse()) || { title: input.value.trim() };
    const listId = this._listId();
    if (!parsed.title || !listId) return;
    const data = { list_id: listId, title: parsed.title, priority: parsed.priority || 0 };
    if (parsed.due) data.due = parsed.due;
    if (parsed.due_time) data.due_time = parsed.due_time;
    if (parsed.recurrence) data.recurrence = parsed.recurrence;
    // A new task should show up in the view it was typed into.
    const view = this._active();
    if (view.type === "smart") {
      if ((view.key === "my_day" || view.key === "overdue") && !data.due) data.due = makePeriod("day", this._today);
      if (view.key === "important") data.priority = Math.max(data.priority, 3);
      if (view.key === "this_week" && !data.due) data.due = makePeriod("week", this._today);
      if (view.key === "this_month" && !data.due) data.due = makePeriod("month", this._today);
    }
    data.priority = Math.max(data.priority, Number(this._config.min_priority) || 0);
    try {
      await this._call("thask/task/create", data);
      input.value = "";
      this.shadowRoot.querySelector(".hint").textContent = "";
    } catch {
      // the error is shown in the card
    }
  }
}

// ---- Editor ---------------------------------------------------------------------------------

class ThaskCardEditor extends HTMLElement {
  setConfig(config) {
    this._config = { ...config };
    this._render();
  }

  set hass(hass) {
    const first = !this._hass;
    this._hass = hass;
    if (first) {
      hass.callWS({ type: "thask/data" }).then((data) => {
        this._lists = data.lists;
        this._render();
      }).catch(() => {});
    }
    if (this._form) this._form.hass = hass;
  }

  _schema() {
    const t = (key) => translate(this._hass, key);
    const views = [
      ...SMART_VIEWS.map((key) => ({ value: key, label: t(key) })),
      ...(this._lists || []).map((l) => ({ value: `list:${l.id}`, label: l.group ? `${l.group} › ${l.name}` : l.name })),
    ];
    return [
      { name: "views", selector: { select: { options: views, multiple: true, mode: "dropdown" } } },
      { name: "title", selector: { text: {} } },
      {
        type: "grid", name: "", schema: [
          { name: "tabs", selector: { boolean: {} } },
          { name: "hide_duplicates", selector: { boolean: {} } },
          { name: "show_entry", selector: { boolean: {} } },
          { name: "show_completed", selector: { boolean: {} } },
          { name: "show_list", selector: { boolean: {} } },
          { name: "compact", selector: { boolean: {} } },
        ],
      },
      {
        name: "min_priority",
        selector: { select: { mode: "dropdown", options: [0, 1, 2, 3].map((p) => ({ value: String(p), label: t(`priority_${p}`) })) } },
      },
      { name: "max_items", selector: { number: { min: 0, max: 50, mode: "box" } } },
    ];
  }

  _render() {
    if (!this._hass || !this._config) return;
    if (!customElements.get("ha-form")) {
      this.textContent = "ha-form is not available";
      return;
    }
    if (!this._form) {
      this._form = document.createElement("ha-form");
      this._form.computeLabel = (schema) => translate(this._hass, schema.name);
      this._form.addEventListener("value-changed", (ev) => {
        const config = { ...ev.detail.value };
        config.min_priority = Number(config.min_priority) || 0;
        // One view is written as `view`, several as `views`.
        const views = (config.views || []).filter(Boolean);
        delete config.views;
        if (views.length > 1) {
          delete config.view;
          config.views = views;
        } else {
          config.view = views[0] || "my_day";
        }
        // Leave out what equals the default, so the YAML stays short.
        for (const [key, value] of Object.entries(DEFAULTS)) {
          if (key !== "view" && config[key] === value) delete config[key];
          if (key === "view" && config.views) delete config.view;
        }
        if (!config.title) delete config.title;
        this._config = config;
        this.dispatchEvent(new CustomEvent("config-changed", { detail: { config }, bubbles: true, composed: true }));
      });
      this.appendChild(this._form);
    }
    this._form.hass = this._hass;
    this._form.schema = this._schema();
    const views = this._config.views?.length ? this._config.views : [this._config.view || "my_day"];
    this._form.data = { ...DEFAULTS, ...this._config, views, min_priority: String(this._config.min_priority ?? 0) };
  }
}

const STYLE = `
  :host {
    --thask-muted: var(--secondary-text-color, #727272);
    --thask-accent: var(--primary-color, #03a9f4);
    --thask-danger: var(--error-color, #db4437);
    --thask-prio-1: var(--success-color, #43a047);
    --thask-prio-2: var(--warning-color, #ffa600);
    --thask-prio-3: var(--error-color, #db4437);
  }
  ha-card { padding: 4px 0 8px; overflow: hidden; color: var(--primary-text-color); }
  button { font: inherit; color: inherit; background: none; border: 0; padding: 0; cursor: pointer; text-align: left; }
  .header[hidden] { display: none; }
  .title-row, .view-head { display: flex; align-items: center; gap: 10px; width: 100%; padding: 12px 16px 8px 24px; font-size: 18px; font-weight: 500; box-sizing: border-box; }
  .view-head { font-size: 16px; padding-top: 14px; }
  .title-row ha-icon, .view-head ha-icon { color: var(--thask-accent); }
  .name { flex: 1; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
  .count { color: var(--thask-muted); font-size: 14px; font-weight: 400; }
  .tabs { display: flex; gap: 4px; padding: 8px 12px 6px 20px; overflow-x: auto; scrollbar-width: none; }
  /* Only the shown tab carries its name, so several tabs fit a narrow card. */
  .tab:not(.on) .name { display: none; }
  .tab { display: flex; align-items: center; gap: 6px; padding: 6px 10px; border-radius: 16px; font-size: 14px; white-space: nowrap; color: var(--thask-muted); }
  .tab ha-icon { --mdc-icon-size: 18px; }
  .tab .name { flex: none; }
  .tab .count { font-size: 12px; }
  .tab.on { background: var(--secondary-background-color, color-mix(in srgb, var(--primary-text-color, #212121) 12%, transparent)); color: var(--primary-text-color); }
  .tab.on ha-icon { color: var(--thask-accent); }
  .entry { display: flex; align-items: center; gap: 8px; margin: 0 12px 6px 20px; padding: 0 10px; border-radius: 8px;
    background: var(--secondary-background-color, color-mix(in srgb, var(--primary-text-color, #212121) 8%, transparent)); }
  .entry[hidden] { display: none; }
  .entry ha-icon { --mdc-icon-size: 18px; color: var(--thask-muted); }
  .quick { flex: 1; min-width: 0; padding: 9px 0; border: 0; outline: none; background: transparent; color: var(--primary-text-color); font: inherit; }
  .hint { font-size: 12px; color: var(--thask-accent); white-space: nowrap; }
  .error { margin: 0 16px 6px; color: var(--thask-danger); font-size: 13px; }
  .error[hidden] { display: none; }
  .section { display: flex; align-items: center; gap: 4px; padding: 10px 16px 2px 24px; font-size: 13px; font-weight: 500; color: var(--thask-muted); width: 100%; box-sizing: border-box; }
  .section span { font-weight: 400; }
  .section ha-icon { --mdc-icon-size: 18px; }
  .section.overdue { color: var(--thask-danger); }
  /* Rows keep clear of the card's edge, so neither the hover nor the priority bar covers a theme's thick card border. */
  .task { position: relative; display: flex; align-items: flex-start; gap: 12px; margin: 0 8px; padding: 7px 8px 7px 16px; border-radius: 8px; cursor: pointer; }
  .task:hover { background: color-mix(in srgb, var(--primary-text-color, #000) 6%, transparent); }
  .task[class*="prio-"]::before { content: ""; position: absolute; left: 0; top: 5px; bottom: 5px; border-radius: 4px; }
  .task.prio-1::before { width: 3px; background: var(--thask-prio-1); }
  .task.prio-2::before { width: 5px; background: var(--thask-prio-2); }
  .task.prio-3::before { width: 7px; background: var(--thask-prio-3); }
  .body { flex: 1; min-width: 0; }
  .title { overflow-wrap: anywhere; line-height: 22px; }
  .task.completed > .body > .title { text-decoration: line-through; color: var(--thask-muted); }
  .metas { display: flex; flex-wrap: wrap; gap: 4px 10px; font-size: 12px; color: var(--thask-muted); }
  .meta { display: inline-flex; align-items: center; gap: 3px; }
  .meta ha-icon { --mdc-icon-size: 14px; }
  .meta.due.current { color: var(--thask-accent); }
  .meta.due.overdue { color: var(--thask-danger); }
  .check { width: 22px; height: 22px; margin-top: 0; border-radius: 50%; border: 2px solid var(--thask-muted); display: inline-flex;
    align-items: center; justify-content: center; flex: none; color: transparent; box-sizing: border-box; }
  .check ha-icon { --mdc-icon-size: 14px; }
  .check:hover { border-color: var(--thask-accent); color: var(--thask-accent); }
  .task.completed > .check, .step.completed .check { background: var(--thask-accent); border-color: var(--thask-accent); color: var(--text-primary-color, #fff); }
  .check.small { width: 18px; height: 18px; }
  .details { display: flex; flex-direction: column; gap: 6px; margin-top: 8px; cursor: default; }
  .step { display: flex; align-items: center; gap: 8px; font-size: 14px; }
  .step.completed span { text-decoration: line-through; color: var(--thask-muted); }
  .step-input { border: 0; border-bottom: 1px solid var(--divider-color, color-mix(in srgb, var(--primary-text-color, #212121) 30%, transparent)); background: transparent; color: var(--primary-text-color);
    font: inherit; font-size: 14px; padding: 4px 0; outline: none; }
  .notes { font-size: 13px; color: var(--thask-muted); white-space: pre-wrap; }
  .more { display: block; padding: 6px 16px 6px 24px; font-size: 13px; color: var(--thask-accent); }
  .empty { padding: 12px 16px 12px 24px; color: var(--thask-muted); }
  ha-card.compact .task { padding-top: 4px; padding-bottom: 4px; }
`;

if (!customElements.get("thask-card")) customElements.define("thask-card", ThaskCard);
if (!customElements.get("thask-card-editor")) customElements.define("thask-card-editor", ThaskCardEditor);

window.customCards = window.customCards || [];
if (!window.customCards.some((c) => c.type === "thask-card")) {
  window.customCards.push({
    type: "thask-card",
    name: "tHAsk",
    description: translate(document.querySelector("home-assistant")?.hass, "card_description"),
    preview: true,
    documentationURL: "https://github.com/Schumey/tHAsk#dashboard-karte",
  });
}
