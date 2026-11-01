"""Constants for tHAsk."""

DOMAIN = "thask"

STORAGE_KEY = f"{DOMAIN}.data"
STORAGE_KEY_TRIGGERS = f"{DOMAIN}.triggers"
STORAGE_VERSION = 1
SAVE_DELAY = 1

# Dispatched shortly after midnight so date dependent views (My Day, This week) refresh.
SIGNAL_DAY_CHANGED = f"{DOMAIN}_day_changed"

PANEL_URL_PATH = DOMAIN
PANEL_STATIC_URL = f"/{DOMAIN}_static"

EVENT_TASK_DUE = f"{DOMAIN}_task_due"
EVENT_TASK_OVERDUE = f"{DOMAIN}_task_overdue"
EVENT_REMINDER = f"{DOMAIN}_reminder"
EVENT_TRIGGER_FIRED = f"{DOMAIN}_trigger_fired"

# Triggers are checked this often.
TRIGGER_INTERVAL_SECONDS = 60

# Dispatched when triggers or their runs change, for the panel.
SIGNAL_TRIGGERS_CHANGED = f"{DOMAIN}_triggers_changed"

# Dispatched when the options of the entry change.
SIGNAL_OPTIONS_CHANGED = f"{DOMAIN}_options_changed"

# Option: how "Today" shows overdue tasks. "section": at the top under their own heading,
# "mixed": among today's tasks, "separate": not in "Today" but in a view "Overdue" of their own.
CONF_OVERDUE = "overdue_in_today"
OVERDUE_MODES = ("section", "mixed", "separate")
DEFAULT_OVERDUE = "section"

# Options: keep the smart views apart. "separate_week": "Today" only has tasks due on a day (and overdue
# ones), periods such as "week 44" go to "This week", which leaves out what "Today" shows.
# "separate_month": "This month" only has what is due after this week.
CONF_SEPARATE_WEEK = "separate_week"
CONF_SEPARATE_MONTH = "separate_month"

# Option: what "This week" covers. "calendar": Monday to Sunday, "rolling": today and the next seven days.
CONF_WEEK_MODE = "week_mode"
WEEK_MODES = ("calendar", "rolling")
DEFAULT_WEEK_MODE = "calendar"

# Option: smart views left out of the navigation (web interface, apps, widget). "Today" always stays.
CONF_HIDDEN_VIEWS = "hidden_views"
HIDEABLE_VIEWS = ("important", "planned", "this_week", "this_month")

# Option: delete completed tasks automatically this many days after completion (0 = never). Runs at start,
# after midnight and when the option changes.
CONF_AUTO_CLEAR_DAYS = "auto_clear_days"

# Option: which priorities "Important" shows. "high" (default) or "medium" (medium and high).
CONF_IMPORTANT_PRIORITY = "important_priority"
IMPORTANT_PRIORITIES = ("high", "medium")

# Defaults of all options, also for the settings page in the web interface.
DEFAULT_OPTIONS = {
    "overdue_in_today": "section",
    CONF_SEPARATE_WEEK: False,
    CONF_SEPARATE_MONTH: False,
    CONF_WEEK_MODE: DEFAULT_WEEK_MODE,
    CONF_HIDDEN_VIEWS: [],
    CONF_AUTO_CLEAR_DAYS: 0,
    CONF_IMPORTANT_PRIORITY: "high",
    "reminder_targets": [],
}

# Option: notify services (notify.<name>) that receive reminders.
CONF_REMINDER_TARGETS = "reminder_targets"

# Dispatched with the task info when a reminder is due, for the apps.
SIGNAL_REMINDER = f"{DOMAIN}_reminder"

# Action of the "Done" button on companion app notifications; the task id follows.
NOTIFY_ACTION_DONE = "THASK_DONE_"
