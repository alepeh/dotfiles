"""Textual TUI application for Claude Code / Cursor agent process management."""

from __future__ import annotations

import subprocess
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
    RadioButton,
    RadioSet,
    RichLog,
    Static,
)

from claude_tui.config import CONFIG_FILE, Preset, load_presets
from claude_tui.session import Backend, Session, SessionManager, Status


# -----------------------------------------------------------------------
# Help screen
# -----------------------------------------------------------------------

HELP_TEXT = """\
[bold]Claude TUI — Keybindings[/bold]

[bold cyan]Session management[/bold cyan]
  [bold]n[/bold]  Spawn a new session (manual prompt)
  [bold]p[/bold]  Spawn from a saved preset
  [bold]b[/bold]  Batch-spawn all presets at once
  [bold]d[/bold]  Kill the selected session
  [bold]x[/bold]  Remove a finished session from the list

[bold cyan]Navigation[/bold cyan]
  [bold]j / k[/bold]      Move down / up in session list
  [bold]up / down[/bold]  Move down / up in session list

[bold cyan]Interaction[/bold cyan]
  [bold]a[/bold]  Attach — suspend TUI, open interactive session
      in the selected session's project directory.
      If the session is done, forks/resumes its conversation.

[bold cyan]Other[/bold cyan]
  [bold]?[/bold]  Show this help
  [bold]q[/bold]  Quit

[bold cyan]Backends[/bold cyan]
  Both [bold]Claude Code[/bold] (\\[C]) and [bold]Cursor Agent[/bold] (\\[R])
  are supported. Choose the backend when spawning.
  Sessions show \\[C] or \\[R] prefix in the sidebar.

[bold cyan]Presets[/bold cyan]
  Save presets in [dim]~/.config/claude-tui/config.toml[/dim]:

  [dim]\\[\\[presets]]
  name = "My task"
  project_dir = "~/code/project"
  prompt = "Run tests and fix failures"
  model = "sonnet"     # optional
  backend = "cursor"   # optional, default "claude"[/dim]
"""


class HelpScreen(ModalScreen):
    """Overlay showing all keybindings."""

    BINDINGS = [
        Binding("escape", "dismiss", "Close"),
        Binding("question_mark", "dismiss", "Close"),
    ]

    DEFAULT_CSS = """
    HelpScreen {
        align: center middle;
    }
    #help-dialog {
        width: 68;
        height: auto;
        max-height: 80%;
        border: thick $accent;
        background: $surface;
        padding: 1 2;
        overflow-y: auto;
    }
    #help-dialog .buttons {
        margin-top: 1;
        align: center middle;
    }
    """

    def compose(self) -> ComposeResult:
        with Vertical(id="help-dialog"):
            yield Static(HELP_TEXT, markup=True)
            with Horizontal(classes="buttons"):
                yield Button("Close", id="close")

    def on_button_pressed(self, event: Button.Pressed) -> None:
        self.dismiss()


# -----------------------------------------------------------------------
# Spawn dialog
# -----------------------------------------------------------------------


class SpawnScreen(ModalScreen[dict | None]):
    """Modal dialog to configure and spawn a new session."""

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
    #dialog RadioSet {
        height: auto;
        margin-top: 0;
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
            yield Label("[bold]New Session[/bold]")
            yield Label("Backend:")
            with RadioSet(id="backend-set"):
                yield RadioButton("Claude Code", value=True, id="rb-claude")
                yield RadioButton("Cursor Agent", id="rb-cursor")
            yield Label("Project directory:")
            yield Input(
                placeholder="/path/to/project",
                id="dir-input",
                value=str(Path.cwd()),
            )
            yield Label("Prompt:")
            yield Input(placeholder="What should the agent do?", id="prompt-input")
            yield Label("Model (optional):")
            yield Input(placeholder="e.g. sonnet, opus, gpt-5", id="model-input")
            with Horizontal(classes="buttons"):
                yield Button("Cancel", id="cancel")
                yield Button("Spawn", variant="primary", id="spawn")

    def _get_result(self) -> dict | None:
        d = self.query_one("#dir-input", Input).value.strip()
        p = self.query_one("#prompt-input", Input).value.strip()
        m = self.query_one("#model-input", Input).value.strip()
        if not (d and p):
            return None
        is_claude = self.query_one("#rb-claude", RadioButton).value
        return {
            "project_dir": d,
            "prompt": p,
            "model": m,
            "backend": "claude" if is_claude else "cursor",
        }

    def on_button_pressed(self, event: Button.Pressed) -> None:
        if event.button.id == "spawn":
            result = self._get_result()
            if result:
                self.dismiss(result)
                return
        self.dismiss(None)

    def on_input_submitted(self, event: Input.Submitted) -> None:
        """Enter in the prompt field submits the form."""
        if event.input.id == "prompt-input":
            self.query_one("#spawn", Button).press()

    def action_dismiss_modal(self) -> None:
        self.dismiss(None)


# -----------------------------------------------------------------------
# Preset picker
# -----------------------------------------------------------------------


class PresetItem(ListItem):
    """A preset entry in the picker."""

    def __init__(self, preset: Preset) -> None:
        super().__init__()
        self.preset = preset

    def compose(self) -> ComposeResult:
        t = Text()
        tag = "C" if self.preset.backend == "claude" else "R"
        t.append(f"[{tag}] ", style="dim bold")
        t.append(self.preset.name, style="bold")
        if self.preset.model:
            t.append(f"  ({self.preset.model})", style="dim")
        t.append(f"\n    {self.preset.resolved_dir}", style="dim")
        t.append(f"\n    {self.preset.prompt[:55]}", style="italic")
        yield Static(t)


class PresetScreen(ModalScreen[Preset | None]):
    """Pick a preset to spawn."""

    BINDINGS = [Binding("escape", "dismiss_modal", "Cancel")]

    DEFAULT_CSS = """
    PresetScreen {
        align: center middle;
    }
    #preset-dialog {
        width: 72;
        height: auto;
        max-height: 70%;
        border: thick $accent;
        background: $surface;
        padding: 1 2;
    }
    #preset-dialog Label {
        margin-bottom: 1;
    }
    #preset-list {
        height: auto;
        max-height: 20;
    }
    #preset-dialog .buttons {
        margin-top: 1;
        align: right middle;
    }
    #preset-dialog .buttons Button {
        margin-left: 1;
    }
    PresetItem {
        padding: 0 1;
        height: auto;
        min-height: 4;
    }
    PresetItem:hover {
        background: $boost;
    }
    """

    def compose(self) -> ComposeResult:
        presets = load_presets()
        with Vertical(id="preset-dialog"):
            if not presets:
                yield Label(
                    f"[bold]No presets found.[/bold]\n\n"
                    f"Create [dim]{CONFIG_FILE}[/dim] with preset entries.\n"
                    f"See config.example.toml in the claude-tui directory."
                )
            else:
                yield Label("[bold]Select a preset:[/bold]")
                lv = ListView(id="preset-list")
                for p in presets:
                    lv.append(PresetItem(p))  # type: ignore[arg-type]
                yield lv
            with Horizontal(classes="buttons"):
                yield Button("Cancel", id="cancel")

    def on_list_view_selected(self, event: ListView.Selected) -> None:
        if isinstance(event.item, PresetItem):
            self.dismiss(event.item.preset)

    def on_button_pressed(self, event: Button.Pressed) -> None:
        self.dismiss(None)

    def action_dismiss_modal(self) -> None:
        self.dismiss(None)


# -----------------------------------------------------------------------
# Session list item
# -----------------------------------------------------------------------


class SessionItem(ListItem):
    """Sidebar entry representing one agent session."""

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
# Helpers
# -----------------------------------------------------------------------


def _backend_from_str(val: str) -> Backend:
    return Backend.CURSOR if val == "cursor" else Backend.CLAUDE


# -----------------------------------------------------------------------
# Main application
# -----------------------------------------------------------------------


class ClaudeTUI(App):
    """TUI process manager for Claude Code / Cursor Agent sessions."""

    CSS_PATH = "app.tcss"
    TITLE = "Claude TUI"

    BINDINGS = [
        Binding("n", "spawn", "New"),
        Binding("p", "preset_spawn", "Preset"),
        Binding("b", "batch_spawn", "Batch"),
        Binding("a", "attach", "Attach"),
        Binding("d", "kill_session", "Kill"),
        Binding("x", "remove_session", "Remove"),
        Binding("question_mark", "help", "Help"),
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
                    "No sessions.  Press [bold]n[/bold] to spawn, "
                    "[bold]p[/bold] for presets, or [bold]?[/bold] for help.",
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
            header.update(
                "No sessions.  Press [bold]n[/bold] to spawn, "
                "[bold]p[/bold] for presets, or [bold]?[/bold] for help."
            )

    # ------------------------------------------------------------------
    # Event handlers
    # ------------------------------------------------------------------

    def on_list_view_highlighted(self, event: ListView.Highlighted) -> None:
        if event.item and isinstance(event.item, SessionItem):
            self.selected_id = event.item.session_ref.id

    # ------------------------------------------------------------------
    # Actions (key bindings)
    # ------------------------------------------------------------------

    def action_help(self) -> None:
        self.push_screen(HelpScreen())

    async def action_spawn(self) -> None:
        result = await self.push_screen_wait(SpawnScreen())
        if not result:
            return
        backend = _backend_from_str(result.get("backend", "claude"))
        session = await self.manager.spawn(
            project_dir=result["project_dir"],
            prompt=result["prompt"],
            model=result.get("model", ""),
            backend=backend,
        )
        self.selected_id = session.id
        self._sync_session_list()

    async def action_preset_spawn(self) -> None:
        """Pick a single preset and spawn it."""
        preset = await self.push_screen_wait(PresetScreen())
        if not preset:
            return
        backend = _backend_from_str(preset.backend)
        session = await self.manager.spawn(
            project_dir=preset.resolved_dir,
            prompt=preset.prompt,
            model=preset.model,
            backend=backend,
        )
        self.selected_id = session.id
        self._sync_session_list()
        self.notify(f"Spawned: {preset.name}")

    async def action_batch_spawn(self) -> None:
        """Spawn all presets at once."""
        presets = load_presets()
        if not presets:
            self.notify(
                f"No presets. Create {CONFIG_FILE}",
                severity="warning",
            )
            return
        session = None
        for preset in presets:
            backend = _backend_from_str(preset.backend)
            session = await self.manager.spawn(
                project_dir=preset.resolved_dir,
                prompt=preset.prompt,
                model=preset.model,
                backend=backend,
            )
        self._sync_session_list()
        if session:
            self.selected_id = session.id
        self.notify(f"Batch-spawned {len(presets)} sessions")

    def action_attach(self) -> None:
        """Suspend TUI and drop into interactive session in the project dir."""
        if not self.selected_id:
            self.notify("No session selected", severity="warning")
            return
        session = self.manager.sessions.get(self.selected_id)
        if not session:
            return

        if session.backend == Backend.CURSOR:
            cmd = ["cursor-agent"]
            if session.remote_session_id and not session.alive:
                cmd.extend(["--resume", session.remote_session_id])
        else:
            cmd = ["claude"]
            if session.remote_session_id and not session.alive:
                cmd.extend(["-r", session.remote_session_id, "--fork-session"])

        with self.suspend():
            subprocess.run(cmd, cwd=session.project_dir)

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
