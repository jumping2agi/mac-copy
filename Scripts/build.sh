#!/usr/bin/env bash
#
# Build MenuBarTool with SwiftPM and package it into a .app bundle.
#
# Usage:
#   ./Scripts/build.sh              # release build -> build/MenuBarTool.app
#   ./Scripts/build.sh debug        # debug build
#   ./Scripts/build.sh run          # build (release) and launch the app
set -euo pipefail

CONFIG="release"
[[ "${1:-}" == "debug" ]] && CONFIG="debug"

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/build"
APP_BUNDLE="$BUILD_DIR/MenuBarTool.app"

echo "==> Building ($CONFIG) with SwiftPM..."
swift build -c "$CONFIG"

# Resolve the path to the built executable for the current arch.
BIN_PATH="$(swift build -c "$CONFIG" --show-bin-path)"
EXECUTABLE="$BIN_PATH/MenuBarTool"
if [[ ! -x "$EXECUTABLE" ]]; then
  echo "error: built executable not found at $EXECUTABLE" >&2
  exit 1
fi

echo "==> Packaging .app bundle at $APP_BUNDLE"
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

cp "$EXECUTABLE" "$APP_BUNDLE/Contents/MacOS/MenuBarTool"
cp "$ROOT_DIR/Resources/Info.plist" "$APP_BUNDLE/Contents/Info.plist"

echo "==> Done."
echo "    App:  $APP_BUNDLE"
echo "    Run:  open \"$APP_BUNDLE\""

if [[ "${1:-}" == "run" ]]; then
  echo "==> Launching…"
  open "$APP_BUNDLE"
fi
