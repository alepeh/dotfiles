---
title: "Added Claude Code and Codex to installation"
date: 2025-08-10
draft: false
tags: ["Claude Code", "Shell"]
summary: "Adding Claude Code and OpenAI Codex to the automated install script."
---

Adding Claude Code and OpenAI Codex as globally-installed npm packages to the install script. Node.js goes into the Brewfile as a prerequisite, and `scripts/install.sh` gets two `npm install -g` lines for `@anthropic-ai/claude-code` and `@openai/codex`. First appearance of AI coding agents in the dotfiles.
