"""Read session history from Claude Code and Cursor Agent JSONL files."""

from __future__ import annotations

import json
import os
import re
from dataclasses import dataclass, field
from datetime import datetime, timezone
from pathlib import Path


CLAUDE_PROJECTS_DIR = Path.home() / ".claude" / "projects"
CURSOR_PROJECTS_DIR = Path.home() / ".cursor" / "projects"


class Backend:
    CLAUDE = "claude"
    CURSOR = "cursor"


@dataclass
class SessionMessage:
    """A single message in a session conversation."""

    role: str  # "user" or "assistant"
    content: str
    timestamp: str = ""
    tool_name: str = ""

    @property
    def display(self) -> str:
        if self.tool_name:
            return f"[tool: {self.tool_name}] {self.content}"
        return self.content


@dataclass
class HistoricSession:
    """A past session parsed from a JSONL file."""

    session_id: str
    slug: str
    cwd: str
    project_dir_key: str
    first_prompt: str
    timestamp: str  # ISO 8601
    backend: str = Backend.CLAUDE
    messages: list[SessionMessage] = field(default_factory=list)
    cost_usd: float = 0.0
    model: str = ""

    @property
    def project_name(self) -> str:
        parts = self.project_dir_key.strip("-").split("-")
        return parts[-1] if parts else self.project_dir_key

    @property
    def project_path(self) -> str:
        if self.cwd:
            return self.cwd
        return "/" + self.project_dir_key.lstrip("-").replace("-", "/")

    @property
    def display_name(self) -> str:
        return self.slug or self.first_prompt[:50] or self.session_id[:8]

    @property
    def display_time(self) -> str:
        try:
            dt = datetime.fromisoformat(self.timestamp.replace("Z", "+00:00"))
            return dt.strftime("%b %d, %H:%M")
        except (ValueError, AttributeError):
            return ""

    @property
    def datetime_obj(self) -> datetime:
        try:
            return datetime.fromisoformat(self.timestamp.replace("Z", "+00:00"))
        except (ValueError, AttributeError):
            return datetime.min.replace(tzinfo=timezone.utc)

    @property
    def backend_tag(self) -> str:
        return "C" if self.backend == Backend.CLAUDE else "R"


# ---------------------------------------------------------------------------
# Claude Code parser
# ---------------------------------------------------------------------------

def _parse_claude_session(path: Path, project_dir_key: str) -> HistoricSession | None:
    session_id = path.stem
    slug = ""
    cwd = ""
    first_prompt = ""
    timestamp = ""
    model = ""
    cost_usd = 0.0
    messages: list[SessionMessage] = []

    try:
        with open(path, "r", encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                try:
                    obj = json.loads(line)
                except json.JSONDecodeError:
                    continue

                etype = obj.get("type", "")

                if etype == "user":
                    if not slug:
                        slug = obj.get("slug", "")
                    if not cwd:
                        cwd = obj.get("cwd", "")
                    if not timestamp:
                        timestamp = obj.get("timestamp", "")

                    msg = obj.get("message", {})
                    content = msg.get("content", "")
                    if isinstance(content, str) and content.strip():
                        if not first_prompt:
                            first_prompt = content.strip()
                        messages.append(SessionMessage(
                            role="user",
                            content=content.strip(),
                            timestamp=obj.get("timestamp", ""),
                        ))

                elif etype == "assistant":
                    msg = obj.get("message", {})
                    if not model:
                        model = msg.get("model", "")
                    _extract_assistant_blocks(msg, messages, obj.get("timestamp", ""))

                elif etype == "result":
                    cost_usd = obj.get("cost_usd", 0.0) or 0.0

    except (OSError, UnicodeDecodeError):
        return None

    if not first_prompt and not messages:
        return None

    return HistoricSession(
        session_id=session_id,
        slug=slug,
        cwd=cwd,
        project_dir_key=project_dir_key,
        first_prompt=first_prompt,
        timestamp=timestamp,
        backend=Backend.CLAUDE,
        messages=messages,
        cost_usd=cost_usd,
        model=model,
    )


# ---------------------------------------------------------------------------
# Cursor Agent parser
# ---------------------------------------------------------------------------

_USER_QUERY_RE = re.compile(r"<user_query>\s*(.*?)\s*</user_query>", re.DOTALL)


def _parse_cursor_session(path: Path, project_dir_key: str) -> HistoricSession | None:
    session_id = path.stem
    messages: list[SessionMessage] = []
    first_prompt = ""

    try:
        mtime = os.path.getmtime(path)
        timestamp = datetime.fromtimestamp(mtime, tz=timezone.utc).isoformat()
    except OSError:
        timestamp = ""

    # Derive cwd from project_dir_key (e.g. "Users-foo-code-bar" -> "/Users/foo/code/bar")
    cwd = "/" + project_dir_key.lstrip("-").replace("-", "/")

    try:
        with open(path, "r", encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                try:
                    obj = json.loads(line)
                except json.JSONDecodeError:
                    continue

                role = obj.get("role", "")
                msg = obj.get("message", {})

                if role == "user":
                    text = _extract_text_from_blocks(msg.get("content", []))
                    # Strip <user_query> wrapper if present
                    m = _USER_QUERY_RE.search(text)
                    if m:
                        text = m.group(1).strip()
                    if text:
                        if not first_prompt:
                            first_prompt = text
                        messages.append(SessionMessage(role="user", content=text))

                elif role == "assistant":
                    text = _extract_text_from_blocks(msg.get("content", []))
                    if text:
                        messages.append(SessionMessage(role="assistant", content=text))

    except (OSError, UnicodeDecodeError):
        return None

    if not first_prompt and not messages:
        return None

    return HistoricSession(
        session_id=session_id,
        slug="",
        cwd=cwd,
        project_dir_key=project_dir_key,
        first_prompt=first_prompt,
        timestamp=timestamp,
        backend=Backend.CURSOR,
        messages=messages,
    )


# ---------------------------------------------------------------------------
# Shared helpers
# ---------------------------------------------------------------------------

def _extract_text_from_blocks(content: list | str) -> str:
    if isinstance(content, str):
        return content.strip()
    parts: list[str] = []
    for block in content:
        if isinstance(block, str):
            parts.append(block)
        elif isinstance(block, dict) and block.get("type") == "text":
            parts.append(block.get("text", ""))
    return "\n".join(parts).strip()


def _extract_assistant_blocks(
    msg: dict,
    messages: list[SessionMessage],
    ts: str,
) -> None:
    for block in msg.get("content", []):
        btype = block.get("type", "")
        if btype == "text":
            text = block.get("text", "").strip()
            if text:
                messages.append(SessionMessage(
                    role="assistant", content=text, timestamp=ts,
                ))
        elif btype == "tool_use":
            name = block.get("name", "")
            inp = block.get("input", {})
            summary = _tool_summary(name, inp)
            messages.append(SessionMessage(
                role="assistant", content=summary, timestamp=ts, tool_name=name,
            ))


def _tool_summary(name: str, inp: dict) -> str:
    if name == "Bash":
        return inp.get("command", "")[:120]
    if name in ("Read", "Edit", "Write"):
        return inp.get("file_path", inp.get("path", ""))
    if name == "Grep":
        return f'/{inp.get("pattern", "")}/'
    if name == "Glob":
        return inp.get("pattern", inp.get("glob_pattern", ""))
    if name == "Task":
        return inp.get("description", "")[:80]
    if name == "WebFetch":
        return inp.get("url", "")[:80]
    if name == "TodoWrite":
        return "update todos"
    return str(inp)[:60]


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

def load_all_sessions() -> list[HistoricSession]:
    """Load all sessions from both Claude and Cursor, sorted newest-first."""
    sessions: list[HistoricSession] = []

    if CLAUDE_PROJECTS_DIR.exists():
        for project_dir in CLAUDE_PROJECTS_DIR.iterdir():
            if not project_dir.is_dir():
                continue
            project_key = project_dir.name
            for jsonl_file in project_dir.glob("*.jsonl"):
                session = _parse_claude_session(jsonl_file, project_key)
                if session:
                    sessions.append(session)

    if CURSOR_PROJECTS_DIR.exists():
        for project_dir in CURSOR_PROJECTS_DIR.iterdir():
            if not project_dir.is_dir():
                continue
            project_key = project_dir.name
            transcripts_dir = project_dir / "agent-transcripts"
            if transcripts_dir.is_dir():
                for jsonl_file in transcripts_dir.glob("*.jsonl"):
                    session = _parse_cursor_session(jsonl_file, project_key)
                    if session:
                        sessions.append(session)

    sessions.sort(key=lambda s: s.datetime_obj, reverse=True)
    return sessions


def load_sessions_for_project(project_path: str) -> list[HistoricSession]:
    """Load sessions whose cwd matches project_path, sorted newest-first."""
    all_sessions = load_all_sessions()
    resolved = str(Path(project_path).expanduser().resolve())
    return [s for s in all_sessions if s.cwd == resolved or s.project_path == resolved]
