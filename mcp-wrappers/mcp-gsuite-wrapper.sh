#!/bin/bash
if [ -f ~/.env.mcp ]; then
    source ~/.env.mcp
fi
cd ~
exec /opt/homebrew/bin/uvx mcp-gsuite --gauth-file ~/.gauth.json
