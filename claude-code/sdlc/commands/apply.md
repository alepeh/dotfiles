---
name: sdlc:apply
description: Implement the tasks from a change. Reads the change's artifacts and architecture rules/guidelines, loops through pending tasks, marks each complete as code is written, and prompts for rule-distillation at the end. Use when ready to write code for a scoped change.
---

Implement tasks from a change, guided by its artifacts and the project's
architecture system. Read the **change-protocol** skill for the
rule-distillation prompt and format.

**Input**: Optionally a change name. If omitted, infer from conversation
context or prompt.

## Steps

### 1. Select the change

If no name provided:
- List active changes: `ls <changes_dir>/` (excluding `archive/`)
- Auto-select if only one
- If multiple, use **AskUserQuestion**

Announce: "Implementing change: <name>"

### 2. Read architecture context

Before any implementation:
- `<rules_file>` — distilled rules to follow (these are load-bearing — they
  exist because past changes surfaced lessons)
- `<guidelines>` — coding conventions
- `<domain_model>` — only if `meta.yaml` shows domain impact

### 3. Read change artifacts

Read every artifact in `<changes_dir>/<name>/`:
- `meta.yaml` — type, domain impact
- `proposal.md` — why and what
- `specs/` — requirements and scenarios
- `design.md` — technical decisions
- `tasks.md` — the task list

### 4. Check task status

Parse `tasks.md` checkboxes:
- `- [ ]` = pending
- `- [x]` = complete

If all tasks complete: congratulate, suggest `/sdlc:verify` or `/sdlc:archive`.
STOP.

### 5. Implement tasks (loop until done or blocked)

For each pending task:
- Announce which task is being worked on
- Make the code changes required
- Keep changes minimal and focused on the task
- Follow rules from `<rules_file>` and conventions from `<guidelines>`
- Mark task complete in `tasks.md`: `- [ ]` → `- [x]`
- Continue to next task

**Pause if:**
- Task is unclear → ask for clarification
- Implementation reveals a design issue → suggest updating artifacts, don't
  silently patch around it
- Error or blocker → report and wait
- User interrupts

### 6. On completion, prompt for DISTILL

When all tasks are done, ask:

> All tasks complete. Before we wrap up — did this implementation reveal
> anything that should become a rule?
>
> Look for:
> - Mistakes narrowly avoided
> - Patterns that worked well
> - Assumptions that broke
> - Debt taken on deliberately
>
> If yes, I'll add it to `<rules_file>`. If nothing stands out, that's fine
> too.

If the user identifies a rule: add it to `<rules_file>` with the next R-NNN
ID and update `meta.yaml` `rules_distilled` field. Use the format from the
**change-protocol** skill:

```
### R-NNN: <rule title>
**Source:** <change-name>
**Rule:** <the rule, one sentence>
**Why:** <the reason>
```

## Output during implementation

```
## Implementing: <name> (<type>)

Working on task 3/7: <task description>
[...implementation...]
Task complete.

Working on task 4/7: <task description>
```

## Output on completion

```
## Implementation Complete

**Change:** <name>
**Type:** <type>
**Progress:** 7/7 tasks complete
**Rules distilled:** R-NNN, R-NNN | none

All tasks complete. Ready for `/sdlc:verify` or `/sdlc:archive`.
```

## Guardrails

- Always read architecture context before starting
- Keep going through tasks until done or blocked
- If a task is ambiguous, pause and ask
- If implementation reveals design issues, pause and suggest artifact updates
  — don't silently patch
- Keep code changes minimal and scoped per task
- Update the task checkbox immediately after each task, not in a batch at the end
- Follow `<rules_file>` and `<guidelines>` during implementation
