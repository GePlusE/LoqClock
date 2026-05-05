# LoqClock

LoqClock is a local-only macOS menu bar app for tracking working hours and overtime.

The product goal is simple:
- track work time quickly
- show overtime balances for total, week, month, and year
- show when the user can leave to reach `0` overtime today
- show when the user can leave to reach `0` overtime this week

## Current Status

The MVP app is implemented locally and can be built, packaged, and tested from this repository.

The core product and engineering rules are defined in [PRODUCT_SPEC.md](./PRODUCT_SPEC.md).

## Product Constraints

- local only
- menu bar icon only
- fast and lightweight
- no cloud sync
- no holiday or vacation detection
- no flexible weekly contract logic
- import/export is part of MVP
- charts/statistics and reminders belong to MVP 2.0

## MVP Summary

- native macOS menu bar app
- Swift + SwiftUI
- manual time tracking
- default workday:
  - `8h` target work
  - `1h` lunch
- per-day overrides for target work duration and lunch duration
- balances:
  - total
  - week
  - month
  - year
- leave predictions:
  - `0 today`
  - `0 this week`
- local persistence
- JSON and CSV import/export

## Core Rule

If a day has no entry, it contributes:
- `0 worked`
- `0 expected`
- `0 balance`

Do not infer holidays, weekends, or expected workdays from missing dates.

## Implementation Order

Recommended order:
1. bootstrap app shell
2. implement persistence and domain models
3. implement calculations
4. implement settings and day editing
5. implement start/end tracking flow
6. implement main popover UI
7. implement import/export
8. polish and QA

## GitHub Backlog

The initial backlog exists as GitHub issues `#1` through `#8`.

## Packaging

Apple Silicon packaging is scriptable from this repo:

1. Build the app bundle and DMG:
   `./Packaging/build-app.sh`
2. Validate the generated release artifacts:
   `./Packaging/validate-release.sh`

Artifacts are written to:
- `Artifacts/LoqClock.app`
- `Artifacts/LoqClock-apple-silicon.dmg`

Optional version overrides:
- `LOQCLOCK_VERSION=0.1.0 ./Packaging/build-app.sh`
- `LOQCLOCK_BUILD_NUMBER=1 ./Packaging/build-app.sh`

## GitHub Releases

Draft GitHub Release publishing is also scriptable:

1. Review the documented flow in [RELEASE.md](./RELEASE.md)
2. Dry run the publish helper:
   `./Packaging/publish-release.sh --version 0.1.0 --notes-file Packaging/release-notes-template.md --dry-run`
3. Publish the draft release:
   `./Packaging/publish-release.sh --version 0.1.0 --notes-file Packaging/release-notes-template.md`

## For New Codex Sessions

Start with:
1. read [PRODUCT_SPEC.md](./PRODUCT_SPEC.md)
2. read [AGENTS.md](./AGENTS.md)
3. inspect open GitHub issues
4. implement one issue at a time with small commits
