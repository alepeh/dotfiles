# Initialize Project

Bootstrap this project with a Makefile, OpenSpec, and an Obsidian project note. Follow these steps in order.

## Step 1: Analyze the Project

- Read the existing codebase structure, package.json / build files, README, etc.
- Identify the tech stack, test framework, build commands, and linting setup.
- If a CLAUDE.md already exists, read it and preserve any existing content.

## Step 2: Generate Makefile

Based on what you learned in Step 1, create or update a Makefile as the project's command interface.

**If a Makefile already exists:** Check for missing standard targets (`help`, `dev`, `build`, `test`, `lint`, `clean`). Ask the user before adding any.

**If a Justfile exists (no Makefile):** Skip — note the Justfile in CLAUDE.md and use `just --list` instead.

**If neither exists:** Generate a `Makefile` with:

- `.DEFAULT_GOAL := help` and a self-documenting `help` target:
  ```makefile
  help: ## Show available targets
  	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n"} /^##@/ {printf "\n\033[1m%s\033[0m\n", substr($$0, 5)} /^[a-zA-Z_-]+:.*?## / {printf "  \033[36m%-25s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)
  ```
- `dev`, `build`, `test` targets — always present. Populate from Step 1 discovery, or use `@echo "TODO: configure [target]"` placeholder.
- `lint`, `migrate`, `clean` — only when applicable to the stack.
- `.PHONY` declarations for all targets.
- `##@` section groupings (e.g., `##@ Development`, `##@ Testing`, `##@ Build`).

**Tech stack fallback defaults** (use if Step 1 discovery didn't find explicit commands):

| Stack | dev | build | test | lint |
|-------|-----|-------|------|------|
| Node/npm | `npm run dev` | `npm run build` | `npm test` | `npm run lint` |
| Python | `python -m flask run` or `uvicorn` | — | `pytest` | `ruff check .` |
| Go | `go run .` | `go build ./...` | `go test ./...` | `golangci-lint run` |
| Rust | `cargo run` | `cargo build --release` | `cargo test` | `cargo clippy` |
| Java/Maven | `mvn spring-boot:run` | `mvn package` | `mvn test` | `mvn checkstyle:check` |
| Java/Gradle | `./gradlew bootRun` | `./gradlew build` | `./gradlew test` | `./gradlew check` |
| Hugo | `hugo server -D` | `hugo --gc --minify` | — | — |

## Step 3: Initialize OpenSpec

Run `openspec init` to create the `openspec/` directory for spec-driven development.

## Step 4: Update CLAUDE.md with Project Context

Add a **project-specific context section** to CLAUDE.md (the generic workflow rules are already in the global CLAUDE.md — don't duplicate them). Focus on:

```markdown
## Project Context
- **Stack**: [tech stack discovered in Step 1]
- **Build**: `make build` ([underlying command])
- **Test**: `make test` ([underlying command])
- **Lint**: `make lint` ([underlying command])

Run `make help` for all available commands.
```

Only add commands that actually exist in the project. If a Justfile is used instead, reference `just` commands.

## Step 5: Create Obsidian Project Note

Create a project overview note in Obsidian via the Obsidian CLI (`obsidian vault=brain create name="..." content="..." silent`). This note tracks the project's current state at a glance — it does **not** replace detailed technical documentation in the repository.

**Note path:** `notes/{Project Name}.md` (use the same name as the project directory or README title)

**Content:** Use the `Code Project Template` structure with frontmatter:

```markdown
---
category:
  - "[[Projects]]"
status: active
area:
repo: {github repo URL if known, otherwise leave blank}
tags:
  - projects
  - code
created: {today YYYY-MM-DD}
updated: {today YYYY-MM-DD}
---

# {Project Name}

## Überblick
{1-2 sentence description of the project based on what was learned in Step 1}

## Stack
{Bullet list of key technologies discovered in Step 1 — language, framework, database, hosting}

## Aktueller Stand
Projekt initialisiert. OpenSpec eingerichtet.

## Nächste Prioritäten
{Top 3-5 items to work on, based on project analysis or user input}

## Letzte Änderungen
- {today} — Projekt-Setup: Makefile, OpenSpec, Obsidian-Notiz erstellt

## Links
- Repository: {repo URL or local path}
- {Any deployment URLs, documentation links, or related Obsidian notes}
```

Write in German. Keep it concise — this is a status overview, not technical documentation.

## Step 6: Summary

After completing all steps, show:
- A summary of files created/modified
- Whether a Makefile was generated, augmented, or skipped (and why)
- The name of the Obsidian project note created
