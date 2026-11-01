from datetime import date
from pathlib import Path

import pytest

from core.collection import NotFoundError, TaskCollection
from core.files import remove_orphans, remove_task_files
from core.models import Attachment, Task

TODAY = date(2026, 11, 4)


def _collection() -> tuple[TaskCollection, Task]:
    collection = TaskCollection()
    task_list = collection.create_list("Aufgaben")
    return collection, collection.create_task(task_list.id, "Steuer")


def test_attachments_are_stored_with_the_task() -> None:
    collection, task = _collection()
    changes = []
    collection.subscribe(changes.append)
    collection.add_attachment(task.id, Attachment(id="a1", name="Bescheid.pdf", size=1234, content_type="application/pdf"))
    assert changes[-1].action == "updated"
    assert changes[-1].item["attachments"][0]["name"] == "Bescheid.pdf"
    restored = Task.from_dict(task.as_dict())
    assert [(a.id, a.name, a.size, a.content_type) for a in restored.attachments] == [
        ("a1", "Bescheid.pdf", 1234, "application/pdf")
    ]


def test_clients_cannot_patch_attachments() -> None:
    collection, task = _collection()
    collection.update_task(task.id, {"attachments": [{"id": "x", "name": "evil", "size": 1}]}, TODAY)
    assert task.attachments == []


def test_remove_attachment() -> None:
    collection, task = _collection()
    collection.add_attachment(task.id, Attachment(id="a1", name="a.txt", size=1))
    assert collection.remove_attachment(task.id, "a1").name == "a.txt"
    assert task.attachments == []
    with pytest.raises(NotFoundError):
        collection.remove_attachment(task.id, "a1")


def test_next_occurrence_has_no_attachments() -> None:
    collection, task = _collection()
    collection.update_task(task.id, {"due": {"granularity": "week", "start": "2026-11-02"}, "recurrence": {"unit": "week"}}, TODAY)
    collection.add_attachment(task.id, Attachment(id="a1", name="a.txt", size=1))
    collection.update_task(task.id, {"completed": True}, TODAY)
    following = [t for t in collection.tasks.values() if t.id != task.id]
    assert len(following) == 1 and following[0].attachments == []


def test_file_cleanup(tmp_path: Path) -> None:
    for task_id in ("keep", "gone"):
        (tmp_path / task_id).mkdir()
        (tmp_path / task_id / "a1").write_bytes(b"x")
    assert remove_orphans(tmp_path, {"keep"}) == 1
    assert (tmp_path / "keep" / "a1").exists() and not (tmp_path / "gone").exists()
    remove_task_files(tmp_path, "keep")
    assert not (tmp_path / "keep").exists()
    assert remove_orphans(tmp_path / "missing", set()) == 0
