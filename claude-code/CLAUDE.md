# Git Workflow Best Practices

## Branch Strategy

- Always create feature branches for new work - never commit directly to main/master
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

- [ ] Working on a feature branch (not main/master)
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
- `/retrospective` — End-of-session learnings capture

See `claude-code/WORKFLOW.md` for the full workflow guide.
