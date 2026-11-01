"""Files of attachments on disk: `<config>/thask_attachments/<task id>/<attachment id>`."""

from __future__ import annotations

from pathlib import Path
import shutil

ATTACHMENTS_DIR = "thask_attachments"


def remove_task_files(root: Path, task_id: str) -> None:
    shutil.rmtree(root / task_id, ignore_errors=True)


def remove_orphans(root: Path, task_ids: set[str]) -> int:
    """Delete folders of tasks that no longer exist (e.g. deleted while HA was down); returns how many."""
    if not root.is_dir():
        return 0
    removed = 0
    for folder in root.iterdir():
        if folder.is_dir() and folder.name not in task_ids:
            shutil.rmtree(folder, ignore_errors=True)
            removed += 1
    return removed
