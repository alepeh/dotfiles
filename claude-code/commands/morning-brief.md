# Morning Brief — Daily Chief-of-Staff Briefing

Gather emails, calendar, tasks, and recent journals to produce a prioritised morning brief. Write it to Obsidian and present an approval queue for actions.

## Steps

1. **Determine dates**
   - Set `TODAY` to the current date (YYYY-MM-DD)
   - Set `YESTERDAY` to the previous date (YYYY-MM-DD)

2. **Fetch data sources** (run all four in parallel where possible)

   **Gmail** — `query_gmail_emails`
   - Account: `alexander@pehm.biz`
   - Query: `is:unread newer_than:1d`
   - Limit: 25
   - For each email, note: sender, subject, date, and a one-line summary (do NOT fetch full bodies unless needed for a specific action item — subject lines are usually sufficient)

   **Calendar** — `get_calendar_events`
   - Account: `alexander@pehm.biz`
   - Time range: start of TODAY to end of TOMORROW
   - For each event, note: title, start time, duration, attendee count, and a one-line context note

   **Todoist** — `find-tasks-by-date`
   - Start date: `today` (this automatically includes overdue items)
   - Limit: 30
   - Note: content, project, priority, due date, and whether overdue

   **Obsidian** — `obsidian_get_file_contents`
   - Read `journals/YESTERDAY.md` (replace YESTERDAY with the actual date)
   - If file doesn't exist, skip this step — note "no journal entry yesterday"
   - Look for any open items, Evening Recap carry-overs, or CoS Feedback section

3. **Scan recent journals for patterns** — `obsidian_get_file_contents`
   - Read the last 3-5 journal entries (headings and Follow-up sections only, not full content)
   - Look for recurring topics, themes, or items that keep appearing
   - If a topic appeared in 3+ recent journals, flag it: "Recurring theme: [topic] — appeared [N] times recently. Consider creating a dedicated project or systematic approach."
   - Also collect any `## Follow-up Next Session` items from the most recent journal

4. **Check for CoS Feedback**
   - If yesterday's journal (or today's, if it already exists) contains a `## CoS Feedback` section, read it carefully
   - Apply any preferences or corrections mentioned there to this run
   - Acknowledge the feedback in your output

5. **Synthesise the brief** — Produce the following sections:

   **Task Overview with Status Indicators**
   - Present all Todoist tasks with traffic light indicators:
     - 🔴 **Overdue** — past due date
     - 🟡 **Due today/this week** — high priority (p1/p2)
     - 🟢 **In progress** — has activity or `chief-of-staff` label, not overdue
     - ⚪ **Planned** — due later, lower priority
   - This overview comes first so the user sees their full task landscape at a glance

   **Priorities grouped by category** (replace the old flat list)
   - **URGENT** — overdue tasks, today's hard deadlines, emails requiring same-day reply
   - **OPERATIVE** — ongoing business items, routine follow-ups, this week's deadlines
   - **STRATEGIC** — longer-term items, recurring themes from journal scan, items that keep slipping
   - Each item gets one line: what it is, why it matters, and the source
   - Cap at 3-5 items per category; if more exist, mention the overflow

   **Today's Schedule**
   - List meetings/events chronologically with time, title, and one-line context
   - Flag meetings that look like they need prep (external attendees, presentations, reviews)
   - Group back-to-back meetings into blocks

   **Emails Needing Attention**
   - Separate into: "Needs Reply" vs "FYI Only"
   - For "Needs Reply": suggest a one-line response direction
   - **Implicit to-do detection**: For emails that don't explicitly ask for something but *imply* an action is needed (e.g., someone sends documents to review, a vendor shares pricing, a client mentions a problem), flag the implied action. Example: "Herr Mijajlovic sent product links → implied to-do: check Austrian certification status"
   - Skip obvious newsletters, notifications, and automated emails

   **Carry-overs & Follow-ups**
   - Items from yesterday's Evening Recap "Still Open" section
   - Items from the most recent `## Follow-up Next Session` section
   - Recurring themes flagged in step 3

6. **Build approval queue**
   - For each suggested action, categorise as:
     - `auto`: Safe to execute (create Todoist task with `chief-of-staff` label)
     - `approve`: Needs explicit approval (draft email, calendar change, ambiguous action)
   - Include both explicit actions and implicit to-dos detected from emails
   - Present the approval queue conversationally — describe each item and ask whether to proceed
   - Never auto-send emails. Never auto-modify calendar events. Never auto-delete anything.

7. **Write to Obsidian**
   - Check if `journals/TODAY.md` exists using `obsidian_get_file_contents`
   - If the file exists AND already contains a `# Morning Brief` heading:
     - Use `obsidian_patch_content` with `target_type: heading`, `target: Morning Brief`, `operation: replace` to overwrite (idempotency on re-run)
   - If the file exists but has no Morning Brief heading:
     - Use `obsidian_patch_content` to append after existing content
   - If the file does not exist:
     - Use `obsidian_append_content` to create it
   - Format the brief as Markdown under a `# Morning Brief` heading
   - Include a timestamp: `*Generated at HH:MM on YYYY-MM-DD*`
   - The Obsidian output should include the full brief (task overview, priorities, schedule, emails) but keep it concise
   - The detailed approval queue stays in the conversation only

8. **Present the brief and approval queue**
   - Show the user a formatted summary in the conversation
   - List each approval queue item with a number
   - Ask: "Which items should I action? (e.g. 'all', '1,3,5', or 'none')"
   - Wait for the user's response before taking any action

9. **Execute approved actions**
   - For approved Todoist tasks: use `add-tasks` with label `chief-of-staff` and appropriate project/due date
   - Before creating any task, search Todoist for existing tasks with similar content and `chief-of-staff` label to avoid duplicates
   - For approved email drafts: use `create_gmail_draft` with `[CoS Draft]` prefix in subject
   - Report what was created and link to relevant items

10. **Log decisions and follow-ups to Obsidian**
    - After executing approved actions, append two sections to today's journal:
    - `## Decisions` — what was approved/rejected and why (e.g., "Created task for Zulassungsprüfung based on Mijajlovic email", "Skipped reply to newsletter")
    - `## Follow-up Next Session` — items that need attention but aren't actionable right now (e.g., "Waiting for reply from X", "Revisit topic Y after meeting on Thursday")
    - Use `obsidian_patch_content` with heading-based replace for idempotency

## Guardrails

- **Read** Gmail, Calendar, Todoist, Obsidian: always allowed
- **Create** Todoist tasks (with `chief-of-staff` label): allowed after approval
- **Create** Gmail drafts (never send): allowed after approval
- **Append** to Obsidian journal: always allowed
- **Send** emails: never — always draft only
- **Modify** calendar events: never — flag for manual action
- **Delete** anything: never

## Context Window Management

- Do NOT fetch full email bodies — use subject + sender + snippet only
- Limit to 25 emails, 30 tasks — if more exist, mention the overflow count
- For recent journal scan (step 3): read headings + Follow-up sections only, not full content
- If yesterday's journal is very long, scan for headings and only read Morning Brief, Evening Recap, Follow-up Next Session, and CoS Feedback sections
