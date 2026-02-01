#!/bin/bash
if [ -f ~/.env.mcp ]; then
    source ~/.env.mcp
fi
exec ~/go/bin/github-mcp-server stdio
