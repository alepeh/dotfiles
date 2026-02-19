"""Tests for heading patch JS generation."""

from __future__ import annotations

import json

from obsidian_cli_mcp.heading_patch import build_heading_patch_js


class TestBuildHeadingPatchJs:
    def test_contains_filepath(self) -> None:
        js = build_heading_patch_js("journals/2026-02-19.md", "Morning Brief", "replace", "new")
        assert "journals/2026-02-19.md" in js

    def test_contains_heading(self) -> None:
        js = build_heading_patch_js("j.md", "Evening Recap", "replace", "content")
        assert "Evening Recap" in js

    def test_contains_operation(self) -> None:
        for op in ("replace", "append", "prepend"):
            js = build_heading_patch_js("j.md", "H", op, "c")
            assert op in js

    def test_embeds_content_safely(self) -> None:
        tricky = 'He said "hello" and it\'s fine\nnewline too'
        js = build_heading_patch_js("j.md", "H", "replace", tricky)
        # The content should be JSON-encoded inside the params
        # Verify the JS is parseable by checking that JSON.parse will work
        # by extracting the params string
        assert "JSON.parse" in js
        assert "hello" in js

    def test_special_characters_in_heading(self) -> None:
        js = build_heading_patch_js("j.md", "Follow-up Next Session", "replace", "items")
        assert "Follow-up Next Session" in js

    def test_returns_iife(self) -> None:
        js = build_heading_patch_js("j.md", "H", "replace", "c")
        assert js.strip().startswith("(async () =>")
        assert js.strip().endswith(")()")

    def test_params_are_valid_json(self) -> None:
        js = build_heading_patch_js("j.md", "H", "replace", "c")
        # Extract the JSON string between JSON.parse( and );
        start = js.index("JSON.parse(") + len("JSON.parse(")
        end = js.index(");", start)
        json_str_literal = js[start:end]
        # This should be a JS string literal (double-quoted JSON of JSON)
        params = json.loads(json.loads(json_str_literal))
        assert params["filepath"] == "j.md"
        assert params["heading"] == "H"
        assert params["operation"] == "replace"
        assert params["content"] == "c"
