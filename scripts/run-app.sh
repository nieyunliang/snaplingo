#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="Snaplingo"
APP_IDENTIFIER="com.snaplingo.app"
APP_BUNDLE="$ROOT_DIR/.build/snaplingo-dev/$APP_NAME.app"
CONTENTS_DIR="$APP_BUNDLE/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

cd "$ROOT_DIR"

swift build
BIN_DIR="$(swift build --show-bin-path)"

rm -rf "$APP_BUNDLE"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

cp "$BIN_DIR/$APP_NAME" "$MACOS_DIR/$APP_NAME"
chmod +x "$MACOS_DIR/$APP_NAME"
cp "$ROOT_DIR/Packaging/Info.plist" "$CONTENTS_DIR/Info.plist"

RESOURCE_BUNDLE="$BIN_DIR/${APP_NAME}_${APP_NAME}.bundle"
if [[ -d "$RESOURCE_BUNDLE" ]]; then
    cp -R "$RESOURCE_BUNDLE" "$RESOURCES_DIR/"
fi

if [[ -d "$ROOT_DIR/Packaging/Resources" ]]; then
    cp -R "$ROOT_DIR/Packaging/Resources/." "$RESOURCES_DIR/"
fi

codesign --force --deep --identifier "$APP_IDENTIFIER" --sign - "$APP_BUNDLE"

stop_app() {
    pkill -x "$APP_NAME" >/dev/null 2>&1 || true
}

stop_app
trap stop_app EXIT INT TERM

echo "Starting $APP_NAME..."
echo "The app will appear in the macOS menu bar."
echo "Press Ctrl+C in this terminal to stop it."

/usr/bin/open -n -W "$APP_BUNDLE"
