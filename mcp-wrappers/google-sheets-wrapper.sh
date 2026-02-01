#!/bin/bash
if [ -f ~/.env.mcp ]; then
    source ~/.env.mcp
fi
export GOOGLE_APPLICATION_CREDENTIALS="$GOOGLE_SHEETS_SERVICE_ACCOUNT_PATH"
exec /opt/homebrew/bin/uvx mcp-google-sheets
