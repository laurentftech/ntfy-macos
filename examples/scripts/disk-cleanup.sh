#!/bin/bash
# Clean up disk space when storage is low
# Triggered by: disk-alerts topic

LOG_FILE="/tmp/disk-cleanup.log"
MESSAGE="$1"

echo "$(date): Disk cleanup triggered: $MESSAGE" >> "$LOG_FILE"

# Clear Homebrew cache
if command -v brew &> /dev/null; then
    brew cleanup --prune=all >> "$LOG_FILE" 2>&1
fi

# Clear pip cache
if command -v pip3 &> /dev/null; then
    pip3 cache purge >> "$LOG_FILE" 2>&1
fi

# Clear npm cache
if command -v npm &> /dev/null; then
    npm cache clean --force >> "$LOG_FILE" 2>&1
fi

# Clear Xcode derived data (optional, uncomment if needed)
# rm -rf ~/Library/Developer/Xcode/DerivedData/* >> "$LOG_FILE" 2>&1

# Clear system caches (user only)
rm -rf ~/Library/Caches/com.apple.Safari/Cache.db 2>/dev/null
rm -rf ~/Library/Caches/Google/Chrome/Default/Cache/* 2>/dev/null

echo "$(date): Disk cleanup complete" >> "$LOG_FILE"

# Report free space
FREE_SPACE=$(df -h / | awk 'NR==2 {print $4}')
echo "$(date): Free space after cleanup: $FREE_SPACE" >> "$LOG_FILE"
