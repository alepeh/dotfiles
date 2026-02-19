## Why

The Obsidian CLI skill was introduced to replace the old MCP server, but CLI commands have known silent failures (exit 0 with wrong/empty data) and undocumented edge cases. Without integration tests, there's no way to verify which commands actually work reliably before using them in workflows like morning-brief and evening-recap. Tests will serve as both a validation suite and a living reference for what works.

## What Changes

- Add a comprehensive shell-based integration test suite for all Obsidian CLI features documented in the skill
- Tests run against the live `brain` vault (Obsidian must be running)
- Cover all command categories: CRUD, search, daily notes, properties, tags, tasks, eval, heading-edit
- Explicitly validate the documented silent failure workarounds
- Add a `make test-obsidian` target to run the suite

## Capabilities

### New Capabilities
- `obsidian-cli-integration-tests`: Shell test suite that validates every Obsidian CLI feature used by the skill, including silent failure workarounds and heading-level eval edits

### Modified Capabilities

_(none — no existing spec requirements change)_

## Impact

- New test script(s) in the repo (likely `tests/obsidian-cli/`)
- New Makefile target `test-obsidian`
- Requires a running Obsidian instance with the `brain` vault open
- Creates and cleans up temporary test notes during execution
