# Signing And Notarization Prep

This repository is prepared for signed and notarized public distribution, but the final release path is currently blocked on real Apple Developer credentials.

## Current Status

Prepared now:
- stable bundle identifier: `com.gepluse.loqclock`
- Apple Silicon `.app` and `.dmg` packaging scripts
- validation of app bundle metadata and DMG layout
- a signing/notarization helper script that can be dry-run safely

Blocked now:
- actual Developer ID signing
- actual notarization submission
- final Gatekeeper-clean public release verification

## Required Future Inputs

Real signing/notarization runs require:

- `LOQCLOCK_DEVELOPER_ID_APPLICATION`
  - example shape: `Developer ID Application: Your Name (TEAMID)`
- `LOQCLOCK_NOTARY_PROFILE`
  - keychain profile configured for `xcrun notarytool`
- `LOQCLOCK_TEAM_ID`
  - Apple Developer Team ID

These are intentionally not hardcoded or faked in the repository.

## Dry Run

You can inspect the prepared workflow without credentials:

```zsh
./Packaging/sign-and-notarize.sh --dry-run
```

This prints the exact commands that will later be used for:
- app signing
- app verification
- DMG signing
- notarization submission
- stapling
- Gatekeeper assessment

## Intended Real Flow

Once credentials are available:

```zsh
LOQCLOCK_DEVELOPER_ID_APPLICATION="Developer ID Application: Example (TEAMID)" \
LOQCLOCK_NOTARY_PROFILE="loqclock-notary" \
LOQCLOCK_TEAM_ID="TEAMID" \
./Packaging/sign-and-notarize.sh
```

## Design Decisions Kept Stable For Later

- bundle identifier: `com.gepluse.loqclock`
- platform target: Apple Silicon, macOS 14+
- release artifact type: `.dmg`
- distribution surface: GitHub Releases

## What This Issue Does Not Claim Yet

- The repository is not claiming notarized public-release readiness today.
- The repository is not storing fake certificate names or placeholder secrets.
- CI-based notarization automation is intentionally deferred.
