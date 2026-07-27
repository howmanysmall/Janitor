#!/usr/bin/env bash

set -euo pipefail

contents='{ "FFlagEnableLoadModule": true }'
path="/Applications/RobloxStudio.app/Contents/MacOS/ClientSettings/ClientAppSettings.json"

mkdir -p "$(dirname "$path")"
touch "$path"
printf '%s\n' "$contents" > "$path"
