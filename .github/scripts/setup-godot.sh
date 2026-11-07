#!/usr/bin/env bash
set -euo pipefail
# Official Godot 4.7.2 release artifacts. Works on GitHub Linux/macOS runners.
VERSION="4.7.2"
TAG="${VERSION}-stable"
BASE="https://github.com/godotengine/godot-builds/releases/download/${TAG}"
mkdir -p "${RUNNER_TEMP:-/tmp}/potap-tools"
TOOLS="${RUNNER_TEMP:-/tmp}/potap-tools"

if [[ "$(uname -s)" == "Darwin" ]]; then
  curl -fL --retry 3 -o "$TOOLS/godot.zip" "$BASE/Godot_v${TAG}_macos.universal.zip"
  unzip -q "$TOOLS/godot.zip" -d "$TOOLS"
  GODOT=$(find "$TOOLS" -path '*/Contents/MacOS/Godot' -type f -print -quit)
else
  curl -fL --retry 3 -o "$TOOLS/godot.zip" "$BASE/Godot_v${TAG}_linux.x86_64.zip"
  unzip -q "$TOOLS/godot.zip" -d "$TOOLS"
  GODOT=$(find "$TOOLS" -type f -name "Godot_v${TAG}_linux.x86_64" -print -quit)
fi
test -n "$GODOT"
chmod +x "$GODOT"
echo "GODOT=$GODOT" >> "$GITHUB_ENV"
"$GODOT" --headless --version

if [[ "${1:-}" == "--templates" ]]; then
  curl -fL --retry 3 -o "$TOOLS/templates.tpz" "$BASE/Godot_v${TAG}_export_templates.tpz"
  mkdir -p "$TOOLS/export-templates"
  unzip -q "$TOOLS/templates.tpz" -d "$TOOLS/export-templates"
  target="${HOME}/.local/share/godot/export_templates/${VERSION}.stable"
  if [[ "$(uname -s)" == "Darwin" ]]; then
    target="${HOME}/Library/Application Support/Godot/export_templates/${VERSION}.stable"
  fi
  mkdir -p "$target"
  cp -R "$TOOLS/export-templates/templates/." "$target/"
  test -f "$target/web_nothreads_release.zip" || find "$target" -maxdepth 1 -type f | head -10
fi
