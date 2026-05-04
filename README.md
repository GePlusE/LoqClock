# LoqClock

LoqClock is a local-only macOS menu bar app for tracking working hours and overtime.

The product goal is simple:
- track work time quickly
- show overtime balances for total, week, month, and year
- show when the user can leave to reach `0` overtime today
- show when the user can leave to reach `0` overtime this week

## Current Status

This repository is in pre-implementation setup.

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

## For New Codex Sessions

Start with:
1. read [PRODUCT_SPEC.md](./PRODUCT_SPEC.md)
2. read [AGENTS.md](./AGENTS.md)
3. inspect open GitHub issues
4. implement one issue at a time with small commits
