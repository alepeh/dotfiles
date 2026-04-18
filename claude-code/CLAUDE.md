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
- `/sdlc:bootstrap` scaffolds a Makefile (plus the rest of the SDLC baseline) for new personal projects

# Project Management

## Task Workflow
- Use TaskCreate only for complex multi-step features with real dependencies
  (e.g., "design schema" blocks "build API" blocks "write tests")
- For straightforward sequential work, just work naturally — don't create tasks as a focus aid
- When using tasks: set addBlockedBy for sequential phases, mark in_progress before starting,
  mark completed only after verification

## Workflow Commands
- `/new-diff` — Create a short-form changelog entry for the Hugo site
- `/morning-brief` — Chief-of-Staff daily briefing (Gmail, Calendar, Todoist, Obsidian)
- `/evening-recap` — Chief-of-Staff end-of-day review and carry-over planning

## Agentic SDLC (personal projects, opt-in)
Installed via `make install-sdlc` in the dotfiles repo. One-time bootstrap,
then every subsequent piece of work is a change.

**Bootstrap** (rare, one-shot):
- `/sdlc:bootstrap <name>` — Scaffold a new project on the Cloudflare baseline
  (monorepo, Makefile, architecture/, .sdlc.yaml, OpenSpec, Obsidian note)
- `/sdlc:import <path>` — Retrofit an existing project onto the baseline

**Changes** (everyday, see `architecture/change-protocol.md` + the `change-protocol` skill):
- `/sdlc:new <name>` — Classify and scaffold a new change (one artifact at a time)
- `/sdlc:ff <name>` — Fast-forward: classify + all artifacts in one go
- `/sdlc:continue` — Create the next artifact for an in-flight change
- `/sdlc:apply` — Implement tasks from a change (prompts for rule-distillation at the end)
- `/sdlc:verify` — Verify implementation against artifacts (completeness/correctness/AC gate/coherence)
- `/sdlc:archive` — Distill rules, sync delta specs, move to archive/
- `/sdlc:explore` — Thinking partner for ideas and investigation (no implementation)

Not installed on Paysafe / work machines.
