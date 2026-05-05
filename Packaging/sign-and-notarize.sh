#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ARTIFACTS_DIR="$ROOT_DIR/Artifacts"
APP_DIR="$ARTIFACTS_DIR/LoqClock.app"
DMG_PATH="$ARTIFACTS_DIR/LoqClock-apple-silicon.dmg"
DRY_RUN=0
SKIP_BUILD=0
VERSION="${LOQCLOCK_VERSION:-0.1.0}"
BUILD_NUMBER="${LOQCLOCK_BUILD_NUMBER:-1}"
BUNDLE_IDENTIFIER="${LOQCLOCK_BUNDLE_IDENTIFIER:-com.gepluse.loqclock}"

required_env=(
  LOQCLOCK_DEVELOPER_ID_APPLICATION
  LOQCLOCK_NOTARY_PROFILE
  LOQCLOCK_TEAM_ID
)

usage() {
  cat <<'EOF'
Usage:
  ./Packaging/sign-and-notarize.sh [options]

Options:
  --dry-run      Print the signing/notarization plan without executing it
  --skip-build   Reuse existing app and DMG artifacts instead of rebuilding them
  --help         Show this help

Required environment variables for a real run:
  LOQCLOCK_DEVELOPER_ID_APPLICATION  Developer ID Application certificate name
  LOQCLOCK_NOTARY_PROFILE            notarytool keychain profile name
  LOQCLOCK_TEAM_ID                   Apple Developer Team ID

Optional environment variables:
  LOQCLOCK_VERSION
  LOQCLOCK_BUILD_NUMBER
  LOQCLOCK_BUNDLE_IDENTIFIER
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    --skip-build)
      SKIP_BUILD=1
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

missing_env=()
for key in "${required_env[@]}"; do
  if [[ -z "${(P)key:-}" ]]; then
    missing_env+=("$key")
  fi
done

if [[ $SKIP_BUILD -eq 0 ]]; then
  echo "Preparing unsigned release artifacts..."
  LOQCLOCK_VERSION="$VERSION" LOQCLOCK_BUILD_NUMBER="$BUILD_NUMBER" LOQCLOCK_BUNDLE_IDENTIFIER="$BUNDLE_IDENTIFIER" \
    "$ROOT_DIR/Packaging/build-app.sh"
  "$ROOT_DIR/Packaging/validate-release.sh"
fi

[[ -d "$APP_DIR" ]] || { echo "Missing app bundle: $APP_DIR" >&2; exit 1; }
[[ -f "$DMG_PATH" ]] || { echo "Missing DMG artifact: $DMG_PATH" >&2; exit 1; }

SIGN_APP_CMD=(
  codesign
  --force
  --options runtime
  --timestamp
  --sign "${LOQCLOCK_DEVELOPER_ID_APPLICATION:-<Developer ID Application>}"
  "$APP_DIR"
)

VERIFY_APP_CMD=(
  codesign
  --verify
  --deep
  --strict
  --verbose=2
  "$APP_DIR"
)

SIGN_DMG_CMD=(
  codesign
  --force
  --timestamp
  --sign "${LOQCLOCK_DEVELOPER_ID_APPLICATION:-<Developer ID Application>}"
  "$DMG_PATH"
)

NOTARIZE_CMD=(
  xcrun
  notarytool
  submit
  "$DMG_PATH"
  --keychain-profile "${LOQCLOCK_NOTARY_PROFILE:-<notary profile>}"
  --wait
)

STAPLE_CMD=(
  xcrun
  stapler
  staple
  "$DMG_PATH"
)

ASSESS_CMD=(
  spctl
  --assess
  --type
  open
  --context
  context:primary-signature
  --verbose=4
  "$DMG_PATH"
)

if [[ $DRY_RUN -eq 1 ]]; then
  echo "Dry run signing/notarization plan for bundle identifier $BUNDLE_IDENTIFIER"
  if [[ ${#missing_env[@]} -gt 0 ]]; then
    echo "Missing required environment variables for a real run:"
    printf '  - %s\n' "${missing_env[@]}"
  fi
  for cmd in SIGN_APP_CMD VERIFY_APP_CMD SIGN_DMG_CMD NOTARIZE_CMD STAPLE_CMD ASSESS_CMD; do
    printf '  %q' "${(@P)cmd}"
    printf '\n'
  done
  exit 0
fi

if [[ ${#missing_env[@]} -gt 0 ]]; then
  echo "Cannot sign or notarize yet. Missing required environment variables:" >&2
  printf '  - %s\n' "${missing_env[@]}" >&2
  echo "Use --dry-run to inspect the prepared workflow without credentials." >&2
  exit 1
fi

echo "Signing app bundle..."
"${SIGN_APP_CMD[@]}"

echo "Verifying signed app bundle..."
"${VERIFY_APP_CMD[@]}"

echo "Signing DMG artifact..."
"${SIGN_DMG_CMD[@]}"

echo "Submitting DMG for notarization..."
"${NOTARIZE_CMD[@]}"

echo "Stapling notarization ticket..."
"${STAPLE_CMD[@]}"

echo "Assessing final DMG..."
"${ASSESS_CMD[@]}"

echo "Signing and notarization flow completed."
