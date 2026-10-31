// Shared by the tHAsk panel and the dashboard card: dates, periods and the smart views.

export const MONTHS = {
  de: ["Januar", "Februar", "März", "April", "Mai", "Juni", "Juli", "August", "September", "Oktober", "November", "Dezember"],
  en: ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"],
};
export const MONTHS_SHORT = {
  de: ["Jan.", "Feb.", "März", "Apr.", "Mai", "Juni", "Juli", "Aug.", "Sep.", "Okt.", "Nov.", "Dez."],
  en: ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"],
};
export const WEEKDAYS_SHORT = { de: ["Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"], en: ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"] };
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

export function shiftPeriod(period, count) {
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

export function periodRange(period, lang) {
  if (period.granularity === "day") return "";
  const start = parseISO(period.start);
  const end = periodEndOf(period);
  const fmt = (d) => d.toLocaleDateString(lang === "de" ? "de-DE" : "en-GB", { day: "numeric", month: "short" });
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

// Whether a task belongs to a smart view. `ctx`: { today, overdueMode, importantRange }.
export function matchesSmart(task, key, ctx) {
  const { today } = ctx;
  switch (key) {
    case "my_day":
      // Today: everything due by today, and what was completed today. Overdue tasks may have a view of their own.
      if (!dueBy(task, today)) return false;
      if (task.completed) return completedSince(task, today);
      return ctx.overdueMode !== "separate" || !isOverdue(task, today);
    case "overdue":
      return isOverdue(task, today);
    case "important":
      if (task.priority < 3) return false;
      if (!ctx.importantRange || ctx.importantRange === "all") return true;
      return dueBy(task, periodEnd(ctx.importantRange, periodStart(ctx.importantRange, today)));
    case "planned":
      return !!task.due;
    case "this_week":
      if (!dueBy(task, periodEnd("week", periodStart("week", today)))) return false;
      return !task.completed || completedSince(task, periodStart("week", today));
    case "this_month":
      if (!dueBy(task, periodEnd("month", periodStart("month", today)))) return false;
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
