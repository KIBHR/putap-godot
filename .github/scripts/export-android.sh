#!/usr/bin/env bash
set -euo pipefail
: "${GODOT:?Godot executable not configured}"
: "${ANDROID_HOME:?Android SDK not configured}"
: "${JAVA_HOME:?Java SDK not configured}"
# Avoid exporting release keys or passwords to build logs.
mkdir -p "$HOME/.android"
if [[ ! -f "$HOME/.android/debug.keystore" ]]; then
  keytool -genkeypair -noprompt -keystore "$HOME/.android/debug.keystore" \
    -alias androiddebugkey -storepass android -keypass android \
    -dname "CN=Android Debug,O=Android,C=US" -keyalg RSA -keysize 2048 -validity 10000
fi
export GODOT_ANDROID_KEYSTORE_DEBUG_PATH="$HOME/.android/debug.keystore"
export GODOT_ANDROID_KEYSTORE_DEBUG_USER=androiddebugkey
export GODOT_ANDROID_KEYSTORE_DEBUG_PASSWORD=android
cd godot
mkdir -p build/android
"$GODOT" --headless --editor --path . --script res://scripts/setup_android_sdk.gd
"$GODOT" --headless --editor --path . --import --quit
"$GODOT" --headless --path . --export-debug Android build/android/Potap-debug.apk
test -s build/android/Potap-debug.apk
