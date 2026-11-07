#!/usr/bin/env bash
set -euo pipefail
: "${GODOT:?Godot executable not configured}"
cd godot
mkdir -p build/windows build/linux build/web
"$GODOT" --headless --path . --editor --import --quit
"$GODOT" --headless --path . --export-release "Windows Desktop" build/windows/Potap.exe
"$GODOT" --headless --path . --export-release Linux build/linux/Potap.x86_64
chmod +x build/linux/Potap.x86_64
"$GODOT" --headless --path . --export-release Web build/web/potap.html
cp ../docs/potap-ui.css ../docs/potap-ui.js build/web/
cp build/web/potap.html build/web/index.html
# Exports must be playable, not just empty directories.
test -s build/windows/Potap.exe
test -s build/linux/Potap.x86_64
test -s build/web/potap.pck
test -s build/web/potap.html
test -s build/web/index.html
