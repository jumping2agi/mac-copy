#!/usr/bin/env bash
#
# Build MenuBarTool with SwiftPM and package it into a .app bundle.
#
# Usage:
#   ./Scripts/build.sh              # release build -> build/MenuBarTool.app
#   ./Scripts/build.sh debug        # debug build
#   ./Scripts/build.sh run          # build (release) and launch the app
#   ./Scripts/build.sh zip          # build + create MenuBarTool.zip for distribution
set -euo pipefail

CONFIG="release"
ACTION="build"
case "${1:-}" in
  debug) CONFIG="debug" ;;
  run)   ACTION="run" ;;
  zip)   ACTION="zip" ;;
esac

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/build"
APP_BUNDLE="$BUILD_DIR/MenuBarTool.app"

echo "==> Building ($CONFIG) with SwiftPM..."
BIN_PATH="$(swift build -c "$CONFIG" --show-bin-path)"
swift build -c "$CONFIG"

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
chmod +x "$APP_BUNDLE/Contents/MacOS/MenuBarTool"
cp "$ROOT_DIR/Resources/Info.plist" "$APP_BUNDLE/Contents/Info.plist"

# Ad-hoc sign so the bundle launches without Gatekeeper blocking on macOS 11+.
# Replace with a Developer ID certificate for notarized distribution.
echo "==> Ad-hoc code signing..."
codesign --sign - --force --deep "$APP_BUNDLE" 2>/dev/null || \
  echo "    (codesign skipped — not running on macOS)"

echo "==> Done."
echo "    App:  $APP_BUNDLE"
echo "    Run:  open \"$APP_BUNDLE\""

if [[ "$ACTION" == "run" ]]; then
  echo "==> Launching…"
  open "$APP_BUNDLE"
elif [[ "$ACTION" == "zip" ]]; then
  ZIP="$BUILD_DIR/MenuBarTool.zip"
  echo "==> Creating $ZIP"
  rm -f "$ZIP"
  cd "$BUILD_DIR"
  ditto -c -k --keepParent "MenuBarTool.app" "$ZIP"
  echo "    Zip:  $ZIP"
fi
