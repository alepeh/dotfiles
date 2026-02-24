"""Session management — spawn, track, and control Claude/Cursor sessions."""

from __future__ import annotations

import asyncio
import json
import time
import uuid
from dataclasses import dataclass, field
from enum import Enum
from pathlib import Path


class Backend(Enum):
    CLAUDE = "claude"
    CURSOR = "cursor"


class Status(Enum):
    STARTING = "starting"
    THINKING = "thinking"
    TOOL_USE = "tool_use"
    STREAMING = "streaming"
    DONE = "done"
    ERROR = "error"


@dataclass
class LogLine:
    """A single log entry with category for colour-coding."""

    timestamp: float
    category: str  # system | thinking | text | tool | result | error | killed
    text: str

    @property
    def markup(self) -> str:
        """Rich markup string for RichLog display."""
        styles: dict[str, str] = {
            "system": "dim",
            "thinking": "cyan italic",
            "text": "",
            "tool": "magenta",
            "result": "green",
            "error": "red bold",
            "killed": "red",
        }
        style = styles.get(self.category, "")
        safe = self.text.replace("[", "\\[")
        if style:
            return f"[{style}]\\[{self.category}][/{style}] {safe}"
        return f"\\[{self.category}] {safe}"


@dataclass
class Session:
    """A managed agent session (Claude Code or Cursor)."""

    id: str
    project_dir: str
    prompt: str
    backend: Backend = Backend.CLAUDE
    status: Status = Status.STARTING
    current_tool: str = ""
    last_text: str = ""
    log: list[LogLine] = field(default_factory=list)
    _process: asyncio.subprocess.Process | None = None
    started_at: float = field(default_factory=time.time)
    cost_usd: float = 0.0
    duration_ms: int = 0
    remote_session_id: str = ""

    @property
    def name(self) -> str:
        tag = "C" if self.backend == Backend.CLAUDE else "R"
        return f"[{tag}] {Path(self.project_dir).name}"

    @property
    def display_status(self) -> str:
        if self.status == Status.TOOL_USE and self.current_tool:
            return f"tool:{self.current_tool}"
        return self.status.value

    @property
    def elapsed(self) -> str:
        s = int(time.time() - self.started_at)
        if s < 60:
            return f"{s}s"
        m, s = divmod(s, 60)
        return f"{m}m{s:02d}s"

    @property
    def alive(self) -> bool:
        return self._process is not None and self._process.returncode is None

    def _append(self, category: str, text: str) -> None:
        self.log.append(LogLine(time.time(), category, text))


class SessionManager:
    """Manages multiple concurrent agent sessions."""

    def __init__(self) -> None:
        self.sessions: dict[str, Session] = {}

    async def spawn(
        self,
        project_dir: str,
        prompt: str,
        model: str = "",
        backend: Backend = Backend.CLAUDE,
    ) -> Session:
        sid = uuid.uuid4().hex[:8]
        session = Session(
            id=sid, project_dir=project_dir, prompt=prompt, backend=backend,
        )
        self.sessions[sid] = session

        cmd = self._build_cmd(backend, prompt, model)
        bin_name = cmd[0]

        try:
            proc = await asyncio.create_subprocess_exec(
                *cmd,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE,
                cwd=project_dir,
            )
            session._process = proc
            short = prompt[:60] + ("..." if len(prompt) > 60 else "")
            session._append("system", f"[{backend.value}] Spawned: {short}")
            asyncio.create_task(self._read_stream(session))
        except FileNotFoundError:
            session.status = Status.ERROR
            session._append("error", f"'{bin_name}' command not found in PATH")
        except Exception as exc:
            session.status = Status.ERROR
            session._append("error", str(exc))

        return session

    @staticmethod
    def _build_cmd(backend: Backend, prompt: str, model: str) -> list[str]:
        if backend == Backend.CURSOR:
            cmd = [
                "cursor-agent", "--print", "--force",
                "--output-format", "stream-json",
            ]
            if model:
                cmd.extend(["--model", model])
            cmd.append(prompt)
        else:
            cmd = ["claude", "--print", "--output-format", "stream-json"]
            if model:
                cmd.extend(["--model", model])
            cmd.extend(["-p", prompt])
        return cmd

    # ------------------------------------------------------------------
    # Stream reader
    # ------------------------------------------------------------------

    async def _read_stream(self, session: Session) -> None:
        proc = session._process
        assert proc and proc.stdout

        while True:
            line = await proc.stdout.readline()
            if not line:
                break
            raw = line.decode("utf-8", errors="replace").strip()
            if not raw:
                continue
            try:
                event = json.loads(raw)
                self._handle_event(session, event)
            except json.JSONDecodeError:
                session._append("text", raw)

        rc = await proc.wait()
        if session.status not in (Status.DONE, Status.ERROR):
            if rc == 0:
                session.status = Status.DONE
                session._append("system", "Session completed")
            else:
                session.status = Status.ERROR
                if proc.stderr:
                    err = await proc.stderr.read()
                    if err:
                        session._append(
                            "error",
                            err.decode("utf-8", errors="replace").strip(),
                        )

    # ------------------------------------------------------------------
    # Event parser — translates stream-json into status + log entries
    # ------------------------------------------------------------------

    def _handle_event(self, session: Session, event: dict) -> None:
        etype = event.get("type", "")

        if etype == "system":
            sub = event.get("subtype", "")
            if sub == "init":
                session.status = Status.STREAMING
                # Claude uses "sessionId", Cursor uses "session_id"
                sid = (
                    event.get("sessionId", "")
                    or event.get("session_id", "")
                )
                if sid:
                    session.remote_session_id = sid
                session._append("system", "Initialized")
            else:
                session._append("system", sub or "system event")

        elif etype == "assistant":
            msg = event.get("message", {})
            for block in msg.get("content", []):
                btype = block.get("type", "")

                if btype == "thinking":
                    session.status = Status.THINKING
                    text = block.get("thinking", "")
                    if text:
                        session._append(
                            "thinking",
                            text[:300].replace("\n", " "),
                        )

                elif btype == "text":
                    session.status = Status.STREAMING
                    text = block.get("text", "")
                    if text:
                        session.last_text = text[:80]
                        for tline in text.split("\n"):
                            session._append("text", tline)

                elif btype == "tool_use":
                    session.status = Status.TOOL_USE
                    name = block.get("name", "?")
                    session.current_tool = name
                    inp = block.get("input", {})
                    summary = self._tool_summary(name, inp)
                    session._append("tool", f"{name}: {summary}")

        # Cursor emits tool_call events (started/completed) separately
        elif etype == "tool_call":
            sub = event.get("subtype", "")
            if sub == "started":
                session.status = Status.TOOL_USE
                tc = event.get("tool_call", {})
                name = tc.get("name", "")
                if name:
                    inp = tc.get("input", {})
                    summary = self._tool_summary(name, inp)
                else:
                    name, summary = self._parse_cursor_tool(tc)
                session.current_tool = name
                session._append("tool", f"{name}: {summary}")

        elif etype == "result":
            sub = event.get("subtype", "")
            if sub == "success":
                session.status = Status.DONE
                session.cost_usd = event.get("cost_usd", 0)
                session.duration_ms = event.get("duration_ms", 0)
                # Capture session_id from result too (Cursor puts it here)
                sid = (
                    event.get("sessionId", "")
                    or event.get("session_id", "")
                )
                if sid and not session.remote_session_id:
                    session.remote_session_id = sid
                result = event.get("result", "")
                if result:
                    for rline in str(result)[:500].split("\n"):
                        session._append("result", rline)
                session._append(
                    "system",
                    f"Done — ${session.cost_usd:.4f} / {session.duration_ms}ms",
                )
            elif sub == "error":
                session.status = Status.ERROR
                session._append("error", event.get("error", "unknown"))

    @staticmethod
    def _tool_summary(name: str, inp: dict) -> str:
        if name == "Bash":
            return inp.get("command", "")[:120]
        if name in ("Read", "Edit", "Write"):
            return inp.get("file_path", "")
        if name == "Grep":
            return f'/{inp.get("pattern", "")}/'
        if name == "Glob":
            return inp.get("pattern", "")
        if name == "Task":
            return inp.get("description", "")
        if name == "WebFetch":
            return inp.get("url", "")[:80]
        return str(inp)[:80]

    @staticmethod
    def _parse_cursor_tool(tc: dict) -> tuple[str, str]:
        """Extract tool name and summary from Cursor's tool_call dict.

        Cursor uses keys like readToolCall, shellToolCall, writeToolCall,
        deleteToolCall rather than a generic name + input structure.
        """
        for key, val in tc.items():
            if key.endswith("ToolCall"):
                name = key.replace("ToolCall", "")
                if isinstance(val, dict):
                    summary = (
                        val.get("command", "")
                        or val.get("path", "")
                        or val.get("pattern", "")
                        or str(val)[:80]
                    )
                    return name, summary
        return "unknown", str(tc)[:80]

    # ------------------------------------------------------------------
    # Lifecycle
    # ------------------------------------------------------------------

    async def kill(self, session_id: str) -> None:
        session = self.sessions.get(session_id)
        if not session or not session._process:
            return
        session._process.terminate()
        try:
            await asyncio.wait_for(session._process.wait(), timeout=5)
        except asyncio.TimeoutError:
            session._process.kill()
        session.status = Status.ERROR
        session._append("killed", "Terminated by user")

    def remove(self, session_id: str) -> None:
        session = self.sessions.get(session_id)
        if session and session.alive:
            return  # refuse to remove a running session
        self.sessions.pop(session_id, None)
