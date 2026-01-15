#!/bin/bash

# Example ntfy-macos notification handler script
# This script receives the notification message as the first argument

MESSAGE="$1"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
LOG_FILE="$HOME/.ntfy-macos-handler.log"

# Log the message
echo "[$TIMESTAMP] Received: $MESSAGE" >> "$LOG_FILE"

# Example: Send a desktop notification using osascript
osascript -e "display notification \"$MESSAGE\" with title \"ntfy-macos Handler\""

# Example: You could trigger other actions here:
# - Send a Slack/Discord message
# - Update a dashboard
# - Restart a service
# - Run a deployment script
# - etc.

exit 0
