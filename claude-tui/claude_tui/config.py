"""Configuration loading for Claude TUI (projects and presets from TOML)."""

from __future__ import annotations

import tomllib
from dataclasses import dataclass
from pathlib import Path

CONFIG_DIR = Path.home() / ".config" / "claude-tui"
CONFIG_FILE = CONFIG_DIR / "config.toml"


@dataclass
class Project:
    """A saved project directory."""

    name: str
    path: str

    @property
    def resolved_path(self) -> str:
        return str(Path(self.path).expanduser().resolve())

    @property
    def display(self) -> str:
        return f"{self.name}  ({self.path})"


@dataclass
class Preset:
    """A saved session configuration."""

    name: str
    project_dir: str
    prompt: str
    model: str = ""
    backend: str = "claude"  # "claude" or "cursor"

    @property
    def resolved_dir(self) -> str:
        return str(Path(self.project_dir).expanduser())


def ensure_config_dir() -> None:
    CONFIG_DIR.mkdir(parents=True, exist_ok=True)


def load_config() -> dict:
    if not CONFIG_FILE.exists():
        return {}
    with open(CONFIG_FILE, "rb") as f:
        return tomllib.load(f)


def load_projects() -> list[Project]:
    data = load_config()
    return [
        Project(name=p["name"], path=p["path"])
        for p in data.get("projects", [])
    ]


def load_presets() -> list[Preset]:
    data = load_config()
    return [
        Preset(
            name=p["name"],
            project_dir=p["project_dir"],
            prompt=p["prompt"],
            model=p.get("model", ""),
            backend=p.get("backend", "claude"),
        )
        for p in data.get("presets", [])
    ]


def save_project(project: Project) -> None:
    """Add a project to config.toml (preserves existing content)."""
    ensure_config_dir()
    existing = load_projects()
    for p in existing:
        if p.resolved_path == project.resolved_path:
            return

    _append_toml_block(
        "projects",
        {"name": project.name, "path": project.path},
    )


def remove_project(project_path: str) -> None:
    """Remove a project from config.toml by its resolved path."""
    ensure_config_dir()
    data = load_config()
    projects = data.get("projects", [])
    projects = [
        p for p in projects
        if str(Path(p["path"]).expanduser().resolve()) != project_path
    ]
    data["projects"] = projects
    _write_config(data)


def _append_toml_block(table_name: str, entry: dict) -> None:
    """Append a [[table_name]] entry to the config file."""
    ensure_config_dir()
    lines: list[str] = []
    if CONFIG_FILE.exists():
        lines = CONFIG_FILE.read_text().splitlines()

    lines.append("")
    lines.append(f"[[{table_name}]]")
    for key, val in entry.items():
        lines.append(f'{key} = "{val}"')

    CONFIG_FILE.write_text("\n".join(lines) + "\n")


def _write_config(data: dict) -> None:
    """Rewrite config.toml from a dict (used for removal)."""
    ensure_config_dir()
    lines: list[str] = []

    for proj in data.get("projects", []):
        lines.append("[[projects]]")
        lines.append(f'name = "{proj["name"]}"')
        lines.append(f'path = "{proj["path"]}"')
        lines.append("")

    for preset in data.get("presets", []):
        lines.append("[[presets]]")
        lines.append(f'name = "{preset["name"]}"')
        lines.append(f'project_dir = "{preset["project_dir"]}"')
        lines.append(f'prompt = "{preset["prompt"]}"')
        if preset.get("model"):
            lines.append(f'model = "{preset["model"]}"')
        if preset.get("backend"):
            lines.append(f'backend = "{preset["backend"]}"')
        lines.append("")

    CONFIG_FILE.write_text("\n".join(lines) + "\n")
