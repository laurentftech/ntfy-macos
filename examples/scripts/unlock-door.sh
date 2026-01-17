#!/bin/bash
# Unlock front door via Home Assistant API
# Triggered by: doorbell topic action button

LOG_FILE="/tmp/door.log"

# Home Assistant configuration
HA_URL="http://homeassistant.local:8123"
HA_TOKEN="your_long_lived_access_token"
ENTITY_ID="lock.front_door"

echo "$(date): Unlocking front door..." >> "$LOG_FILE"

curl -s -X POST \
    -H "Authorization: Bearer $HA_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{\"entity_id\": \"$ENTITY_ID\"}" \
    "$HA_URL/api/services/lock/unlock" >> "$LOG_FILE" 2>&1

echo "$(date): Front door unlock command sent" >> "$LOG_FILE"
