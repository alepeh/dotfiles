#!/usr/bin/env bash
set -euo pipefail
git submodule foreach '
  set -e
  git fetch --tags --prune
  (git checkout main 2>/dev/null || git checkout master 2>/dev/null || true)
  git pull --ff-only || true
'
