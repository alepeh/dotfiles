## Context

The Obsidian CLI (v1.12+) communicates via IPC with a running Obsidian instance. It has 100+ commands but documented silent failures where commands exit 0 with wrong or empty data. The obsidian-cli skill documents workarounds, but these have never been systematically validated. The test suite needs to run against a live vault since the CLI requires a running Obsidian instance — there's no mock/offline mode.

## Goals / Non-Goals

**Goals:**
- Validate every CLI feature referenced in the obsidian-cli skill
- Confirm documented silent failure workarounds actually work
- Self-contained test script with setup/teardown (no leftover test data in vault)
- Clear pass/fail output with failure details
- `make test-obsidian` as the single entry point

**Non-Goals:**
- Testing Obsidian CLI commands not used by the skill
- Performance/load testing
- Testing the skill file itself (just the underlying CLI commands)
- Mocking or offline testing — this is strictly live integration testing

## Decisions

**1. Plain shell test script (not a test framework)**
Shell script with simple assertion helpers (`assert_eq`, `assert_contains`, `assert_exit_0`). The dotfiles repo is shell-native — adding pytest or bats would be unnecessary dependencies. A single `tests/obsidian-cli/run-tests.sh` script keeps it simple.

**2. Dedicated test folder in vault for isolation**
All test notes go under a `_test-obsidian-cli/` folder in the vault. The script creates this folder at setup and deletes it at teardown. Prefix with `_` to sort to top and signal it's transient. Teardown runs even on failure via a `trap`.

**3. Test categories matching skill sections**
Organize tests into groups that map directly to the skill documentation:
- CRUD (read, create, append, prepend, delete, move)
- Search
- Daily notes (read, append, prepend, path)
- Properties (get, set, remove)
- Files and navigation (list, backlinks, links, orphans)
- Tags and tasks
- Eval (basic + heading-edit pattern)
- Silent failure workarounds (verify each documented gotcha)

**4. 10-second timeout per command**
Use `timeout 10` on each CLI call. If Obsidian isn't running or IPC hangs, the test fails fast rather than blocking indefinitely.

**5. Exit code summary**
Script exits 0 if all tests pass, 1 if any fail. Prints a summary line: `PASSED: N  FAILED: M`.

## Risks / Trade-offs

- **Requires running Obsidian** → Tests can't run in CI. Mitigation: document this clearly, make `make test-obsidian` check for Obsidian first and skip with a message if not running.
- **Daily notes depend on vault config** → The daily note path format varies per vault. Mitigation: use `daily:path` first to verify daily notes are configured, skip daily note tests if not.
- **Vault state interference** → Tests could collide with real notes if naming isn't careful. Mitigation: use `_test-obsidian-cli/` prefix and unique timestamps in note names.
- **CLI version differences** → Commands may behave differently across Obsidian versions. Mitigation: print CLI version at start of test run for debugging.
