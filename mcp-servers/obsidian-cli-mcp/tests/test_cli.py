"""Tests for the ObsidianCLI subprocess wrapper."""

from __future__ import annotations

import json
import subprocess
from unittest.mock import patch

import pytest

from obsidian_cli_mcp.cli import CLIResult, ObsidianCLI


@pytest.fixture
def cli() -> ObsidianCLI:
    return ObsidianCLI(default_vault="brain")


@pytest.fixture
def cli_no_vault() -> ObsidianCLI:
    return ObsidianCLI()


class TestRun:
    def test_basic_command(self, cli: ObsidianCLI) -> None:
        fake = subprocess.CompletedProcess(
            args=[], returncode=0, stdout="hello", stderr=""
        )
        with patch("obsidian_cli_mcp.cli.subprocess.run", return_value=fake) as mock:
            result = cli.run("read", "path=test.md")

        mock.assert_called_once_with(
            ["obsidian", "vault=brain", "read", "path=test.md"],
            capture_output=True,
            text=True,
            timeout=30,
        )
        assert result == CLIResult(stdout="hello", stderr="", returncode=0)

    def test_vault_override(self, cli: ObsidianCLI) -> None:
        fake = subprocess.CompletedProcess(args=[], returncode=0, stdout="", stderr="")
        with patch("obsidian_cli_mcp.cli.subprocess.run", return_value=fake) as mock:
            cli.run("read", "path=x.md", vault="other")

        assert mock.call_args[0][0][:2] == ["obsidian", "vault=other"]

    def test_no_vault(self, cli_no_vault: ObsidianCLI) -> None:
        fake = subprocess.CompletedProcess(args=[], returncode=0, stdout="", stderr="")
        with patch("obsidian_cli_mcp.cli.subprocess.run", return_value=fake) as mock:
            cli_no_vault.run("vault")

        assert mock.call_args[0][0] == ["obsidian", "vault"]

    def test_custom_timeout(self, cli: ObsidianCLI) -> None:
        fake = subprocess.CompletedProcess(args=[], returncode=0, stdout="", stderr="")
        with patch("obsidian_cli_mcp.cli.subprocess.run", return_value=fake) as mock:
            cli.run("eval", "code=1+1", timeout=60)

        assert mock.call_args[1]["timeout"] == 60


class TestRunJson:
    def test_parses_json(self, cli: ObsidianCLI) -> None:
        data = [{"path": "a.md"}, {"path": "b.md"}]
        fake = subprocess.CompletedProcess(
            args=[], returncode=0, stdout=json.dumps(data), stderr=""
        )
        with patch("obsidian_cli_mcp.cli.subprocess.run", return_value=fake):
            result = cli.run_json("files")

        assert result == data

    def test_appends_format_json(self, cli: ObsidianCLI) -> None:
        fake = subprocess.CompletedProcess(
            args=[], returncode=0, stdout="[]", stderr=""
        )
        with patch("obsidian_cli_mcp.cli.subprocess.run", return_value=fake) as mock:
            cli.run_json("files")

        cmd = mock.call_args[0][0]
        assert "format=json" in cmd

    def test_raises_on_error(self, cli: ObsidianCLI) -> None:
        fake = subprocess.CompletedProcess(
            args=[], returncode=1, stdout="", stderr="not found"
        )
        with patch("obsidian_cli_mcp.cli.subprocess.run", return_value=fake):
            with pytest.raises(RuntimeError, match="not found"):
                cli.run_json("files")


class TestCheckAvailable:
    def test_available(self, cli: ObsidianCLI) -> None:
        fake = subprocess.CompletedProcess(args=[], returncode=0, stdout="", stderr="")
        with patch("obsidian_cli_mcp.cli.subprocess.run", return_value=fake):
            assert cli.check_available() is True

    def test_not_found(self, cli: ObsidianCLI) -> None:
        with patch(
            "obsidian_cli_mcp.cli.subprocess.run", side_effect=FileNotFoundError
        ):
            assert cli.check_available() is False

    def test_timeout(self, cli: ObsidianCLI) -> None:
        with patch(
            "obsidian_cli_mcp.cli.subprocess.run",
            side_effect=subprocess.TimeoutExpired("obsidian", 5),
        ):
            assert cli.check_available() is False
