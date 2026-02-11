---
title: "Makefiles as Project Interface"
date: 2026-02-11
draft: false
tags: ["Workflow", "Tooling", "Claude Code", "Productivity"]
summary: "Why a Makefile belongs in every project — as a universal interface for humans, CI systems, and AI coding agents."
---

I work across a lot of projects. Java with Maven, Node with npm (or pnpm, or yarn — who remembers which), Python with pip, Go with its own toolchain. Each has its own way to build, test, lint, run migrations, and start a dev server. The commands aren't hard, but they're different enough that I can't keep them in my head — especially when I'm jumping between codebases daily.

With the rise of agentic AI, this problem has gotten worse, not better. I'm exploring more frameworks and technologies than ever, often spinning up proof-of-concept projects in languages I haven't touched in months. The cognitive overhead isn't the code — it's remembering the incantations to make the code go.

The fix is almost embarrassingly simple: a Makefile in every project.

## The idea

Not as a build system — that's what Maven, Cargo, and `go build` are for. As an interface. A thin wrapper that gives every project the same vocabulary:

```makefile
make dev       # start the development environment
make build     # build the project
make test      # run the tests
make lint      # check code quality
make migrate   # run database migrations
make clean     # remove build artifacts
```

The underlying commands are completely different. `make test` might run `go test ./...` in one project and `./mvnw test` in another. But I don't need to remember that. I just type `make test`.

This works because Make doesn't care about your language. It runs shell commands. That's it. A Makefile for a Quarkus project:

```makefile
.PHONY: dev test build

dev:
    ./mvnw quarkus:dev

test:
    ./mvnw test

build: test
    ./mvnw package -Dnative
```

And for a Node project:

```makefile
.PHONY: dev test build

dev:
    npm run dev

test:
    npm test

build: test
    npm run build
```

Same interface, different plumbing. The dependency chain (`build` depends on `test`) is declared once and enforced automatically.

## Self-documenting with `make help`

The most useful pattern I've adopted is a `help` target that turns `make` into a CLI help menu. Add `##` comments after your targets:

```makefile
.DEFAULT_GOAL := help

help: ## Show available commands
    @awk 'BEGIN {FS = ":.*##"; printf "\nUsage: make \033[36m<target>\033[0m\n\n"} \
        /^[a-zA-Z_-]+:.*?##/ { printf "  \033[36m%-15s\033[0m %s\n", $1, $2 } \
        /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($0, 5) }' $(MAKEFILE_LIST)

##@ Development
dev: ## Start development environment
    docker compose up -d
    npm run dev

##@ Testing
test: ## Run all tests
    npm test

lint: ## Run linter
    npm run lint

##@ Database
migrate: ## Run database migrations
    npx prisma migrate deploy

db-reset: ## Drop, recreate, migrate, and seed the database
    npx prisma migrate reset --force
```

Now running `make` with no arguments prints a clean summary of every available command, grouped by section. No need to open the Makefile or dig through a README.

## Standard targets

After using this pattern across a dozen projects, I've settled on a core vocabulary:

| Target | Purpose |
|--------|---------|
| `help` | List available commands (default) |
| `dev` | Start the local development environment |
| `build` | Build the project |
| `test` | Run all tests |
| `lint` | Run linters and formatters |
| `migrate` | Run database migrations |
| `clean` | Remove build artifacts |
| `docker-build` | Build container image |
| `deploy` | Deploy (with dependency on `test` and `build`) |
| `doctor` | Check that all prerequisites are installed |

Not every project needs all of them. But when a target exists, it always means the same thing.

## The agent angle

Here's where it gets interesting. The same property that makes Makefiles useful for forgetful humans — a consistent, discoverable interface — makes them even more useful for AI coding agents.

When Claude Code or Codex drops into a project, it needs to figure out how to build, test, and run things. It could parse a `pom.xml`, guess at npm scripts, or read through a README. Or it could run `make help` and immediately know the full landscape.

Armin Ronacher [wrote about this](https://lucumr.pocoo.org/2025/6/12/agentic-coding/) in his agentic coding recommendations. He puts critical tools into a Makefile and made two changes specifically for agents: he protects his `make dev` target against spawning the dev server twice (because the agent sometimes doesn't know it's already running), and he logs all output to a file so the agent can `cat` the logs to diagnose issues. His example shows Claude Code running `make dev`, getting back "services already running," then pivoting to `make tail-log` to check the state — exactly the kind of resilient tooling that works well with an LLM that might not track process state perfectly.

The dependency graph helps too. When an agent runs `make deploy`, it doesn't need to know that tests and builds should run first. Make handles the ordering. The agent just needs to know the goal.

I document the available Make targets in my `CLAUDE.md` files so they're loaded into context at the start of every session:

```markdown
## Build & Run
Run `make help` for all commands. Key targets:
- `make dev` — Start development environment
- `make test` — Run tests (includes lint)
- `make migrate` — Run database migrations
```

This turns the Makefile into a tool contract between me, CI, and whatever agent happens to be working on the project.

## A note on alternatives

Make has real warts. Tabs-vs-spaces will bite you. The `.PHONY` declarations are noisy. Variable assignment has four different syntaxes. The error messages are cryptic.

[`just`](https://github.com/casey/just) is a modern command runner that fixes most of these issues — it accepts spaces, doesn't need `.PHONY`, has built-in `--list`, and supports recipe arguments cleanly. It even has a `just-mcp` adapter for LLM integration. If I were starting fresh with no constraints, I'd probably reach for `just`.

But Make is pre-installed on every Unix system, every CI runner understands it, and every AI model has seen millions of Makefiles in training. That ubiquity is hard to beat. I stick with Make for the same reason I'd write a README in English — it's the lingua franca.

## The real value

The Makefile pattern is less about Make and more about the principle: every project should have a discoverable, consistent, language-agnostic interface for its common operations. The tool matters less than the convention.

As AI agents become a regular part of the development workflow, this kind of interface stops being a convenience and starts being infrastructure. The agent needs to build your project, run your tests, start your services. Give it — and your future self — a clean, predictable way to do that.
