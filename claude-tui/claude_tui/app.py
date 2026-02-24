"""Textual TUI application for Claude Code process management."""

from __future__ import annotations

from pathlib import Path

from rich.text import Text
from textual.app import App, ComposeResult
from textual.binding import Binding
from textual.containers import Horizontal, Vertical
from textual.reactive import reactive
from textual.screen import ModalScreen
from textual.widgets import (
    Button,
    Footer,
    Header,
    Input,
    Label,
    ListItem,
    ListView,
    RichLog,
    Static,
)

from claude_tui.session import Session, SessionManager, Status


# -----------------------------------------------------------------------
# Spawn dialog
# -----------------------------------------------------------------------


class SpawnScreen(ModalScreen[dict | None]):
    """Modal dialog to configure and spawn a new Claude Code session."""

    BINDINGS = [Binding("escape", "dismiss_modal", "Cancel")]

    DEFAULT_CSS = """
    SpawnScreen {
        align: center middle;
    }
    #dialog {
        width: 72;
        height: auto;
        border: thick $accent;
        background: $surface;
        padding: 1 2;
    }
    #dialog Label {
        margin-top: 1;
    }
    #dialog Input {
        margin-bottom: 0;
    }
    .buttons {
        margin-top: 1;
        align: right middle;
    }
    .buttons Button {
        margin-left: 1;
    }
    """

    def compose(self) -> ComposeResult:
        with Vertical(id="dialog"):
            yield Label("[bold]New Claude Code Session[/bold]")
            yield Label("Project directory:")
            yield Input(
                placeholder="/path/to/project",
                id="dir-input",
                value=str(Path.cwd()),
            )
            yield Label("Prompt:")
            yield Input(placeholder="What should Claude do?", id="prompt-input")
            yield Label("Model (optional):")
            yield Input(placeholder="e.g. sonnet, opus", id="model-input")
            with Horizontal(classes="buttons"):
                yield Button("Cancel", id="cancel")
                yield Button("Spawn", variant="primary", id="spawn")

    def on_button_pressed(self, event: Button.Pressed) -> None:
        if event.button.id == "spawn":
            d = self.query_one("#dir-input", Input).value.strip()
            p = self.query_one("#prompt-input", Input).value.strip()
            m = self.query_one("#model-input", Input).value.strip()
            if d and p:
                self.dismiss({"project_dir": d, "prompt": p, "model": m})
                return
        self.dismiss(None)

    def on_input_submitted(self, event: Input.Submitted) -> None:
        """Enter in the prompt field submits the form."""
        if event.input.id == "prompt-input":
            self.query_one("#spawn", Button).press()

    def action_dismiss_modal(self) -> None:
        self.dismiss(None)


# -----------------------------------------------------------------------
# Session list item
# -----------------------------------------------------------------------


class SessionItem(ListItem):
    """Sidebar entry representing one Claude Code session."""

    def __init__(self, session: Session) -> None:
        super().__init__()
        self.session_ref = session

    def compose(self) -> ComposeResult:
        yield Static(id="info")

    def refresh_display(self) -> None:
        s = self.session_ref
        colours: dict[Status, str] = {
            Status.STARTING: "yellow",
            Status.THINKING: "cyan",
            Status.TOOL_USE: "magenta",
            Status.STREAMING: "green",
            Status.DONE: "green bold",
            Status.ERROR: "red bold",
        }
        t = Text()
        t.append(s.name, style="bold")
        t.append(f"  {s.elapsed}\n", style="dim")
        t.append(s.display_status, style=colours.get(s.status, "white"))
        if s.cost_usd > 0:
            t.append(f"  ${s.cost_usd:.4f}", style="dim")
        if s.status == Status.STREAMING and s.last_text:
            t.append(f"\n{s.last_text[:38]}", style="dim italic")
        self.query_one("#info", Static).update(t)


# -----------------------------------------------------------------------
# Main application
# -----------------------------------------------------------------------


class ClaudeTUI(App):
    """TUI process manager for Claude Code sessions."""

    CSS_PATH = "app.tcss"
    TITLE = "Claude TUI"

    BINDINGS = [
        Binding("n", "spawn", "New"),
        Binding("d", "kill_session", "Kill"),
        Binding("x", "remove_session", "Remove"),
        Binding("q", "quit", "Quit"),
    ]

    selected_id: reactive[str | None] = reactive(None)

    def __init__(self) -> None:
        super().__init__()
        self.manager = SessionManager()
        self._log_cursors: dict[str, int] = {}

    def compose(self) -> ComposeResult:
        yield Header()
        with Horizontal(id="main"):
            with Vertical(id="sidebar"):
                yield Static(" Sessions", id="sidebar-header")
                yield ListView(id="session-list")
            with Vertical(id="content"):
                yield Static(
                    "No sessions.  Press [bold]n[/bold] to spawn one.",
                    id="content-header",
                )
                yield RichLog(
                    id="log",
                    wrap=True,
                    highlight=True,
                    markup=True,
                    max_lines=5000,
                )
        yield Footer()

    def on_mount(self) -> None:
        self.set_interval(0.5, self._tick)

    # ------------------------------------------------------------------
    # Periodic refresh
    # ------------------------------------------------------------------

    def _tick(self) -> None:
        self._sync_session_list()
        self._append_new_log_lines()

    def _sync_session_list(self) -> None:
        lv = self.query_one("#session-list", ListView)
        items: dict[str, SessionItem] = {}
        for item in lv.query(SessionItem):
            items[item.session_ref.id] = item

        current = set(self.manager.sessions)
        existing = set(items)

        for sid in existing - current:
            items[sid].remove()

        for sid in current - existing:
            lv.append(SessionItem(self.manager.sessions[sid]))

        for item in lv.query(SessionItem):
            item.refresh_display()

    def _append_new_log_lines(self) -> None:
        """Incrementally write only new log lines for the selected session."""
        sid = self.selected_id
        if not sid:
            return
        session = self.manager.sessions.get(sid)
        if not session:
            return

        log_widget = self.query_one("#log", RichLog)
        cursor = self._log_cursors.get(sid, 0)
        new_lines = session.log[cursor:]

        for entry in new_lines:
            log_widget.write(entry.markup)

        self._log_cursors[sid] = len(session.log)

        header = self.query_one("#content-header", Static)
        cost = f" — ${session.cost_usd:.4f}" if session.cost_usd > 0 else ""
        header.update(
            f"[bold]{session.name}[/bold] — "
            f"{session.display_status} — "
            f"{session.elapsed}{cost}"
        )

    # ------------------------------------------------------------------
    # Reactive watcher — clears log when switching sessions
    # ------------------------------------------------------------------

    def watch_selected_id(
        self, old_val: str | None, new_val: str | None
    ) -> None:
        log_widget = self.query_one("#log", RichLog)
        log_widget.clear()

        if new_val:
            # Reset cursor so the full log replays into the widget
            self._log_cursors[new_val] = 0
            self._append_new_log_lines()
        else:
            header = self.query_one("#content-header", Static)
            header.update("No sessions.  Press [bold]n[/bold] to spawn one.")

    # ------------------------------------------------------------------
    # Event handlers
    # ------------------------------------------------------------------

    def on_list_view_highlighted(self, event: ListView.Highlighted) -> None:
        if event.item and isinstance(event.item, SessionItem):
            self.selected_id = event.item.session_ref.id

    # ------------------------------------------------------------------
    # Actions (key bindings)
    # ------------------------------------------------------------------

    async def action_spawn(self) -> None:
        result = await self.push_screen_wait(SpawnScreen())
        if not result:
            return
        session = await self.manager.spawn(
            project_dir=result["project_dir"],
            prompt=result["prompt"],
            model=result.get("model", ""),
        )
        self.selected_id = session.id
        self._sync_session_list()

    async def action_kill_session(self) -> None:
        if self.selected_id:
            await self.manager.kill(self.selected_id)

    def action_remove_session(self) -> None:
        if not self.selected_id:
            return
        session = self.manager.sessions.get(self.selected_id)
        if session and not session.alive:
            self.manager.remove(self.selected_id)
            self.selected_id = None
            self._sync_session_list()
