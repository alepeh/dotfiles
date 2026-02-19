"""Thin subprocess wrapper around the Obsidian CLI."""

from __future__ import annotations

import json
import subprocess
from dataclasses import dataclass


@dataclass
class CLIResult:
    stdout: str
    stderr: str
    returncode: int


class ObsidianCLI:
    """Wraps the ``obsidian`` CLI binary via subprocess."""

    def __init__(self, default_vault: str | None = None) -> None:
        self.default_vault = default_vault

    def run(
        self,
        *args: str,
        vault: str | None = None,
        timeout: int = 30,
    ) -> CLIResult:
        """Run an obsidian CLI command and return the result."""
        cmd: list[str] = ["obsidian"]
        v = vault or self.default_vault
        if v:
            cmd.append(f"vault={v}")
        cmd.extend(args)

        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=timeout,
        )
        return CLIResult(
            stdout=result.stdout,
            stderr=result.stderr,
            returncode=result.returncode,
        )

    def run_json(
        self,
        *args: str,
        vault: str | None = None,
        timeout: int = 30,
    ) -> dict | list:
        """Run a CLI command expecting JSON output."""
        result = self.run(*args, "format=json", vault=vault, timeout=timeout)
        if result.returncode != 0:
            raise RuntimeError(
                f"obsidian CLI error (exit {result.returncode}): {result.stderr.strip()}"
            )
        return json.loads(result.stdout)

    def check_available(self) -> bool:
        """Return True if the obsidian CLI is reachable."""
        try:
            result = subprocess.run(
                ["obsidian", "help"],
                capture_output=True,
                text=True,
                timeout=5,
            )
            return result.returncode == 0
        except (FileNotFoundError, subprocess.TimeoutExpired):
            return False
