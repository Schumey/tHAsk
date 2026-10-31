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
