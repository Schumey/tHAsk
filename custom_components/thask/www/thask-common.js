// Shared by the tHAsk panel and the dashboard card: dates, periods and the smart views.

export const LANGUAGES = ["de", "en", "nl", "fr", "es"];
// The supported language for a Home Assistant language code ("de-CH" -> "de"); English otherwise.
export const language = (code) => {
  const lang = (code || "en").split("-")[0].toLowerCase();
  return LANGUAGES.includes(lang) ? lang : "en";
};
// Locale for dates; the full code keeps regional formats ("en-US" vs "en-GB").
export const dateLocale = (code) => (!code || code === "en" ? "en-GB" : code);

export const MONTHS = {
  de: ["Januar", "Februar", "März", "April", "Mai", "Juni", "Juli", "August", "September", "Oktober", "November", "Dezember"],
  en: ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"],
  nl: ["januari", "februari", "maart", "april", "mei", "juni", "juli", "augustus", "september", "oktober", "november", "december"],
  fr: ["janvier", "février", "mars", "avril", "mai", "juin", "juillet", "août", "septembre", "octobre", "novembre", "décembre"],
  es: ["enero", "febrero", "marzo", "abril", "mayo", "junio", "julio", "agosto", "septiembre", "octubre", "noviembre", "diciembre"],
};
export const MONTHS_SHORT = {
  de: ["Jan.", "Feb.", "März", "Apr.", "Mai", "Juni", "Juli", "Aug.", "Sep.", "Okt.", "Nov.", "Dez."],
  en: ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"],
  nl: ["jan.", "feb.", "mrt.", "apr.", "mei", "jun.", "jul.", "aug.", "sep.", "okt.", "nov.", "dec."],
  fr: ["janv.", "févr.", "mars", "avr.", "mai", "juin", "juil.", "août", "sept.", "oct.", "nov.", "déc."],
  es: ["ene", "feb", "mar", "abr", "may", "jun", "jul", "ago", "sept", "oct", "nov", "dic"],
};
export const WEEKDAYS_SHORT = {
  de: ["Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"],
  en: ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"],
  nl: ["ma", "di", "wo", "do", "vr", "za", "zo"],
  fr: ["lun.", "mar.", "mer.", "jeu.", "ven.", "sam.", "dim."],
  es: ["lun", "mar", "mié", "jue", "vie", "sáb", "dom"],
};
// Same formats as core/period.py.
const DAY_FORMAT = {
  de: (w, d, m) => `${w}, ${d}. ${m}`,
  en: (w, d, m) => `${w}, ${m} ${d}`,
  nl: (w, d, m) => `${w} ${d} ${m}`,
  fr: (w, d, m) => `${w} ${d} ${m}`,
  es: (w, d, m) => `${w}, ${d} ${m}`,
};
const WEEK_LABEL = { de: "KW", en: "Week", nl: "Week", fr: "Semaine", es: "Semana" };
export const GRANULARITIES = ["day", "week", "month", "quarter", "year"];

// ---- Dates and periods (same rules as core/period.py) ------------------------------------

export const pad = (n) => String(n).padStart(2, "0");
export const toISO = (d) => `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`;
export const parseISO = (s) => {
  const [y, m, d] = s.split("-").map(Number);
  return new Date(y, m - 1, d);
};
export const addDays = (d, n) => new Date(d.getFullYear(), d.getMonth(), d.getDate() + n);
export const addMonths = (d, n) => {
  const first = new Date(d.getFullYear(), d.getMonth() + n, 1);
  const last = new Date(first.getFullYear(), first.getMonth() + 1, 0).getDate();
  return new Date(first.getFullYear(), first.getMonth(), Math.min(d.getDate(), last));
};
export const weekdayIndex = (d) => (d.getDay() + 6) % 7;

export function periodStart(granularity, d) {
  switch (granularity) {
    case "week": return addDays(d, -weekdayIndex(d));
    case "month": return new Date(d.getFullYear(), d.getMonth(), 1);
    case "quarter": return new Date(d.getFullYear(), Math.floor(d.getMonth() / 3) * 3, 1);
    case "year": return new Date(d.getFullYear(), 0, 1);
    default: return new Date(d.getFullYear(), d.getMonth(), d.getDate());
  }
}

export function periodEnd(granularity, start) {
  switch (granularity) {
    case "week": return addDays(start, 6);
    case "month": return addDays(addMonths(start, 1), -1);
    case "quarter": return addDays(addMonths(start, 3), -1);
    case "year": return new Date(start.getFullYear(), 11, 31);
    default: return start;
  }
}

export function isoWeek(d) {
  const thursday = addDays(d, 3 - weekdayIndex(d));
  const year = thursday.getFullYear();
  const dayOfYear = Math.round((thursday - new Date(year, 0, 1)) / 864e5);
  return [year, Math.floor(dayOfYear / 7) + 1];
}

export function makePeriod(granularity, d) {
  return { granularity, start: toISO(periodStart(granularity, d)) };
}

// Move a period by `count` units (default: its own granularity); it keeps its granularity (Period.shift).
export function shiftPeriod(period, count, unit = period.granularity) {
  const start = parseISO(period.start);
  const shifted = {
    day: () => addDays(start, count),
    week: () => addDays(start, 7 * count),
    month: () => addMonths(start, count),
    quarter: () => addMonths(start, 3 * count),
    year: () => addMonths(start, 12 * count),
  }[unit]();
  return makePeriod(period.granularity, shifted);
}

export const periodEndOf = (period) => periodEnd(period.granularity, parseISO(period.start));

export function periodStatus(period, today) {
  if (periodEndOf(period) < today) return "overdue";
  if (parseISO(period.start) <= today) return "current";
  return "upcoming";
}

export function periodLabel(period, lang, today) {
  const start = parseISO(period.start);
  let text;
  let year = start.getFullYear();
  switch (period.granularity) {
    case "day": {
      const weekday = WEEKDAYS_SHORT[lang][weekdayIndex(start)];
      const month = MONTHS_SHORT[lang][start.getMonth()];
      text = DAY_FORMAT[lang](weekday, start.getDate(), month);
      break;
    }
    case "week": {
      const [weekYear, week] = isoWeek(start);
      year = weekYear;
      text = `${WEEK_LABEL[lang]} ${week}`;
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

export function periodRange(period, locale) {
  if (period.granularity === "day") return "";
  const start = parseISO(period.start);
  const end = periodEndOf(period);
  const fmt = (d) => d.toLocaleDateString(locale === "de" ? "de-DE" : locale === "en" ? "en-GB" : locale, { day: "numeric", month: "short" });
  return `${fmt(start)} – ${fmt(end)}`;
}

// Same rules as sort_tasks in core/models.py; ties keep the manual order.
export function sortTasks(tasks, mode) {
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

export const esc = (value) =>
  String(value ?? "").replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[c]);

// ---- Smart views (same rules as todo.py) ----------------------------------------------------

export const dueBy = (task, day) => !!task.due && periodEndOf(task.due) <= day;

export const completedSince = (task, day) => !!task.completed_at && new Date(task.completed_at) >= day;

export const isOverdue = (task, today) => !task.completed && !!task.due && periodEndOf(task.due) < today;

// "This week": the calendar week, or with `rolling` today and the next seven days (this_week_range in core/models.py).
export const thisWeekRange = (today, rolling) =>
  rolling ? [today, addDays(today, 7)] : [periodStart("week", today), periodEnd("week", periodStart("week", today))];

// Whether a task belongs to a smart view (same rules as core/models.py).
// `ctx`: { today, overdueMode, importantRange, separateWeek, separateMonth, rollingWeek }.
export function matchesSmart(task, key, ctx) {
  const { today } = ctx;
  switch (key) {
    case "my_day":
      // Today: everything due by today, and what was completed today. Overdue tasks may have a view of their own.
      if (!dueBy(task, today)) return false;
      // Kept apart from "This week": a period that ends today ("week 44" on a Sunday) belongs there.
      if (ctx.separateWeek && task.due.granularity !== "day" && periodEndOf(task.due) >= today) return false;
      if (task.completed) return completedSince(task, today);
      return ctx.overdueMode !== "separate" || !isOverdue(task, today);
    case "overdue":
      return isOverdue(task, today);
    case "important":
      // Option "important_priority": high only, or medium and high.
      if (task.priority < (ctx.importantMedium ? 2 : 3)) return false;
      if (!ctx.importantRange || ctx.importantRange === "all") return true;
      return dueBy(task, periodEnd(ctx.importantRange, periodStart(ctx.importantRange, today)));
    case "planned":
      return !!task.due;
    case "this_week": {
      const [weekStart, weekEnd] = thisWeekRange(today, ctx.rollingWeek);
      if (!dueBy(task, weekEnd)) return false;
      // Kept apart from "Today": without overdue tasks and days due today.
      const end = periodEndOf(task.due);
      if (ctx.separateWeek && (end < today || (task.due.granularity === "day" && end.getTime() === today.getTime()))) return false;
      return !task.completed || completedSince(task, weekStart);
    }
    case "this_month":
      if (!dueBy(task, periodEnd("month", periodStart("month", today)))) return false;
      // Kept apart: only what is due after this week.
      if (ctx.separateMonth && dueBy(task, thisWeekRange(today, ctx.rollingWeek)[1])) return false;
      return !task.completed || completedSince(task, periodStart("month", today));
  }
  return false;
}

// Order of the smart views: by due date, then priority, then the manual order.
export function sortByDue(tasks) {
  const dueKey = (task) => (task.due ? toISO(periodEndOf(task.due)) : "9999");
  return [...tasks].sort((a, b) => dueKey(a).localeCompare(dueKey(b)) || b.priority - a.priority || a.position - b.position);
}

// Open and completed tasks, the completed ones newest first.
export function splitDone(tasks) {
  return {
    open: tasks.filter((task) => !task.completed),
    done: tasks.filter((task) => task.completed).sort((a, b) => (b.completed_at || "").localeCompare(a.completed_at || "")),
  };
}

// ---- Recurrence (same rules as Recurrence in core/models.py) ---------------------------------

// The next period after `period` that has not already ended before today.
export function nextPeriod(recurrence, period, today) {
  const interval = recurrence.interval || 1;
  const weekdays = recurrence.unit === "week" ? recurrence.weekdays || [] : [];
  if (weekdays.length && period.granularity === "day") {
    // Weeks are counted from the week of the current due day, so "every other week" stays in step.
    const start = parseISO(period.start);
    const anchor = addDays(start, -weekdayIndex(start));
    for (let day = addDays(start, 1); ; day = addDays(day, 1)) {
      const weeks = Math.floor(Math.round((day - anchor) / 864e5) / 7);
      if (weeks % interval === 0 && weekdays.includes(weekdayIndex(day)) && day >= today) return makePeriod("day", day);
    }
  }
  let following = shiftPeriod(period, interval, recurrence.unit);
  while (periodEndOf(following) < today) {
    const after = shiftPeriod(following, interval, recurrence.unit);
    if (after.start <= following.start) break; // a unit finer than the period ("daily" on a week) does not move it
    following = after;
  }
  return following;
}

// The due periods a recurring task will get after its current one, up to those starting on `until`:
// what completing it again and again would create. Empty for tasks that do not repeat or are completed.
export function projectedPeriods(task, until, today, limit = 2000) {
  if (!task.recurrence || !task.due || task.completed) return [];
  const last = toISO(until);
  const periods = [];
  let period = task.due;
  while (periods.length < limit) {
    const next = nextPeriod(task.recurrence, period, today);
    if (next.start <= period.start || next.start > last) break;
    periods.push(next);
    period = next;
  }
  return periods;
}

// Everything due on `day`: tasks whose due period contains it, plus previews of recurring tasks that will be due
// then but do not exist yet (they are created when completing the current one). A preview is a copy of the task
// with that due period and `preview: true`; it keeps the task's id.
export function dayTasks(tasks, day, today) {
  const iso = toISO(day);
  const contains = (period) => period.start <= iso && toISO(periodEndOf(period)) >= iso;
  const result = [];
  for (const task of tasks) {
    if (task.due && contains(task.due)) result.push(task);
    const due = projectedPeriods(task, day, today).find(contains);
    if (due) result.push({ ...task, due, preview: true });
  }
  return result;
}

// Order within a day: by time of day, then priority, then the manual order.
export function sortByTime(tasks) {
  return [...tasks].sort((a, b) => (a.due_time || "99").localeCompare(b.due_time || "99") || b.priority - a.priority || a.position - b.position);
}
