// tHAsk dashboard card: one view (Today, This week, a list …) with fuzzy due dates, quick add and steps.
// Loaded on every dashboard by the integration; use it as `type: custom:thask-card`.

const VERSION = new URL(import.meta.url).searchParams.get("v") || "";
// The sidebar entry uses the icon `thask:logo`; this module is loaded on every page, so it registers it.
await import(`./thask-icons.js?v=${VERSION}`);
const {
  parseISO, periodStart, periodEnd, periodEndOf, periodStatus, periodLabel, makePeriod, sortTasks, esc,
  isOverdue, matchesSmart, sortByDue, splitDone, language, addDays, dayTasks, sortByTime,
} = await import(`./thask-common.js?v=${VERSION}`);

const STRINGS = {
  de: {
    my_day: "Heute", day_view: "Tagesplan", in_period: "Im Zeitraum fällig", preview: "Vorschau", occurrence_done: "Vorab erledigen", prev_day: "Vorheriger Tag", next_day: "Nächster Tag", overdue: "Überfällig", important: "Wichtig", planned: "Geplant", this_week: "Diese Woche",
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
    menu: "Aktionen", due_today: "Heute", due_tomorrow: "Morgen", next_week: "Nächste Woche",
    next_month: "Nächsten Monat", no_date: "Ohne Datum", delete: "Löschen", deleted: "„{0}“ gelöscht",
    undo: "Rückgängig", drag: "Ziehen zum Sortieren", prio_none: "Keine", priority: "Priorität",
    lists: "Nur aus diesen Listen (intelligente Ansichten)", categories: "Nur mit diesen Kategorien", hide_if_empty: "Ausblenden, wenn nichts offen ist",
    card_description: "Eine tHAsk-Ansicht oder -Liste mit Zeiträumen, Schnelleingabe und Schritten.",
  },
  en: {
    my_day: "Today", day_view: "Day plan", in_period: "Due within a period", preview: "Preview", occurrence_done: "Tick off ahead of time", prev_day: "Previous day", next_day: "Next day", overdue: "Overdue", important: "Important", planned: "Planned", this_week: "This week",
    this_month: "This month", later: "Later", today: "Today", tomorrow: "Tomorrow", empty: "No tasks",
    completed: "Completed", add_task: "Add a task", more: "{0} more", loading: "Loading …",
    not_loaded: "tHAsk is not loaded", unknown_list: "Unknown list", open_panel: "Open in tHAsk",
    complete: "Completed", add_step: "Add a step",
    views: "Views (one or more)", tabs: "As tabs instead of one below the other",
    hide_duplicates: "Show each task only once", title: "Title (empty = name of the view)", show_entry: "Quick add",
    show_completed: "Show completed", show_list: "Show the list of each task",
    min_priority: "At least priority", max_items: "At most this many tasks (0 = all)", compact: "Compact",
    priority_0: "All", priority_1: "Low", priority_2: "Medium", priority_3: "High",
    menu: "Actions", due_today: "Today", due_tomorrow: "Tomorrow", next_week: "Next week",
    next_month: "Next month", no_date: "No date", delete: "Delete", deleted: "“{0}” deleted",
    undo: "Undo", drag: "Drag to reorder", prio_none: "None", priority: "Priority",
    lists: "Only from these lists (smart views)", categories: "Only with these categories", hide_if_empty: "Hide when nothing is open",
    card_description: "A tHAsk view or list with fuzzy due dates, quick add and steps.",
  },
  nl: {
    my_day: "Vandaag", day_view: "Dagplanning", in_period: "In een periode", preview: "Voorbeeld", occurrence_done: "Vooraf afronden", prev_day: "Vorige dag", next_day: "Volgende dag", overdue: "Te laat", important: "Belangrijk", planned: "Gepland", this_week: "Deze week",
    this_month: "Deze maand", later: "Later", today: "Vandaag", tomorrow: "Morgen", empty: "Geen taken",
    completed: "Voltooid", add_task: "Taak toevoegen", more: "nog {0}", loading: "Laden …",
    not_loaded: "tHAsk is niet geladen", unknown_list: "Onbekende lijst", open_panel: "Openen in tHAsk",
    complete: "Voltooid", add_step: "Stap toevoegen",
    views: "Weergaven (een of meer)", tabs: "Als tabbladen in plaats van onder elkaar",
    hide_duplicates: "Elke taak maar één keer tonen", title: "Titel (leeg = naam van de weergave)", show_entry: "Snel toevoegen",
    show_completed: "Voltooide tonen", show_list: "Lijst bij elke taak tonen",
    min_priority: "Minstens prioriteit", max_items: "Hoogstens zoveel taken (0 = alle)", compact: "Compact",
    priority_0: "Alle", priority_1: "Laag", priority_2: "Gemiddeld", priority_3: "Hoog",
    menu: "Acties", due_today: "Vandaag", due_tomorrow: "Morgen", next_week: "Volgende week",
    next_month: "Volgende maand", no_date: "Geen datum", delete: "Verwijderen", deleted: "„{0}” verwijderd",
    undo: "Ongedaan maken", drag: "Slepen om te sorteren", prio_none: "Geen", priority: "Prioriteit",
    lists: "Alleen uit deze lijsten (slimme weergaven)", categories: "Alleen met deze categorieën", hide_if_empty: "Verbergen als er niets open is",
    card_description: "Een tHAsk-weergave of -lijst met vage vervaldatums, snel toevoegen en stappen.",
  },
  fr: {
    my_day: "Aujourd'hui", day_view: "Programme du jour", in_period: "Dans une période", preview: "Aperçu", occurrence_done: "Terminer à l'avance", prev_day: "Jour précédent", next_day: "Jour suivant", overdue: "En retard", important: "Important", planned: "Planifié", this_week: "Cette semaine",
    this_month: "Ce mois-ci", later: "Plus tard", today: "Aujourd'hui", tomorrow: "Demain", empty: "Aucune tâche",
    completed: "Terminées", add_task: "Ajouter une tâche", more: "{0} de plus", loading: "Chargement …",
    not_loaded: "tHAsk n'est pas chargé", unknown_list: "Liste inconnue", open_panel: "Ouvrir dans tHAsk",
    complete: "Terminée", add_step: "Ajouter une étape",
    views: "Vues (une ou plusieurs)", tabs: "En onglets plutôt que l'une sous l'autre",
    hide_duplicates: "Afficher chaque tâche une seule fois", title: "Titre (vide = nom de la vue)", show_entry: "Saisie rapide",
    show_completed: "Afficher les terminées", show_list: "Afficher la liste de chaque tâche",
    min_priority: "Priorité minimale", max_items: "Au plus ce nombre de tâches (0 = toutes)", compact: "Compact",
    priority_0: "Toutes", priority_1: "Basse", priority_2: "Moyenne", priority_3: "Haute",
    menu: "Actions", due_today: "Aujourd'hui", due_tomorrow: "Demain", next_week: "Semaine prochaine",
    next_month: "Mois prochain", no_date: "Sans date", delete: "Supprimer", deleted: "« {0} » supprimée",
    undo: "Annuler", drag: "Glisser pour trier", prio_none: "Aucune", priority: "Priorité",
    lists: "Seulement de ces listes (vues intelligentes)", categories: "Seulement avec ces catégories", hide_if_empty: "Masquer s'il n'y a rien à faire",
    card_description: "Une vue ou une liste tHAsk avec échéances souples, saisie rapide et étapes.",
  },
  es: {
    my_day: "Hoy", day_view: "Plan del día", in_period: "Dentro de un periodo", preview: "Vista previa", occurrence_done: "Completar por adelantado", prev_day: "Día anterior", next_day: "Día siguiente", overdue: "Vencidas", important: "Importante", planned: "Planificado", this_week: "Esta semana",
    this_month: "Este mes", later: "Más tarde", today: "Hoy", tomorrow: "Mañana", empty: "No hay tareas",
    completed: "Completadas", add_task: "Añadir una tarea", more: "{0} más", loading: "Cargando …",
    not_loaded: "tHAsk no está cargado", unknown_list: "Lista desconocida", open_panel: "Abrir en tHAsk",
    complete: "Completada", add_step: "Añadir un paso",
    views: "Vistas (una o varias)", tabs: "En pestañas en lugar de una debajo de otra",
    hide_duplicates: "Mostrar cada tarea solo una vez", title: "Título (vacío = nombre de la vista)", show_entry: "Entrada rápida",
    show_completed: "Mostrar completadas", show_list: "Mostrar la lista de cada tarea",
    min_priority: "Prioridad mínima", max_items: "Como máximo tantas tareas (0 = todas)", compact: "Compacto",
    priority_0: "Todas", priority_1: "Baja", priority_2: "Media", priority_3: "Alta",
    menu: "Acciones", due_today: "Hoy", due_tomorrow: "Mañana", next_week: "La próxima semana",
    next_month: "El próximo mes", no_date: "Sin fecha", delete: "Eliminar", deleted: "«{0}» eliminada",
    undo: "Deshacer", drag: "Arrastrar para ordenar", prio_none: "Ninguna", priority: "Prioridad",
    lists: "Solo de estas listas (vistas inteligentes)", categories: "Solo con estas categorías", hide_if_empty: "Ocultar si no hay nada pendiente",
    card_description: "Una vista o lista de tHAsk con vencimientos flexibles, entrada rápida y pasos.",
  },
};

const SMART_VIEWS = ["my_day", "overdue", "important", "planned", "day_view", "this_week", "this_month"];
const VIEW_ICONS = {
  my_day: "mdi:calendar-today", overdue: "mdi:calendar-alert", important: "mdi:flag-outline",
  planned: "mdi:calendar-month-outline", this_week: "mdi:calendar-week", this_month: "mdi:calendar-month",
  day_view: "mdi:calendar-cursor",
};
const DEFAULTS = {
  view: "my_day", tabs: false, hide_duplicates: true, show_entry: true, show_completed: false, show_list: true,
  min_priority: 0, max_items: 0, compact: false, lists: [], categories: [], hide_if_empty: false,
};
const UNDO_MS = 5000;

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
    this._day = this._today; // the day shown in the day plan
    this._overdueMode = "section";
    this._options = {};
    this._expanded = null; // id of the task whose steps and notes are shown
    this._showDone = new Set(); // views whose completed tasks are unfolded
    this._tab = 0;
    this._overdueCollapsed = readStorage(OVERDUE_COLLAPSED_KEY) === "1";
    this._parseTimer = null;
    this._parsed = null;
    this._menu = null; // id of the task whose actions (postpone, priority, delete) are open
    this._deleting = null; // { task, timer }: deleted, but still undoable
    this._drag = null;
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

  // Hidden by hide_if_empty, the card must stay connected to notice new tasks (read by hui-card).
  get connectedWhileHidden() {
    return true;
  }

  disconnectedCallback() {
    this._commitDelete();
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
        // The day plan follows a new day as long as it shows today.
        if (this._day.getTime() === this._today.getTime()) this._day = parseISO(event.today);
        this._today = parseISO(event.today);
        this._lists = event.lists;
        this._tasks = new Map(event.tasks.map((task) => [task.id, task]));
        this._overdueMode = event.options?.overdue_in_today || "section";
        this._options = event.options || {};
        this._periods = event.periods || [];
        this._loaded = true;
        this._error = null;
        break;
      case "day_changed":
        if (this._day.getTime() === this._today.getTime()) this._day = parseISO(event.today);
        this._today = parseISO(event.today);
        break;
      case "options":
        this._overdueMode = event.overdue_in_today || "section";
        this._options = event;
        break;
      case "periods":
        this._periods = event.periods || [];
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
      rollingWeek: this._options.week_mode === "rolling", importantMedium: this._options.important_priority === "medium",
    };
    const minPriority = Number(this._config.min_priority) || 0;
    // Smart views only show lists for everyone or with me among the members (like the web interface).
    const me = this._hass?.user?.id;
    const mine = new Set(this._lists.filter((l) => !l.members?.length || !me || l.members.includes(me)).map((l) => l.id));
    // Optional filters: smart views only from some lists, every view only with some categories.
    const lists = this._config.lists || [];
    const categories = this._config.categories || [];
    const deleting = this._deleting?.task.id;
    const filtered = (task) => (!categories.length || (task.categories || []).some((c) => categories.includes(c)))
      && task.priority >= minPriority && task.id !== deleting;
    if (view.type === "smart" && view.key === "day_view") {
      const pool = [...this._tasks.values()].filter((task) =>
        mine.has(task.list_id) && (!lists.length || lists.includes(task.list_id)) && filtered(task));
      // Previews keep the id of their task, so hide_duplicates only applies to real tasks.
      const tasks = dayTasks(pool, this._day, this._today, this._periods).filter((task) => task.preview || !skip?.has(task.id));
      if (this._day.getTime() === this._today.getTime()) {
        tasks.push(...pool.filter((task) => isOverdue(task, this._today) && !skip?.has(task.id)));
      }
      return splitDone(sortByTime(tasks));
    }
    const tasks = [...this._tasks.values()].filter((task) =>
      (view.type === "list" ? task.list_id === view.listId
        : mine.has(task.list_id) && (!lists.length || lists.includes(task.list_id)) && matchesSmart(task, view.key, ctx))
      && filtered(task) && !skip?.has(task.id)
    );
    if (view.type === "list") {
      const sort = this._lists.find((l) => l.id === view.listId)?.sort || "manual";
      return splitDone(sortTasks(tasks, sort));
    }
    return splitDone(sortByDue(tasks));
  }

  _listId() {
    const view = this._active();
    if (view.type === "list") return view.listId;
    // The first of the filtered lists, otherwise the first list for me.
    const me = this._hass?.user?.id;
    const mine = this._lists.filter((l) => !l.members?.length || !me || l.members.includes(me));
    const filtered = (this._config.lists || []).map((id) => mine.find((l) => l.id === id)).find(Boolean);
    return (filtered || mine[0] || this._lists[0])?.id;
  }

  // In a list with manual order, open tasks can be dragged into place.
  _reorderable(view) {
    return view.type === "list" && (this._lists.find((l) => l.id === view.listId)?.sort || "manual") === "manual";
  }

  // ---- Rendering --------------------------------------------------------------------------

  _render() {
    // Without hass the language is unknown; Home Assistant sets it right after the config.
    if (!this._config || !this._hass) return;
    if (this._drag) {
      // Rebuilding the rows would drop the dragged one; render once the drag ends.
      this._drag.renderPending = true;
      return;
    }
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
        visible.open.forEach((task) => !task.preview && seen?.add(task.id));
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
    const toast = root.querySelector(".toast");
    toast.hidden = !this._deleting;
    if (this._deleting) {
      toast.innerHTML = `<span>${esc(this.t("deleted", this._deleting.task.title))}</span>
        <button data-action="undo">${esc(this.t("undo"))}</button>`;
    }
    // Not in the editor's preview, where hui-card would otherwise hide the card being edited.
    const empty = this._loaded && !this._error && !this._deleting && views.every((view) => !this._visible(view).open.length);
    this._setHidden(!!this._config.hide_if_empty && empty && !this.preview && !this.editMode);
  }

  _setHidden(hidden) {
    if (this.hidden === hidden) return;
    this.hidden = hidden;
    this.dispatchEvent(new CustomEvent("card-visibility-changed", { detail: { value: !hidden } }));
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
        <div class="toast" hidden></div>
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
    this.shadowRoot.addEventListener("pointerdown", (ev) => this._onPointerDown(ev));
    this.shadowRoot.addEventListener("pointermove", (ev) => this._onPointerMove(ev));
    this.shadowRoot.addEventListener("pointerup", (ev) => this._onPointerUp(ev));
    this.shadowRoot.addEventListener("pointercancel", (ev) => this._onPointerUp(ev, true));
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
    } else if (view.type === "smart" && view.key === "day_view") {
      // Overdue (only on today), the day itself, then periods such as "week 45" that contain it.
      const isToday = this._day.getTime() === this._today.getTime();
      html += `<div class="day-nav">
        <button class="icon" data-action="day" data-shift="-1" title="${esc(this.t("prev_day"))}"><ha-icon icon="mdi:chevron-left"></ha-icon></button>
        <span class="day-label">${esc(this._day.toLocaleDateString(this._hass?.language || "en", { weekday: "long", day: "numeric", month: "long" }))}</span>
        <button class="icon" data-action="day" data-shift="1" title="${esc(this.t("next_day"))}"><ha-icon icon="mdi:chevron-right"></ha-icon></button>
        <button class="icon" data-action="day" data-shift="0" title="${esc(this.t("today"))}" ${isToday ? "disabled" : ""}><ha-icon icon="mdi:calendar-today"></ha-icon></button>
      </div>`;
      const overdue = shown.filter((t) => !t.preview && isOverdue(t, this._today));
      const day = shown.filter((t) => !overdue.includes(t) && t.due.granularity === "day");
      const periods = shown.filter((t) => !overdue.includes(t) && t.due.granularity !== "day");
      if (overdue.length) {
        html += `<button class="section overdue toggle" data-action="toggle-overdue">
          <ha-icon icon="${this._overdueCollapsed ? "mdi:chevron-right" : "mdi:chevron-down"}"></ha-icon>${esc(this.t("overdue"))} <span>${overdue.length}</span></button>`;
        if (!this._overdueCollapsed) html += overdue.map((t) => this._row(t, view)).join("");
        if (day.length) html += `<div class="section">${esc(periodLabel(makePeriod("day", this._day), lang(this._hass), this._today))}</div>`;
      }
      html += day.map((t) => this._row(t, view)).join("");
      if (periods.length) html += `<div class="section">${esc(this.t("in_period"))}</div>${periods.map((t) => this._row(t, view)).join("")}`;
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
    // Like the app (DueChip): red when overdue, blue when it ends today; periods fade out to the right.
    const end = periodEndOf(task.due).getTime();
    const status = task.completed ? "" : end < this._today.getTime() ? "overdue" : end === this._today.getTime() ? "today" : "";
    const fuzzy = task.due.granularity !== "day" ? "fuzzy" : "";
    let label = periodLabel(task.due, lang(this._hass), this._today);
    if (task.due.granularity === "day") {
      const days = Math.round((parseISO(task.due.start) - this._today) / 864e5);
      if (days === 0) label = this.t("today");
      else if (days === 1) label = this.t("tomorrow");
      if (task.due_time) label += `, ${task.due_time}`;
    }
    const icon = task.due.granularity === "day" ? "mdi:calendar" : "mdi:calendar-range";
    return `<span class="meta due ${status} ${fuzzy}"><ha-icon icon="${icon}"></ha-icon>${esc(label)}</span>`;
  }

  _row(task, view) {
    const meta = [];
    if (task.due) meta.push(this._dueChip(task));
    // In smart views: which list the task comes from, right after the due date.
    if (view.type === "smart" && this._config.show_list) {
      const list = this._lists.find((l) => l.id === task.list_id);
      if (list) meta.push(`<span class="meta list"><ha-icon icon="mdi:format-list-checks"></ha-icon>${esc(list.name)}</span>`);
    }
    if (task.steps?.length) meta.push(`<span class="meta"><ha-icon icon="mdi:format-list-bulleted"></ha-icon>${task.steps.filter((s) => s.completed).length}/${task.steps.length}</span>`);
    if (task.preview) meta.push(`<span class="meta preview-tag"><ha-icon icon="mdi:repeat"></ha-icon>${esc(this.t("preview"))}</span>`);
    else if (task.recurrence) meta.push(`<span class="meta"><ha-icon icon="mdi:repeat"></ha-icon></span>`);
    if (task.notes) meta.push(`<span class="meta"><ha-icon icon="mdi:note-text-outline"></ha-icon></span>`);
    if (task.attachments?.length) meta.push(`<span class="meta"><ha-icon icon="mdi:paperclip"></ha-icon>${task.attachments.length}</span>`);
    if (task.preview) {
      // A coming occurrence of a recurring task: it does not exist yet. Ticking it off does it ahead of time
      // (a completed task of its own; the recurrence then jumps over it).
      return `
      <div class="task preview" data-view="${esc(view.id)}">
        <button class="check preview" data-action="occurrence" data-id="${esc(task.id)}" data-period='${esc(JSON.stringify(task.due))}' title="${esc(this.t("occurrence_done"))}"><ha-icon icon="mdi:check"></ha-icon></button>
        <div class="body">
          <div class="title">${esc(task.title)}</div>
          ${meta.length && !this._config.compact ? `<div class="metas">${meta.join("")}</div>` : ""}
        </div>
      </div>`;
    }
    const expanded = this._expanded === task.id;
    const menu = this._menu === task.id;
    const drag = !task.completed && this._reorderable(view)
      ? `<span class="drag" data-drag="${esc(task.id)}" title="${esc(this.t("drag"))}"><ha-icon icon="mdi:drag-vertical"></ha-icon></span>` : "";
    return `
      <div class="task prio-${task.priority || 0} ${task.completed ? "completed" : ""} ${expanded ? "expanded" : ""}" data-action="expand" data-id="${esc(task.id)}" data-view="${esc(view.id)}">
        <button class="check" data-action="complete" data-id="${esc(task.id)}" title="${esc(this.t("complete"))}"><ha-icon icon="mdi:check"></ha-icon></button>
        <div class="body">
          <div class="title">${esc(task.title)}</div>
          ${meta.length && !this._config.compact ? `<div class="metas">${meta.join("")}</div>` : ""}
          ${menu ? this._actions(task) : ""}
          ${expanded ? this._details(task) : ""}
        </div>
        ${drag}
        <button class="menu-button ${menu ? "on" : ""}" data-action="menu" data-id="${esc(task.id)}" title="${esc(this.t("menu"))}"><ha-icon icon="mdi:dots-vertical"></ha-icon></button>
      </div>`;
  }

  // Postpone, priority and delete, below the title; big enough for a wall tablet.
  _actions(task) {
    const due = (key, icon) => `<button class="chip" data-action="due" data-due="${key}" data-id="${esc(task.id)}"><ha-icon icon="${icon}"></ha-icon>${esc(this.t(key))}</button>`;
    const prio = [0, 1, 2, 3].map((p) => `<button class="chip prio p${p} ${(task.priority || 0) === p ? "on" : ""}" data-action="priority" data-priority="${p}" data-id="${esc(task.id)}"
      title="${esc(this.t("priority"))}: ${esc(this.t(p ? `priority_${p}` : "prio_none"))}"><ha-icon icon="${p ? "mdi:flag" : "mdi:flag-off-outline"}"></ha-icon></button>`).join("");
    return `<div class="actions">
      ${task.completed ? "" : `${due("due_today", "mdi:calendar-today")}${due("due_tomorrow", "mdi:calendar-arrow-right")}${due("next_week", "mdi:calendar-week")}${due("next_month", "mdi:calendar-month")}${task.due ? due("no_date", "mdi:calendar-remove-outline") : ""}`}
      <span class="prios">${prio}</span>
      <button class="chip danger" data-action="delete" data-id="${esc(task.id)}"><ha-icon icon="mdi:delete-outline"></ha-icon>${esc(this.t("delete"))}</button>
    </div>`;
  }

  _duePeriod(key) {
    const t = this._today;
    switch (key) {
      case "due_today": return makePeriod("day", t);
      case "due_tomorrow": return makePeriod("day", new Date(t.getFullYear(), t.getMonth(), t.getDate() + 1));
      case "next_week": return makePeriod("week", new Date(t.getFullYear(), t.getMonth(), t.getDate() + 7));
      case "next_month": return makePeriod("month", new Date(t.getFullYear(), t.getMonth() + 1, 1));
      default: return null;
    }
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
    if (ev.target.closest(".drag")) return;
    if (!target || target.classList.contains("step-input")) return;
    const task = this._tasks.get(target.dataset.id);
    switch (target.dataset.action) {
      case "menu":
        ev.stopPropagation();
        this._menu = this._menu === target.dataset.id ? null : target.dataset.id;
        this._render();
        break;
      case "due":
        ev.stopPropagation();
        this._menu = null;
        if (task) this._update(task, { due: this._duePeriod(target.dataset.due), ...(target.dataset.due === "no_date" ? { due_time: null } : {}) });
        break;
      case "priority":
        ev.stopPropagation();
        this._menu = null;
        if (task) this._update(task, { priority: Number(target.dataset.priority) });
        break;
      case "delete":
        ev.stopPropagation();
        if (task) this._delete(task);
        break;
      case "undo":
        clearTimeout(this._deleting?.timer);
        this._deleting = null;
        this._render();
        break;
      case "complete":
        ev.stopPropagation();
        if (task) this._update(task, { completed: !task.completed });
        break;
      case "occurrence": {
        ev.stopPropagation();
        if (!task) break;
        const due = JSON.parse(target.dataset.period);
        // Hide the preview at once; the completed task of its own arrives as a change.
        this._tasks.set(task.id, { ...task, skipped: [...new Set([...(task.skipped || []), due.start])].sort() });
        this._render();
        this._call("thask/task/occurrence", { task_id: task.id, due, done: true }).catch(() => {});
        break;
      }
      case "step": {
        ev.stopPropagation();
        if (!task) break;
        const steps = task.steps.map((s) => (s.id === target.dataset.step ? { ...s, completed: !s.completed } : s));
        this._update(task, { steps });
        break;
      }
      case "expand":
        if (ev.target.closest(".details, .actions")) break;
        this._expanded = this._expanded === target.dataset.id ? null : target.dataset.id;
        this._render();
        break;
      case "day":
        this._day = Number(target.dataset.shift) ? addDays(this._day, Number(target.dataset.shift)) : this._today;
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

  // Deleting waits a few seconds for "Undo"; the server deletes attachments with the task.
  _delete(task) {
    this._commitDelete();
    this._menu = null;
    if (this._expanded === task.id) this._expanded = null;
    this._deleting = { task, timer: setTimeout(() => this._commitDelete(), UNDO_MS) };
    this._render();
  }

  _commitDelete() {
    const pending = this._deleting;
    if (!pending) return;
    clearTimeout(pending.timer);
    this._deleting = null;
    this._tasks.delete(pending.task.id);
    this._call("thask/task/delete", { task_id: pending.task.id }).catch(() => {
      this._tasks.set(pending.task.id, pending.task);
      this._render();
    });
    this._render();
  }

  // ---- Drag & drop (mouse and touch, via the handle) ----------------------------------------

  _onPointerDown(ev) {
    const handle = ev.target.closest?.(".drag");
    if (!handle || ev.button > 0) return;
    const row = handle.closest(".task");
    const rows = [...this.shadowRoot.querySelectorAll(`.task[data-view="${CSS.escape(row.dataset.view)}"]:not(.completed)`)];
    ev.preventDefault();
    try {
      handle.setPointerCapture(ev.pointerId); // keeps the moves coming when the pointer leaves the handle
    } catch {
      // pointer already gone
    }
    this._drag = {
      id: row.dataset.id, row, rows, index: rows.indexOf(row), target: rows.indexOf(row), startY: ev.clientY,
      rects: rows.map((r) => r.getBoundingClientRect()), renderPending: false,
    };
    row.classList.add("dragging");
  }

  _onPointerMove(ev) {
    const drag = this._drag;
    if (!drag) return;
    const dy = ev.clientY - drag.startY;
    const own = drag.rects[drag.index];
    const center = own.top + own.height / 2 + dy;
    // The new place: before the first other row whose middle lies below the dragged row's middle.
    let target = drag.rects.findIndex((r, i) => i !== drag.index && center < r.top + r.height / 2);
    if (target === -1) target = drag.rows.length;
    if (target > drag.index) target -= 1;
    drag.target = target;
    drag.rows.forEach((r, i) => {
      if (i === drag.index) r.style.transform = `translateY(${dy}px)`;
      else if (drag.index < target && i > drag.index && i <= target) r.style.transform = `translateY(${-own.height}px)`;
      else if (target < drag.index && i >= target && i < drag.index) r.style.transform = `translateY(${own.height}px)`;
      else r.style.transform = "";
    });
  }

  _onPointerUp(ev, cancelled = false) {
    const drag = this._drag;
    if (!drag) return;
    this._drag = null;
    drag.rows.forEach((r) => { r.style.transform = ""; });
    drag.row.classList.remove("dragging");
    if (!cancelled && drag.target !== drag.index) {
      const order = drag.rows.map((r) => r.dataset.id);
      order.splice(drag.target, 0, ...order.splice(drag.index, 1));
      const previous = drag.target === 0 ? null : order[drag.target - 1];
      // Show the new order at once: a position between the new neighbours.
      const task = this._tasks.get(drag.id);
      const before = this._tasks.get(previous)?.position;
      const after = this._tasks.get(order[drag.target + 1])?.position;
      const position = before == null ? (after ?? 0) - 1 : after == null ? before + 1 : (before + after) / 2;
      if (task) this._tasks.set(task.id, { ...task, position });
      this._call("thask/task/move", { task_id: drag.id, previous_id: previous }).catch(() => {});
    }
    this._render();
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
    // With a category filter, the new task gets the first category, so it stays in the card.
    if (this._config.categories?.length) data.categories = [this._config.categories[0]];
    // A new task should show up in the view it was typed into.
    const view = this._active();
    if (view.type === "smart") {
      if ((view.key === "my_day" || view.key === "overdue") && !data.due) data.due = makePeriod("day", this._today);
      if (view.key === "day_view" && !data.due) data.due = makePeriod("day", this._day);
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
        this._categories = [...new Set(data.tasks.flatMap((t) => t.categories || []))].sort((a, b) => a.localeCompare(b));
        this._render();
      }).catch(() => {});
    }
    if (this._form) this._form.hass = hass;
  }

  _schema() {
    const t = (key) => translate(this._hass, key);
    const listLabel = (l) => (l.group ? `${l.group} › ${l.name}` : l.name);
    const views = [
      ...SMART_VIEWS.map((key) => ({ value: key, label: t(key) })),
      ...(this._lists || []).map((l) => ({ value: `list:${l.id}`, label: listLabel(l) })),
    ];
    const categories = [...new Set([...(this._categories || []), ...(this._config.categories || [])])];
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
          { name: "hide_if_empty", selector: { boolean: {} } },
        ],
      },
      { name: "lists", selector: { select: { options: (this._lists || []).map((l) => ({ value: l.id, label: listLabel(l) })), multiple: true, mode: "dropdown" } } },
      { name: "categories", selector: { select: { options: categories, multiple: true, custom_value: true, mode: "dropdown" } } },
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
          if (Array.isArray(value) && !config[key]?.length) delete config[key];
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
  .meta.due {
    --thask-due: var(--thask-muted); --thask-due-bg: color-mix(in srgb, var(--thask-due) 14%, transparent);
    color: var(--thask-due); background: var(--thask-due-bg); padding: 1px 8px; border-radius: 10px;
  }
  .meta.due.today { --thask-due: var(--thask-accent); }
  .meta.due.overdue { --thask-due: var(--thask-danger); }
  .meta.due.fuzzy { background: linear-gradient(90deg, var(--thask-due-bg) 55%, transparent); padding-right: 16px; }
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
  .day-nav { display: flex; align-items: center; gap: 4px; padding: 2px 8px 4px 16px; }
  .day-nav .day-label { flex: 1; font-size: 14px; font-weight: 500; }
  .day-nav .icon { display: inline-flex; padding: 6px; border-radius: 50%; color: var(--thask-muted); }
  .day-nav .icon:disabled { opacity: 0.35; }
  /* Coming occurrences of recurring tasks that do not exist yet. */
  .task.preview { cursor: default; }
  .task.preview > .body > .title { color: var(--thask-muted); }
  .check.preview { border-style: dashed; opacity: 0.6; }
  .check.preview:hover { opacity: 1; }
  .meta.preview-tag { font-style: italic; }
  .more { display: block; padding: 6px 16px 6px 24px; font-size: 13px; color: var(--thask-accent); }
  .empty { padding: 12px 16px 12px 24px; color: var(--thask-muted); }
  ha-card.compact .task { padding-top: 4px; padding-bottom: 4px; }
  .menu-button, .drag { flex: none; width: 28px; height: 28px; margin: -3px -4px -3px 0; border-radius: 50%; display: inline-flex;
    align-items: center; justify-content: center; color: var(--thask-muted); }
  .menu-button ha-icon, .drag ha-icon { --mdc-icon-size: 20px; }
  .menu-button.on { color: var(--thask-accent); background: color-mix(in srgb, var(--thask-accent) 14%, transparent); }
  /* Without a mouse there is no hover, so the buttons stay visible; with one they appear on hover. */
  @media (hover: hover) {
    .task:not(:hover) .menu-button:not(.on), .task:not(:hover) .drag { opacity: 0; }
  }
  .drag { cursor: grab; touch-action: none; }
  .task.dragging { z-index: 1; background: var(--card-background-color, #fff); box-shadow: 0 2px 8px rgba(0, 0, 0, .25); cursor: grabbing; }
  .tasks .task { transition: transform .15s; }
  .tasks .task.dragging { transition: none; }
  .actions { display: flex; flex-wrap: wrap; gap: 6px; margin-top: 8px; cursor: default; }
  .chip { display: inline-flex; align-items: center; gap: 4px; padding: 5px 10px; border-radius: 16px; font-size: 13px;
    background: color-mix(in srgb, var(--primary-text-color, #212121) 8%, transparent); }
  .chip ha-icon { --mdc-icon-size: 16px; }
  .chip:hover { background: color-mix(in srgb, var(--thask-accent) 18%, transparent); }
  .prios { display: inline-flex; gap: 2px; }
  .chip.prio { padding: 5px 7px; color: var(--thask-muted); }
  .chip.prio.p1 { color: var(--thask-prio-1); }
  .chip.prio.p2 { color: var(--thask-prio-2); }
  .chip.prio.p3 { color: var(--thask-prio-3); }
  .chip.prio.on { box-shadow: inset 0 0 0 2px currentColor; }
  .chip.danger { color: var(--thask-danger); }
  .toast { display: flex; align-items: center; gap: 12px; margin: 6px 12px 0 20px; padding: 8px 12px; border-radius: 8px; font-size: 14px;
    background: var(--primary-text-color, #212121); color: var(--card-background-color, #fff); }
  .toast[hidden] { display: none; }
  .toast span { flex: 1; min-width: 0; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
  .toast button { font-weight: 500; color: var(--thask-accent); text-transform: uppercase; font-size: 13px; }
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
