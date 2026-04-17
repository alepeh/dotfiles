---
name: sdlc:verify
description: Verify a change's implementation matches its artifacts — completeness (tasks + spec requirements), correctness (impl matches spec intent), acceptance-criteria gate (via scripts/verify-ac.py), coherence (rules + guidelines + domain model). Produces a report with CRITICAL/WARNING/SUGGESTION tiers. Run before /sdlc:archive.
---

Verify that an implementation matches the change artifacts. Four dimensions:
completeness, correctness, acceptance criteria, coherence. Read the
**change-protocol** skill for the dimension definitions.

**Input**: Optionally a change name. If omitted, infer or prompt.

## Steps

### 1. Select the change

If no name provided:
- List active changes (exclude `archive/`)
- Use **AskUserQuestion** if multiple

Read `<changes_dir>/<name>/meta.yaml` for type + `feature_group` +
`acceptance_criteria`.

### 2. Load all artifacts

Read everything in `<changes_dir>/<name>/`: `meta.yaml`, `proposal.md`,
`design.md`, `tasks.md`, `specs/`.

### 3. Verify Completeness

**Task completion:**
- Parse `tasks.md` checkboxes
- Count `- [ ]` (incomplete) vs `- [x]` (complete)
- Each incomplete task = **CRITICAL**

**Spec coverage** (if `specs/` exists):
- Extract all `### Requirement:` entries from the delta specs
- For each, search the codebase for implementation evidence
- Unimplemented requirement = **CRITICAL**

### 4. Verify Correctness

**Requirement implementation:**
- For each requirement from specs, search for the implementation
- If found, note file paths
- If implementation diverges from spec intent = **WARNING**

**Scenario coverage:**
- For each `#### Scenario:`, check if the WHEN/THEN conditions are handled
- Missing scenario coverage = **WARNING**

### 5. Verify Acceptance Criteria (gate)

Read `.sdlc.yaml`. If `feature_groups` is non-empty AND `meta.yaml` has a
non-null `acceptance_criteria` list, run the AC verifier:

```bash
python <SDLC_SCRIPTS>/verify-ac.py <changes_dir>/<name>
```

The verifier enforces:
- Every listed AC ID exists in `<acceptance_dir>/<feature_group>.md`
- Every listed AC references a concrete test path (not `*(needs test)*`)
- The referenced test file exists on disk
- The AC status in the acceptance file is ✅ (not ⚠️ or 📋)

Any failure = **CRITICAL** — blocks archive.

**If `.sdlc.yaml` has `feature_groups: []`:** skip the AC gate with a neutral
note in the report ("AC gate skipped — project has no feature_groups
defined"). This is the graceful-degradation path for early-stage projects.

**If `acceptance_criteria` is missing from `meta.yaml` but feature_groups is
populated:** emit **CRITICAL** and ask the user to classify the feature
group + pick/introduce AC IDs. (Cross-cutting changes may set
`acceptance_criteria: []` — still required for the field to be present.)

**Additionally remind the user to run the actual tests:** `make test`,
`make test-e2e`. This command does not execute the tests — it validates the
AC→test wiring. Trust `make test` for green/red.

### 6. Verify Coherence

**Design adherence** (if `design.md` exists):
- Extract key decisions
- Check the implementation follows them
- Contradiction = **WARNING**

**Architecture compliance:**
- Check against `<rules_file>` — any rules violated? = **WARNING**
- Check against `<guidelines>` — any convention deviations? = **SUGGESTION**

**Domain model** (if `meta.yaml` shows `domain_impact: additive | breaking`):
- Verify `<domain_model>` was updated
- If not updated = **CRITICAL**

### 7. Generate report

```
## Verification Report: <name>

### Summary
| Dimension            | Status                        |
|----------------------|-------------------------------|
| Completeness         | X/Y tasks, N reqs             |
| Correctness          | M/N reqs covered              |
| Acceptance Criteria  | G/T green, Z missing tests    |
| Coherence            | Followed | Issues              |

### CRITICAL (must fix before archive)
- ...

### WARNING (should fix)
- ...

### SUGGESTION (nice to fix)
- ...

### Assessment
<verdict: ready | fix needed>
```

## Graceful degradation

- Only `tasks.md` exists → verify task completion only, skip the rest
- `tasks.md` + `specs/` → verify completeness + correctness, skip design-adherence
- Full artifacts → verify all four dimensions
- Always note which checks were skipped and why

## Guardrails

- Every issue must include a specific, actionable recommendation with file
  references
- When uncertain, prefer SUGGESTION over WARNING, WARNING over CRITICAL
- Check architecture compliance (`<rules_file>`, `<guidelines>`) as part of
  coherence
- If domain impact was flagged, verify `<domain_model>` was updated
- This command does NOT run tests — only validates the AC→test wiring
- `<SDLC_SCRIPTS>` resolves to wherever `verify-ac.py` was installed during
  `/sdlc:bootstrap` (default: `tools/verify-ac.py` in the project, or the
  change-protocol skill's script dir if the project didn't vendor it)
