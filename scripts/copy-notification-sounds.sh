#!/bin/bash
set -euo pipefail

DESTINATION="${1:?Usage: copy-notification-sounds.sh <app-resources-directory>}"
SOUND_NAMES=(Glass Basso Blow Bottle Frog Funk Hero Morse Ping Pop Purr Sosumi Submarine Tink)

mkdir -p "$DESTINATION"

for sound_name in "${SOUND_NAMES[@]}"; do
    sound_path="/System/Library/Sounds/${sound_name}.aiff"
    if [[ ! -f "$sound_path" ]]; then
        echo "Required macOS notification sound is missing: $sound_path" >&2
        exit 1
    fi
    cp "$sound_path" "$DESTINATION/${sound_name}.aiff"
done
