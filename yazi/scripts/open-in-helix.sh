#!/bin/bash
# Open file in adjacent Helix pane (Zellij layout)
#
# This script is called by Yazi when opening a file.
# It focuses the Helix pane and sends the :open command.

file="$1"

if [ -z "$file" ]; then
    exit 0
fi

# Get absolute path
file=$(realpath "$file")

# Check if we're running inside Zellij
if [ -n "$ZELLIJ" ]; then
    # Focus the next pane (assumes Helix is to the right)
    zellij action focus-next-pane

    # Send the open command to Helix
    # Using Helix's command mode: :open <file>
    zellij action write-chars ":open ${file}"
    zellij action write 13  # Enter key
else
    # Fallback: open in new helix instance
    hx "$file"
fi
