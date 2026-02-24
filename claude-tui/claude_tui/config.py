"""Configuration loading for Claude TUI (presets from TOML)."""

from __future__ import annotations

import tomllib
from dataclasses import dataclass
from pathlib import Path

CONFIG_DIR = Path.home() / ".config" / "claude-tui"
CONFIG_FILE = CONFIG_DIR / "config.toml"


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
        """Expand ~ in project_dir."""
        return str(Path(self.project_dir).expanduser())


def load_presets() -> list[Preset]:
    """Load presets from ~/.config/claude-tui/config.toml."""
    if not CONFIG_FILE.exists():
        return []
    with open(CONFIG_FILE, "rb") as f:
        data = tomllib.load(f)
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


def ensure_config_dir() -> None:
    """Create config directory if it doesn't exist."""
    CONFIG_DIR.mkdir(parents=True, exist_ok=True)
