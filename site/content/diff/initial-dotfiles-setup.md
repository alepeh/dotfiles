---
title: "Initial Dotfiles Setup"
date: 2019-01-22
draft: false
tags: ["Shell", "Docker"]
summary: "The very first commit — a bash profile, Docker wrapper functions, and a Makefile to symlink them all."
pr: "https://github.com/alepeh/dotfiles/commit/62ccce4"
---

This is where it all started. A `.bash_profile` that sources a `.dockerfunc` file, a couple of Docker wrapper functions for `yq` and a personal shell container, and a Makefile that symlinks everything into `$HOME`. The whole thing was documented in an Org-mode literate programming file (`dotfiles.org`) that tangled out the actual dotfiles — I found the literate programming approach in Emacs with Org-mode very powerful. In practice though, I spent more time tweaking my Emacs setup and getting complicated X11 tunneling to work with Docker than actually using the system.
