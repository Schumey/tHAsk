"""Attachments: files of a task in `config/thask_attachments/<task id>/<attachment id>` (part of backups).

Upload and download go over HTTP (`/api/thask/attachments/...`), with the usual HA authentication: a bearer token,
or for links in the browser a path signed with `auth/sign_path`. Deleting goes over the WebSocket API.
"""

from __future__ import annotations

import mimetypes
from pathlib import Path
from urllib.parse import quote

from aiohttp import web

from homeassistant.components.http import KEY_HASS, HomeAssistantView
from homeassistant.core import HomeAssistant

from .core.collection import NotFoundError
from .core.files import ATTACHMENTS_DIR, remove_task_files
from .core.models import Attachment, new_id
from .data import async_get_data

# Home Assistant accepts requests up to 16 MB; leave room for the multipart overhead.
MAX_SIZE = 15 * 1024 * 1024
URL = "/api/thask/attachments"


def attachments_root(hass: HomeAssistant) -> Path:
    return Path(hass.config.path(ATTACHMENTS_DIR))


def attachment_path(hass: HomeAssistant, task_id: str, attachment_id: str) -> Path:
    # Both ids come from the collection (uuid hex), never straight from a request.
    return attachments_root(hass) / task_id / attachment_id


def _write(path: Path, content: bytes) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(content)


class AttachmentUploadView(HomeAssistantView):
    """POST a file (multipart field `file`) to a task; answers with the new attachment."""

    url = URL + "/{task_id}"
    name = "api:thask:attachments"
    requires_auth = True

    async def post(self, request: web.Request, task_id: str) -> web.Response:
        hass = request.app[KEY_HASS]
        data = async_get_data(hass)
        if task_id not in data.collection.tasks:
            return self.json_message("Task not found", 404)
        reader = await request.multipart()
        field = await reader.next()
        while field is not None and field.name != "file":
            field = await reader.next()
        if field is None or not field.filename:
            return self.json_message("No file", 400)
        content = bytearray()
        while chunk := await field.read_chunk():
            content.extend(chunk)
            if len(content) > MAX_SIZE:
                return self.json_message(f"File larger than {MAX_SIZE // (1024 * 1024)} MB", 413)
        name = Path(field.filename.replace("\\", "/")).name or "file"
        content_type = field.headers.get("Content-Type") or ""
        if not content_type or content_type == "application/octet-stream":
            content_type = mimetypes.guess_type(name)[0] or "application/octet-stream"
        attachment = Attachment(id=new_id(), name=name, size=len(content), content_type=content_type)
        await hass.async_add_executor_job(_write, attachment_path(hass, task_id, attachment.id), bytes(content))
        try:
            data.collection.add_attachment(task_id, attachment)
        except NotFoundError:
            # The task was deleted during the upload.
            await hass.async_add_executor_job(remove_task_files, attachments_root(hass), task_id)
            return self.json_message("Task not found", 404)
        return self.json(attachment.as_dict())


class AttachmentView(HomeAssistantView):
    """GET a file; `?download=1` asks the browser to save it instead of showing it."""

    url = URL + "/{task_id}/{attachment_id}"
    name = "api:thask:attachment"
    requires_auth = True

    async def get(self, request: web.Request, task_id: str, attachment_id: str) -> web.StreamResponse:
        hass = request.app[KEY_HASS]
        data = async_get_data(hass)
        try:
            attachment = data.collection.get_attachment(task_id, attachment_id)
        except NotFoundError:
            return self.json_message("Attachment not found", 404)
        path = attachment_path(hass, task_id, attachment.id)
        if not await hass.async_add_executor_job(path.is_file):
            return self.json_message("File missing", 404)
        disposition = "attachment" if request.query.get("download") else "inline"
        return web.FileResponse(
            path,
            headers={
                "Content-Type": attachment.content_type,
                "Content-Disposition": f"{disposition}; filename*=UTF-8''{quote(attachment.name)}",
                # Uploaded HTML or SVG must not run as a page of Home Assistant.
                "Content-Security-Policy": "sandbox",
                "X-Content-Type-Options": "nosniff",
            },
        )


def async_register_views(hass: HomeAssistant) -> None:
    hass.http.register_view(AttachmentUploadView())
    hass.http.register_view(AttachmentView())
