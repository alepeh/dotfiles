# Evening Recap — Daily Chief-of-Staff Review

Review the day against the morning brief, capture what happened, and set up tomorrow.

## Steps

1. **Determine dates**
   - Set `TODAY` to the current date (YYYY-MM-DD)
   - Set `TOMORROW` to the next date (YYYY-MM-DD)

2. **Read today's journal** — `obsidian_get_file_contents`
   - Read `journals/TODAY.md`
   - If it contains a `# Morning Brief` section, parse out the priorities, schedule, and action items
   - If no Morning Brief exists, note this — the recap will be based on raw data only

3. **Fetch end-of-day data** (run in parallel where possible)

   **Todoist completed** — `find-completed-tasks`
   - Since: TODAY, Until: TODAY
   - Get by: `completion` (when actually completed, not due date)
   - Note which tasks had the `chief-of-staff` label (agent-created vs manual)

   **Todoist still open** — `find-tasks-by-date`
   - Start date: `today`
   - Check which morning priorities are still open
   - Note any new tasks that appeared during the day

   **Gmail new** — `query_gmail_emails`
   - Account: `alexander@pehm.biz`
   - Query: `is:unread newer_than:12h`
   - Limit: 15
   - Identify emails that arrived after the morning brief

   **Calendar** — `get_calendar_events`
   - Account: `alexander@pehm.biz`
   - Time range: start of TODAY to end of TODAY
   - Check which meetings actually happened

4. **Check for CoS Feedback**
   - If today's journal contains a `## CoS Feedback` section, read and acknowledge it
   - Apply any corrections to this run's output

5. **Compare morning plan vs. reality** — Produce the following sections:

   **Completed Today**
   - List completed Todoist tasks
   - Note morning priorities that were accomplished
   - Include any wins or notable completions

   **Still Open**
   - Morning priorities that weren't addressed
   - Tasks that were due today but remain incomplete
   - For each, briefly note why (if apparent from context) — meeting-heavy day, new urgent items displaced them, etc.

   **New Items That Appeared**
   - Emails that arrived after the morning brief needing attention
   - Tasks added during the day (not from morning brief)
   - Anything that disrupted the planned day

   **Tomorrow's Setup**
   - Carry-over items that should be priorities tomorrow
   - Any prep needed for tomorrow's first meeting
   - Upcoming deadlines in the next 2-3 days

6. **Write to Obsidian**
   - Check if `journals/TODAY.md` already contains a `# Evening Recap` heading:
     - If yes: use `obsidian_patch_content` with `target_type: heading`, `target: Evening Recap`, `operation: replace` to overwrite (idempotency)
     - If no: use `obsidian_patch_content` to append to the file, or `obsidian_append_content` if simpler
   - Format as Markdown under a `# Evening Recap` heading
   - Include a timestamp: `*Generated at HH:MM on YYYY-MM-DD*`

7. **Offer carry-over actions**
   - For items that should carry to tomorrow, offer to:
     - Reschedule existing Todoist tasks to tomorrow
     - Create new Todoist tasks (with `chief-of-staff` label) for items that don't have one
   - Before creating tasks, search for existing ones with similar content and `chief-of-staff` label
   - Present each proposed action and ask for approval
   - Never auto-create — always confirm first

8. **Present the recap**
   - Show a formatted summary in the conversation
   - Highlight the day's completion rate (e.g. "3 of 5 morning priorities completed")
   - List proposed carry-over actions with numbers
   - Ask: "Which carry-overs should I create for tomorrow? (e.g. 'all', '1,2', or 'none')"

9. **Execute approved carry-overs**
   - For approved tasks: use `add-tasks` or `update-tasks` with label `chief-of-staff`, due tomorrow
   - Report what was created or rescheduled

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
- If the journal is long, read only Morning Brief, Evening Recap, and CoS Feedback headings
