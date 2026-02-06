# Initialize Project with Roadmap & Task Management

Bootstrap this project with a roadmap-driven workflow. Follow these steps in order.

## Step 1: Analyze the Project

- Read the existing codebase structure, package.json / build files, README, etc.
- Identify the tech stack, test framework, build commands, and linting setup.
- If a CLAUDE.md already exists, read it and preserve any existing content.

## Step 2: Create ROADMAP.md

Create `ROADMAP.md` in the project root with this structure:

```markdown
# [Project Name] Roadmap

## Progress Convention
- `[ ]` = Todo | `[-]` = In Progress 🏗️ | `[x]` = Completed ✅
- Add date when starting (🏗️ YYYY-MM-DD) and completing (✅ YYYY-MM-DD)

## Current Sprint
<!-- Move items here that are actively being worked on -->

## High Priority
<!-- Features and fixes that should be tackled next -->

## Backlog
<!-- Lower priority items, ideas, tech debt -->

## Recently Completed
<!-- Move finished items here with completion date -->
```

Interview me briefly using AskUserQuestion — ask about:
1. What are the top 3-5 features or tasks to work on next?
2. Any known tech debt or refactors needed?
3. Any blockers or dependencies I should know about?

Then populate the roadmap with my answers.

## Step 3: Create AD_HOC_TASKS.md

Create `reference/AD_HOC_TASKS.md` (create the `reference/` directory if needed):

```markdown
# Ad Hoc Tasks & Small Fixes

Quick tasks too small for the roadmap but worth tracking.

## Pending
<!-- Small fixes, one-off improvements -->

## Done
<!-- Completed ad hoc items -->
```

## Step 4: Update CLAUDE.md with Project Context

Add a **project-specific context section** to CLAUDE.md (the generic roadmap workflow rules are already in the global CLAUDE.md — don't duplicate them). Focus on:

```markdown
## Project Context
- **Stack**: [tech stack discovered in Step 1]
- **Build**: `[build command]`
- **Test**: `[test command]`
- **Lint**: `[lint command]`
```

Only add commands that actually exist in the project.

## Step 5: Summary

After completing all steps, show me:
- A summary of files created/modified
- The current state of ROADMAP.md
- Remind me to set `CLAUDE_CODE_TASK_LIST_ID=<project-name>` in my shell if I want multi-session task sync
