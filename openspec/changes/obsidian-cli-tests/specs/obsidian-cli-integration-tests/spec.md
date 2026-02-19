## ADDED Requirements

### Requirement: Test infrastructure with setup and teardown
The test script SHALL create a `_test-obsidian-cli/` folder in the vault before tests and remove it after all tests complete (including on failure). The script SHALL check that Obsidian is running before executing tests and exit with a clear message if not. The script SHALL print the Obsidian CLI version at the start of the run.

#### Scenario: Obsidian not running
- **WHEN** the test script runs and Obsidian is not open
- **THEN** the script prints "Obsidian is not running — please open it and retry" and exits with code 1

#### Scenario: Clean teardown on success
- **WHEN** all tests complete successfully
- **THEN** the `_test-obsidian-cli/` folder and all test notes are deleted from the vault

#### Scenario: Clean teardown on failure
- **WHEN** a test fails partway through
- **THEN** the `_test-obsidian-cli/` folder is still cleaned up via trap before exit

### Requirement: Test result reporting
The script SHALL print each test name and PASS/FAIL result. At the end, it SHALL print a summary line `PASSED: N  FAILED: M` and exit 0 if all passed, 1 if any failed.

#### Scenario: All tests pass
- **WHEN** every assertion succeeds
- **THEN** the script exits 0 and prints `PASSED: N  FAILED: 0`

#### Scenario: Some tests fail
- **WHEN** one or more assertions fail
- **THEN** the script exits 1 and the summary shows the failure count

### Requirement: Test CRUD operations
The script SHALL test create, read, append, prepend, delete, and move commands.

#### Scenario: Create and read a note
- **WHEN** `obsidian vault=brain create name="_test-obsidian-cli/test-note" content="# Test\n\nHello" silent` is run
- **THEN** `obsidian vault=brain read path=_test-obsidian-cli/test-note.md` returns content containing "# Test" and "Hello"

#### Scenario: Append to a note
- **WHEN** `obsidian vault=brain append path=_test-obsidian-cli/test-note.md content="Appended line"` is run
- **THEN** reading the note contains "Appended line" after the original content

#### Scenario: Prepend to a note
- **WHEN** `obsidian vault=brain prepend path=_test-obsidian-cli/test-note.md content="Prepended line"` is run
- **THEN** reading the note contains "Prepended line" before the original content

#### Scenario: Delete a note
- **WHEN** `obsidian vault=brain delete path=_test-obsidian-cli/test-note.md` is run
- **THEN** reading the note fails or returns empty

#### Scenario: Move a note
- **WHEN** a note is created and then `obsidian vault=brain move file="test-move-src" to=_test-obsidian-cli/moved/` is run
- **THEN** the note exists at the new path and no longer exists at the original path

### Requirement: Test search
The script SHALL test search with text queries and output format options.

#### Scenario: Search finds a matching note
- **WHEN** a note with known content exists and `obsidian vault=brain search query="<known content>" format=json` is run
- **THEN** the output contains a JSON result referencing the test note

#### Scenario: Search with limit
- **WHEN** `obsidian vault=brain search query="<term>" limit=1` is run
- **THEN** at most 1 result is returned

### Requirement: Test daily notes
The script SHALL test daily note read, append, prepend, and path commands. Tests SHALL be skipped if daily notes are not configured.

#### Scenario: Daily path returns a value
- **WHEN** `obsidian vault=brain daily:path` is run
- **THEN** it returns a non-empty file path

#### Scenario: Daily read returns content
- **WHEN** `obsidian vault=brain daily:read` is run
- **THEN** it returns content (or the test creates today's daily note first if it doesn't exist)

#### Scenario: Daily append adds content
- **WHEN** `obsidian vault=brain daily:append content="<!-- test-marker-append -->"` is run
- **THEN** reading the daily note contains `<!-- test-marker-append -->`

#### Scenario: Daily prepend adds content
- **WHEN** `obsidian vault=brain daily:prepend content="<!-- test-marker-prepend -->"` is run
- **THEN** reading the daily note contains `<!-- test-marker-prepend -->`

### Requirement: Test properties (frontmatter)
The script SHALL test reading, setting, and removing frontmatter properties.

#### Scenario: Read properties from a note
- **WHEN** a note with frontmatter exists and `obsidian vault=brain properties path=<note> format=tsv` is run
- **THEN** the output contains the property names and values in TSV format

#### Scenario: Set a property
- **WHEN** `obsidian vault=brain property:set name="test-prop" value="test-val" path=<note>` is run
- **THEN** reading properties shows `test-prop` with value `test-val`

#### Scenario: Remove a property
- **WHEN** `obsidian vault=brain property:remove name="test-prop" path=<note>` is run
- **THEN** reading properties no longer contains `test-prop`

### Requirement: Test files and navigation
The script SHALL test file listing, backlinks, links, and orphans commands.

#### Scenario: List files in a folder
- **WHEN** `obsidian vault=brain files folder=_test-obsidian-cli ext=md format=json` is run
- **THEN** the output lists the test notes created in that folder

#### Scenario: Backlinks for a note
- **WHEN** note A links to note B and `obsidian vault=brain backlinks file="B" format=json` is run
- **THEN** the output includes note A

#### Scenario: Links from a note
- **WHEN** note A contains a link to note B and `obsidian vault=brain links file="A" format=json` is run
- **THEN** the output includes note B

#### Scenario: Orphans detection
- **WHEN** `obsidian vault=brain orphans format=json` is run
- **THEN** the command exits 0 and returns valid JSON

### Requirement: Test tags and tasks
The script SHALL test tag listing and task listing, using the `all` flag to avoid the documented silent failure.

#### Scenario: List all tags with counts
- **WHEN** `obsidian vault=brain tags all counts` is run
- **THEN** the output contains tag names with counts (non-empty if vault has tags)

#### Scenario: List all tasks (todo)
- **WHEN** `obsidian vault=brain tasks all todo format=json` is run
- **THEN** the command exits 0 and returns valid JSON

#### Scenario: List all tasks (all statuses)
- **WHEN** `obsidian vault=brain tasks all format=json` is run
- **THEN** the command exits 0 and returns valid JSON

### Requirement: Test eval
The script SHALL test basic eval and the heading-edit eval pattern.

#### Scenario: Basic eval returns a value
- **WHEN** `obsidian vault=brain eval code="app.vault.getFiles().length"` is run
- **THEN** the output is a number greater than 0

#### Scenario: Heading-edit eval replaces content under a heading
- **WHEN** a note has `## Section A` with content "old text" and the heading-edit eval pattern is used to replace it with "new text"
- **THEN** reading the note shows "new text" under `## Section A` and all other content is unchanged

### Requirement: Test silent failure workarounds
The script SHALL explicitly validate each documented workaround from the skill's gotchas table.

#### Scenario: tasks all todo vs tasks todo
- **WHEN** `obsidian vault=brain tasks all todo format=json` is run
- **THEN** it returns results (whereas `tasks todo` would return 0 results)

#### Scenario: tags all counts vs tags counts
- **WHEN** `obsidian vault=brain tags all counts` is run
- **THEN** it returns tag data (whereas `tags counts` would report no tags found)

#### Scenario: properties format=tsv vs format=json
- **WHEN** `obsidian vault=brain properties path=<note> format=tsv` is run
- **THEN** it returns actual TSV data (whereas `format=json` returns YAML)

#### Scenario: create with silent flag
- **WHEN** `obsidian vault=brain create name="<note>" content="test" silent` is run
- **THEN** the note is created without opening the GUI

### Requirement: Makefile target
A `test-obsidian` Make target SHALL exist that runs the test script.

#### Scenario: make test-obsidian runs the suite
- **WHEN** `make test-obsidian` is run
- **THEN** it executes the test script and reports results

### Requirement: Command timeout
Each CLI command invocation SHALL be wrapped with a 10-second timeout to prevent hangs.

#### Scenario: Hung command times out
- **WHEN** a CLI command hangs (e.g., Obsidian becomes unresponsive)
- **THEN** the test fails after 10 seconds rather than blocking indefinitely
