# Release Process

This repository uses a manual but repeatable GitHub Release flow.

Current scope:
- artifact type: Apple Silicon `.dmg`
- distribution surface: GitHub Releases
- release style: intentional `gh`-driven publishing, not CI automation

## Prerequisites

- GitHub CLI authenticated with permission to create releases in `GePlusE/LoqClock`
- Xcode installed locally
- Apple Silicon Mac

## Release Steps

1. Choose the release version, for example `0.1.0`.
2. Optionally update the release notes file:
   - [Packaging/release-notes-template.md](/Users/gepluse/Coding/LoqClock/Packaging/release-notes-template.md)
3. Run a dry run first:

```zsh
./Packaging/publish-release.sh \
  --version 0.1.0 \
  --notes-file Packaging/release-notes-template.md \
  --dry-run
```

4. Publish the draft GitHub Release:

```zsh
./Packaging/publish-release.sh \
  --version 0.1.0 \
  --notes-file Packaging/release-notes-template.md
```

5. Review the draft release on GitHub and confirm the uploaded DMG artifact.

## What The Script Does

- builds the Apple Silicon release DMG unless `--skip-build` is used
- validates the generated app bundle and DMG layout
- creates a draft GitHub Release if the tag does not exist yet
- or updates the existing release metadata and re-uploads the DMG with `--clobber`

## Useful Options

- `--build-number 2`
- `--title "LoqClock 0.1.0"`
- `--skip-build`
- `--dry-run`

## Notes

- The publish flow does not sign or notarize the app yet.
- Signing and notarization are tracked separately in issue `#14`.
- Analytics and auto-update work are tracked separately and are not part of this release flow.
