#!/bin/bash
# Run Time Machine backup or custom backup script
# Triggered by: backup-trigger topic (silent)

LOG_FILE="/tmp/backup.log"
MESSAGE="$1"

echo "$(date): Backup triggered with message: $MESSAGE" >> "$LOG_FILE"

# Option 1: Trigger Time Machine
# tmutil startbackup >> "$LOG_FILE" 2>&1

# Option 2: Run rsync backup
SOURCE="/Users/$(whoami)/Documents"
DEST="/Volumes/Backup/Documents"

if [ -d "$DEST" ]; then
    rsync -av --delete "$SOURCE/" "$DEST/" >> "$LOG_FILE" 2>&1
    echo "$(date): Backup complete" >> "$LOG_FILE"
else
    echo "$(date): Backup destination not mounted" >> "$LOG_FILE"
    exit 1
fi
