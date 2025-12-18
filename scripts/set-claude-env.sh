#!/bin/bash

# ============================================================================
# DEPRECATED: This script uses the old launchctl method
# ============================================================================
# The new setup uses wrapper scripts instead, which is more reliable.
# See: claude/README.md for the updated approach
#
# This script is kept for backward compatibility and migration purposes.
# ============================================================================

# Script to set environment variables for Claude Desktop from ~/.env file
# Note: This uses launchctl which requires re-running after each reboot

ENV_FILE="$HOME/.env"

if [[ ! -f "$ENV_FILE" ]]; then
    echo "Warning: ~/.env file not found at $ENV_FILE"
    echo "Please:"
    echo "1. Copy the .env template: cp ~/code/dotfiles/claude/.env.template ~/.env"
    echo "2. Edit ~/.env and replace the placeholder values with your actual API keys"
    echo "3. Run this script again: $0"
    exit 0
fi

echo "Setting environment variables for Claude Desktop..."

# Check if .env contains placeholder values
if grep -q "your_.*_here" "$ENV_FILE"; then
    echo "Warning: ~/.env contains placeholder values (your_*_here)"
    echo "Please edit ~/.env and replace these with your actual API keys before proceeding."
    echo "Then run this script again."
    exit 0
fi

# Read .env file and set variables using launchctl
while IFS='=' read -r key value || [[ -n "$key" ]]; do
    # Skip comments and empty lines
    if [[ "$key" =~ ^[[:space:]]*# ]] || [[ -z "$key" ]]; then
        continue
    fi
    
    # Remove leading/trailing whitespace
    key=$(echo "$key" | xargs)
    value=$(echo "$value" | xargs)
    
    if [[ -n "$key" && -n "$value" ]]; then
        echo "Setting $key"
        launchctl setenv "$key" "$value"
    fi
done < "$ENV_FILE"

echo "Environment variables set! Please restart Claude Desktop or restart your Mac."
echo "You can verify by running: launchctl getenv OBSIDIAN_API_KEY"