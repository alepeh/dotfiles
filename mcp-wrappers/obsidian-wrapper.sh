#!/bin/bash
if [ -f ~/.env.mcp ]; then
    source ~/.env.mcp
fi
exec /opt/homebrew/bin/uvx mcp-obsidian
