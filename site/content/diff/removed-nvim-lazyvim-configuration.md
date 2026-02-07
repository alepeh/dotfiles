---
title: "Removed nvim/LazyVim Configuration"
date: 2026-01-17
draft: false
tags: ["Neovim", "Helix"]
summary: "Dropped the nvim/LazyVim config after switching to Helix as the terminal editor."
pr: "https://github.com/alepeh/dotfiles/pull/2"
---

Removed the entire `nvim/` directory that held a LazyVim-based Neovim configuration. Helix has taken over as the terminal editor — it's lightweight, needs almost no configuration, and still ships with advanced features like built-in LSP support, a file picker, and a selection-first editing model that feels more intuitive than Vim's verb-first approach. With the general direction of agentic AI development putting less emphasis on heavyweight IDE-like editors — true for the terminal as well — a minimal, capable editor like Helix is the better fit.
