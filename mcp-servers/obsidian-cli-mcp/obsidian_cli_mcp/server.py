"""MCP tool definitions — backward-compatible with mcp-obsidian."""

from __future__ import annotations

import argparse
import sys

from fastmcp import FastMCP

from .cli import ObsidianCLI
from .heading_patch import build_heading_patch_js

mcp = FastMCP("mcp-obsidian")
cli = ObsidianCLI()


# ---------------------------------------------------------------------------
# Backward-compatible tools (slash commands depend on these names)
# ---------------------------------------------------------------------------


@mcp.tool()
def obsidian_get_file_contents(filepath: str) -> str:
    """Read the contents of a file in the vault.

    Args:
        filepath: Path relative to vault root (e.g. ``journals/2026-02-19.md``).
    """
    result = cli.run("read", f"path={filepath}")
    if result.returncode != 0:
        raise RuntimeError(f"Failed to read {filepath}: {result.stderr.strip()}")
    return result.stdout


@mcp.tool()
def obsidian_append_content(filepath: str, content: str) -> str:
    """Append content to a file, creating it if it doesn't exist.

    Args:
        filepath: Path relative to vault root.
        content: Markdown content to append.
    """
    result = cli.run("append", f"path={filepath}", f"content={content}")
    if result.returncode != 0:
        raise RuntimeError(f"Failed to append to {filepath}: {result.stderr.strip()}")
    return result.stdout or "OK"


@mcp.tool()
def obsidian_patch_content(
    filepath: str,
    content: str,
    operation: str = "replace",
    target_type: str | None = None,
    target: str | None = None,
) -> str:
    """Patch content in a file, optionally targeting a specific heading section.

    Without a target, operates on the whole file.  With ``target_type='heading'``
    the operation applies to the section under the named heading.

    Args:
        filepath: Path relative to vault root.
        content: New Markdown content.
        operation: ``replace``, ``append``, or ``prepend``.
        target_type: Set to ``heading`` for heading-level edits.
        target: The heading text to target (required when target_type is heading).
    """
    if target_type == "heading":
        if not target:
            raise ValueError("target is required when target_type is 'heading'")
        js = build_heading_patch_js(filepath, target, operation, content)
        result = cli.run("eval", f"code={js}")
        if result.returncode != 0:
            raise RuntimeError(
                f"Heading patch failed for '{target}' in {filepath}: {result.stderr.strip()}"
            )
        return result.stdout.strip() or "OK"

    # Whole-file operations
    if operation == "append":
        return obsidian_append_content(filepath, content)

    if operation == "replace":
        # Write replaces entire file content via eval
        js_params = (
            f'const file = app.vault.getAbstractFileByPath("{filepath}");'
            f"if (!file) throw new Error('File not found');"
            f"await app.vault.modify(file, {_js_string(content)});"
        )
        result = cli.run("eval", f"code=(async () => {{{js_params}}})()")
        if result.returncode != 0:
            raise RuntimeError(
                f"Replace failed for {filepath}: {result.stderr.strip()}"
            )
        return "OK"

    if operation == "prepend":
        js_params = (
            f'const file = app.vault.getAbstractFileByPath("{filepath}");'
            f"if (!file) throw new Error('File not found');"
            f"const old = await app.vault.read(file);"
            f"await app.vault.modify(file, {_js_string(content)} + '\\n' + old);"
        )
        result = cli.run("eval", f"code=(async () => {{{js_params}}})()")
        if result.returncode != 0:
            raise RuntimeError(
                f"Prepend failed for {filepath}: {result.stderr.strip()}"
            )
        return "OK"

    raise ValueError(f"Unknown operation: {operation}")


@mcp.tool()
def obsidian_simple_search(query: str) -> str:
    """Search the vault for notes matching a query.

    Args:
        query: Search text.
    """
    result = cli.run("search", f"query={query}", "format=json")
    if result.returncode != 0:
        raise RuntimeError(f"Search failed: {result.stderr.strip()}")
    return result.stdout


@mcp.tool()
def obsidian_list_files_in_vault() -> str:
    """List all files in the vault."""
    result = cli.run("files", "format=json")
    if result.returncode != 0:
        raise RuntimeError(f"Failed to list files: {result.stderr.strip()}")
    return result.stdout


@mcp.tool()
def obsidian_list_files_in_dir(dirpath: str) -> str:
    """List files in a specific vault directory.

    Args:
        dirpath: Directory path relative to vault root.
    """
    result = cli.run("files", f"folder={dirpath}", "format=json")
    if result.returncode != 0:
        raise RuntimeError(f"Failed to list files in {dirpath}: {result.stderr.strip()}")
    return result.stdout


@mcp.tool()
def obsidian_get_periodic_note(period: str = "daily") -> str:
    """Get the current periodic note (daily, weekly, monthly, etc.).

    Args:
        period: Note period — ``daily``, ``weekly``, ``monthly``, ``quarterly``, or ``yearly``.
    """
    result = cli.run(period)
    if result.returncode != 0:
        raise RuntimeError(f"Failed to get {period} note: {result.stderr.strip()}")
    return result.stdout


@mcp.tool()
def obsidian_delete_file(filepath: str) -> str:
    """Delete a file from the vault.

    Args:
        filepath: Path relative to vault root.
    """
    result = cli.run("delete", f"path={filepath}")
    if result.returncode != 0:
        raise RuntimeError(f"Failed to delete {filepath}: {result.stderr.strip()}")
    return result.stdout or "OK"


# ---------------------------------------------------------------------------
# New tools (CLI-exclusive capabilities)
# ---------------------------------------------------------------------------


@mcp.tool()
def obsidian_properties_read(filepath: str) -> str:
    """Read frontmatter properties of a note.

    Args:
        filepath: Path relative to vault root.
    """
    result = cli.run("properties", f"path={filepath}", "format=json")
    if result.returncode != 0:
        raise RuntimeError(
            f"Failed to read properties of {filepath}: {result.stderr.strip()}"
        )
    return result.stdout


@mcp.tool()
def obsidian_property_set(filepath: str, key: str, value: str) -> str:
    """Set a single frontmatter property on a note.

    Args:
        filepath: Path relative to vault root.
        key: Property name.
        value: Property value.
    """
    result = cli.run("property:set", f"path={filepath}", f"key={key}", f"value={value}")
    if result.returncode != 0:
        raise RuntimeError(
            f"Failed to set property {key} on {filepath}: {result.stderr.strip()}"
        )
    return result.stdout or "OK"


@mcp.tool()
def obsidian_tasks_list() -> str:
    """List all tasks (checkboxes) across the vault."""
    result = cli.run("tasks", "format=json")
    if result.returncode != 0:
        raise RuntimeError(f"Failed to list tasks: {result.stderr.strip()}")
    return result.stdout


@mcp.tool()
def obsidian_tags_list() -> str:
    """List all tags used across the vault."""
    result = cli.run("tags", "format=json")
    if result.returncode != 0:
        raise RuntimeError(f"Failed to list tags: {result.stderr.strip()}")
    return result.stdout


@mcp.tool()
def obsidian_daily_append(content: str) -> str:
    """Append content to today's daily note.

    Args:
        content: Markdown content to append.
    """
    result = cli.run("daily:append", f"content={content}")
    if result.returncode != 0:
        raise RuntimeError(f"Failed to append to daily note: {result.stderr.strip()}")
    return result.stdout or "OK"


@mcp.tool()
def obsidian_backlinks(filepath: str) -> str:
    """Get all backlinks pointing to a note.

    Args:
        filepath: Path relative to vault root.
    """
    result = cli.run("backlinks", f"path={filepath}", "format=json")
    if result.returncode != 0:
        raise RuntimeError(
            f"Failed to get backlinks for {filepath}: {result.stderr.strip()}"
        )
    return result.stdout


@mcp.tool()
def obsidian_eval(code: str) -> str:
    """Evaluate arbitrary JavaScript in the Obsidian context.

    The code runs with access to the ``app`` object.

    Args:
        code: JavaScript code to evaluate.
    """
    result = cli.run("eval", f"code={code}", timeout=60)
    if result.returncode != 0:
        raise RuntimeError(f"Eval failed: {result.stderr.strip()}")
    return result.stdout


@mcp.tool()
def obsidian_vault_info() -> str:
    """Get information about the current vault."""
    result = cli.run("vault")
    if result.returncode != 0:
        raise RuntimeError(f"Failed to get vault info: {result.stderr.strip()}")
    return result.stdout


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def _js_string(value: str) -> str:
    """Encode a Python string as a JS string literal (JSON-safe)."""
    import json

    return json.dumps(value, ensure_ascii=False)


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------


def main() -> None:
    parser = argparse.ArgumentParser(description="Obsidian CLI MCP server")
    parser.add_argument(
        "--default-vault",
        default=None,
        help="Vault name passed to every CLI call (e.g. 'brain').",
    )
    args, remaining = parser.parse_known_args()
    cli.default_vault = args.default_vault

    # Let FastMCP handle its own flags (like --transport)
    sys.argv = [sys.argv[0], *remaining]
    mcp.run()
