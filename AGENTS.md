# LoqClock Agent Notes

This file is optimized for coding agents working in this repository.

## Read First

- `PRODUCT_SPEC.md`: authoritative product and engineering rules
- `README.md`: high-level project overview

If repository code and spec conflict, prefer the explicit product decisions already agreed in `PRODUCT_SPEC.md` unless the user says otherwise.

## Project Goal

Build a polished, local-only macOS menu bar app for work-time tracking and overtime visibility.

Primary UX promise:
- instant glanceability
- minimal menu bar footprint
- native macOS feel

## Non-Negotiable Rules

- menu bar must show icon only, not text
- app is local only
- no account system
- no cloud sync
- no public holiday or vacation detection
- no flexible weekly contract logic
- import/export is required for MVP
- charts/statistics/reminders are not MVP

## Most Important Calculation Rule

If a day has no entry:
- `0 worked`
- `0 expected`
- `0 balance`

This applies equally to weekdays and weekends.

Do not auto-generate expected hours for missing days.

## Default Settings

- target work duration: `480` minutes
- lunch duration: `60` minutes

Both are overridable per day.

## MVP Architecture Direction

Preferred:
- Swift
- SwiftUI
- `MenuBarExtra`
- lightweight local persistence

Possible persistence choices:
- SwiftData
- SQLite
- JSON-backed storage

Choose the simplest option that keeps calculations correct and editing stable.

## Working Style

- implement one GitHub issue at a time where possible
- keep changes scoped
- prefer correctness of calculations over fancy UI
- prefer native components over custom complexity
- follow the latest Apple Human Interface Guidelines and current macOS UX conventions

## Git / Delivery Expectations

- commit in small logical steps
- push frequently when meaningful progress exists
- do not rewrite history unless explicitly requested

## Suggested Startup Checklist For A Fresh Session

1. read `PRODUCT_SPEC.md`
2. read `README.md`
3. review open issues and current branch state
4. confirm which issue or slice is being implemented
5. keep the `0 expected hours for missing days` rule visible during implementation
