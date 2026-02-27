## ADDED Requirements

### Requirement: make cleanup-dry shows orphaned processes without killing them
The `make cleanup-dry` target SHALL display counts and memory usage for orphaned wrangler dev servers, workerd runtimes, esbuild service processes, and EXITED Zellij sessions, without terminating any of them.

#### Scenario: Orphaned processes exist
- **WHEN** `make cleanup-dry` runs and orphaned dev processes are found
- **THEN** it displays each process category with count, memory usage in MB, and a total reclaimable memory summary

#### Scenario: No orphaned processes
- **WHEN** `make cleanup-dry` runs and no orphaned processes are found
- **THEN** it displays zero counts and 0 MB for each category

#### Scenario: EXITED Zellij sessions exist
- **WHEN** `make cleanup-dry` runs and EXITED Zellij sessions are present
- **THEN** it lists each EXITED session name

#### Scenario: Zellij is not installed
- **WHEN** `make cleanup-dry` runs and `zellij` is not on PATH
- **THEN** it displays "zellij not found" in the Zellij section without failing

### Requirement: make cleanup kills orphaned processes and cleans EXITED Zellij sessions
The `make cleanup` target SHALL terminate orphaned wrangler, workerd, esbuild, and pywrangler processes via `pkill`, and delete EXITED Zellij sessions via `zellij delete-session`.

#### Scenario: Orphaned processes are killed
- **WHEN** `make cleanup` runs and orphaned dev processes exist
- **THEN** each category is killed and a confirmation message is printed for each

#### Scenario: No processes to kill
- **WHEN** `make cleanup` runs and no orphaned processes are found
- **THEN** it prints a "no processes running" message for each category without error

#### Scenario: EXITED Zellij sessions are deleted
- **WHEN** `make cleanup` runs and EXITED Zellij sessions exist
- **THEN** each EXITED session is deleted and a confirmation message is printed

### Requirement: cleanup targets are registered as PHONY
The Makefile SHALL include `cleanup` and `cleanup-dry` in the `.PHONY` declaration.

#### Scenario: Targets are always re-run
- **WHEN** `make cleanup` or `make cleanup-dry` is invoked
- **THEN** the target always executes regardless of filesystem state
