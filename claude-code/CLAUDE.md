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
