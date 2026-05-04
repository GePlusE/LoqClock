#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/.build/apple-silicon-release"
ARTIFACTS_DIR="$ROOT_DIR/Artifacts"
APP_NAME="LoqClock.app"
APP_DIR="$ARTIFACTS_DIR/$APP_NAME"
DMG_DIR="$ARTIFACTS_DIR/LoqClock-dmg"
DMG_PATH="$ARTIFACTS_DIR/LoqClock-apple-silicon.dmg"
EXECUTABLE_PATH="$BUILD_DIR/arm64-apple-macosx/release/LoqClock"
PLIST_TEMPLATE="$ROOT_DIR/Packaging/LoqClock-Info.plist"
PLIST_OUTPUT="$APP_DIR/Contents/Info.plist"

export HOME=/tmp
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer

echo "Building LoqClock for Apple Silicon release..."
swift build \
  --configuration release \
  --arch arm64 \
  --scratch-path "$BUILD_DIR"

if [[ ! -x "$EXECUTABLE_PATH" ]]; then
  echo "Expected executable not found at $EXECUTABLE_PATH" >&2
  exit 1
fi

echo "Preparing app bundle..."
rm -rf "$APP_DIR" "$DMG_DIR" "$DMG_PATH"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources" "$DMG_DIR"
cp "$EXECUTABLE_PATH" "$APP_DIR/Contents/MacOS/LoqClock"
cp "$PLIST_TEMPLATE" "$PLIST_OUTPUT"
chmod 755 "$APP_DIR/Contents/MacOS/LoqClock"

plutil -replace CFBundleShortVersionString -string "${LOQCLOCK_VERSION:-0.1.0}" "$PLIST_OUTPUT"
plutil -replace CFBundleVersion -string "${LOQCLOCK_BUILD_NUMBER:-1}" "$PLIST_OUTPUT"

echo "Preparing DMG staging folder..."
cp -R "$APP_DIR" "$DMG_DIR/"
ln -s /Applications "$DMG_DIR/Applications"

echo "Creating DMG artifact..."
hdiutil create \
  -volname "LoqClock" \
  -srcfolder "$DMG_DIR" \
  -ov \
  -format UDZO \
  "$DMG_PATH" >/dev/null

echo
echo "Built app bundle: $APP_DIR"
echo "Built DMG: $DMG_PATH"
