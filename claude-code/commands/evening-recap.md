# Evening Recap — Daily Chief-of-Staff Review

Review the day against the morning brief, capture what happened, and set up tomorrow.

## Link Formats

When presenting items, always include a clickable link to the source:

- **Todoist tasks**: `[task title](https://app.todoist.com/showTask?id={task_id})`
- **Gmail emails**: `[subject](https://mail.google.com/mail/u/0/#all/{email_id})` — use the `id` field from `query_gmail_emails`
- **Obsidian notes**: `[note title](obsidian://open?vault=brain&file={filepath_without_extension})` — e.g., `obsidian://open?vault=brain&file=journals/2026-02-08`
- **Google Calendar events**: `[event title](https://calendar.google.com/calendar/u/0/r/day/{YYYY}/{MM}/{DD})` — link to the day view

Include links in both the conversation output and the Obsidian journal. In Obsidian, use standard Markdown links (not wikilinks) so they work as clickable URLs.

## Steps

1. **Determine dates**
   - Set `TODAY` to the current date (YYYY-MM-DD)
   - Set `TOMORROW` to the next date (YYYY-MM-DD)

2. **Read today's journal** — `obsidian_get_file_contents`
   - Read `journals/TODAY.md`
   - If it contains a `# Morning Brief` section, parse out the priorities (URGENT/OPERATIVE/STRATEGIC), schedule, and action items
   - If it contains a `## Decisions` section, note what was already acted on
   - If it contains a `## Follow-up Next Session` section, collect those items
   - If no Morning Brief exists, note this — the recap will be based on raw data only

3. **Fetch end-of-day data** (run in parallel where possible)

   **Todoist completed** — `find-completed-tasks`
   - Since: TODAY, Until: TODAY
   - Get by: `completion` (when actually completed, not due date)
   - Capture `id` field for each task for linking
   - Note which tasks had the `chief-of-staff` label (agent-created vs manual)

   **Todoist still open** — `find-tasks-by-date`
   - Start date: `today`
   - Capture `id` field for each task for linking
   - Check which morning priorities are still open
   - Note any new tasks that appeared during the day

   **Gmail new** — `query_gmail_emails`
   - Account: `alexander@pehm.biz`
   - Query: `is:unread newer_than:12h`
   - Limit: 15
   - Capture `id` field for each email for linking
   - Identify emails that arrived after the morning brief

   **Calendar** — `get_calendar_events`
   - Account: `alexander@pehm.biz`
   - Time range: start of TODAY to end of TODAY
   - Check which meetings actually happened

4. **Escalation check** — `find-tasks`
   - Search Todoist for tasks with `chief-of-staff` label that are overdue by 3+ days
   - Search for tasks that have been rescheduled repeatedly (same content, different due dates appearing in recent journal Decisions sections)
   - Flag escalation items with links to the task:
     - Task overdue 3+ days: "[Task](link) has been open for [N] days — should we reprioritize, delegate, or drop it?"
     - Same topic rescheduled 3+ times across journals: "[Task](link) keeps getting pushed — is there a blocker we should address?"
     - Many overdue items in one Todoist project: "[Project] has [N] overdue items — is this project stalled?"

5. **Check for CoS Feedback**
   - If today's journal contains a `## CoS Feedback` section, read and acknowledge it
   - Apply any corrections to this run's output

6. **Compare morning plan vs. reality** — Produce the following sections:

   **Completed Today**
   - List completed Todoist tasks with 🟢 indicator and linked titles
   - Example: `🟢 [Angebot Burggrabengasse erstellen](https://app.todoist.com/showTask?id=12345)`
   - Note morning priorities that were accomplished
   - Include any wins or notable completions

   **Still Open**
   - Morning priorities that weren't addressed, with status indicators and linked titles:
     - 🔴 Was URGENT and still not done
     - 🟡 Was OPERATIVE, can carry to tomorrow
     - ⚪ Was STRATEGIC, no change expected
   - For each, briefly note why (if apparent from context) — meeting-heavy day, new urgent items displaced them, etc.

   **Escalations**
   - Items flagged in step 4 (only if any exist), each with a link to the task
   - Present each with a concrete suggestion: reprioritize, delegate, break into smaller tasks, or drop

   **New Items That Appeared**
   - Emails that arrived after the morning brief needing attention, each linked: `[Subject](https://mail.google.com/mail/u/0/#all/{email_id})`
   - **Implicit to-do detection**: flag emails that imply an action even if not explicit
   - Tasks added during the day (not from morning brief), linked to Todoist
   - Anything that disrupted the planned day

   **Tomorrow's Setup**
   - Carry-over items that should be priorities tomorrow, grouped by:
     - **URGENT** — overdue carry-overs, hard deadlines tomorrow
     - **OPERATIVE** — routine items, follow-ups
     - **STRATEGIC** — longer-term items worth scheduling time for
   - Each item linked to its Todoist task or source email
   - Any prep needed for tomorrow's first meeting
   - Upcoming deadlines in the next 2-3 days

7. **Write to Obsidian**
   - Check if `journals/TODAY.md` already contains a `# Evening Recap` heading:
     - If yes: use `obsidian_patch_content` with `target_type: heading`, `target: Evening Recap`, `operation: replace` to overwrite (idempotency)
     - If no: use `obsidian_patch_content` to append to the file, or `obsidian_append_content` if simpler
   - Format as Markdown under a `# Evening Recap` heading
   - Include a timestamp: `*Generated at HH:MM on YYYY-MM-DD*`
   - All links (Todoist, Gmail, Calendar) should be included as standard Markdown links
   - Include the full recap (completed, still open, escalations, new items, tomorrow's setup)

8. **Offer carry-over actions**
   - For items that should carry to tomorrow, offer to:
     - Reschedule existing Todoist tasks to tomorrow
     - Create new Todoist tasks (with `chief-of-staff` label) for items that don't have one
   - Before creating tasks, search for existing ones with similar content and `chief-of-staff` label
   - Present each proposed action and ask for approval
   - Never auto-create — always confirm first

9. **Present the recap**
   - Show a formatted summary in the conversation (with clickable links)
   - Highlight the day's completion rate (e.g. "3 of 5 morning priorities completed")
   - Show escalation items prominently if any exist
   - List proposed carry-over actions with numbers
   - Ask: "Which carry-overs should I create for tomorrow? (e.g. 'all', '1,2', or 'none')"

10. **Execute approved carry-overs**
    - For approved tasks: use `add-tasks` or `update-tasks` with label `chief-of-staff`, due tomorrow
    - Report what was created or rescheduled, including links to the Todoist tasks

11. **Log decisions and follow-ups to Obsidian**
    - Update today's journal with two sections (or create them if they don't exist):
    - `## Decisions` — append evening decisions to existing morning decisions, with links (e.g., "Carried over [task](https://app.todoist.com/showTask?id=12345) to tomorrow", "Dropped [task](link) — no longer relevant")
    - `## Follow-up Next Session` — replace with updated list of items for tomorrow's morning brief, with source links (e.g., "Check if reply from [email](https://mail.google.com/mail/u/0/#all/{id}) arrived")
    - Use `obsidian_patch_content` with heading-based replace for Follow-up; use append for Decisions (to preserve morning entries)

## Guardrails

- **Read** Gmail, Calendar, Todoist, Obsidian: always allowed
- **Create/update** Todoist tasks (with `chief-of-staff` label): allowed after approval
- **Append** to Obsidian journal: always allowed
- **Send** emails: never
- **Modify** calendar events: never
- **Delete** anything: never

## Context Window Management

- Focus on changes since the morning brief, not a full re-scan
- Email fetch is limited to 15 and 12h window (afternoon only)
- Skip full email bodies — subject + sender + snippet only
- If the journal is long, read only Morning Brief, Decisions, Follow-up Next Session, Evening Recap, and CoS Feedback headings
