---
title: "Added todo.txt via Docker"
date: 2019-01-23
draft: false
tags: ["Docker", "todo.txt"]
summary: "Introduced todo.txt-cli as a Dockerized shell function for plain-text task management."
---

This commit introduced todo.txt-cli as a Docker container, wrapped in a simple `t` shell function that mounts your task directory and forwards arguments to `todo.sh`. Todo.txt's beauty lies in its format: every task is a single line in a plain text file, with optional priority markers `(A)`, projects `+project`, and contexts `@context`. No database, no sync service — just a file you can `grep`, `sort`, `awk`, or edit in any text editor. Wrapping it in Docker meant zero local dependencies while keeping the full power of shell-based task management one keystroke away.
