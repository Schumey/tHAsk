"""Constants for tHAsk."""

DOMAIN = "thask"

STORAGE_KEY = f"{DOMAIN}.data"
STORAGE_VERSION = 1
SAVE_DELAY = 1

# Dispatched shortly after midnight so date dependent views (My Day, This week) refresh.
SIGNAL_DAY_CHANGED = f"{DOMAIN}_day_changed"

EVENT_TASK_DUE = f"{DOMAIN}_task_due"
EVENT_TASK_OVERDUE = f"{DOMAIN}_task_overdue"
EVENT_REMINDER = f"{DOMAIN}_reminder"
