#!/bin/bash
# Toggle garage door via Home Assistant API
# Triggered by: garage topic action button

LOG_FILE="/tmp/garage.log"

# Home Assistant configuration
HA_URL="http://homeassistant.local:8123"
HA_TOKEN="your_long_lived_access_token"
ENTITY_ID="cover.garage_door"

echo "$(date): Toggling garage door..." >> "$LOG_FILE"

curl -s -X POST \
    -H "Authorization: Bearer $HA_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{\"entity_id\": \"$ENTITY_ID\"}" \
    "$HA_URL/api/services/cover/toggle" >> "$LOG_FILE" 2>&1

echo "$(date): Garage door command sent" >> "$LOG_FILE"
