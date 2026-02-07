#!/bin/bash

# Example ntfy-macos notification handler script
# This script receives the notification message as the first argument
# and ntfy message metadata as environment variables.

# First argument (legacy, still supported)
MESSAGE="$1"

# Environment variables set by ntfy-macos
# NTFY_ID       - Unique message ID
# NTFY_TOPIC    - Topic name
# NTFY_TIME     - Message timestamp (Unix epoch)
# NTFY_EVENT    - Event type (usually "message")
# NTFY_TITLE    - Notification title (if set)
# NTFY_MESSAGE  - Notification message
# NTFY_PRIORITY - Priority level 1-5 (if set)
# NTFY_TAGS     - Comma-separated tags (if set)
# NTFY_CLICK    - Click URL (if set)

TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
LOG_FILE="$HOME/.ntfy-macos-handler.log"

# Log the message with metadata
echo "[$TIMESTAMP] Topic: $NTFY_TOPIC | Priority: ${NTFY_PRIORITY:-3} | Message: $NTFY_MESSAGE" >> "$LOG_FILE"

# Example: Different behavior based on priority
if [ "${NTFY_PRIORITY:-3}" -ge 4 ]; then
    # High priority: send follow-up notification via local server
    curl -s -X POST http://127.0.0.1:9292/notify \
        -H "Content-Type: application/json" \
        -d "{\"title\": \"Script completed\", \"message\": \"Handled high-priority alert from $NTFY_TOPIC\"}" \
        > /dev/null 2>&1
fi

# Example: Different behavior based on topic
case "$NTFY_TOPIC" in
    "backup-trigger")
        /usr/local/bin/run-backup.sh
        ;;
    "deploy")
        /usr/local/bin/deploy.sh
        ;;
    *)
        echo "[$TIMESTAMP] No specific handler for topic: $NTFY_TOPIC" >> "$LOG_FILE"
        ;;
esac

exit 0
