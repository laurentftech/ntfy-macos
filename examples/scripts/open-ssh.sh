#!/bin/bash
# Open SSH session in Terminal
# Triggered by: server-alerts topic action button

MESSAGE="$1"

# Extract server name from message if provided, or use default
SERVER="${MESSAGE:-myserver.example.com}"

# Open Terminal with SSH session
osascript -e "tell application \"Terminal\"
    activate
    do script \"ssh $SERVER\"
end tell"
