# Outlook Calendar Export — Power Automate Flow

Hudson reads Outlook calendar data from a local folder populated by a Power Automate scheduled flow. Direct Microsoft Graph access is typically blocked by enterprise policy; Power Automate runs under *your* corporate identity and doesn't need admin consent.

## Contract

- **Output location**: `~/Library/CloudStorage/OneDrive-Paysafe/meeting_export/`
- **File per appointment**: one `.txt` file named `YYYY-MM-DDTHH_MM_SS.fffffff <subject>.txt`.
- **File contents**: a single JSON object — the raw Outlook event.

### Fields Hudson consumes

| Field | Purpose |
|---|---|
| `subject` | Display + filter (denylist, patterns) |
| `start`, `end`, `startWithTimeZone`, `endWithTimeZone` | Agenda ordering and display |
| `organizer` | Solo-blocker detection |
| `requiredAttendees` | Attendee list, solo-blocker detection |
| `optionalAttendees` | Solo-blocker detection |
| `location` | Display |
| `recurrence` / `seriesMasterId` | Marks recurring series |
| `categories` | Future filter dimension |
| `body` | Meeting prep context (HTML) |
| `webLink` | "Open in Outlook" |

## Flow shape (rough)

1. **Trigger**: Recurrence — daily at 06:30 local.
2. **Action**: Office 365 Outlook — *Get calendar view of events (V3)*
   - Calendar: your primary
   - Start: `utcNow()`
   - End: `addDays(utcNow(), 1)`
3. **Action**: Apply to each event
   1. *Compose* → the event object as JSON
   2. *Create file* (OneDrive for Business)
      - Folder: `/meeting_export`
      - File name: `@{formatDateTime(items('Apply_to_each')?['start'], 'yyyy-MM-ddTHH_mm_ss.fffffff')} @{items('Apply_to_each')?['subject']}.txt`
      - File content: output of the Compose step

## Hygiene

- Use a separate sub-step at the start of the daily flow to delete files older than 7 days in `/meeting_export` so the folder doesn't grow unbounded.
- The flow owner identity must have rights to the OneDrive folder that syncs to this Mac.

## Failure mode

If the flow doesn't run or OneDrive hasn't synced, Hudson will report `Calendar: no export for today found at <path>` in the morning briefing and proceed without the agenda section. No crash, no blocking behaviour.
