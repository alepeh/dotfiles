"""Tests for MCP tool functions."""

from __future__ import annotations

from unittest.mock import patch

import pytest

from obsidian_cli_mcp.cli import CLIResult
from obsidian_cli_mcp import server


def _ok(stdout: str = "") -> CLIResult:
    return CLIResult(stdout=stdout, stderr="", returncode=0)


def _err(stderr: str = "error") -> CLIResult:
    return CLIResult(stdout="", stderr=stderr, returncode=1)


class TestGetFileContents:
    def test_returns_content(self) -> None:
        with patch.object(server.cli, "run", return_value=_ok("# Hello\nworld")):
            result = server.obsidian_get_file_contents("test.md")
        assert result == "# Hello\nworld"

    def test_raises_on_error(self) -> None:
        with patch.object(server.cli, "run", return_value=_err("not found")):
            with pytest.raises(RuntimeError, match="not found"):
                server.obsidian_get_file_contents("missing.md")


class TestAppendContent:
    def test_calls_append(self) -> None:
        with patch.object(server.cli, "run", return_value=_ok()) as mock:
            server.obsidian_append_content("journal.md", "new text")

        mock.assert_called_once_with(
            "append", "path=journal.md", "content=new text"
        )

    def test_returns_ok_on_empty_stdout(self) -> None:
        with patch.object(server.cli, "run", return_value=_ok("")):
            assert server.obsidian_append_content("j.md", "x") == "OK"


class TestPatchContent:
    def test_heading_replace(self) -> None:
        with patch.object(server.cli, "run", return_value=_ok("OK")) as mock:
            server.obsidian_patch_content(
                filepath="journal.md",
                content="new brief",
                operation="replace",
                target_type="heading",
                target="Morning Brief",
            )

        args = mock.call_args[0]
        assert args[0] == "eval"
        assert "Morning Brief" in args[1]

    def test_heading_requires_target(self) -> None:
        with pytest.raises(ValueError, match="target is required"):
            server.obsidian_patch_content(
                filepath="j.md",
                content="x",
                target_type="heading",
                target=None,
            )

    def test_whole_file_append_delegates(self) -> None:
        with patch.object(server.cli, "run", return_value=_ok()) as mock:
            server.obsidian_patch_content(
                filepath="j.md",
                content="more",
                operation="append",
            )

        mock.assert_called_once_with("append", "path=j.md", "content=more")

    def test_unknown_operation_raises(self) -> None:
        with pytest.raises(ValueError, match="Unknown operation"):
            server.obsidian_patch_content(
                filepath="j.md",
                content="x",
                operation="delete",
            )


class TestSimpleSearch:
    def test_returns_json(self) -> None:
        with patch.object(
            server.cli, "run", return_value=_ok('[{"path":"a.md"}]')
        ):
            result = server.obsidian_simple_search("test query")
        assert '"path"' in result


class TestListFiles:
    def test_list_vault(self) -> None:
        with patch.object(server.cli, "run", return_value=_ok("[]")) as mock:
            server.obsidian_list_files_in_vault()
        mock.assert_called_once_with("files", "format=json")

    def test_list_dir(self) -> None:
        with patch.object(server.cli, "run", return_value=_ok("[]")) as mock:
            server.obsidian_list_files_in_dir("journals")
        mock.assert_called_once_with("files", "folder=journals", "format=json")


class TestPeriodicNote:
    def test_daily(self) -> None:
        with patch.object(server.cli, "run", return_value=_ok("# Today")) as mock:
            result = server.obsidian_get_periodic_note("daily")
        mock.assert_called_once_with("daily")
        assert result == "# Today"


class TestDeleteFile:
    def test_calls_delete(self) -> None:
        with patch.object(server.cli, "run", return_value=_ok()) as mock:
            server.obsidian_delete_file("trash.md")
        mock.assert_called_once_with("delete", "path=trash.md")


class TestNewTools:
    def test_properties_read(self) -> None:
        with patch.object(
            server.cli, "run", return_value=_ok('{"tags":["a"]}')
        ) as mock:
            server.obsidian_properties_read("note.md")
        mock.assert_called_once_with("properties", "path=note.md", "format=json")

    def test_property_set(self) -> None:
        with patch.object(server.cli, "run", return_value=_ok()) as mock:
            server.obsidian_property_set("note.md", "status", "active")
        mock.assert_called_once_with(
            "property:set", "path=note.md", "key=status", "value=active"
        )

    def test_tasks_list(self) -> None:
        with patch.object(server.cli, "run", return_value=_ok("[]")) as mock:
            server.obsidian_tasks_list()
        mock.assert_called_once_with("tasks", "format=json")

    def test_tags_list(self) -> None:
        with patch.object(server.cli, "run", return_value=_ok("[]")) as mock:
            server.obsidian_tags_list()
        mock.assert_called_once_with("tags", "format=json")

    def test_daily_append(self) -> None:
        with patch.object(server.cli, "run", return_value=_ok()) as mock:
            server.obsidian_daily_append("hello")
        mock.assert_called_once_with("daily:append", "content=hello")

    def test_backlinks(self) -> None:
        with patch.object(server.cli, "run", return_value=_ok("[]")) as mock:
            server.obsidian_backlinks("note.md")
        mock.assert_called_once_with("backlinks", "path=note.md", "format=json")

    def test_eval(self) -> None:
        with patch.object(server.cli, "run", return_value=_ok("42")) as mock:
            result = server.obsidian_eval("1+1")
        mock.assert_called_once_with("eval", "code=1+1", timeout=60)
        assert result == "42"

    def test_vault_info(self) -> None:
        with patch.object(server.cli, "run", return_value=_ok("brain")) as mock:
            server.obsidian_vault_info()
        mock.assert_called_once_with("vault")
