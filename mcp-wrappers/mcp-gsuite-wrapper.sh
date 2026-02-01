#!/bin/bash
if [ -f ~/.env.mcp ]; then
    source ~/.env.mcp
fi
cd ~
exec /opt/homebrew/bin/uvx --from ~/.local/share/mcp-gsuite-patched mcp-gsuite --gauth-file ~/.gauth.json
