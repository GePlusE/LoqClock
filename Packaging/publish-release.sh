#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ARTIFACTS_DIR="$ROOT_DIR/Artifacts"
DMG_PATH="$ARTIFACTS_DIR/LoqClock-apple-silicon.dmg"
VERSION=""
BUILD_NUMBER="1"
NOTES_FILE=""
SKIP_BUILD=0
DRY_RUN=0
RELEASE_TITLE=""
REPO="GePlusE/LoqClock"

usage() {
  cat <<'EOF'
Usage:
  ./Packaging/publish-release.sh --version <version> [options]

Options:
  --version <version>       Release version, for example 0.1.0
  --build-number <number>   Bundle build number used during packaging (default: 1)
  --notes-file <path>       Markdown file to use as the release notes body
  --title <title>           Override release title (default: LoqClock <version>)
  --skip-build              Reuse the existing DMG instead of rebuilding it
  --dry-run                 Print the gh commands without creating or updating a release
  --help                    Show this help

Examples:
  ./Packaging/publish-release.sh --version 0.1.0
  ./Packaging/publish-release.sh --version 0.1.0 --notes-file Packaging/release-notes-template.md --dry-run
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --version)
      VERSION="${2:-}"
      shift 2
      ;;
    --build-number)
      BUILD_NUMBER="${2:-}"
      shift 2
      ;;
    --notes-file)
      NOTES_FILE="${2:-}"
      shift 2
      ;;
    --title)
      RELEASE_TITLE="${2:-}"
      shift 2
      ;;
    --skip-build)
      SKIP_BUILD=1
      shift
      ;;
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    --help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [[ -z "$VERSION" ]]; then
  echo "Missing required --version value." >&2
  usage >&2
  exit 1
fi

if [[ -z "$RELEASE_TITLE" ]]; then
  RELEASE_TITLE="LoqClock $VERSION"
fi

TAG="v$VERSION"

export HOME=/tmp
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer

if [[ $SKIP_BUILD -eq 0 ]]; then
  echo "Building and validating release artifacts for $TAG..."
  LOQCLOCK_VERSION="$VERSION" LOQCLOCK_BUILD_NUMBER="$BUILD_NUMBER" "$ROOT_DIR/Packaging/build-app.sh"
  "$ROOT_DIR/Packaging/validate-release.sh"
else
  echo "Skipping build and validation. Reusing existing artifacts."
fi

[[ -f "$DMG_PATH" ]] || {
  echo "Missing DMG artifact: $DMG_PATH" >&2
  exit 1
}

NOTES_ARGS=()
if [[ -n "$NOTES_FILE" ]]; then
  [[ -f "$NOTES_FILE" ]] || {
    echo "Notes file not found: $NOTES_FILE" >&2
    exit 1
  }
  NOTES_ARGS=(--notes-file "$NOTES_FILE")
else
  NOTES_ARGS=(--notes "LoqClock $VERSION Apple Silicon DMG release.")
fi

RELEASE_EXISTS=0
if gh release view "$TAG" --repo "$REPO" >/dev/null 2>&1; then
  RELEASE_EXISTS=1
fi

if [[ $RELEASE_EXISTS -eq 1 ]]; then
  CREATE_OR_EDIT_CMD=(gh release edit "$TAG" --repo "$REPO" --title "$RELEASE_TITLE" "${NOTES_ARGS[@]}")
  UPLOAD_CMD=(gh release upload "$TAG" "$DMG_PATH" --repo "$REPO" --clobber)
else
  CREATE_OR_EDIT_CMD=(gh release create "$TAG" "$DMG_PATH" --repo "$REPO" --title "$RELEASE_TITLE" --draft "${NOTES_ARGS[@]}")
  UPLOAD_CMD=()
fi

if [[ $DRY_RUN -eq 1 ]]; then
  echo "Dry run:"
  printf '  %q' "${CREATE_OR_EDIT_CMD[@]}"
  printf '\n'

  if [[ ${#UPLOAD_CMD[@]} -gt 0 ]]; then
    printf '  %q' "${UPLOAD_CMD[@]}"
    printf '\n'
  fi

  exit 0
fi

echo "Publishing GitHub Release for $TAG..."
"${CREATE_OR_EDIT_CMD[@]}"

if [[ ${#UPLOAD_CMD[@]} -gt 0 ]]; then
  "${UPLOAD_CMD[@]}"
fi

echo "Release flow completed for $TAG."
