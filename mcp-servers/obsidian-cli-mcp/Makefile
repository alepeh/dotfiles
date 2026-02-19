SHELL := /bin/bash

.DEFAULT_GOAL := help

.PHONY: help test lint install dev

help: ## Show available targets
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n"} /^##@/ {printf "\n\033[1m%s\033[0m\n", substr($$0, 5)} /^[a-zA-Z_-]+:.*?## / {printf "  \033[36m%-25s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

##@ Development

dev: ## Install in development mode with test dependencies
	uv sync --group dev

test: ## Run test suite
	uv run pytest tests/ -v

lint: ## Run ruff linter
	uv run ruff check .

##@ Installation

install: ## Install as uv tool (globally available as obsidian-cli-mcp)
	uv tool install --from . obsidian-cli-mcp --force

doctor: ## Verify obsidian CLI is available
	@command -v obsidian >/dev/null 2>&1 && echo "✓ obsidian CLI found" || \
		(echo "✗ obsidian CLI not found" && \
		 echo "  Enable it: Obsidian → Settings → General → Command line interface" && \
		 exit 1)
