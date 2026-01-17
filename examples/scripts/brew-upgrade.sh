#!/bin/bash
# Upgrade all Homebrew packages
# Triggered by: homebrew-updates topic

LOG_FILE="/tmp/brew-upgrade.log"

echo "$(date): Starting Homebrew upgrade..." >> "$LOG_FILE"

export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

brew update >> "$LOG_FILE" 2>&1
brew upgrade >> "$LOG_FILE" 2>&1
brew cleanup >> "$LOG_FILE" 2>&1

echo "$(date): Homebrew upgrade complete" >> "$LOG_FILE"
