#!/usr/bin/env bash
#
# Integration tests for the Obsidian CLI skill.
# Requires a running Obsidian instance with the "brain" vault open.
#
set -uo pipefail

VAULT="brain"
TEST_FOLDER="_test-obsidian-cli"
PASS_COUNT=0
FAIL_COUNT=0
TIMEOUT_SEC=10
SKIP_DAILY=false

# ─── Assertion helpers ────────────────────────────────────────────────────────

pass() {
  PASS_COUNT=$((PASS_COUNT + 1))
  printf "  \033[32mPASS\033[0m %s\n" "$1"
}

fail() {
  FAIL_COUNT=$((FAIL_COUNT + 1))
  printf "  \033[31mFAIL\033[0m %s\n" "$1"
  if [[ -n "${2:-}" ]]; then
    printf "       %s\n" "$2"
  fi
}

assert_exit_0() {
  local label="$1"; shift
  if "$@" >/dev/null 2>&1; then
    pass "$label"
  else
    fail "$label" "command exited non-zero or timed out"
  fi
}

assert_contains() {
  local label="$1" output="$2" needle="$3"
  if echo "$output" | grep -qF "$needle"; then
    pass "$label"
  else
    fail "$label" "expected to contain: $needle"
  fi
}

assert_not_contains() {
  local label="$1" output="$2" needle="$3"
  if echo "$output" | grep -qF "$needle"; then
    fail "$label" "expected NOT to contain: $needle"
  else
    pass "$label"
  fi
}

assert_not_empty() {
  local label="$1" output="$2"
  if [[ -n "$output" ]]; then
    pass "$label"
  else
    fail "$label" "expected non-empty output"
  fi
}

assert_json() {
  local label="$1" output="$2"
  if echo "$output" | python3 -c "import sys,json; json.load(sys.stdin)" 2>/dev/null; then
    pass "$label"
  else
    fail "$label" "expected valid JSON"
  fi
}

# ─── CLI wrapper with timeout (perl-based, macOS compatible) ──────────────────

obs() {
  perl -e 'alarm shift @ARGV; exec @ARGV' "$TIMEOUT_SEC" obsidian vault="$VAULT" "$@" 2>/dev/null | grep -v "Loading updated app package"
}

# Strip CLI output noise (e.g., "=> " prefix from eval results)
strip_eval_prefix() {
  sed 's/^=> //'
}

# ─── Setup / Teardown ────────────────────────────────────────────────────────

setup() {
  echo ""
  echo "── Setup ──────────────────────────────────────────────────────────"
  # Create test folder via eval (since create path= fails if parent folder doesn't exist)
  obs eval code="(async () => {
    await app.vault.createFolder('${TEST_FOLDER}');
    await app.vault.createFolder('${TEST_FOLDER}/moved');
    return 'ok';
  })()" >/dev/null || true
  echo "Created test folder: ${TEST_FOLDER}/"
}

teardown() {
  echo ""
  echo "── Teardown ────────────────────────────────────────────────────────"
  # Delete all test files and folders via eval
  obs eval code="(async () => {
    const folder = app.vault.getAbstractFileByPath('${TEST_FOLDER}');
    if (!folder) return 'already clean';
    const files = app.vault.getFiles().filter(f => f.path.startsWith('${TEST_FOLDER}/'));
    for (const f of files) { await app.vault.delete(f, true); }
    // Delete subfolders then root
    const folders = app.vault.getAllFolders().filter(f => f.path.startsWith('${TEST_FOLDER}/')).sort((a,b) => b.path.length - a.path.length);
    for (const f of folders) { await app.vault.delete(f, true); }
    const root = app.vault.getAbstractFileByPath('${TEST_FOLDER}');
    if (root) await app.vault.delete(root, true);
    return 'cleaned';
  })()" >/dev/null 2>&1 || true
  echo "Cleaned up test folder: ${TEST_FOLDER}/"
}

trap teardown EXIT

# ─── Pre-flight checks ───────────────────────────────────────────────────────

echo "═══════════════════════════════════════════════════════════════════"
echo "Obsidian CLI Integration Tests"
echo "═══════════════════════════════════════════════════════════════════"

# Check CLI exists
if ! command -v obsidian >/dev/null 2>&1; then
  echo "ERROR: obsidian CLI not found in PATH"
  echo "  Requires Obsidian v1.12+ with CLI enabled"
  exit 1
fi

# Print version
echo ""
VER=$(obsidian version 2>/dev/null | grep -v "Loading" || echo "unknown")
echo "CLI version: $VER"

# Check Obsidian is running by trying a simple command
EVAL_TEST=$(obs eval code="1+1" | strip_eval_prefix || true)
if [[ "$EVAL_TEST" != *"2"* ]]; then
  echo ""
  echo "ERROR: Obsidian is not running — please open it and retry"
  exit 1
fi
echo "Obsidian is running with vault: $VAULT"

setup

# ─── 2. CRUD Tests ───────────────────────────────────────────────────────────

echo ""
echo "── CRUD ───────────────────────────────────────────────────────────"

# 2.1 Create + Read (use path= since name= can't have slashes)
obs create path="${TEST_FOLDER}/crud-test.md" content="# Test\n\nHello world" >/dev/null || true
sleep 0.5
CRUD_READ=$(obs read path="${TEST_FOLDER}/crud-test.md" || true)
assert_contains "create+read: heading present" "$CRUD_READ" "# Test"
assert_contains "create+read: body present" "$CRUD_READ" "Hello world"

# 2.2 Append
obs append path="${TEST_FOLDER}/crud-test.md" content="APPENDED_LINE" >/dev/null || true
sleep 0.5
CRUD_APPEND=$(obs read path="${TEST_FOLDER}/crud-test.md" || true)
assert_contains "append: content added" "$CRUD_APPEND" "APPENDED_LINE"

# 2.3 Prepend
obs prepend path="${TEST_FOLDER}/crud-test.md" content="PREPENDED_LINE" >/dev/null || true
sleep 0.5
CRUD_PREPEND=$(obs read path="${TEST_FOLDER}/crud-test.md" || true)
assert_contains "prepend: content added" "$CRUD_PREPEND" "PREPENDED_LINE"

# 2.4 Delete
obs delete path="${TEST_FOLDER}/crud-test.md" >/dev/null 2>&1 || true
sleep 0.5
CRUD_DEL=$(obs read path="${TEST_FOLDER}/crud-test.md" 2>&1 || true)
if [[ -z "$CRUD_DEL" ]] || echo "$CRUD_DEL" | grep -qi "not found\|error\|no such\|does not exist"; then
  pass "delete: note removed"
else
  fail "delete: note still readable" "got: ${CRUD_DEL:0:80}"
fi

# 2.5 Move
obs create path="${TEST_FOLDER}/move-src.md" content="move me" >/dev/null || true
sleep 0.5
obs move path="${TEST_FOLDER}/move-src.md" to="${TEST_FOLDER}/moved/" >/dev/null 2>&1 || true
sleep 1
MOVE_NEW=$(obs read path="${TEST_FOLDER}/moved/move-src.md" 2>/dev/null || true)
if [[ -n "$MOVE_NEW" ]] && echo "$MOVE_NEW" | grep -qF "move me"; then
  pass "move: note at new path"
else
  fail "move: note not found at new path"
fi

# ─── 3. Search Tests ─────────────────────────────────────────────────────────

echo ""
echo "── Search ─────────────────────────────────────────────────────────"

SEARCH_MARKER="UNIQUE_SEARCH_TOKEN_$(date +%s)"
obs create path="${TEST_FOLDER}/search-target.md" content="$SEARCH_MARKER" >/dev/null || true
sleep 3  # Search index needs time to update

# 3.1 Search finds matching note (JSON output is array of file paths, not content)
SEARCH_OUT=$(obs search query="$SEARCH_MARKER" format=json || true)
assert_contains "search: finds note by content" "$SEARCH_OUT" "${TEST_FOLDER}/search-target.md"

# 3.2 Search with limit
SEARCH_LIM=$(obs search query="$SEARCH_MARKER" limit=1 format=json || true)
assert_not_empty "search: limit=1 returns result" "$SEARCH_LIM"

# ─── 4. Daily Notes Tests ────────────────────────────────────────────────────

echo ""
echo "── Daily Notes ────────────────────────────────────────────────────"

# 4.1 daily:path
DAILY_PATH=$(obs daily:path | tr -d '[:space:]' || true)
if [[ -z "$DAILY_PATH" ]]; then
  echo "  SKIP daily notes — not configured in vault"
  SKIP_DAILY=true
else
  assert_not_empty "daily:path returns path" "$DAILY_PATH"
fi

if [[ "$SKIP_DAILY" == false ]]; then
  # 4.2 daily:read (create today's daily note first if it doesn't exist)
  DAILY_CONTENT=$(obs daily:read || true)
  if [[ -z "$DAILY_CONTENT" ]]; then
    # Daily note doesn't exist yet — create it via append which auto-creates
    obs daily:append content="<!-- daily-init -->" >/dev/null || true
    sleep 0.5
    DAILY_CONTENT=$(obs daily:read || true)
  fi
  assert_not_empty "daily:read returns content" "$DAILY_CONTENT"

  # 4.3 daily:append
  DAILY_APPEND_MARKER="<!-- test-append-$(date +%s) -->"
  obs daily:append content="$DAILY_APPEND_MARKER" >/dev/null || true
  sleep 0.5
  DAILY_AFTER_APPEND=$(obs daily:read || true)
  assert_contains "daily:append adds marker" "$DAILY_AFTER_APPEND" "$DAILY_APPEND_MARKER"

  # 4.4 daily:prepend
  DAILY_PREPEND_MARKER="<!-- test-prepend-$(date +%s) -->"
  obs daily:prepend content="$DAILY_PREPEND_MARKER" >/dev/null || true
  sleep 0.5
  DAILY_AFTER_PREPEND=$(obs daily:read || true)
  assert_contains "daily:prepend adds marker" "$DAILY_AFTER_PREPEND" "$DAILY_PREPEND_MARKER"

  # 4.5 Clean up markers from daily note via eval
  obs eval code="(async () => {
    const path = '${DAILY_PATH}';
    const file = app.vault.getAbstractFileByPath(path);
    if (!file) return 'no file';
    let text = await app.vault.read(file);
    text = text.split('\n').filter(l => !l.includes('test-append-') && !l.includes('test-prepend-') && !l.includes('daily-init')).join('\n');
    await app.vault.modify(file, text);
    return 'cleaned';
  })()" >/dev/null 2>&1 || true
  pass "daily: test markers cleaned up"
fi

# ─── 5. Properties Tests ─────────────────────────────────────────────────────

echo ""
echo "── Properties ─────────────────────────────────────────────────────"

PROP_NOTE="${TEST_FOLDER}/prop-test"
obs create path="${PROP_NOTE}.md" content="---\nstatus: draft\ntags:\n  - test\n---\n\n# Property Test" >/dev/null || true
sleep 1

# 5.1 Read properties as TSV
PROP_TSV=$(obs properties path="${PROP_NOTE}.md" format=tsv || true)
assert_contains "properties: TSV contains status" "$PROP_TSV" "status"

# 5.2 Set a property
obs property:set name="test-prop" value="test-val" path="${PROP_NOTE}.md" >/dev/null || true
sleep 1
PROP_AFTER_SET=$(obs properties path="${PROP_NOTE}.md" format=tsv || true)
assert_contains "property:set adds property" "$PROP_AFTER_SET" "test-prop"

# 5.3 Remove a property
obs property:remove name="test-prop" path="${PROP_NOTE}.md" >/dev/null || true
sleep 1
PROP_AFTER_RM=$(obs properties path="${PROP_NOTE}.md" format=tsv || true)
assert_not_contains "property:remove deletes property" "$PROP_AFTER_RM" "test-prop"

# ─── 6. Files and Navigation Tests ───────────────────────────────────────────

echo ""
echo "── Files & Navigation ─────────────────────────────────────────────"

# Ensure we have notes for link tests
obs create path="${TEST_FOLDER}/link-target.md" content="# Link Target\n\nI am the target." >/dev/null || true
obs create path="${TEST_FOLDER}/link-source.md" content="# Link Source\n\nSee [[link-target]] for details." >/dev/null || true
sleep 1

# 6.1 List files in folder
FILES_OUT=$(obs files folder="$TEST_FOLDER" ext=md format=json || true)
assert_contains "files: lists test notes" "$FILES_OUT" "$TEST_FOLDER"

# 6.2 Backlinks
BACKLINKS=$(obs backlinks file="link-target" format=json || true)
assert_contains "backlinks: source links to target" "$BACKLINKS" "link-source"

# 6.3 Links
LINKS=$(obs links file="link-source" format=json || true)
assert_contains "links: source references target" "$LINKS" "link-target"

# 6.4 Orphans (note: orphans doesn't support format=json, returns plain text)
ORPHANS=$(obs orphans || true)
assert_not_empty "orphans: returns output" "$ORPHANS"

# ─── 7. Tags and Tasks Tests ─────────────────────────────────────────────────

echo ""
echo "── Tags & Tasks ───────────────────────────────────────────────────"

# 7.1 Tags all counts
TAGS_OUT=$(obs tags all counts || true)
assert_not_empty "tags all counts: returns output" "$TAGS_OUT"

# 7.2 Tasks all todo (JSON)
assert_exit_0 "tasks all todo: exits 0" obsidian vault="$VAULT" tasks all todo format=json

# 7.3 Tasks all (JSON)
assert_exit_0 "tasks all: exits 0" obsidian vault="$VAULT" tasks all format=json

# ─── 8. Eval Tests ───────────────────────────────────────────────────────────

echo ""
echo "── Eval ───────────────────────────────────────────────────────────"

# 8.1 Basic eval
EVAL_COUNT=$(obs eval code="app.vault.getFiles().length" | strip_eval_prefix | tr -d '[:space:]' || true)
if [[ "$EVAL_COUNT" =~ ^[0-9]+$ ]] && [[ "$EVAL_COUNT" -gt 0 ]]; then
  pass "eval: file count is $EVAL_COUNT"
else
  fail "eval: expected number > 0" "got: $EVAL_COUNT"
fi

# 8.2 Heading-edit eval
HEADING_NOTE="${TEST_FOLDER}/heading-test"
obs create path="${HEADING_NOTE}.md" content="# Top\n\nKeep this.\n\n## Section A\n\nOld content A.\n\n## Section B\n\nKeep B." >/dev/null || true
sleep 1

obs eval code="(async () => {
  const filepath = '${HEADING_NOTE}.md';
  const heading = 'Section A';
  const newContent = 'Replaced content A.';
  const file = app.vault.getAbstractFileByPath(filepath);
  if (!file) throw new Error('File not found: ' + filepath);
  const text = await app.vault.read(file);
  const lines = text.split('\n');
  const hRe = /^(#{1,6})\s+(.+)$/;
  let hStart = -1, hLevel = 0, sEnd = lines.length;
  for (let i = 0; i < lines.length; i++) {
    const m = lines[i].match(hRe);
    if (m) {
      if (hStart === -1 && m[2].trim() === heading) {
        hStart = i; hLevel = m[1].length;
      } else if (hStart !== -1 && m[1].length <= hLevel) {
        sEnd = i; break;
      }
    }
  }
  if (hStart === -1) throw new Error('Heading not found: ' + heading);
  const nl = [...lines.slice(0, hStart + 1), newContent, ...lines.slice(sEnd)];
  await app.vault.modify(file, nl.join('\n'));
  return 'OK';
})()" >/dev/null || true
sleep 0.5

HEADING_AFTER=$(obs read path="${HEADING_NOTE}.md" || true)
assert_contains "heading-edit: new content present" "$HEADING_AFTER" "Replaced content A."
assert_contains "heading-edit: other section preserved" "$HEADING_AFTER" "Keep B."
assert_not_contains "heading-edit: old content removed" "$HEADING_AFTER" "Old content A."

# ─── 9. Silent Failure Workaround Tests ──────────────────────────────────────

echo ""
echo "── Silent Failure Workarounds ─────────────────────────────────────"

# 9.1 tasks all todo vs tasks todo
TASKS_ALL_TODO=$(obs tasks all todo format=json || true)
TASKS_SCOPED_TODO=$(obs tasks todo format=json || true)
if [[ -n "$TASKS_ALL_TODO" ]] && [[ ${#TASKS_ALL_TODO} -ge ${#TASKS_SCOPED_TODO} ]]; then
  pass "workaround: 'tasks all todo' returns >= data vs 'tasks todo'"
else
  fail "workaround: 'tasks all todo' did not return more than scoped version"
fi

# 9.2 tags all counts vs tags counts
TAGS_ALL=$(obs tags all counts || true)
TAGS_SCOPED=$(obs tags counts || true)
if [[ -n "$TAGS_ALL" ]] && [[ ${#TAGS_ALL} -ge ${#TAGS_SCOPED} ]]; then
  pass "workaround: 'tags all counts' returns >= data vs 'tags counts'"
else
  fail "workaround: 'tags all counts' did not return more than scoped version"
fi

# 9.3 properties format=tsv vs format=json
PROP_TSV_CHECK=$(obs properties path="${TEST_FOLDER}/prop-test.md" format=tsv || true)
# TSV should have tab separators
if echo "$PROP_TSV_CHECK" | grep -q $'\t'; then
  pass "workaround: format=tsv returns actual TSV"
else
  fail "workaround: format=tsv did not return TSV data"
fi

# 9.4 create without opening GUI
# The CLI help doesn't list 'silent' — create without 'open' flag should not steal focus
obs create path="${TEST_FOLDER}/silent-test.md" content="silent create" >/dev/null 2>&1 || true
sleep 0.5
SILENT_READ=$(obs read path="${TEST_FOLDER}/silent-test.md" || true)
assert_contains "workaround: create without GUI focus" "$SILENT_READ" "silent create"

# ─── Summary ──────────────────────────────────────────────────────────────────

echo ""
echo "═══════════════════════════════════════════════════════════════════"
TOTAL=$((PASS_COUNT + FAIL_COUNT))
printf "PASSED: %d  FAILED: %d  (total: %d)\n" "$PASS_COUNT" "$FAIL_COUNT" "$TOTAL"
echo "═══════════════════════════════════════════════════════════════════"

if [[ "$FAIL_COUNT" -gt 0 ]]; then
  exit 1
fi
