"""Textual TUI for browsing Claude Code / Cursor Agent session history."""

from __future__ import annotations

import os
import subprocess
import tempfile
import time
from pathlib import Path

from rich.text import Text
from textual.app import App, ComposeResult
from textual.binding import Binding
from textual import work
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

from claude_tui.config import (
    CONFIG_FILE,
    Project,
    load_projects,
    remove_project,
    save_project,
    update_project,
)
from claude_tui.sessions import (
    Backend,
    HistoricSession,
    load_all_sessions,
)


# -----------------------------------------------------------------------
# Help screen
# -----------------------------------------------------------------------

HELP_TEXT = """\
[bold]Claude TUI — Keybindings[/bold]

[bold cyan]Session navigation[/bold cyan]
  [bold]j / k[/bold]      Move down / up in session list
  [bold]up / down[/bold]   Move down / up in session list

[bold cyan]Panel navigation[/bold cyan]
  [bold]h[/bold]          Focus session list (sidebar)
  [bold]l[/bold]          Focus conversation log (scroll with arrows)
  [bold]Tab[/bold]        Cycle focus between panels
  [bold]escape[/bold]     Return to session list / clear filter

[bold cyan]Session actions[/bold cyan]
  [bold]r[/bold]  Resume selected session in a zellij dev layout
      Opens agent (resume), helix, shell, lazygit, yazi.
  [bold]n[/bold]  New session — pick a saved project
  [bold]N[/bold]  New session — manual directory entry

[bold cyan]Project management[/bold cyan]
  [bold]a[/bold]  Add a project (save a folder for quick access)
  [bold]p[/bold]  Manage projects (edit / remove)

[bold cyan]Filtering[/bold cyan]
  [bold]/[/bold]  Focus the search/filter bar

[bold cyan]Other[/bold cyan]
  [bold]?[/bold]  Show this help
  [bold]q[/bold]  Quit

[bold cyan]Backends[/bold cyan]
  Sessions show [bold]\\[C][/bold] for Claude Code or [bold]\\[R][/bold] for Cursor Agent.
  Resume uses [dim]claude -r <id> --fork-session[/dim] or
  [dim]cursor-agent --resume <id>[/dim] inside the zellij layout.

[bold cyan]Projects[/bold cyan]
  Save projects in [dim]~/.config/claude-tui/config.toml[/dim]:

  [dim]\\[\\[projects]]
  name = "dotfiles"
  path = "~/code/dotfiles"[/dim]
"""


class HelpScreen(ModalScreen):
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
# Add Project screen
# -----------------------------------------------------------------------


class AddProjectScreen(ModalScreen[Project | None]):
    BINDINGS = [Binding("escape", "dismiss_modal", "Cancel")]

    DEFAULT_CSS = """
    AddProjectScreen {
        align: center middle;
    }
    #add-project-dialog {
        width: 64;
        height: auto;
        border: thick $accent;
        background: $surface;
        padding: 1 2;
    }
    #add-project-dialog Label {
        margin-top: 1;
    }
    #add-project-dialog Input {
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
        with Vertical(id="add-project-dialog"):
            yield Label("[bold]Add Project[/bold]")
            yield Label("Project name:")
            yield Input(placeholder="e.g. dotfiles", id="name-input")
            yield Label("Folder path:")
            yield Input(
                placeholder="~/code/my-project",
                id="path-input",
                value=str(Path.cwd()),
            )
            with Horizontal(classes="buttons"):
                yield Button("Cancel", id="cancel")
                yield Button("Add", variant="primary", id="add")

    def on_button_pressed(self, event: Button.Pressed) -> None:
        if event.button.id == "add":
            name = self.query_one("#name-input", Input).value.strip()
            path = self.query_one("#path-input", Input).value.strip()
            if name and path:
                self.dismiss(Project(name=name, path=path))
                return
        self.dismiss(None)

    def on_input_submitted(self, event: Input.Submitted) -> None:
        if event.input.id == "path-input":
            self.query_one("#add", Button).press()

    def action_dismiss_modal(self) -> None:
        self.dismiss(None)


# -----------------------------------------------------------------------
# Edit Project screen
# -----------------------------------------------------------------------


class EditProjectScreen(ModalScreen[Project | None]):
    """Edit a project's name and path."""

    BINDINGS = [Binding("escape", "dismiss_modal", "Cancel")]

    DEFAULT_CSS = """
    EditProjectScreen {
        align: center middle;
    }
    #edit-project-dialog {
        width: 64;
        height: auto;
        border: thick $accent;
        background: $surface;
        padding: 1 2;
    }
    #edit-project-dialog Label {
        margin-top: 1;
    }
    #edit-project-dialog Input {
        margin-bottom: 0;
    }
    #edit-project-dialog .buttons {
        margin-top: 1;
        align: right middle;
    }
    #edit-project-dialog .buttons Button {
        margin-left: 1;
    }
    """

    def __init__(self, project: Project) -> None:
        super().__init__()
        self._original = project

    def compose(self) -> ComposeResult:
        with Vertical(id="edit-project-dialog"):
            yield Label("[bold]Edit Project[/bold]")
            yield Label("Project name:")
            yield Input(value=self._original.name, id="name-input")
            yield Label("Folder path:")
            yield Input(value=self._original.path, id="path-input")
            with Horizontal(classes="buttons"):
                yield Button("Cancel", id="cancel")
                yield Button("Save", variant="primary", id="save")

    def on_button_pressed(self, event: Button.Pressed) -> None:
        if event.button.id == "save":
            name = self.query_one("#name-input", Input).value.strip()
            path = self.query_one("#path-input", Input).value.strip()
            if name and path:
                self.dismiss(Project(name=name, path=path))
                return
        self.dismiss(None)

    def on_input_submitted(self, event: Input.Submitted) -> None:
        if event.input.id == "path-input":
            self.query_one("#save", Button).press()

    def action_dismiss_modal(self) -> None:
        self.dismiss(None)


# -----------------------------------------------------------------------
# Manage Projects screen
# -----------------------------------------------------------------------


class ManageProjectItem(ListItem):
    """A project item in the manage-projects list."""

    def __init__(self, project: Project) -> None:
        super().__init__()
        self.project = project

    def compose(self) -> ComposeResult:
        t = Text()
        t.append(self.project.name, style="bold")
        t.append(f"  {self.project.path}", style="dim")
        yield Static(t)


class ManageProjectsScreen(ModalScreen):
    """Edit or remove saved projects."""

    BINDINGS = [
        Binding("escape", "dismiss_modal", "Close"),
        Binding("d", "delete_project", "Delete"),
        Binding("e", "edit_project", "Edit"),
    ]

    DEFAULT_CSS = """
    ManageProjectsScreen {
        align: center middle;
    }
    #manage-dialog {
        width: 72;
        height: auto;
        max-height: 80%;
        border: thick $accent;
        background: $surface;
        padding: 1 2;
    }
    #manage-dialog Label {
        margin-top: 1;
    }
    #manage-project-list {
        height: auto;
        max-height: 16;
    }
    ManageProjectItem {
        padding: 0 1;
        height: auto;
        min-height: 2;
    }
    ManageProjectItem:hover {
        background: $boost;
    }
    #manage-dialog .buttons {
        margin-top: 1;
        align: right middle;
    }
    #manage-dialog .buttons Button {
        margin-left: 1;
    }
    """

    def compose(self) -> ComposeResult:
        projects = load_projects()
        with Vertical(id="manage-dialog"):
            yield Label("[bold]Manage Projects[/bold]")
            yield Label(
                "[dim]d[/dim] delete  [dim]e[/dim] edit  "
                "[dim]escape[/dim] close"
            )
            if projects:
                yield ListView(
                    *[ManageProjectItem(p) for p in projects],
                    id="manage-project-list",
                )
            else:
                yield Label("No projects saved yet.")
            with Horizontal(classes="buttons"):
                yield Button("Close", id="close")

    def action_delete_project(self) -> None:
        try:
            lv = self.query_one("#manage-project-list", ListView)
        except Exception:
            return
        item = lv.highlighted_child
        if item and isinstance(item, ManageProjectItem):
            remove_project(item.project.resolved_path)
            item.remove()
            self.app.notify(f"Removed: {item.project.name}")

    @work
    async def action_edit_project(self) -> None:
        try:
            lv = self.query_one("#manage-project-list", ListView)
        except Exception:
            return
        item = lv.highlighted_child
        if not (item and isinstance(item, ManageProjectItem)):
            return
        old_path = item.project.resolved_path
        result = await self.app.push_screen_wait(EditProjectScreen(item.project))
        if result:
            update_project(old_path, result)
            self._refresh_list()
            self.app.notify(f"Updated: {result.name}")

    def _refresh_list(self) -> None:
        try:
            lv = self.query_one("#manage-project-list", ListView)
        except Exception:
            return
        lv.clear()
        for p in load_projects():
            lv.append(ManageProjectItem(p))

    def on_button_pressed(self, event: Button.Pressed) -> None:
        self.dismiss()

    def action_dismiss_modal(self) -> None:
        self.dismiss()


# -----------------------------------------------------------------------
# New Session screen (pick project + backend)
# -----------------------------------------------------------------------


class ProjectItem(ListItem):
    def __init__(self, project: Project) -> None:
        super().__init__()
        self.project = project

    def compose(self) -> ComposeResult:
        t = Text()
        t.append(self.project.name, style="bold")
        t.append(f"  {self.project.path}", style="dim")
        yield Static(t)


class NewSessionScreen(ModalScreen[dict | None]):
    """Pick a project and backend to start a new session."""

    BINDINGS = [Binding("escape", "dismiss_modal", "Cancel")]

    DEFAULT_CSS = """
    NewSessionScreen {
        align: center middle;
    }
    #new-session-dialog {
        width: 72;
        height: auto;
        max-height: 80%;
        border: thick $accent;
        background: $surface;
        padding: 1 2;
    }
    #new-session-dialog Label {
        margin-top: 1;
    }
    #project-list {
        height: auto;
        max-height: 16;
    }
    ProjectItem {
        padding: 0 1;
        height: auto;
        min-height: 2;
    }
    ProjectItem:hover {
        background: $boost;
    }
    #new-session-dialog RadioSet {
        height: auto;
        margin-top: 0;
    }
    #new-session-dialog .buttons {
        margin-top: 1;
        align: right middle;
    }
    #new-session-dialog .buttons Button {
        margin-left: 1;
    }
    """

    def compose(self) -> ComposeResult:
        projects = load_projects()
        with Vertical(id="new-session-dialog"):
            yield Label("[bold]New Session[/bold]")
            if projects:
                yield Label("Select a project:")
                yield ListView(
                    *[ProjectItem(p) for p in projects],
                    id="project-list",
                )
            else:
                yield Label(
                    f"No projects saved yet.\n"
                    f"Press [bold]a[/bold] in the main view to add one,\n"
                    f"or add entries to [dim]{CONFIG_FILE}[/dim]."
                )
            yield Label("Backend:")
            with RadioSet(id="backend-set"):
                yield RadioButton("Claude Code", value=True, id="rb-claude")
                yield RadioButton("Cursor Agent", id="rb-cursor")
            with Horizontal(classes="buttons"):
                yield Button("Cancel", id="cancel")

    def on_list_view_selected(self, event: ListView.Selected) -> None:
        if isinstance(event.item, ProjectItem):
            is_claude = self.query_one("#rb-claude", RadioButton).value
            backend = "claude" if is_claude else "cursor"
            self.dismiss({
                "project_dir": event.item.project.resolved_path,
                "backend": backend,
            })

    def on_button_pressed(self, event: Button.Pressed) -> None:
        self.dismiss(None)

    def action_dismiss_modal(self) -> None:
        self.dismiss(None)


# -----------------------------------------------------------------------
# Manual new session (directory entry)
# -----------------------------------------------------------------------


class ManualSessionScreen(ModalScreen[dict | None]):
    BINDINGS = [Binding("escape", "dismiss_modal", "Cancel")]

    DEFAULT_CSS = """
    ManualSessionScreen {
        align: center middle;
    }
    #manual-dialog {
        width: 72;
        height: auto;
        border: thick $accent;
        background: $surface;
        padding: 1 2;
    }
    #manual-dialog Label {
        margin-top: 1;
    }
    #manual-dialog Input {
        margin-bottom: 0;
    }
    #manual-dialog RadioSet {
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
        with Vertical(id="manual-dialog"):
            yield Label("[bold]New Session (manual)[/bold]")
            yield Label("Project directory:")
            yield Input(
                placeholder="/path/to/project",
                id="dir-input",
                value=str(Path.cwd()),
            )
            yield Label("Backend:")
            with RadioSet(id="backend-set"):
                yield RadioButton("Claude Code", value=True, id="rb-claude")
                yield RadioButton("Cursor Agent", id="rb-cursor")
            with Horizontal(classes="buttons"):
                yield Button("Cancel", id="cancel")
                yield Button("Open", variant="primary", id="open")

    def on_button_pressed(self, event: Button.Pressed) -> None:
        if event.button.id == "open":
            d = self.query_one("#dir-input", Input).value.strip()
            if d:
                is_claude = self.query_one("#rb-claude", RadioButton).value
                self.dismiss({
                    "project_dir": str(Path(d).expanduser().resolve()),
                    "backend": "claude" if is_claude else "cursor",
                })
                return
        self.dismiss(None)

    def on_input_submitted(self, event: Input.Submitted) -> None:
        if event.input.id == "dir-input":
            self.query_one("#open", Button).press()

    def action_dismiss_modal(self) -> None:
        self.dismiss(None)


# -----------------------------------------------------------------------
# Session sidebar item
# -----------------------------------------------------------------------


class HistoricSessionItem(ListItem):
    def __init__(self, session: HistoricSession) -> None:
        super().__init__()
        self.session_ref = session

    def compose(self) -> ComposeResult:
        s = self.session_ref
        t = Text()
        t.append(f"[{s.backend_tag}] ", style="dim bold")
        t.append(s.display_name, style="bold")
        t.append(f"\n  {s.project_name}", style="cyan dim")
        t.append(f"  {s.display_time}", style="dim")
        if s.cost_usd > 0:
            t.append(f"  ${s.cost_usd:.2f}", style="dim")
        yield Static(t)


# -----------------------------------------------------------------------
# Main application
# -----------------------------------------------------------------------


class ClaudeTUI(App):
    """Browse and resume Claude Code / Cursor Agent sessions."""

    CSS_PATH = "app.tcss"
    TITLE = "Claude TUI"

    BINDINGS = [
        Binding("j", "cursor_down", "Down", show=False),
        Binding("k", "cursor_up", "Up", show=False),
        Binding("h", "focus_sidebar", "Sidebar", show=False),
        Binding("l", "focus_content", "Content", show=False),
        Binding("escape", "handle_escape", "Back", show=False),
        Binding("n", "new_session", "New"),
        Binding("N", "manual_session", "Manual"),
        Binding("r", "resume_session", "Resume"),
        Binding("a", "add_project", "Add Project"),
        Binding("p", "manage_projects", "Projects"),
        Binding("slash", "focus_filter", "Filter"),
        Binding("question_mark", "help", "Help"),
        Binding("q", "quit", "Quit"),
    ]

    selected_session: reactive[HistoricSession | None] = reactive(None)
    _all_sessions: list[HistoricSession] = []
    _filter_text: str = ""

    def compose(self) -> ComposeResult:
        yield Header()
        with Horizontal(id="main"):
            with Vertical(id="sidebar"):
                yield Static(" Sessions", id="sidebar-header")
                yield Input(
                    placeholder="Filter sessions…",
                    id="filter-input",
                )
                yield ListView(id="session-list")
            with Vertical(id="content"):
                yield Static(
                    "Select a session to view its conversation.\n"
                    "Press [bold]n[/bold] for new session, "
                    "[bold]a[/bold] to add project, "
                    "[bold]?[/bold] for help.",
                    id="content-header",
                )
                yield RichLog(
                    id="log",
                    wrap=True,
                    highlight=True,
                    markup=True,
                    max_lines=10000,
                )
        yield Footer()

    def on_mount(self) -> None:
        self._load_sessions()

    # ------------------------------------------------------------------
    # Session loading
    # ------------------------------------------------------------------

    @work(thread=True)
    def _load_sessions(self) -> None:
        sessions = load_all_sessions()
        self.call_from_thread(self._populate_sessions, sessions)

    def _populate_sessions(self, sessions: list[HistoricSession]) -> None:
        self._all_sessions = sessions
        self._apply_filter()

    def _apply_filter(self) -> None:
        lv = self.query_one("#session-list", ListView)
        lv.clear()

        query = self._filter_text.lower()
        for session in self._all_sessions:
            if query:
                haystack = (
                    f"{session.display_name} {session.project_name} "
                    f"{session.first_prompt} {session.slug}"
                ).lower()
                if query not in haystack:
                    continue
            lv.append(HistoricSessionItem(session))

        header = self.query_one("#sidebar-header", Static)
        total = len(self._all_sessions)
        shown = lv.children.__len__()
        if query:
            header.update(f" Sessions ({shown}/{total})")
        else:
            header.update(f" Sessions ({total})")

    # ------------------------------------------------------------------
    # Content display
    # ------------------------------------------------------------------

    def watch_selected_session(
        self,
        old_val: HistoricSession | None,
        new_val: HistoricSession | None,
    ) -> None:
        log_widget = self.query_one("#log", RichLog)
        log_widget.clear()
        header = self.query_one("#content-header", Static)

        if not new_val:
            header.update(
                "Select a session to view its conversation.\n"
                "Press [bold]n[/bold] for new session, "
                "[bold]a[/bold] to add project, "
                "[bold]?[/bold] for help."
            )
            return

        s = new_val
        cost_str = f"  ${s.cost_usd:.2f}" if s.cost_usd > 0 else ""
        model_str = f"  {s.model}" if s.model else ""
        header.update(
            f"[bold]\\[{s.backend_tag}] {s.display_name}[/bold]  "
            f"{s.display_time}{model_str}{cost_str}\n"
            f"[dim]{s.project_path}[/dim]"
        )

        for msg in s.messages:
            if msg.role == "user":
                log_widget.write(Text(f"\n▶ {msg.content}", style="bold"))
            elif msg.tool_name:
                log_widget.write(
                    Text(f"  ⚡ {msg.tool_name}: {msg.content}", style="magenta")
                )
            else:
                for line in msg.content.split("\n"):
                    log_widget.write(Text(f"  {line}"))

    # ------------------------------------------------------------------
    # Event handlers
    # ------------------------------------------------------------------

    def on_list_view_highlighted(self, event: ListView.Highlighted) -> None:
        if event.item and isinstance(event.item, HistoricSessionItem):
            self.selected_session = event.item.session_ref

    def on_input_changed(self, event: Input.Changed) -> None:
        if event.input.id == "filter-input":
            self._filter_text = event.value
            self._apply_filter()

    def on_input_submitted(self, event: Input.Submitted) -> None:
        if event.input.id == "filter-input":
            self.query_one("#session-list", ListView).focus()

    # ------------------------------------------------------------------
    # Actions
    # ------------------------------------------------------------------

    def action_help(self) -> None:
        self.push_screen(HelpScreen())

    def action_cursor_down(self) -> None:
        lv = self.query_one("#session-list", ListView)
        lv.focus()
        lv.action_cursor_down()

    def action_cursor_up(self) -> None:
        lv = self.query_one("#session-list", ListView)
        lv.focus()
        lv.action_cursor_up()

    def action_focus_sidebar(self) -> None:
        self.query_one("#session-list", ListView).focus()

    def action_focus_content(self) -> None:
        self.query_one("#log", RichLog).focus()

    def action_handle_escape(self) -> None:
        focused = self.focused
        filter_input = self.query_one("#filter-input", Input)
        lv = self.query_one("#session-list", ListView)
        if focused is filter_input:
            if filter_input.value:
                filter_input.value = ""
            else:
                lv.focus()
        else:
            lv.focus()

    def action_focus_filter(self) -> None:
        self.query_one("#filter-input", Input).focus()

    def action_manage_projects(self) -> None:
        self.push_screen(ManageProjectsScreen())

    def action_resume_session(self) -> None:
        """Resume selected session in a dev layout (cmux or zellij)."""
        session = self.selected_session
        if not session:
            self.notify("No session selected", severity="warning")
            return

        if session.backend == Backend.CURSOR:
            agent_cmd = "cursor-agent"
            agent_args = f'"--resume" "{session.session_id}"'
        else:
            agent_cmd = "claude"
            agent_args = f'"-r" "{session.session_id}" "--fork-session"'

        if _is_cmux_running():
            _launch_cmux_dev(
                agent_cmd=agent_cmd,
                agent_args=agent_args,
                cwd=session.project_path,
            )
            self.notify(f"Resumed in cmux: {session.display_name}")
        else:
            project_name = Path(session.project_path).name
            zellij_session = f"{session.backend_tag.lower()}-{project_name}-resume"
            _launch_zellij_dev(
                agent_cmd=agent_cmd,
                agent_args=agent_args,
                cwd=session.project_path,
                zellij_session=zellij_session,
            )
            self.notify(f"Resumed in zellij: {session.display_name}")

    @work
    async def action_new_session(self) -> None:
        result = await self.push_screen_wait(NewSessionScreen())
        if not result:
            return
        project_name = Path(result["project_dir"]).name
        backend = result["backend"]
        agent_cmd = "claude" if backend == "claude" else "cursor-agent"

        if _is_cmux_running():
            _launch_cmux_dev(
                agent_cmd=agent_cmd,
                agent_args="",
                cwd=result["project_dir"],
            )
        else:
            tag = "c" if backend == "claude" else "r"
            zellij_session = f"{tag}-{project_name}"
            _launch_zellij_dev(
                agent_cmd=agent_cmd,
                agent_args="",
                cwd=result["project_dir"],
                zellij_session=zellij_session,
            )
        self.notify(f"New session in {project_name}")

    @work
    async def action_manual_session(self) -> None:
        result = await self.push_screen_wait(ManualSessionScreen())
        if not result:
            return
        project_name = Path(result["project_dir"]).name
        backend = result["backend"]
        agent_cmd = "claude" if backend == "claude" else "cursor-agent"

        if _is_cmux_running():
            _launch_cmux_dev(
                agent_cmd=agent_cmd,
                agent_args="",
                cwd=result["project_dir"],
            )
        else:
            tag = "c" if backend == "claude" else "r"
            zellij_session = f"{tag}-{project_name}"
            _launch_zellij_dev(
                agent_cmd=agent_cmd,
                agent_args="",
                cwd=result["project_dir"],
                zellij_session=zellij_session,
            )
        self.notify(f"New session in {project_name}")

    @work
    async def action_add_project(self) -> None:
        project = await self.push_screen_wait(AddProjectScreen())
        if not project:
            return
        save_project(project)
        self.notify(f"Saved project: {project.name}")


# -----------------------------------------------------------------------
# Zellij layout launcher
# -----------------------------------------------------------------------

_DEV_LAYOUT_TEMPLATE = """\
layout {{
    cwd "{cwd}"

    default_tab_template {{
        pane size=1 borderless=true {{
            plugin location="zellij:tab-bar"
        }}
        children
    }}

    tab name="dev" focus=true {{
        pane split_direction="vertical" {{
            pane name="agent" size="50%" {{
                command "{agent_cmd}"
                {args_line}
                focus true
            }}
            pane name="editor" size="50%" {{
                command "hx"
                args "."
                start_suspended true
            }}
        }}
        pane stacked=true size="25%" {{
            pane name="shell"
        }}
    }}

    tab name="git" {{
        pane name="lazygit" {{
            command "lazygit"
            start_suspended true
        }}
    }}

    tab name="files" {{
        pane split_direction="vertical" {{
            pane name="yazi" size="30%" {{
                command "yazi"
            }}
            pane name="editor" size="70%" {{
                command "hx"
            }}
        }}
    }}
}}
"""


def _launch_zellij_dev(
    agent_cmd: str,
    agent_args: str,
    cwd: str,
    zellij_session: str,
) -> None:
    """Write a temporary KDL layout and launch a new zellij session."""
    args_line = f"args {agent_args}" if agent_args else ""
    layout_content = _DEV_LAYOUT_TEMPLATE.format(
        cwd=cwd,
        agent_cmd=agent_cmd,
        args_line=args_line,
    )

    with tempfile.NamedTemporaryFile(
        mode="w", suffix=".kdl", prefix="claude-tui-", delete=False,
    ) as f:
        f.write(layout_content)
        layout_path = f.name

    escaped_cwd = cwd.replace("'", "'\\''")
    zellij_cmd = (
        f"cd '{escaped_cwd}' && "
        f"zellij -n '{layout_path}' -s '{zellij_session}'"
    )

    # Open in a new iTerm2 tab; fall back to Terminal.app
    try:
        subprocess.Popen([
            "osascript", "-e",
            'tell application "iTerm2"\n'
            "  tell current window\n"
            "    create tab with default profile\n"
            "    tell current session\n"
            f'      write text "{zellij_cmd}"\n'
            "    end tell\n"
            "  end tell\n"
            "end tell",
        ], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    except Exception:
        subprocess.Popen([
            "osascript", "-e",
            'tell application "Terminal"\n'
            "  activate\n"
            f'  do script "{zellij_cmd}"\n'
            "end tell",
        ], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


# -----------------------------------------------------------------------
# cmux detection and launcher
# -----------------------------------------------------------------------


def _is_cmux_running() -> bool:
    """Check if cmux is running by testing for its Unix socket."""
    return os.path.exists("/tmp/cmux.sock")


def _cmux_run(*args: str) -> str:
    """Run a cmux CLI command and return stdout."""
    result = subprocess.run(
        ["cmux", *args],
        capture_output=True, text=True, timeout=5,
    )
    return result.stdout.strip()


def _cmux_send_command(workspace: str, surface: str, command: str) -> None:
    """Send a shell command to a cmux surface (type text + press Enter)."""
    _cmux_run("send", "--workspace", workspace, "--surface", surface, command)
    _cmux_run("send-key", "--workspace", workspace, "--surface", surface, "Enter")


def _launch_cmux_dev(
    agent_cmd: str,
    agent_args: str,
    cwd: str,
) -> None:
    """Set up a dev environment in cmux using workspaces and splits."""
    # Build the full agent command line
    if agent_args:
        # agent_args comes as '"arg1" "arg2"' — convert to space-separated
        full_agent = f"{agent_cmd} {agent_args.replace(chr(34), '')}"
    else:
        full_agent = agent_cmd

    # --- Workspace 1: dev (agent + editor) ---
    ws1_out = _cmux_run("new-workspace")
    # Output: "OK <uuid>" — extract workspace ref from list
    _cmux_run("list-workspaces")  # refresh state
    # Get the new workspace ref by identifying the last one
    ws_list = _cmux_run("list-workspaces")
    # Parse last workspace ref (newest = last line)
    ws1_ref = None
    for line in ws_list.strip().splitlines():
        parts = line.split()
        for p in parts:
            if p.startswith("workspace:"):
                ws1_ref = p
    if not ws1_ref:
        return

    _cmux_run("rename-workspace", "--workspace", ws1_ref, "dev")
    _cmux_run("select-workspace", "--workspace", ws1_ref)

    # Identify the initial surface in this workspace
    panes = _cmux_run("list-pane-surfaces", "--workspace", ws1_ref)
    agent_surface = None
    for line in panes.strip().splitlines():
        for p in line.split():
            if p.startswith("surface:"):
                agent_surface = p
                break
        if agent_surface:
            break

    if not agent_surface:
        return

    # cd to project dir and launch agent
    _cmux_send_command(ws1_ref, agent_surface, f"cd '{cwd}'")
    time.sleep(0.2)
    _cmux_send_command(ws1_ref, agent_surface, full_agent)

    # Split right for Helix editor
    split_out = _cmux_run("new-split", "right", "--workspace", ws1_ref)
    # Output: "OK surface:<n> workspace:<n>"
    editor_surface = None
    for p in split_out.split():
        if p.startswith("surface:"):
            editor_surface = p
            break
    if editor_surface:
        _cmux_send_command(ws1_ref, editor_surface, f"cd '{cwd}'")
        time.sleep(0.1)
        _cmux_send_command(ws1_ref, editor_surface, "hx .")

    # --- Workspace 2: git (lazygit) ---
    _cmux_run("new-workspace")
    ws_list = _cmux_run("list-workspaces")
    ws2_ref = None
    for line in ws_list.strip().splitlines():
        parts = line.split()
        for p in parts:
            if p.startswith("workspace:"):
                ws2_ref = p
    if ws2_ref:
        _cmux_run("rename-workspace", "--workspace", ws2_ref, "git")
        git_panes = _cmux_run("list-pane-surfaces", "--workspace", ws2_ref)
        git_surface = None
        for line in git_panes.strip().splitlines():
            for p in line.split():
                if p.startswith("surface:"):
                    git_surface = p
                    break
            if git_surface:
                break
        if git_surface:
            _cmux_send_command(ws2_ref, git_surface, f"cd '{cwd}'")
            time.sleep(0.1)
            _cmux_send_command(ws2_ref, git_surface, "lazygit")

    # --- Workspace 3: files (yazi + helix) ---
    _cmux_run("new-workspace")
    ws_list = _cmux_run("list-workspaces")
    ws3_ref = None
    for line in ws_list.strip().splitlines():
        parts = line.split()
        for p in parts:
            if p.startswith("workspace:"):
                ws3_ref = p
    if ws3_ref:
        _cmux_run("rename-workspace", "--workspace", ws3_ref, "files")
        files_panes = _cmux_run("list-pane-surfaces", "--workspace", ws3_ref)
        yazi_surface = None
        for line in files_panes.strip().splitlines():
            for p in line.split():
                if p.startswith("surface:"):
                    yazi_surface = p
                    break
            if yazi_surface:
                break
        if yazi_surface:
            _cmux_send_command(ws3_ref, yazi_surface, f"cd '{cwd}'")
            time.sleep(0.1)
            _cmux_send_command(ws3_ref, yazi_surface, "yazi")

        # Split right for Helix
        split_out = _cmux_run("new-split", "right", "--workspace", ws3_ref)
        hx_surface = None
        for p in split_out.split():
            if p.startswith("surface:"):
                hx_surface = p
                break
        if hx_surface:
            _cmux_send_command(ws3_ref, hx_surface, f"cd '{cwd}'")
            time.sleep(0.1)
            _cmux_send_command(ws3_ref, hx_surface, "hx")

    # Focus back on the dev workspace
    _cmux_run("select-workspace", "--workspace", ws1_ref)
