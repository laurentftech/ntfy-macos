#!/bin/bash
# Update yt-dlp to the latest version
# Triggered by: yt-dlp-releases topic
# Requires: local_server_port enabled in config

LOG_FILE="/tmp/yt-dlp-update.log"
LOCAL_SERVER="http://127.0.0.1:9292/notify"

notify() {
    local title="$1"
    local message="$2"
    local priority="${3:-3}"
    local tags="${4:-}"
    curl -s -X POST "$LOCAL_SERVER" \
        -H "Content-Type: application/json" \
        -d "{\"title\": \"$title\", \"message\": \"$message\", \"priority\": $priority, \"tags\": [\"$tags\"]}" \
        > /dev/null 2>&1
}

echo "$(date): Starting yt-dlp update..." >> "$LOG_FILE"

OLD_VERSION=$(yt-dlp --version 2>/dev/null || echo "not installed")

if command -v brew &> /dev/null && brew list yt-dlp &> /dev/null; then
    OUTPUT=$(brew upgrade yt-dlp 2>&1)
elif command -v pipx &> /dev/null && pipx list 2>/dev/null | grep -q yt-dlp; then
    OUTPUT=$(pipx upgrade yt-dlp 2>&1)
elif command -v pip3 &> /dev/null; then
    OUTPUT=$(pip3 install --user --upgrade yt-dlp 2>&1)
else
    echo "$(date): No package manager found to update yt-dlp" >> "$LOG_FILE"
    notify "yt-dlp Update Failed" "No package manager found (pip3/brew)" 4 "x"
    exit 1
fi

EXIT_CODE=$?
echo "$OUTPUT" >> "$LOG_FILE"

if [ $EXIT_CODE -ne 0 ]; then
    echo "$(date): Update failed with exit code $EXIT_CODE" >> "$LOG_FILE"
    notify "yt-dlp Update Failed" "Update command failed (exit $EXIT_CODE)" 4 "x"
    exit 1
fi

NEW_VERSION=$(yt-dlp --version 2>/dev/null || echo "unknown")

if [ "$OLD_VERSION" = "$NEW_VERSION" ]; then
    echo "$(date): yt-dlp already at latest version ($NEW_VERSION)" >> "$LOG_FILE"
    notify "yt-dlp" "Already at latest version ($NEW_VERSION)" 2 "white_check_mark"
else
    echo "$(date): yt-dlp updated from $OLD_VERSION to $NEW_VERSION" >> "$LOG_FILE"
    notify "yt-dlp Updated" "$OLD_VERSION → $NEW_VERSION" 3 "tada"
fi
