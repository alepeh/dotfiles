## 1. Test Infrastructure

- [x] 1.1 Create `tests/obsidian-cli/run-tests.sh` with assertion helpers (`assert_eq`, `assert_contains`, `assert_exit_0`, `assert_not_empty`), pass/fail counters, and summary reporting
- [x] 1.2 Add Obsidian-running check at script start (attempt a simple CLI command with timeout, exit with message if not reachable)
- [x] 1.3 Add setup function that creates `_test-obsidian-cli/` folder in vault and teardown via `trap` that removes it
- [x] 1.4 Wrap all CLI calls with `timeout 10` to prevent hangs
- [x] 1.5 Print Obsidian CLI version at start of run

## 2. CRUD Tests

- [x] 2.1 Test create + read: create a note with `silent` flag, read it back, assert content matches
- [x] 2.2 Test append: append to existing note, read back, assert appended content present
- [x] 2.3 Test prepend: prepend to existing note, read back, assert prepended content present
- [x] 2.4 Test delete: delete the note, assert read fails or returns empty
- [x] 2.5 Test move: create a note, move it to a subfolder, assert it exists at new path and not at old path

## 3. Search Tests

- [x] 3.1 Test search with known content: create a note with unique string, search for it, assert found in JSON output
- [x] 3.2 Test search with limit: search with `limit=1`, assert at most 1 result returned

## 4. Daily Notes Tests

- [x] 4.1 Test `daily:path` returns a non-empty path (skip all daily tests if this fails)
- [x] 4.2 Test `daily:read` returns content
- [x] 4.3 Test `daily:append` adds a test marker, verify by reading daily note
- [x] 4.4 Test `daily:prepend` adds a test marker, verify by reading daily note
- [x] 4.5 Clean up test markers from daily note after tests

## 5. Properties Tests

- [x] 5.1 Create a test note with frontmatter, test `properties format=tsv` returns TSV data
- [x] 5.2 Test `property:set` adds a property, verify with `properties format=tsv`
- [x] 5.3 Test `property:remove` removes the property, verify it's gone

## 6. Files and Navigation Tests

- [x] 6.1 Test `files folder=_test-obsidian-cli ext=md format=json` lists test notes
- [x] 6.2 Test backlinks: create note A linking to note B, assert `backlinks file="B"` includes A
- [x] 6.3 Test links: assert `links file="A"` includes B
- [x] 6.4 Test `orphans format=json` exits 0 and returns valid JSON

## 7. Tags and Tasks Tests

- [x] 7.1 Test `tags all counts` returns non-empty output
- [x] 7.2 Test `tasks all todo format=json` exits 0 and returns valid JSON
- [x] 7.3 Test `tasks all format=json` exits 0 and returns valid JSON

## 8. Eval Tests

- [x] 8.1 Test basic eval: `eval code="app.vault.getFiles().length"` returns a number > 0
- [x] 8.2 Test heading-edit eval: create note with two headings, replace content under one heading via eval, verify only that section changed

## 9. Silent Failure Workaround Tests

- [x] 9.1 Verify `tasks all todo` returns results (document if `tasks todo` returns 0)
- [x] 9.2 Verify `tags all counts` returns data (document if `tags counts` returns empty)
- [x] 9.3 Verify `properties format=tsv` returns TSV (document if `format=json` returns YAML instead)
- [x] 9.4 Verify `create ... silent` does not open GUI (note is created without focus steal)

## 10. Makefile Integration

- [x] 10.1 Add `test-obsidian` target to Makefile that runs `tests/obsidian-cli/run-tests.sh`
- [x] 10.2 Add `test-obsidian` to `.PHONY`
