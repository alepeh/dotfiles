#!/usr/bin/env python3
"""
Acceptance-criteria gate for /sdlc:verify.

Reads changes/<name>/meta.yaml and validates that every AC ID listed under
`acceptance_criteria` is:

  1. present in <acceptance_dir>/<feature_group>.md
  2. marked ✅ in the acceptance file
  3. referencing a concrete test file path (backtick-quoted, after a `Test:` marker)
  4. the referenced test file exists on disk

Exits non-zero if any check fails. Intended to be called from the
/sdlc:verify command; can also be run manually:

    python tools/verify-ac.py changes/<name>

Configuration:
    The script reads .sdlc.yaml at the project root for:
      - feature_groups (list)  — the known group slugs
      - acceptance_dir (str)   — directory containing <group>.md files

    Graceful degradation:
      - If .sdlc.yaml is missing: falls back to defaults + empty feature_groups,
        which causes any run with a non-null acceptance_criteria to fail with
        a clear message telling the user to run /sdlc:bootstrap (or add the
        file manually).
      - If feature_groups == []: the AC gate is skipped with a neutral note.
        meta.yaml fields feature_group / acceptance_criteria may be null.
      - If meta.yaml sets acceptance_criteria: [] (empty list): skipped as
        cross-cutting.
      - If feature_group is "cross-cutting" but acceptance_criteria is
        non-empty: hard error — that combination is invalid.

Ported from ~/code/blackwhite/tools/verify-ac.py with generalization.
"""

from __future__ import annotations

import re
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import NoReturn

# ── Regex ──────────────────────────────────────────────────────────────

AC_ID_RE = re.compile(r"\b(AC-[A-Z]+-\d+)\b")
# An AC block starts at either a markdown heading `### AC-X-01 · …`
# or a list bullet `- **AC-X-01** — …`. Inline references in prose are ignored.
AC_SCOPE_RE = re.compile(r"^\s*(?:###?\s+|[-*]\s+\*\*AC-)")
STATUS_EMOJI_RE = re.compile(r"(✅|⚠️|📋)")
# Only grab file paths from lines that explicitly say "Test:" — avoids picking
# up backtick-quoted source filenames that happen to appear in AC prose.
TEST_LINE_RE = re.compile(r"(?i)(?:^|\s)test(?:s)?\s*[:：]")
TEST_PATH_RE = re.compile(r"`([^`]+?\.(?:py|js|ts|tsx|mjs|cjs|rb|go|rs))(?:::[^`]+)?`")

# ── Config loading ─────────────────────────────────────────────────────

DEFAULT_CONFIG = {
    "feature_groups": [],
    "acceptance_dir": "architecture/acceptance",
    "changes_dir": "changes",
}


def load_sdlc_config(root: Path) -> dict:
    """Parse .sdlc.yaml at the repo root. No PyYAML dep.

    Supports the fields this script cares about:
      - feature_groups: list of strings (block-list under the key)
      - acceptance_dir: string
      - changes_dir: string

    Unknown fields are ignored. Missing file → returns DEFAULT_CONFIG (which
    has feature_groups == [] → graceful-degradation path kicks in).
    """
    config_file = root / ".sdlc.yaml"
    if not config_file.exists():
        return dict(DEFAULT_CONFIG)

    cfg: dict = dict(DEFAULT_CONFIG)
    current_key: str | None = None
    for raw in config_file.read_text().splitlines():
        line = raw.rstrip()
        if not line or line.lstrip().startswith("#"):
            continue
        m_item = re.match(r"^\s*-\s+(.+?)\s*(?:#.*)?$", line)
        if m_item and current_key is not None:
            val = m_item.group(1).strip().strip("'\"")
            existing = cfg.get(current_key)
            if not isinstance(existing, list):
                cfg[current_key] = []
            cfg[current_key].append(val)
            continue
        m_kv = re.match(r"^([A-Za-z_][A-Za-z0-9_]*)\s*:\s*(.*?)\s*$", line)
        if m_kv:
            key = m_kv.group(1)
            raw_val = m_kv.group(2).strip()
            current_key = key
            if raw_val == "" or raw_val == "[]":
                cfg[key] = [] if raw_val == "[]" else None
            else:
                cfg[key] = _coerce(raw_val)
            continue
    # Ensure lists are lists even if parser got confused
    if not isinstance(cfg.get("feature_groups"), list):
        cfg["feature_groups"] = []
    return cfg


def _coerce(raw: str):
    s = raw.strip().strip("'\"")
    if s.lower() in {"null", "none", "~"}:
        return None
    return s


# ── meta.yaml loading ─────────────────────────────────────────────────


def load_meta(change_dir: Path) -> dict:
    """Parse meta.yaml. Supports scalars, nulls, and block lists."""
    meta_file = change_dir / "meta.yaml"
    if not meta_file.exists():
        fail(f"{change_dir}/meta.yaml not found")

    meta: dict = {}
    current_key: str | None = None
    for raw in meta_file.read_text().splitlines():
        line = raw.rstrip()
        if not line or line.lstrip().startswith("#"):
            continue
        m_item = re.match(r"^\s*-\s+(.+?)\s*(?:#.*)?$", line)
        if m_item and current_key is not None:
            val = m_item.group(1).strip().strip("'\"")
            existing = meta.get(current_key)
            if not isinstance(existing, list):
                meta[current_key] = []
            meta[current_key].append(val)
            continue
        m_kv = re.match(r"^([A-Za-z_][A-Za-z0-9_]*)\s*:\s*(.*?)\s*$", line)
        if m_kv:
            key = m_kv.group(1)
            raw_val = m_kv.group(2).strip()
            current_key = key
            if raw_val == "" or raw_val == "[]":
                meta[key] = [] if raw_val == "[]" else None
            else:
                meta[key] = _coerce(raw_val)
            continue
    return meta


# ── Acceptance-file parsing ───────────────────────────────────────────


@dataclass
class AcRecord:
    id: str
    status: str | None  # "✅" / "⚠️" / "📋" / None
    test_path: str | None
    line: int  # 1-based, for diagnostics


def parse_acceptance_file(path: Path) -> dict[str, AcRecord]:
    """Return { AC_ID: AcRecord } for every AC found in the file."""
    records: dict[str, AcRecord] = {}
    if not path.exists():
        return records

    lines = path.read_text().splitlines()
    current_id: str | None = None
    current_line: int = 0
    status: str | None = None
    test_path: str | None = None

    def flush():
        if current_id:
            records[current_id] = AcRecord(
                id=current_id,
                status=status,
                test_path=test_path,
                line=current_line,
            )

    for i, line in enumerate(lines, start=1):
        m = AC_ID_RE.search(line)
        if m and AC_SCOPE_RE.match(line):
            flush()
            current_id = m.group(1)
            current_line = i
            status = None
            test_path = None
            s = STATUS_EMOJI_RE.search(line)
            if s:
                status = s.group(1)
            if TEST_LINE_RE.search(line):
                t = TEST_PATH_RE.search(line)
                if t:
                    test_path = t.group(1)
            continue

        if current_id is None:
            continue

        # A new top-level heading closes the block.
        if line.startswith("## "):
            flush()
            current_id = None
            status = None
            test_path = None
            continue

        if status is None:
            s = STATUS_EMOJI_RE.search(line)
            if s:
                status = s.group(1)
        if test_path is None:
            if TEST_LINE_RE.search(line):
                t = TEST_PATH_RE.search(line)
                if t:
                    test_path = t.group(1)

    flush()
    return records


# ── Main ─────────────────────────────────────────────────────────────


def fail(msg: str) -> NoReturn:
    sys.stderr.write(f"[verify-ac] {msg}\n")
    sys.exit(1)


def main(argv: list[str]) -> int:
    if len(argv) < 2:
        sys.stderr.write("usage: verify-ac.py changes/<name>\n")
        return 2

    # Assume cwd is the project root. Allow override via env var for tests.
    root = Path.cwd()
    change_dir = (root / argv[1]).resolve()
    if not change_dir.is_dir():
        fail(f"change directory not found: {change_dir}")

    cfg = load_sdlc_config(root)
    feature_groups: list[str] = cfg.get("feature_groups") or []
    accept_dir = root / (cfg.get("acceptance_dir") or "architecture/acceptance")

    meta = load_meta(change_dir)
    ac_ids = meta.get("acceptance_criteria")
    group = meta.get("feature_group")

    # ── Graceful degradation paths ──

    if not feature_groups:
        # Project hasn't defined feature groups yet → skip the whole AC gate.
        print(
            "[verify-ac] feature_groups is empty in .sdlc.yaml — "
            "skipping AC gate (add groups when project needs formal AC tracking)."
        )
        return 0

    if ac_ids is None:
        fail(
            f"{change_dir.name}/meta.yaml is missing `acceptance_criteria:` "
            "(use [] for cross-cutting changes, or set to a list of AC IDs)."
        )

    if group is None:
        fail(
            f"{change_dir.name}/meta.yaml is missing `feature_group:` "
            f"(one of: {', '.join(feature_groups)} | cross-cutting)."
        )

    # Explicit cross-cutting opt-out.
    if not ac_ids:
        print("[verify-ac] no ACs declared — skipping (cross-cutting change).")
        return 0

    if group == "cross-cutting":
        fail(
            "feature_group is cross-cutting but acceptance_criteria is non-empty — "
            "pick a concrete group or clear the AC list."
        )

    if group not in feature_groups:
        fail(
            f"unknown feature_group '{group}'. "
            f"Expected one of: {', '.join(feature_groups)} | cross-cutting. "
            "Add the group to .sdlc.yaml or fix the meta.yaml."
        )

    accept_file = accept_dir / f"{group}.md"
    if not accept_file.exists():
        fail(
            f"acceptance file not found: {accept_file.relative_to(root)}. "
            f"Create it and define the ACs before verifying."
        )

    records = parse_acceptance_file(accept_file)

    errors: list[str] = []
    checked = 0
    green = 0
    for ac_id in ac_ids:
        checked += 1
        rec = records.get(ac_id)
        if rec is None:
            errors.append(
                f"  - {ac_id}: not found in {accept_file.relative_to(root)} — "
                "add the AC before verifying."
            )
            continue

        if rec.status != "✅":
            errors.append(
                f"  - {ac_id} ({accept_file.relative_to(root)}:{rec.line}): "
                f"status is {rec.status or 'missing'}, expected ✅."
            )

        if rec.test_path is None:
            errors.append(
                f"  - {ac_id} ({accept_file.relative_to(root)}:{rec.line}): "
                "no test file referenced. Cite the test path in a backtick-quoted string "
                "after a `Test:` marker."
            )
            continue

        test_path = (root / rec.test_path.split("::", 1)[0]).resolve()
        if not test_path.exists():
            errors.append(
                f"  - {ac_id}: referenced test `{rec.test_path}` does not exist on disk."
            )
            continue

        green += 1

    print(f"[verify-ac] group={group} checked={checked} green={green}")

    if errors:
        sys.stderr.write("[verify-ac] CRITICAL — acceptance gate failed:\n")
        for e in errors:
            sys.stderr.write(e + "\n")
        sys.stderr.write(
            f"\nFix by updating {accept_file.relative_to(root)} and/or adding the tests.\n"
        )
        return 1

    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
