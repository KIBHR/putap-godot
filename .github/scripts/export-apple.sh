#!/usr/bin/env bash
set -euo pipefail
: "${GODOT:?Godot executable not configured}"
if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "Apple exports require macOS" >&2
  exit 1
fi
cd godot
mkdir -p build/macos build/ios
"$GODOT" --headless --editor --path . --import --quit
"$GODOT" --headless --path . --export-release macOS build/macos/Potap.zip
test -s build/macos/Potap.zip

# An iOS Xcode project can be generated without committing private signing
# credentials, but Godot still requires an Apple Team ID.
if [[ -z "${APPLE_TEAM_ID:-}" ]]; then
  echo "iOS export skipped: APPLE_TEAM_ID secret is missing."
  exit 0
fi
cp export_presets.cfg "${RUNNER_TEMP:-/tmp}/potap-export-presets-backup.cfg"
trap 'cp "${RUNNER_TEMP:-/tmp}/potap-export-presets-backup.cfg" export_presets.cfg' EXIT
python3 - <<'PY'
import os
from pathlib import Path
p = Path('export_presets.cfg')
s = p.read_text()
tid = os.environ['APPLE_TEAM_ID']
if len(tid) != 10 or not tid.isalnum():
    raise SystemExit("Invalid Apple Team ID; expected 10 alphanumeric characters")
s = s.replace('application/app_store_team_id=""', f'application/app_store_team_id="{tid}"')
p.write_text(s)
PY
"$GODOT" --headless --path . --export-debug iOS build/ios/Potap.zip
test -s build/ios/Potap.zip
