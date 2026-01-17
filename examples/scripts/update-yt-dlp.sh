#!/bin/bash
# Update yt-dlp to the latest version
# Triggered by: yt-dlp-releases topic

LOG_FILE="/tmp/yt-dlp-update.log"

echo "$(date): Starting yt-dlp update..." >> "$LOG_FILE"

if command -v pip3 &> /dev/null; then
    pip3 install --upgrade yt-dlp >> "$LOG_FILE" 2>&1
elif command -v brew &> /dev/null; then
    brew upgrade yt-dlp >> "$LOG_FILE" 2>&1
else
    echo "$(date): No package manager found to update yt-dlp" >> "$LOG_FILE"
    exit 1
fi

echo "$(date): yt-dlp updated to $(yt-dlp --version)" >> "$LOG_FILE"
