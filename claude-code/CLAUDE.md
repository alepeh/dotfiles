# Git Workflow Best Practices

## Branch Strategy

- Always create feature branches for new work - never commit directly to main
- Branch naming conventions:
  - `feature/` - new functionality
  - `fix/` - bug fixes
  - `docs/` - documentation changes
  - `refactor/` - code refactoring
  - `test/` - test additions or modifications
  - `chore/` - maintenance tasks

## Conventional Commits

Follow the [Conventional Commits](https://www.conventionalcommits.org/) specification:

- **Format**: `<type>(<scope>): <description>`
- **Types**:
  - `feat` - new feature
  - `fix` - bug fix
  - `docs` - documentation only
  - `style` - formatting, missing semicolons, etc.
  - `refactor` - code change that neither fixes a bug nor adds a feature
  - `test` - adding or correcting tests
  - `chore` - maintenance tasks, dependency updates

**Examples**:
- `feat(auth): add OAuth2 login support`
- `fix(api): handle null response from external service`
- `docs(readme): update installation instructions`

## Testing Requirements

- Create unit tests for all new functionality
- Run the full test suite before committing
- Ensure all tests pass before pushing
- Add integration tests for API endpoints and complex workflows

## Pre-Commit Checklist

Before each commit, verify:

- [ ] Working on a feature branch (not main)
- [ ] Tests written for new code
- [ ] All tests pass locally
- [ ] Code follows project style guidelines
- [ ] Commit message follows conventional format
- [ ] No sensitive data (API keys, passwords) in code

## Pull Request Guidelines

- Keep PRs focused and reasonably sized
- Include a clear description of changes
- Reference related issues when applicable
- Ensure CI checks pass before requesting review

## Makefile as Project Interface

Every project should have a Makefile (or Justfile) providing a standard command vocabulary:
- Run `make help` (or `just --list`) first to discover available commands
- Use `make <target>` instead of raw build/test/lint commands
- Standard targets: `dev`, `build`, `test`, `lint`, `clean` (not all may be present)
- When adding new tooling, add a corresponding Make target
- `/init-roadmap` auto-generates a Makefile if one doesn't exist

# Project Management

## Roadmap
- Check ROADMAP.md at the start of each session before doing significant work
- Use checkbox progression: `[ ]` → `[-]` → `[x]` with date stamps
- Move completed items to "Recently Completed" section
- Track small fixes in reference/AD_HOC_TASKS.md
- Never commit ROADMAP.md changes in the same commit as code changes

## Task Workflow
- Use TaskCreate only for complex multi-step features with real dependencies
  (e.g., "design schema" blocks "build API" blocks "write tests")
- For straightforward sequential work, just work naturally — don't create tasks as a focus aid
- When using tasks: set addBlockedBy for sequential phases, mark in_progress before starting,
  mark completed only after verification

## Workflow Commands
- `/init-roadmap` — Bootstrap a new project with ROADMAP.md and tracking files
- `/next-task` — Pick and start the highest priority roadmap item
- `/update-roadmap` — Sync roadmap with recent git activity
- `/new-diff` — Create a short-form changelog entry for the Hugo site
- `/retrospective` — End-of-session learnings capture
- `/morning-brief` — Chief-of-Staff daily briefing (Gmail, Calendar, Todoist, Obsidian)
- `/evening-recap` — Chief-of-Staff end-of-day review and carry-over planning

## Spec-Driven Development
Two SDD toolkits are available. Use spec-kit for thorough planning, OpenSpec for fast iteration.

### spec-kit (thorough)
Initialize with `specify init . --ai claude`, then use:
- `/speckit.constitution` — Establish project principles and guidelines
- `/speckit.specify` — Define requirements and user stories (focus on what/why, not tech stack)
- `/speckit.clarify` — Structured clarification of underspecified areas (run before planning)
- `/speckit.plan` — Create technical implementation plan with architecture and tech stack choices
- `/speckit.tasks` — Break the plan into ordered, actionable tasks with dependencies
- `/speckit.implement` — Execute all tasks to build the feature
- `/speckit.analyze` — Cross-artifact consistency & coverage analysis
- `/speckit.checklist` — Generate quality checklists for requirements validation

### OpenSpec (lightweight)
Initialize with `openspec init`, then use:
- `/opsx:new <name>` — Start a new change (creates proposal/specs/design/tasks folder)
- `/opsx:ff` — Fast-forward: generate all planning artifacts at once
- `/opsx:apply` — Implement all tasks from the plan
- `/opsx:archive` — Archive completed change
- `/opsx:onboard` — Onboard to an existing project

See `claude-code/WORKFLOW.md` for the full workflow guide.
