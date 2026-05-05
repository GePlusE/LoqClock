#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ARTIFACTS_DIR="$ROOT_DIR/Artifacts"
APP_DIR="$ARTIFACTS_DIR/LoqClock.app"
DMG_PATH="$ARTIFACTS_DIR/LoqClock-apple-silicon.dmg"
MOUNT_ROOT="$ARTIFACTS_DIR/LoqClock-mount"
MOUNT_OUTPUT="$(mktemp)"

cleanup() {
  if mount | grep -q "$MOUNT_ROOT"; then
    hdiutil detach "$MOUNT_ROOT" -quiet || true
  fi
  rm -rf "$MOUNT_ROOT"
  rm -f "$MOUNT_OUTPUT"
}
trap cleanup EXIT

[[ -d "$APP_DIR" ]] || { echo "Missing app bundle: $APP_DIR" >&2; exit 1; }
[[ -f "$DMG_PATH" ]] || { echo "Missing DMG artifact: $DMG_PATH" >&2; exit 1; }
[[ -x "$APP_DIR/Contents/MacOS/LoqClock" ]] || { echo "Missing executable in app bundle." >&2; exit 1; }
[[ -f "$APP_DIR/Contents/Info.plist" ]] || { echo "Missing Info.plist in app bundle." >&2; exit 1; }

ARCHITECTURES="$(lipo -archs "$APP_DIR/Contents/MacOS/LoqClock")"
[[ "$ARCHITECTURES" == "arm64" ]] || {
  echo "Expected arm64-only app binary, found: $ARCHITECTURES" >&2
  exit 1
}

MINIMUM_SYSTEM_VERSION="$(defaults read "$APP_DIR/Contents/Info" LSMinimumSystemVersion)"
[[ "$MINIMUM_SYSTEM_VERSION" == "14.0" ]] || {
  echo "Expected minimum macOS version 14.0, found: $MINIMUM_SYSTEM_VERSION" >&2
  exit 1
}

BUNDLE_IDENTIFIER="$(defaults read "$APP_DIR/Contents/Info" CFBundleIdentifier)"
[[ "$BUNDLE_IDENTIFIER" == "com.gepluse.loqclock" ]] || {
  echo "Expected bundle identifier com.gepluse.loqclock, found: $BUNDLE_IDENTIFIER" >&2
  exit 1
}

mkdir -p "$MOUNT_ROOT"

echo "Mounting DMG for validation..."
hdiutil attach "$DMG_PATH" -mountpoint "$MOUNT_ROOT" -nobrowse >"$MOUNT_OUTPUT"

[[ -d "$MOUNT_ROOT/LoqClock.app" ]] || { echo "Mounted DMG does not contain LoqClock.app" >&2; exit 1; }
[[ -L "$MOUNT_ROOT/Applications" ]] || { echo "Mounted DMG does not contain Applications shortcut" >&2; exit 1; }

echo "App bundle and DMG layout validated."
